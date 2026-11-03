/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CourseItem, ScheduleData } from '../common/ScheduleTypes';
import { PrefsStore } from '../common/PrefsStore';
import { PERIOD_START } from '../common/Periods';
import { uniqueCourses, courseFingerprint, countableCount } from './ReminderPlan';

const DOMAIN = 0x0000;
/** 提前几分钟提醒 */
const AHEAD_MIN: number = 10;
/**
 * 系统对单个应用的提醒条数是有限的（30 条），留两条余量。
 * 一门课一条按周重复的闹钟，一周排满也就十几二十条，比按天铺开省得多。
 */
const MAX_REMINDERS: number = 28;
/** 提醒标题，用来识别并清理我们自己发的提醒 */
const TITLE: string = '上课提醒';
/** 点击提醒拉起的包名，必须与本工程一致 */
const PKG_NAME: string = 'com.humour.myshangda';
/** 课表指纹，用来判断提醒需不需要重建 */
const KEY_FP: string = 'reminder_fp';

/**
 * 课表 → 按周重复的上课提醒。
 *
 * 这里以前用的是「日历型 + 只排未来 3 天」，有两个要命的地方：
 *  1. 只有课表内容发生变化时才重排（CardSync 里的 txt !== before 判断）。
 *     可课表一学期都不变，所以排完第一次之后就再也不会重排；
 *  2. 3 天的窗口到期就用完了，第 4 天起系统里一条有效提醒都没有，而且不会自己补。
 * 两个凑一块，表现就是「刚装上一两天响过，之后再也不响」。
 *
 * 现在改成闹钟型（REMINDER_TYPE_ALARM）+ daysOfWeek 按周重复：
 * 一门课发一条，发布一次就长期有效，不依赖用户天天打开 App 来续命。
 * 课表真的变了（调课、换老师、换教室）时靠指纹发现并重建。
 */
export class Reminders {
  /** sync 的串行队列，见 sync() 里的说明 */
  private static chain: Promise<void> = Promise.resolve();

  /**
   * 串行入口。
   *
   * 首页每次加载完（WebTab.onPageEnd）和设置页开关都会调 sync，两处完全可能撞在一起：
   * 第二次进来时第一次的提醒还在异步发布中，aliveCount() 读到的仍是 0，
   * 于是又 cancelAll + 再发一遍 —— 重复闹钟、把系统 30 条配额打满、后半批发布全失败。
   * 这里用一条 Promise 链把调用排队，保证同一时刻只有一次在跑。
   */
  static sync(ctx: common.UIAbilityContext, data: ScheduleData): Promise<void> {
    const run = (): Promise<void> => Reminders.doSync(ctx, data).catch((): void => {
    });
    const next: Promise<void> = Reminders.chain.then(run, run);
    Reminders.chain = next;
    return next;
  }

  /** 课表变了就重建，没变但提醒少了（被系统回收/被手动删）也重建 */
  private static async doSync(ctx: common.UIAbilityContext, data: ScheduleData): Promise<void> {
    if (data.courses.length === 0) {
      return;
    }
    // 用户在设置里关掉了就不发。顺手把上次发布的那批清掉，
    // 免得关了开关之后系统里还留着旧提醒继续响。
    const on: boolean = await PrefsStore.isRemindOn(ctx);
    if (!on) {
      hilog.info(DOMAIN, 'reminder', 'switch off, skip');
      const alive: number = await Reminders.aliveCount();
      // alive 为 -1 表示读不到列表（未知），这种情况也要清一次，
      // 宁可多发一次清空请求，也不要让关了开关的提醒继续响。
      if (alive !== 0) {
        try {
          await Reminders.cancelAll();
        } catch (err) {
          hilog.warn(DOMAIN, 'reminder', 'cancel failed');
        }
      }
      return;
    }
    const uniq: CourseItem[] = uniqueCourses(data.courses);
    const fp: string = courseFingerprint(uniq);

    let store: preferences.Preferences | null = null;
    let oldFp: string = '';
    try {
      store = await PrefsStore.getStore(ctx);
      oldFp = (await store.get(KEY_FP, '')) as string;
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'prefs unavailable');
    }

