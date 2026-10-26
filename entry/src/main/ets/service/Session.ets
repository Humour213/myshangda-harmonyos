import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrefsStore } from '../common/PrefsStore';

const DOMAIN = 0x0000;
const TAG = 'Session';

/**
 * 会话管理：退出登录。
 *
 * 之前「我的」页里点退出登录没反应，是因为 H5 调的是原生桥的 exitLogin，
 * 而桥里那格是空的（空实现会把点击吞掉，页面看起来完全没响应）。
 * 现在统一走这里：
 *   1. 清 WebView 的 Cookie（不清存储，离线缓存还能用）；
 *   2. 清本机保存的账号密码；
 *   3. 通过 AppStorage 通知首页切回登录页。
 */
export class Session {
  /** 只清会话，不弹窗（H5 侧已经确认过了） */
  static async clearAll(): Promise<void> {
    const ctx = getContext() as common.UIAbilityContext;
    try {
      webview.WebCookieManager.clearAllCookiesSync();
      webview.WebCookieManager.clearSessionCookieSync();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear cookie failed');
    }
    try {
      await PrefsStore.clearLogin(ctx);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'clear login failed');
    }
    AppStorage.setOrCreate('dsh_session_user', '');
    AppStorage.setOrCreate('dsh_session_pass', '');
    AppStorage.setOrCreate('dsh_logout_ts', Date.now());
  }

  /** 原生页里调用：先确认再退出 */
  static confirmAndClear(): void {
    const ctx = getContext() as common.UIAbilityContext;
    promptAction.showDialog({
      title: '退出登录',
      message: '将清除本机保存的账号信息与网页登录状态',
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
    // 保持 ctx 引用，避免个别设备上 getContext 在异步回调里失效
    if (ctx === undefined) {
      hilog.warn(DOMAIN, TAG, 'no context');
    }
  }
}
