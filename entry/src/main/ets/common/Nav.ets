/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { webview } from '@kit.ArkWeb';
import { window, promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { inputMethod } from '@kit.IMEKit';
import { Palette } from './Palette';
import { themeDef } from './ThemeConfig';

// 统一状态栏工具：一处设定，所有页面复用
export class BarUtil {
  // 原版App样式的自绘顶栏配套状态栏色。默认主题=品牌蓝(和 blue() 完全一致)，
  // 豆泥主题=accent 深棕，和 ClassicHeader/TabTitleBar 的顶栏同色。
  static topBar(theme: string): void {
    try {
      // 装饰主题用各自 accent，默认主题保持品牌蓝（Palette.accent(default) 正好就是它）
      const c: string = Palette.accent(theme);
      window.getLastWindow(getContext() as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowSystemBarProperties({ statusBarColor: c, statusBarContentColor: '#FFFFFF' });
      });
    } catch (e) {
    }
  }

  // 上下两段配色，两个色都取自小豆泥身上的采样色：
  //   上段状态栏 = accent #9A7855（毛发灰棕提亮一档），白图标
  //   下段导航条/网页/窗口底 = page #FAF4EC（奶油体色）
  // 都是 Palette 里已有的 token，没有新增色值，也没改任何已有色值。
  // 默认主题走原来的浅色状态栏 + barSoft 导航条，行为与豆泥主题出现前完全一致。
  static gray(): void {
    try {
      const theme: string | undefined = AppStorage.get<string>('dsh_theme');
      const t: string = theme === undefined ? '' : theme;
      const def = themeDef(t);
      window.getLastWindow(getContext() as common.UIAbilityContext).then((win: window.Window) => {
        win.setWindowSystemBarProperties({
          statusBarColor: def.titleOnAccent ? Palette.accent(t) : Palette.bar(t),
          statusBarContentColor: def.statusBarLight ? '#FFFFFF' : '#000000',
          navigationBarColor: def.titleOnAccent ? Palette.page(t) : Palette.barSoft(t),
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
    Router.releaseInput();
  }

  /**
   * 释放网页输入框的输入会话和焦点。
   *
   * 搜索页 H5 的输入框会自动聚焦。焦点留在 input 上时，返回键会被 Web 组件当成
   * 「编辑中的返回」消费掉，NavDestination 弹栈收不到，用户就卡在搜索页退不出来。
   * 子页隐藏时（onHidden）调这里，结束输入会话 + 把焦点挪到不可见的非输入节点，
   * 让返回键重新落到导航上。只做焦点收尾，不拦任何跳转。
   */
  static releaseInput(): void {
    try {
      inputMethod.getController().stopInputSession();
    } catch (e) {
    }
    const c: webview.WebviewController | undefined = WebRegistry.activeController();
    if (c === undefined) {
      return;
    }
    const js: string =
      '(function(){try{var a=document.activeElement;' +
      'if(a&&(a.blur)){a.blur();}' +
      'var list=document.querySelectorAll("input,textarea,[contenteditable=true]");' +
      'for(var i=0;i<list.length;i++){try{list[i].blur();}catch(e){}}' +
      'var sink=document.getElementById("__dsh_focus_sink");' +
      'if(!sink&&document.body){sink=document.createElement("button");' +
      'sink.id="__dsh_focus_sink";sink.setAttribute("tabindex","-1");' +
      'sink.style.cssText="position:fixed;left:-9999px;top:-9999px;width:1px;height:1px;opacity:0;border:0;padding:0;";' +
      'document.body.appendChild(sink);}' +
      'if(sink){try{sink.focus();}catch(e){}}' +
      '}catch(e){}})()';
    // 焦点可能在页面重新可见后才恢复，多补几次；用户再碰网页时由 onTouch 停掉
    Router.releaseTimers.forEach((t: number) => clearTimeout(t));
    Router.releaseTimers = [];
    const run = (): void => {
      try {
        c.runJavaScript(js);
      } catch (e) {
      }
    };
    run();
    const times: number[] = [120, 400, 900, 1600];
    for (let i = 0; i < times.length; i++) {
      Router.releaseTimers.push(setTimeout(run, times[i]));
    }
  }

  private static releaseTimers: number[] = [];

  /** 用户又碰网页：停止焦点补扫，别抢走正在输入的输入框 */
  static stopRelease(): void {
    Router.releaseTimers.forEach((t: number) => clearTimeout(t));
    Router.releaseTimers = [];
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
