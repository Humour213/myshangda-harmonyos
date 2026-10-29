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

/** 每一节的开始时间（和桌面卡片保持一致） */
const PERIOD_START: string[] = [
  '08:05', '08:50', '09:50', '10:40', '11:30', '13:40',
  '14:35', '15:30', '16:25', '18:30', '19:25', '20:20'
];

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
  /** 课表变了就重建，没变但提醒没了（被系统回收/被手动删）也重建 */
  static async sync(ctx: common.UIAbilityContext, data: ScheduleData): Promise<void> {
    if (data.courses.length === 0) {
      return;
    }
    // 用户在设置里关掉了就不发。顺手把上次发布的那批清掉，
    // 免得关了开关之后系统里还留着旧提醒继续响。
    const on: boolean = await PrefsStore.isRemindOn(ctx);
    if (!on) {
      const alive: number = await Reminders.aliveCount();
      if (alive > 0) {
        try {
          await Reminders.cancelAll();
        } catch (err) {
          hilog.warn(DOMAIN, 'reminder', 'cancel failed');
        }
      }
      return;
    }
    const uniq: CourseItem[] = Reminders.unique(data.courses);
    const fp: string = Reminders.fingerprint(uniq);

    let store: preferences.Preferences | null = null;
    let oldFp: string = '';
    try {
      store = await PrefsStore.getStore(ctx);
      oldFp = (await store.get(KEY_FP, '')) as string;
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'prefs unavailable');
    }

    // 课表没变、系统里也确实还挂着我们的提醒 —— 什么都不用做。
    // 反过来说，只要一条都不剩了，哪怕指纹相同也要补回来。
    const alive: number = await Reminders.aliveCount();
    if (fp === oldFp && alive > 0) {
      return;
    }

    try {
      await Reminders.cancelAll();
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'cancel failed');
    }

    // 通知权限：没给就申请一次。用户拒过之后系统不会再弹，这里也就不再纠缠。
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification();
      }
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'notification permission not granted');
    }

    const total: number = uniq.length;
    const n: number = total < MAX_REMINDERS ? total : MAX_REMINDERS;
    if (total > MAX_REMINDERS) {
      hilog.warn(DOMAIN, 'reminder', 'too many courses %{public}d, keep %{public}d', total, MAX_REMINDERS);
    }
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
      Reminders.publish(c, hm, hour, minute);
    }

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
   * 同一格（星期 + 节次）只留一门课。
   * 单双周会在同一格里叠两门课，提醒只需要响一次，重复发会被系统当成骚扰。
   */
  private static unique(courses: CourseItem[]): CourseItem[] {
    const out: CourseItem[] = [];
    const seen: string[] = [];
    for (let i = 0; i < courses.length; i++) {
      const c: CourseItem = courses[i];
      const key: string = c.day + '-' + c.start;
      if (seen.indexOf(key) >= 0) {
        continue;
      }
      seen.push(key);
      out.push(c);
    }
    // 按时间排好，条数超上限时截断才不会漏掉周一的课
    out.sort((a: CourseItem, b: CourseItem): number => {
      if (a.day !== b.day) {
        return a.day - b.day;
      }
      return a.start - b.start;
    });
    return out;
  }

  private static fingerprint(courses: CourseItem[]): string {
    let fp: string = '';
    for (let i = 0; i < courses.length; i++) {
      const c: CourseItem = courses[i];
      fp += c.day + ':' + c.start + ':' + c.name + ':' + c.place + ';';
    }
    return fp;
  }

  /** 系统里还挂着几条我们自己的提醒 */
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
      return 0;
    }
  }

  private static publish(c: CourseItem, hm: string, hour: number, minute: number): void {
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
      wantAgent: {
        pkgName: PKG_NAME,
        abilityName: 'EntryAbility'
      },
      actionButton: []
    };
    reminderAgentManager.publishReminder(req).then(() => {
      hilog.info(DOMAIN, 'reminder', 'published %{public}s at %{public}d:%{public}d',
        c.name, hour, minute);
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'reminder', 'publish failed: %{public}s', err.message);
    });
  }

  /** 只取消我们自己发的提醒，不动用户自己的日历提醒 */
  static async cancelAll(): Promise<void> {
    const list: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
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
}
