/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { notificationManager } from '@kit.NotificationKit';
import { PrefsStore } from '../common/PrefsStore';
import { Reminders } from './Reminders';
import { CardSync } from './CardSync';

const DOMAIN = 0x0000;
const TAG = 'Session';

/** 待办通知的 id，和 Index.notifyNewTodos 里的一致 */
const TODO_NOTICE_ID: number = 1001;

/**
 * 会话管理：退出登录。
 *
 * 之前「我的」页里点退出登录没反应，是因为 H5 调的是原生桥的 exitLogin，
 * 而桥里那格是空的（空实现会把点击吞掉，页面看起来完全没响应）。现在统一走这里。
 *
 * 清理分两档，别混用：
 *
 *   clearAll()     —— 用户主动退出登录。本机所有和这个人有关的东西全清：
 *                     cookie、网页 localStorage/IndexedDB、离线缓存文件、
 *                     账号密码、待办角标、已排的上课提醒。
 *   clearSession() —— 只是会话失效（密码改了、票据过期、密码输错）。
 *                     只清 cookie 和账号密码，离线缓存和提醒留着 ——
 *                     用户重新登录后课表、桌面卡片不用再等一次抓取。
 *
 * 以前只有一档，而且只清了 cookie：换账号后进「我的」，看到的还是上一个人的
 * 姓名、学号、成绩、一卡通余额（都是 localStorage 里 __dsh_http_cache_v1__ 缓存的
 * 接口响应），桌面卡片也还挂着上一个人的课表 —— 这是实打实的数据串号。
 */
export class Session {
  /** 用户主动退出：全清 */
  static async clearAll(): Promise<void> {
    const ctx = getContext() as common.UIAbilityContext;

    Session.clearCookies();

    // 网页存储：localStorage 里存着接口响应的离线副本（姓名、学号、成绩、余额都在里面），
    // 不清的话换账号后新用户能直接看到上一个人的数据。
    // IndexedDB / Web SQL 一并带走，否则旧页面还可能从缓存里起来。
    // 注意这个接口是同步返回 void 的（不是 Promise），而且必须在 Web 组件已经加载过之后调用，
    // 所以放在退出登录的时机正好 —— 此时页面还活着。
    try {
      webview.WebStorage.deleteAllData();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear web storage failed');
    }

    // 落盘缓存：三个 json 分别喂「我的」页资料、待办列表、桌面卡片
    Session.wipeFiles(ctx);

    try {
      await PrefsStore.clearLogin(ctx);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear login failed');
    }

    // 待办通知和桌面图标上的数字，否则退出后还挂着「您有 3 条待办」
    try {
      await notificationManager.cancel(TODO_NOTICE_ID);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'cancel todo notice failed');
    }
    try {
      await notificationManager.setBadgeNumber(0);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear badge failed');
    }

    // 已排的上课提醒：不退的话换账号后还会按上一个人的课表响，而且响的是别人的课名。
    // 重新登录后 CardSync 抓完课表会自动再排一遍（alive=0 会触发重建），不用手动补。
    try {
      await Reminders.cancelAll();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'cancel reminders failed');
    }

    Session.resetState();
    hilog.info(DOMAIN, TAG, 'logout: all local data cleared');
  }

  /** 只是会话失效：保留离线缓存与提醒 */
  static async clearSession(): Promise<void> {
    const ctx = getContext() as common.UIAbilityContext;
    Session.clearCookies();
    try {
      await PrefsStore.clearLogin(ctx);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear login failed');
    }
    Session.resetState();
  }

  private static clearCookies(): void {
    try {
      webview.WebCookieManager.clearAllCookiesSync();
      webview.WebCookieManager.clearSessionCookieSync();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear cookie failed');
    }
  }

  /** 删掉本机缓存的 json，删不掉的（不存在 / 被占用）不视为错误 */
  private static wipeFiles(ctx: common.UIAbilityContext): void {
    const paths: string[] = [
      `${ctx.filesDir}/basic.json`,
      `${ctx.filesDir}/todo.json`,
      // 和 CardSync 里的 FILE_NAME 是同一个文件，别单独写死
      CardSync.filePath(ctx)
    ];
    for (let i = 0; i < paths.length; i++) {
      const p: string = paths[i];
      try {
        if (fileIo.accessSync(p)) {
          fileIo.unlinkSync(p);
          hilog.info(DOMAIN, TAG, 'removed %{public}s', p);
        }
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'remove failed %{public}s', p);
      }
    }
  }

  /**
   * 通知界面切回登录页。
   * Index 用 @StorageLink('dsh_logout_ts') 监听，时间戳必须真的变（同一毫秒内两次登出也要变），
   * 所以这里保底 +1。
   */
  private static resetState(): void {
    const old: number = AppStorage.get<number>('dsh_logout_ts') ?? 0;
    const now: number = Date.now();
    AppStorage.setOrCreate('dsh_session_user', '');
    AppStorage.setOrCreate('dsh_session_pass', '');
    // 待办计数归零，否则下一次抓到的条数比它小，就不会再推通知、不再亮角标
    AppStorage.setOrCreate('dsh_last_todo', 0);
    AppStorage.setOrCreate('dsh_logout_ts', now > old ? now : old + 1);
  }

  /** 原生页里调用：先确认再退出 */
  static confirmAndClear(): void {
    promptAction.showDialog({
      title: '退出登录',
      message: '将清除本机保存的账号信息、离线缓存与已排的上课提醒',
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '退出', color: '#D93025' }
      ]
    }).then((res: promptAction.ShowDialogSuccessResponse) => {
      if (res.index === 1) {
        Session.clearAll().then(() => {
          promptAction.showToast({ message: '已退出登录', duration: 1800 });
        });
      }
    }).catch(() => {
      // 用户关掉弹窗
    });
  }
}
