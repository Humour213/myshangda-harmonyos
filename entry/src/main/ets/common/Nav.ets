/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { webview } from '@kit.ArkWeb';
import { window, promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
  /** 最近一次压栈的地址与时间：用来挡住「同一个地址被连续压两次」 */
  private static lastUrl: string = '';
  private static lastTs: number = 0;
  /** 最近一次子页返回的时间：返回瞬间网页常会自己再跳一次，这段时间内不收开子页请求 */
  private static lastPopTs: number = 0;
  /** 返回后的静默期：足够盖住「焦点复原 → H5 自动跳转」这一次，又不影响正常点击 */
  private static readonly POP_QUIET_MS: number = 700;
  /** 子页最多叠这么多层，超过就不再压栈 */
  private static readonly MAX_DEPTH: number = 6;

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
    // 防循环：同一个地址在 1.2 秒内被再次请求就直接忽略。
    // 有些 H5 页面（首页搜索框就是一例）在加载完之后又自己调一次 openWeb / 或者页面自己
    // 改了顶层地址触发 Index.onRouteEvent，两条路各压一层子页，子页里再触发一次 ——
    // 用户看到的就是「不停跳转」，一路推下去根本停不下来。
    const now: number = Date.now();
    if (target === Router.lastUrl && now - Router.lastTs < 1200) {
      hilog.warn(0x0001, 'Router', 'openSub ignored (repeat) %{public}s', target);
      return;
    }
    // 刚从一个子页退回来：这时候网页往往会把焦点还给上次点过的输入框，
    // H5 的 onfocus 里有跳转逻辑就会立刻再开一次 —— 用户看到的就是「退出又进来」。
    // 返回后给它一个很短的不应期，把这一下挡住；正常点击基本不会落在 0.7 秒内。
    if (now - Router.lastPopTs < Router.POP_QUIET_MS) {
      hilog.warn(0x0001, 'Router', 'openSub ignored (just popped) %{public}s', target);
      return;
    }
    // 防深：真出现「A 打开 B、B 又打开 A」这种交替循环时，按时间戳挡不住，按层数总能挡住
    if (Router.stack.size() >= Router.MAX_DEPTH) {
      hilog.warn(0x0001, 'Router', 'openSub blocked (depth %{public}d)', Router.stack.size());
      promptAction.showToast({ message: '页面层级太深，请返回后再试', duration: 1800 });
      return;
    }
    Router.lastUrl = target;
    Router.lastTs = now;
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
    Router.lastPopTs = Date.now();
    Router.blurUnderlying();
  }

  /**
   * 清掉底下那层网页里的焦点。
   *
   * 首页搜索框是个输入框：点它 → 拿到焦点 → H5 的 onfocus 里跳到搜索页 → 我们开子页。
   * 子页退出后 ArkWeb 会把焦点还给那个输入框，H5 的 onfocus 于是又跳一次 ——
   * 用户看到的就是「退出又进来」反复横跳。0.2.27 靠「同一地址 5 秒内不重复开」压过，
   * 但真人进搜索页输字看结果再退出，早就超过 5 秒，闸门等于不存在。
   *
   * 这里在返回时直接把 input/textarea 的焦点摘掉，从源头断掉这次自动跳转。
   * 分几个时间点补几次：焦点是页面重新可见时由内核恢复的，晚了就漏。
   */
  private static blurUnderlying(): void {
    const c: webview.WebviewController | undefined = WebRegistry.activeController();
    if (c === undefined) {
      return;
    }
    const js: string =
      '(function(){try{var a=document.activeElement;' +
      'if(a&&(a.tagName==="INPUT"||a.tagName==="TEXTAREA"||a.isContentEditable===true)){a.blur();return "blur";}' +
      'return "none";}catch(e){return "err";}})()';
    try {
      c.runJavaScript(js);
    } catch (e) {
    }
    // 焦点是页面重新可见之后由内核恢复的，可能比 pop 动画晚一点，所以补两次
    setTimeout(() => {
      try {
        c.runJavaScript(js);
      } catch (e) {
      }
    }, 150);
    setTimeout(() => {
      try {
        c.runJavaScript(js);
      } catch (e) {
      }
    }, 450);
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
