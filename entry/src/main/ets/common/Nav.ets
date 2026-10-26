/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { webview } from '@kit.ArkWeb';
import { window, promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';

// 统一状态栏工具：一处设定，所有页面复用
export class BarUtil {
  static blue(): void {
    try {
      window.getLastWindow(getContext() as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowSystemBarProperties({ statusBarColor: '#2D8CFA', statusBarContentColor: '#FFFFFF' });
      });
    } catch (e) {
    }
  }

  static white(): void {
    try {
      window.getLastWindow(getContext() as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowSystemBarProperties({ statusBarColor: '#FFFFFF', statusBarContentColor: '#000000' });
      });
    } catch (e) {
    }
  }

  // 页面/标题栏统一浅灰背景时使用，避免状态栏与标题栏出现白灰割裂；
  // 原生样式下底部导航条与悬浮 Tab 的灰色材质底色对齐，消除小白条白底突兀感
  static gray(): void {
    try {
      window.getLastWindow(getContext() as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowSystemBarProperties({
          statusBarColor: '#F7F8FA',
          statusBarContentColor: '#000000',
          navigationBarColor: '#F4F5F7',
          navigationBarContentColor: '#000000'
        });
      });
    } catch (e) {
    }
  }
}

// 全局子页面路由：任何组件都可以通过 Router.openSub 打开带系统转场动画的子页面
export class Router {
  static stack: NavPathStack = new NavPathStack();

  static openSub(url: string, onPop?: () => void): void {
    if (!url) {
      return;
    }
    // Web 组件 src 只认 http(s) 与 resource://rawfile/
    // 这里放开 resource:// 是因为 Opener 会把 file:///android_asset/ 映射成它，
    // 早先只认 $rawfile 前缀，映射后的地址会被这行判断静默丢掉（点了没反应）。
    const isRaw = url.startsWith('$rawfile/') || url.startsWith('resource://rawfile/');
    if (!url.startsWith('http://') && !url.startsWith('https://') && !isRaw) {
      promptAction.showToast({ message: '暂不支持打开这个地址', duration: 1800 });
      return;
    }
    const target = url.startsWith('$rawfile/') ? `resource://rawfile/${url.substring(9)}` : url;
    if (onPop !== undefined) {
      Router.stack.pushPathByName('web', target, () => {
        onPop();
      }, true);
      return;
    }
    Router.stack.pushPathByName('web', target, true);
  }

  static pop(): void {
    if (Router.stack.size() > 0) {
      // 带 result 弹出，确保 push 时注册的 onPop 回调会执行（协议页返回后恢复隐私弹层）
      Router.stack.pop('', true);
    }
  }

  // 交给系统浏览器处理（如 .apk 直链），失败时回落应用内打开
  static openExternal(url: string): void {
    try {
      const ctx = getContext() as common.UIAbilityContext;
      const want: Want = { action: 'ohos.want.action.viewData', uri: url };
      ctx.startAbility(want).catch(() => {
        Router.openSub(url);
      });
    } catch (e) {
      Router.openSub(url);
    }
  }
}

// 各 WebTab 的控制器注册表：供返回键、卡登录页刷新等全局逻辑使用
export class WebRegistry {
  private static controllers: Map<string, webview.WebviewController> = new Map();
  private static activeTab: string = '';

  static put(id: string, c: webview.WebviewController): void {
    WebRegistry.controllers.set(id, c);
  }

  static remove(id: string): void {
    WebRegistry.controllers.delete(id);
  }

  static setActive(id: string): void {
    WebRegistry.activeTab = id;
  }

  static activeController(): webview.WebviewController | undefined {
    if (!WebRegistry.activeTab) {
      return undefined;
    }
    return WebRegistry.controllers.get(WebRegistry.activeTab);
  }

  static controllerOf(id: string): webview.WebviewController | undefined {
    return WebRegistry.controllers.get(id);
  }

  // 主 Tab 若一直停在登录页，主会话登录成功后刷新它们
  static refreshStuckLoginTabs(isStuck: (url: string) => boolean): void {
    WebRegistry.controllers.forEach((c, id) => {
      if (id === WebRegistry.activeTab) {
        return;
      }
      try {
        const u = c.getUrl();
        if (u && isStuck(u)) {
          c.refresh();
        }
      } catch (e) {
      }
    });
  }
}