    // 课表没变、系统里也确实还挂着我们的提醒 —— 什么都不用做。
    //
    // 判据必须是「现存条数 >= 应发条数」，不能只判 alive > 0：
    // 实际丢失是渐进的（撞上限被挤掉、单条发布失败、用户在时钟里删掉几条），
    // 只要还剩一条，alive > 0 就会一直判定「还活着」，缺的那几门永远补不回来。
    let expect: number = countableCount(uniq);
    if (expect > MAX_REMINDERS) {
      expect = MAX_REMINDERS;
    }
    const alive: number = await Reminders.aliveCount();
    hilog.info(DOMAIN, 'reminder', 'sync: courses=%{public}d expect=%{public}d fpSame=%{public}s alive=%{public}d',
      uniq.length, expect, fp === oldFp ? 'y' : 'n', alive);
    if (fp === oldFp && alive >= expect && expect > 0) {
      return;
    }

    try {
      await Reminders.cancelAll();
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'cancel failed');
    }

    // 通知权限：直接申请一次，没授过就弹框，授过就立即返回。
    // 这里不能先问 isNotificationEnabled —— 在这个场景下它会谎报「已开启」，
    // 于是永远走不到申请那一步，通知就一直关着，提醒全被系统拒掉。
    // 另外必须传 ctx：空参的重载从 API 12 起就废弃了，调了根本不弹框。
    // 先把这个渠道建出来。
    // 提醒到点是走通知发出来的，而系统在提醒配额那一步会先看应用有没有可用的通知渠道；
    // 渠道不存在时它直接判定「notification not allowed」，再把配额算成 0 条
    //（日志原文：ReminderControl ... notification not allowed / The number of reminders exceeds the limit[0]），
    // 于是一条提醒也发不出去。重复调用是幂等的，已存在不会报错。
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION);
      hilog.info(DOMAIN, 'reminder', 'slot ready');
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'addSlot failed: %{public}s', Reminders.errText(err));
    }

    try {
      await notificationManager.requestEnableNotification(ctx);
      hilog.info(DOMAIN, 'reminder', 'notification granted');
    } catch (err) {
      // 用户点了「不允许」，或系统不再允许弹框（之前拒过一次就再也不弹）。
      // 记下错误码，不然「提醒不响」永远只能靠猜。
      hilog.warn(DOMAIN, 'reminder', 'requestEnableNotification failed: %{public}s', Reminders.errText(err));
    }

    const total: number = uniq.length;
    const n: number = total < MAX_REMINDERS ? total : MAX_REMINDERS;
    hilog.info(DOMAIN, 'reminder', 'republish %{public}d of %{public}d', n, total);
    if (total > MAX_REMINDERS) {
      hilog.warn(DOMAIN, 'reminder', 'too many courses %{public}d, keep %{public}d', total, MAX_REMINDERS);
    }
    // 逐条收集起来一起 await，全部发完才写指纹。
    // 原来是 fire-and-forget，紧接着就写指纹；只要有一条还没回来就写盘，
    // 下次 sync 看到「指纹已存、但 alive 不够」又会整批重发，撞上系统 30 条上限，
    // 后半批直接失败 —— 这正是「少了几门课的提醒」的由来。
    const tasks: Promise<void>[] = [];
    for (let i = 0; i < n; i++) {
      const c: CourseItem = uniq[i];
      const idx: number = c.start - 1;
      if (idx < 0 || idx >= PERIOD_START.length) {
        continue;
      }
      const hm: string = PERIOD_START[idx];
      const parts: string[] = hm.split(':');
      let hour: number = parseInt(parts[0]);
      let minute: number = parseInt(parts[1]) - AHEAD_MIN;
      // 提前 10 分钟可能跨到上一个小时（08:05 → 07:55）
      if (minute < 0) {
        minute += 60;
        hour -= 1;
      }
      // 再跨就跨到前一天了，上课时间不会早到这个程度，兜一下底避免负数
      if (hour < 0) {
        hour += 24;
      }
      tasks.push(Reminders.publish(c, hm, hour, minute));
    }
    await Promise.all(tasks);

    if (store !== null) {
      try {
        await store.put(KEY_FP, fp);
        await store.flush();
      } catch (err) {
        hilog.warn(DOMAIN, 'reminder', 'save fingerprint failed');
      }
    }
  }

  /**
   * 去重、指纹、可发条数这类**纯策略**已经搬到 service/ReminderPlan.ets ——
   * 那里不碰系统 API，可以单测；这里只负责调用系统和落盘。
   */

  /** 系统里还挂着几条我们自己的提醒；读不出来返回 -1（未知，不能当成 0） */
  private static async aliveCount(): Promise<number> {
    try {
      const list: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
      let n: number = 0;
      for (let i = 0; i < list.length; i++) {
        if (list[i].title === TITLE) {
          n++;
        }
      }
      return n;
    } catch (err) {
      // 以前这里静默 return 0，后果很严重：读不到就当「一条都没有」，
      // 于是每次进 App 都判定要重建 → 清不掉旧的（清空接口同样要读列表）→
      // 再发一批新的 → 撞上系统 30 条上限，后半批全失败，界面上就是「提醒时有时无」。
      // 现在明确区分「0 条」和「读不到」，读不到时只走清空 + 重发，并打日志。
      hilog.warn(DOMAIN, 'reminder', 'aliveCount failed: %{public}s', Reminders.errText(err));
      return -1;
    }
  }

  private static publish(c: CourseItem, hm: string, hour: number, minute: number): Promise<void> {
    const req: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      // 提前 10 分钟提醒，所以响的时间和上课时间差一截，正文里把上课时间写清楚
      hour: hour,
      minute: minute,
      // daysOfWeek 取值 1~7 对应周一到周日，而课表里的 day 是 0=周一
      daysOfWeek: [c.day + 1],
      title: TITLE,
      content: `${hm} 上课 · ${c.name} · ${c.place}`,
      expiredContent: '',
      snoozeTimes: 0,
      timeInterval: 0,
      ringDuration: 1,
      // 指定通知渠道。不指定时系统自己去查默认渠道，查不到就直接判「notification not allowed」，
      // 然后按 0 条配额处理（日志里是 The number of reminders exceeds the limit[0]）。
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      wantAgent: {
        pkgName: PKG_NAME,
        abilityName: 'EntryAbility'
      },
      actionButton: []
    };
    return reminderAgentManager.publishReminder(req).then((): void => {
      hilog.info(DOMAIN, 'reminder', 'published %{public}s at %{public}d:%{public}d',
        c.name, hour, minute);
    }).catch((err: Error): void => {
      hilog.warn(DOMAIN, 'reminder', 'publish failed: %{public}s', err.message);
    });
  }

  /**
   * 清掉本应用发出去的全部提醒。
   *
   * 先用 cancelAllReminders()：它不需要逐条枚举 id，一次清空，最可靠。
   * 这个应用只发布上课提醒，不会误删用户自己的日程提醒。
   *
   * 以前只走「getValidReminders() 拿列表 → 逐条 cancelReminder」这一条路，
   * 而列表接口在个别设备上会抛错（日志里的 ReminderAgentService Read result failed），
   * 一抛整批都删不掉，紧接着的 publish 就撞上「The number of reminders exceeds the limit」，
   * 一条也发不出去。这里保留逐条删作为兜底，并记下真实错误。
   */
  static async cancelAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
      hilog.info(DOMAIN, 'reminder', 'cancelAllReminders ok');
      return;
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'cancelAllReminders failed: %{public}s', Reminders.errText(err));
    }
    // 兜底：按标题逐条删（拿不到列表就什么也做不了，只能记日志）
    let list: reminderAgentManager.ReminderRequest[] = [];
    try {
      list = await reminderAgentManager.getValidReminders();
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'list reminders failed: %{public}s', Reminders.errText(err));
      return;
    }
    for (let i = 0; i < list.length; i++) {
      const r: reminderAgentManager.ReminderRequest = list[i];
      if (r.title !== TITLE) {
        continue;
      }
      try {
        // getValidReminders 返回的项带 reminderId，类型声明里没有，放宽后取
        const id: number = (r as object as Record<string, number>)['reminderId'];
        await reminderAgentManager.cancelReminder(id);
      } catch (err) {
        // 忽略单条失败
      }
    }
  }

  /** 把 BusinessError 变成一句能读的话，避免日志里只剩 [object Object] */
  private static errText(err: Object): string {
    const e = err as Record<string, Object>;
    const code: Object | undefined = e === null || e === undefined ? undefined : e['code'];
    const msg: Object | undefined = e === null || e === undefined ? undefined : e['message'];
    return `${code === undefined ? '?' : String(code)} ${msg === undefined ? '' : String(msg)}`;
  }
}
