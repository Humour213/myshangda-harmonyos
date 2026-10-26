/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { webview } from '@kit.ArkWeb';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { filePreview } from '@kit.PreviewKit';
import { common, Want, bundleManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http, connection } from '@kit.NetworkKit';
import { call } from '@kit.TelephonyKit';
import { ANDROID_BRIDGE_JS, SCHEDULE_FIX_JS, AUTO_LOGIN_JS, PAGE_BRIDGE_JS, NET_CACHE_JS } from '../service/BridgeScripts';
import { Router, WebRegistry } from '../common/Nav';
import { PrefsStore, SavedLogin } from '../common/PrefsStore';
import { isLoginUrl, isPortalUrl, isContactUrl, isHttpUrl, MOBILE_UA, OFFICIAL_APK_URL } from '../common/Constants';
import { CardSync } from '../service/CardSync';
import { Opener } from '../service/Opener';
import { Scanner } from '../service/Scanner';
import { Session } from '../service/Session';

// 注意：hilog 非 0 域在该设备上被过滤，统一用 0x0000 域保证日志可见
const DOMAIN = 0x0000;
const TAG = 'WebTab';

@Component
export struct WebTab {
  @Prop tabId: string = '';
  @Prop rootUrl: string = '';
  @Prop needLogin: boolean = false;
  @Prop loadNow: boolean = false;
  /** 首页 tab 打开：页面加载完后静默抓一次课表，供桌面卡片显示 */
  @Prop scrapeSchedule: boolean = false;
  @Prop @Watch('onActiveChange') active: boolean = false;
  onScrollEvent: (y: number) => void = (_y: number) => {};
  /** 网页区的滑动采样：dy>0 表示手指上移，dtMs 为本次采样间隔 */
  onSwipeEvent: (dy: number, dtMs: number) => void = (_dy: number, _dtMs: number) => {};
  onRouteEvent: (url: string) => void = (_url: string) => {};
  onTitleEvent: (t: string) => void = (_t: string) => {};

  @State loaded: boolean = false;
  @State isLoading: boolean = false;
  @State progress: number = 0;
  @State errMsg: string = '';
  @State showFallback: boolean = false;
  @State autoTries: number = 0;
  @State cacheMode: CacheMode = CacheMode.Default;
  @State offlineBanner: boolean = false;
  @State refreshing: boolean = false;
  @StorageLink('dsh_online') @Watch('onNetChange') online: boolean = true;
  /** 重新登录成功后（退出登录 → 再登）由 Index 递增，触发所有 tab 重载拿到新会话 */
  @StorageLink('dsh_relogin_ts') @Watch('onRelogin') reloginTs: number = 0;
  private showingOffline: boolean = false;
  private graceTimer: number = -1;
  private retryTimer: number = -1;
  private watchTimer: number = -1;
  private offlineTimer: number = -1;
  private refreshTimer: number = -1;
  private refreshPending: boolean = false;
  /** 上次真正触发刷新的时间：用来给下拉刷新做防抖 */
  private lastRefreshAt: number = 0;
  private watchExtended: boolean = false;
  private loadFailed: boolean = false;
  /** 底栏收放用的触摸采样 */
  private touchY: number = -1;
  private touchTs: number = 0;

  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: DshBridge | undefined = undefined;
  private dlDelegate: webview.WebDownloadDelegate | undefined = undefined;
  private ctxResult: WebContextMenuResult | undefined = undefined;
  private ctxImageUrl: string = '';
  private creds: SavedLogin = new SavedLogin();

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // 不再按启动瞬间的联网探测预判缓存模式：探测抖动会导致误走 Only，出现半截白页。
    // 统一先在线加载，失败/超时才自动切离线缓存（goOffline）。
    this.bridge = new DshBridge(
      (y: number) => this.onScrollEvent(y),
      (u: string) => this.onRouteEvent(u),
      () => this.requestLogout(),
      () => this.doScan(),
      (payload: string) => this.openFromWeb(payload)
    );
    this.dlDelegate = new webview.WebDownloadDelegate();
    this.dlDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      try {
        const dir = `${ctx.filesDir}/Download`;
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir, true);
        }
        item.start(`${dir}/${item.getSuggestedFileName()}`);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'download start failed %{public}s', JSON.stringify(e));
      }
    });
    this.dlDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      try {
        promptAction.showToast({ message: `下载完成：${item.getSuggestedFileName()}`, duration: 2500 });
        const path = item.getFullPath();
        if (path) {
          const info: filePreview.PreviewInfo = {
            uri: fileUri.getUriFromPath(path),
            title: item.getSuggestedFileName(),
            mimeType: item.getMimeType() ?? ''
          };
          filePreview.openPreview(ctx, info).catch(() => {});
        }
      } catch (e) {
      }
    });
    this.dlDelegate.onDownloadFailed((_item: webview.WebDownloadItem) => {
      promptAction.showToast({ message: '下载失败', duration: 2000 });
    });
    PrefsStore.getLogin(ctx).then((l: SavedLogin) => {
      this.creds = l;
    });
    // Web 的 src 会在挂载时自动发起加载；这里只预置离线策略。
    // 绝不能再调 loadUrl，否则和 src 的加载互相打断（ERR_ABORTED 后无任何页面事件，永久停在 10%）。
    if ((this.loadNow || this.active) && !this.online) {
      this.goOffline();
    }
  }

  aboutToDisappear(): void {
    WebRegistry.remove(this.tabId);
    this.clearGrace();
    this.stopRetryLoop();
    this.clearWatch();
    this.clearOfflineWatch();
    this.endRefresh();
  }

  // ===================== 网页桥过来的动作 =====================

  /** 网页里点了「退出登录」：确认 → 清会话 → 回登录页 */
  private requestLogout(): void {
    Session.confirmAndClear();
  }

  /** 网页里点了扫码（子页面也必须能用，之前只做了主页顶栏） */
  private async doScan(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const value: string = await Scanner.scan(ctx);
    if (value === '') {
      return;
    }
    // 优先把结果回给页面自己处理；页面没接就由原生兜底
    const lit: string = JSON.stringify(value);
    let handled: boolean = false;
    try {
      const r: string = await this.controller.runJavaScript(
        `(function(){try{if(typeof window.__dshScanCallback==="function"){window.__dshScanCallback(${lit});return "cb";}` +
        `if(typeof window.__dshScanResult==="function"){window.__dshScanResult(${lit});return "evt";}}catch(e){}return "none";})()`
      ) as string;
      handled = String(r).indexOf('cb') >= 0 || String(r).indexOf('evt') >= 0;
    } catch (e) {
      handled = false;
    }
    if (handled) {
      return;
    }
    if (/^https?:\/\//i.test(value)) {
      Router.openSub(value);
    } else {
      promptAction.showToast({ message: value, duration: 2500 });
    }
  }

  /** 网页要打开一个文件/附件：H5 里只给地址，下载与预览由原生做 */
  private openFromWeb(payload: string): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    let url: string = '';
    let name: string = '';
    try {
      const obj: Record<string, string> = JSON.parse(payload) as Record<string, string>;
      url = obj['u'] ?? '';
      name = obj['n'] ?? '';
    } catch (e) {
      // 老版本桥可能直接传地址
      url = payload;
    }
    if (url === '') {
      return;
    }
    hilog.info(DOMAIN, TAG, 'open from web %{public}s', url);
    Opener.openSmart(ctx, url, name);
  }

  /** 退出后重新登录：所有 tab 重载，把新会话带到每个页面 */
  onRelogin(): void {
    if (this.reloginTs <= 0) {
      return;
    }
    this.autoTries = 0;
    this.creds.user = AppStorage.get<string>('dsh_session_user') ?? '';
    this.creds.pass = AppStorage.get<string>('dsh_session_pass') ?? '';
    this.showingOffline = false;
    this.offlineBanner = false;
    this.loaded = false;
    this.errMsg = '';
    this.showFallback = false;
    this.reloadWithMode(CacheMode.Default);
  }

  onActiveChange(): void {
    if (this.active && !this.loaded && !this.isLoading) {
      if (!this.online) {
        this.goOffline();
      } else {
        // src 已在组件创建时加载过；走到这里说明此前没有任何页面事件，补一次热重载并上看门狗
        this.reloadWithMode(this.cacheMode);
      }
    }
  }

  // 系统网络变化：恢复联网立即重载在线页；断网时未加载的 tab 立刻亮缓存，已加载的只挂提示不打断
  onNetChange(): void {
    hilog.info(DOMAIN, TAG, 'net change online=%{public}s %{public}s', `${this.online}`, this.rootUrl);
    this.syncOfflineFlag();
    if (this.online) {
      if (this.showingOffline || this.showFallback || this.cacheMode === CacheMode.Only) {
        this.reconnect();
      }
      return;
    }
    if (!this.active) {
      return;
    }
    if (!this.loaded) {
      this.goOffline();
    } else if (this.loaded && !this.isLoading) {
      this.showingOffline = true;
      this.offlineBanner = true;
      this.syncOfflineFlag();
      this.startRetryLoop();
    }
  }

  doLoad(): void {
    if (this.loaded || this.isLoading) {
      return;
    }
    // rawfile 资源由 Web src 直接加载，controller.loadUrl 不支持该协议
    if (this.rootUrl.startsWith('$rawfile') || this.rootUrl.startsWith('resource://rawfile')) {
      this.isLoading = true;
      hilog.info(DOMAIN, TAG, 'rawfile skip loadUrl %{public}s', this.rootUrl);
      return;
    }
    if (!this.online) {
      this.cacheMode = CacheMode.Only;
      this.showingOffline = true;
      this.offlineBanner = true;
      this.armOfflineWatch();
      this.startRetryLoop();
    }
    this.isLoading = true;
    try {
      this.controller.loadUrl(this.rootUrl);
    } catch (e) {
      this.isLoading = false;
    }
  }

  reload(): void {
    try {
      this.errMsg = '';
      this.controller.refresh();
    } catch (e) {
      try {
        this.controller.loadUrl(this.rootUrl);
      } catch (e2) {
      }
    }
  }

  // cacheMode 属性要等状态重渲染后才生效；立刻 refresh 仍会走旧策略，故延迟一拍再刷
  reloadWithMode(mode: CacheMode): void {
    this.cacheMode = mode;
    this.loaded = false;
    this.isLoading = true;
    // 重载也可能既无 pageBegin 也无报错（例如缓存缺失），必须自上看门狗
    this.startWatch();
    setTimeout(() => {
      this.reload();
    }, 200);
  }

  // 在线慢时不要盲目切缓存（会掐断正常的门户首屏，留下半截白页）：
  // 定时探测服务是否可达，确认真连不上才自动亮离线缓存
  startGrace(): void {
    this.clearGrace();
    if (!isHttpUrl(this.rootUrl) || !this.online || this.cacheMode === CacheMode.Only) {
      return;
    }
    this.armGrace(4000);
  }

  private armGrace(delay: number): void {
    this.graceTimer = setTimeout(() => {
      this.graceTimer = -1;
      if (!this.isLoading || this.cacheMode === CacheMode.Only || !this.online) {
        return;
      }
      // 进度 10% 是导航刚开始的固定值，不代表服务器有响应；连接被挂住时会永远停在 10
      if (this.progress >= 25) {
        hilog.info(DOMAIN, TAG, 'online slow but responding %{public}d%', this.progress);
        this.armGrace(6000);
        return;
      }
      this.probeThenDecide();
    }, delay);
  }

  private async probeThenDecide(): Promise<void> {
    const ok = await this.probeOnline();
    if (!this.isLoading || this.cacheMode === CacheMode.Only) {
      return;
    }
    if (ok) {
      this.armGrace(6000);
      return;
    }
    hilog.warn(DOMAIN, TAG, 'probe failed, show offline cache %{public}s', this.rootUrl);
    this.goOffline();
  }

  private async probeOnline(): Promise<boolean> {
    try {
      if (!connection.hasDefaultNetSync()) {
        return false;
      }
    } catch (e) {
    }
    const req = http.createHttp();
    try {
      const resp = await req.request(this.rootUrl, {
        method: http.RequestMethod.GET,
        header: { 'User-Agent': MOBILE_UA },
        connectTimeout: 2500,
        readTimeout: 2500,
        expectDataType: http.HttpDataType.STRING
      });
      return resp.responseCode > 0;
    } catch (e) {
      return false;
    } finally {
      req.destroy();
    }
  }

  clearGrace(): void {
    if (this.graceTimer >= 0) {
      clearTimeout(this.graceTimer);
      this.graceTimer = -1;
    }
  }

  // 让页面内 XHR/fetch 缓存补丁知道当前离线状态（navigator.onLine 在 WebView 内偶尔不准）；
  // 系统在线但站点不可达时 showingOffline 也为 true，数据请求同样回放缓存
  private syncOfflineFlag(): void {
    try {
      this.controller.runJavaScript(`window.__dshOffline = ${!this.online || this.showingOffline};`);
    } catch (e) {
    }
  }

  // 下拉刷新：在线时重载当前页；离线时只触发一次探测，不打断缓存页
  private startRefresh(): void {
    // 闸 1：首屏还在加载时下拉，直接忽略。否则会把正在进行的首屏请求掐断，
    // 页面停在半截白屏上，用户只会觉得“刷新把页面刷坏了”。
    if (!this.loaded && this.isLoading) {
      this.endRefresh();
      return;
    }
    // 闸 2：3 秒内只认一次。阈值调高后仍然可能连着下拉两次，
    // 第二下不应该再触发一次整页重载。
    const now: number = Date.now();
    if (now - this.lastRefreshAt < 3000) {
      this.endRefresh();
      return;
    }
    this.lastRefreshAt = now;
    this.clearRefreshTimer();
    this.refreshPending = true;
    this.refreshTimer = setTimeout(() => {
      // 页面在 15s 内没有任何结束事件：可能“连着网但站点不可达”，主动探一次
      const pending = this.refreshPending;
      this.endRefresh();
      if (pending && this.online) {
        this.checkReachability();
      }
    }, 15000);
    this.errMsg = '';
    if (!this.online) {
      this.endRefresh();
      promptAction.showToast({ message: '当前无网络，正在尝试重连', duration: 1800 });
      this.startRetryLoop();
      return;
    }
    this.showFallback = false;
    this.offlineBanner = false;
    if (this.cacheMode !== CacheMode.Default) {
      this.reloadWithMode(CacheMode.Default);
    } else {
      this.reload();
    }
  }

  // 刷新超时后的可达性探测：系统有网但门户连不上时，及时亮离线兜底而不是一直白屏
  private async checkReachability(): Promise<void> {
    if (!this.online || this.showingOffline) {
      return;
    }
    const ok = await this.probeOnline();
    if (!ok && this.online && !this.showingOffline) {
      hilog.warn(DOMAIN, TAG, 'refresh timeout and probe failed, go offline %{public}s', this.rootUrl);
      promptAction.showToast({ message: '网络不可用，已切换离线缓存', duration: 1800 });
      this.goOffline();
    }
  }

  private endRefresh(): void {
    this.clearRefreshTimer();
    this.refreshPending = false;
    if (this.refreshing) {
      this.refreshing = false;
    }
  }

  private clearRefreshTimer(): void {
    if (this.refreshTimer >= 0) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  // 手动重试：在线直接重载，离线再走一轮探测
  private manualRetry(): void {
    this.showFallback = false;
    if (this.online) {
      this.reconnect();
      return;
    }
    this.goOffline();
  }

  goOffline(): void {
    this.showingOffline = true;
    // 只有真的没网才挂「离线缓存模式」提示。
    // 有网但这一页打不开（权限、附件、站点异常）时误报离线，会把人带偏。
    this.offlineBanner = !this.online;
    this.syncOfflineFlag();
    this.startRetryLoop();
    this.armOfflineWatch();
    // 已经稳定显示的页面不重载，避免打断阅读；只是挂上离线提示并等网络恢复
    if (this.loaded && this.progress >= 100 && !this.showFallback) {
      return;
    }
    if (this.progress > 0) {
      this.reloadWithMode(CacheMode.Only);
    } else {
      this.cacheMode = CacheMode.Only;
      this.loaded = false;
      // 挂起的在线加载会让 doLoad 提前返回，这里显式复位后强制发起缓存加载
      this.isLoading = false;
      this.doLoad();
    }
  }

  // 离线缓存模式可能既不触发 onPageEnd 也不报错（空缓存/加载挂起），超时一律给原生兜底页。
  // 不依赖 isLoading：主框架失败后 refresh 可能不再触发任何页面事件，此时 isLoading 已是 false。
  private armOfflineWatch(): void {
    this.clearOfflineWatch();
    this.offlineTimer = setTimeout(() => {
      this.offlineTimer = -1;
      if (this.cacheMode !== CacheMode.Only || this.loaded) {
        return;
      }
      hilog.warn(DOMAIN, TAG, 'offline cache unavailable %{public}s', this.rootUrl);
      try {
        this.controller.stop();
      } catch (e) {
      }
      this.isLoading = false;
      this.errMsg = this.online ? '本地没有可用离线缓存' : '当前无网络，且该页面没有可用离线缓存';
      this.showFallback = true;
      this.syncOfflineFlag();
      this.startRetryLoop();
    }, 6000);
  }

  clearOfflineWatch(): void {
    if (this.offlineTimer >= 0) {
      clearTimeout(this.offlineTimer);
      this.offlineTimer = -1;
    }
  }

  // 离线期间定时探测：系统在线也可能只是“连了网但不可达”，所以先探测再重连（8s 一次）
  startRetryLoop(): void {
    if (this.retryTimer >= 0) {
      return;
    }
    this.retryTimer = setTimeout(() => {
      this.retryTimer = -1;
      if (!this.showingOffline) {
        return;
      }
      this.probeThenReconnect();
    }, 8000);
  }

  private async probeThenReconnect(): Promise<void> {
    const ok = await this.probeOnline();
    if (!this.showingOffline) {
      return;
    }
    if (ok) {
      this.reconnect();
      return;
    }
    this.startRetryLoop();
  }

  /** 恢复在线：清掉兜底/离线态，重新按在线策略加载 */
  reconnect(): void {
    hilog.info(DOMAIN, TAG, 'reconnect online %{public}s', this.rootUrl);
    this.stopRetryLoop();
    this.clearOfflineWatch();
    // 兜底页保留到重新加载成功，避免自动重连期间闪白
    this.offlineBanner = false;
    this.showingOffline = false;
    this.errMsg = '';
    this.syncOfflineFlag();
    this.startWatch();
    this.reloadWithMode(CacheMode.Default);
  }

  stopRetryLoop(): void {
    if (this.retryTimer >= 0) {
      clearTimeout(this.retryTimer);
      this.retryTimer = -1;
    }
  }

  // 最后保险：连离线缓存加载都挂住（本不该发生）时停载亮兜底页；
  // 已有下载进展的慢页再宽限一轮，避免把正常加载误判为超时
  startWatch(): void {
    this.clearWatch();
    this.watchExtended = false;
    this.armWatch(15000);
  }

  private armWatch(delay: number): void {
    this.watchTimer = setTimeout(() => {
      this.watchTimer = -1;
      if (!this.isLoading) {
        return;
      }
      if (this.progress >= 25 && !this.watchExtended) {
        this.watchExtended = true;
        hilog.info(DOMAIN, TAG, 'watchdog extend progress=%{public}d %{public}s', this.progress, this.rootUrl);
        this.armWatch(15000);
        return;
      }
      hilog.warn(DOMAIN, TAG, 'load watchdog %{public}s', this.rootUrl);
      try {
        this.controller.stop();
      } catch (e) {
      }
      this.isLoading = false;
      this.endRefresh();
      this.clearOfflineWatch();
      this.errMsg = this.online ? '加载超时：服务器无响应' : '当前无网络，且该页面没有可用离线缓存';
      this.showFallback = true;
      this.showingOffline = true;
      this.offlineBanner = false;
      this.syncOfflineFlag();
      this.startRetryLoop();
    }, delay);
  }

  clearWatch(): void {
    if (this.watchTimer >= 0) {
      clearTimeout(this.watchTimer);
      this.watchTimer = -1;
    }
  }

  build() {
    Stack() {
      // 下拉刷新的三个参数各管一件事，别混：
      //   refreshOffset        下拉多少距离算触发（也是刷新态顶部被撑开的空白高度）
      //   pullDownRatio        跟手比：内容位移 = 手指位移 × ratio，越小越"拉不动"
      //   maxPullDownDistance  **拉伸上限**，不给就会一直跟着手指走，快速下甩还会因惯性过冲
      // 另外网页自身还会在顶部做 overscroll 回弹（见下面 Web 的 overScrollMode 注释），
      // 那一段不归 Refresh 管，会再叠出上百 vp 的空白，必须一起关掉——只调这三个参数治不好。
      // 现在的取舍：拉 64 / 0.55 ≈ 116vp 触发（和原来 112 的手感一致），白区最多只到 88vp。
      Refresh({ refreshing: $$this.refreshing }) {
        Web({ src: this.rootUrl, controller: this.controller })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .zoomAccess(false)
        .fileAccess(true)
        .onlineImageAccess(true)
        .darkMode(WebDarkMode.Off)
        .forceDarkAccess(false)
        .multiWindowAccess(true)
        .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
        .userAgent(MOBILE_UA)
        .cacheMode(this.cacheMode)
        .onContextMenuShow((event: OnContextMenuShowEvent) => {
          if (event && event.param.existsImageContents()) {
            this.ctxResult = event.result;
            this.ctxImageUrl = event.param.getSourceUrl();
            promptAction.showDialog({
              title: '图片',
              buttons: [
                { text: '保存图片', color: '#1A1A1A' },
                { text: '复制图片', color: '#1A1A1A' },
                { text: '取消', color: '#808080' }
              ]
            }).then((res) => {
              try {
                if (res.index === 0) {
                  if (this.ctxImageUrl.startsWith('http')) {
                    this.saveImageFromUrl(this.ctxImageUrl);
                  } else {
                    this.ctxResult?.saveImage();
                  }
                } else if (res.index === 1) {
                  this.ctxResult?.copyImage();
                }
                this.ctxResult?.closeContextMenu();
              } catch (e) {
              }
              this.ctxResult = undefined;
              this.ctxImageUrl = '';
            }).catch(() => {
              this.ctxResult?.closeContextMenu();
              this.ctxResult = undefined;
            });
            return true;
          }
          return false;
        })
        .onProgressChange((e: OnProgressChangeEvent) => {
          this.progress = e.newProgress;
        })
        .onLoadIntercept((req: OnLoadInterceptEvent) => {
          const u: string = req.data.getRequestUrl();
          if (u.startsWith('tel:')) {
            this.dialNumber(u);
            return true;
          }
          if (u.startsWith('mailto:')) {
            this.openSystem('ohos.want.action.sendData', u);
            return true;
          }
          // 附件直链（pdf/doc/zip…）：交给原生下载 + 系统预览。
          // 直接丢给 WebView 只会白屏或提示“无效的文件参数”，学生手册、校车时刻表都栽在这。
          if (Opener.isAttachment(u)) {
            hilog.info(DOMAIN, TAG, 'intercept attachment %{public}s', u);
            Opener.openAttachment(getContext(this) as common.UIAbilityContext, u, '');
            return true;
          }
          // 站外 / 自定义 scheme：交给系统，不要在 WebView 里报错
          const lower: string = u.toLowerCase();
          if (!(lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('about:') ||
            lower.startsWith('data:') || lower.startsWith('blob:') || lower.startsWith('resource:') ||
            lower.startsWith('file:'))) {
            this.openSystem('ohos.want.action.viewData', u);
            return true;
          }
          return false;
        })
        // 必须恒为 NEVER：Web 套在 Refresh 里属于嵌套滚动，网页滚到顶部会优先吃掉手势做
        // overscroll 回弹（官方文档原文），那一段回弹不归 Refresh 管，会在原生白区之上再撑出
        // 上百 vp 的空白——"轻轻下拉就一大片白"就是这么来的。以前给 active 的 Tab 开 ALWAYS，
        // 正是把这块空白打开的开关。
        .overScrollMode(OverScrollMode.NEVER)
        // document-start 的空桥 stub 必须先在：zfsoft/CAS 的 app-UA 分支启动时就会调桥，
        // 缺 stub 会永远停在“加载中”转圈（旧版本正常、近期回归的根因）。
        // rules 限定业务域，避免波及 rawfile 等本地页（曾因此白屏）
        .javaScriptOnDocumentStart([
          { script: PAGE_BRIDGE_JS, scriptRules: ['*://myapp.zjgsu.edu.cn/*', '*://uia.zjgsu.edu.cn/*'] },
          {
            script: NET_CACHE_JS,
            scriptRules: [
              '*://myapp.zjgsu.edu.cn/*', '*://uia.zjgsu.edu.cn/*', '*://xym.zjgsu.edu.cn/*',
              '*://txl.zjgsu.edu.cn/*', '*://jwxt.zjgsu.edu.cn/*'
            ]
          }
        ])
        .onControllerAttached(() => {
          WebRegistry.put(this.tabId, this.controller);
          try {
            this.controller.registerJavaScriptProxy(
              this.bridge, '__dshNative',
              ['onScroll', 'onRoute', 'openWith', 'closePage', 'onShareApp', 'onCheckVersion', 'onJsBridge',
                'onLogout', 'onScan', 'onOpenFile', 'onOpenBrowser']
            );
          } catch (e) {
            hilog.error(DOMAIN, TAG, 'register proxy failed %{public}s', JSON.stringify(e));
          }
          if (this.dlDelegate) {
            this.controller.setDownloadDelegate(this.dlDelegate);
          }
          // src 挂载即开始加载，不能再显式 loadUrl（会打断首帧请求得到 ERR_ABORTED 且无后续事件）。
          // 但加载被静默打断时 engine 也不会回调，因此这里先把看门狗挂上。
          if ((this.active || this.loadNow) && !this.loaded) {
            if (!this.isLoading) {
              this.isLoading = true;
            }
            this.startWatch();
            // 页首事件可能因连接被挂住而迟迟不来，探测不能等 onPageBegin
            this.startGrace();
          }
        })
        .onPageBegin((_event) => {
          hilog.info(DOMAIN, TAG, 'pageBegin %{public}s', this.rootUrl);
          this.isLoading = true;
          this.loadFailed = false;
          this.errMsg = '';
          // 兜底页保持到新页面真正加载成功（onPageEnd），避免重试期间闪白
          this.startWatch();
          if (this.cacheMode === CacheMode.Only || !this.online) {
            this.armOfflineWatch();
          } else {
            this.startGrace();
          }
        })
        .onPageEnd((event) => {
          this.clearWatch();
          this.clearGrace();
          this.clearOfflineWatch();
          this.endRefresh();
          hilog.info(DOMAIN, TAG, 'pageEnd %{public}s failed=%{public}s', event?.url ?? '', `${this.loadFailed}`);
          this.isLoading = false;
          // 网络错误页同样会触发 pageEnd，不能当成功页面：离线模式下立即给兜底页，避免长时间白屏
          if (this.loadFailed) {
            this.loaded = false;
            if (this.cacheMode === CacheMode.Only) {
              this.errMsg = this.online ? '本地没有可用离线缓存' : '当前无网络，且该页面没有可用离线缓存';
              this.showFallback = true;
              this.showingOffline = true;
              this.offlineBanner = false;
            }
            this.syncOfflineFlag();
            this.startRetryLoop();
            return;
          }
          this.loaded = true;
          this.showFallback = false;
          const url = event?.url ?? '';
          this.syncOfflineFlag();
          // 缓存加载完成：继续后台探在线；在线加载完成：退出离线模式停止探测
          if (this.cacheMode === CacheMode.Only) {
            this.showingOffline = true;
            this.offlineBanner = !this.online;
            this.startRetryLoop();
          } else {
            this.showingOffline = false;
            this.offlineBanner = false;
            this.stopRetryLoop();
          }
          if (isPortalUrl(url)) {
            this.autoTries = 0;
            AppStorage.set('dsh_session_ready', Date.now());
          }
          WebRegistry.refreshStuckLoginTabs((u: string): boolean => {
            const lower = u.toLowerCase();
            return lower.includes('uia.zjgsu.edu.cn/cas/login') && lower.indexOf('service=') < 0;
          });
          try {
            this.onTitleEvent(this.controller.getTitle());
          } catch (e) {
          }
          // 页面加载完成后立即装桥；不再用固定延时，避免“还没加载完就注入/已加载完却没注入”
          // 通讯录同样是 zfsoft app-UA 分支：二级页（搜索/个人收藏）靠 window.android.openWeb 打开，
          // 缺桥时点击抛 TypeError 毫无反应。故一并注入。
          if (isPortalUrl(url) || isContactUrl(url)) {
            try {
              this.controller.runJavaScript(ANDROID_BRIDGE_JS);
            } catch (e) {
            }
          }
          let pass0 = this.creds.pass;
          if (pass0 === '') {
            const sp = AppStorage.get<string>('dsh_session_pass') ?? '';
            const su = AppStorage.get<string>('dsh_session_user') ?? '';
            if (sp !== '') {
              this.creds.user = su;
              this.creds.pass = sp;
              pass0 = sp;
            }
          }
          if (isLoginUrl(url) && this.needLogin && pass0 !== '' && this.autoTries < 2) {
            this.autoTries++;
            const script = AUTO_LOGIN_JS
              .replace('__DSH_USER__', this.creds.user)
              .replace('__DSH_PASS__', this.creds.pass);
            try {
              this.controller.runJavaScript(script);
            } catch (e) {
            }
          }
          // CAS 页在套壳 UA 下只会转圈等待桥送凭据；无凭据或自动登录耗尽时必须给用户可见提示，否则永远“加载中”
          if (isLoginUrl(url)) {
            if (pass0 === '') {
              this.errMsg = '未登录：门户需要统一身份认证，请在启动页登录后使用';
              this.showFallback = true;
            } else if (this.autoTries >= 2) {
              this.errMsg = '自动登录失败：请检查账号密码后重试';
              this.showFallback = true;
            }
          }
          if (url.indexOf('/kb') >= 0 || url.toLowerCase().indexOf('schedule') >= 0) {
            try {
              this.controller.runJavaScript(SCHEDULE_FIX_JS);
            } catch (e) {
            }
          }
          // 首页：等页面把课表渲染完，静默抓一次写进缓存，桌面卡片与上课提醒都吃这份数据
          if (this.scrapeSchedule && !this.loadFailed) {
            setTimeout(() => {
              const ctx = getContext(this) as common.UIAbilityContext;
              CardSync.scrape(this.controller, ctx, true).then((ok: boolean) => {
                if (ok) {
                  hilog.info(DOMAIN, TAG, 'schedule synced to card');
                }
              });
            }, 3500);
          }
        })
        .onErrorReceive((event) => {
          if (event && event.request.isMainFrame()) {
            // ERR_ABORTED 是主动取消（重载/导航打断），不是网络故障；当成失败会误切离线缓存
            const code = event.error.getErrorCode();
            if (code === -3) {
              hilog.info(DOMAIN, TAG, 'main frame aborted %{public}s', event.request.getRequestUrl());
              return;
            }
            this.clearWatch();
            this.clearGrace();
            this.clearOfflineWatch();
            this.endRefresh();
            const info = event.error.getErrorInfo() || '网络连接失败';
            hilog.error(DOMAIN, TAG, 'main frame error %{public}s %{public}s', event.request.getRequestUrl(), info);
            this.isLoading = false;
            this.loadFailed = true;
            if (this.cacheMode === CacheMode.Only || !this.online) {
              // 连本地缓存都没有：兜底页 + 后台继续等在线恢复
              this.errMsg = this.online ? '本地没有可用离线缓存' : '当前无网络，且该页面没有可用离线缓存';
              this.showFallback = true;
              this.showingOffline = true;
              this.offlineBanner = false;
              this.syncOfflineFlag();
              this.startRetryLoop();
              return;
            }
            // 在线失败：立即切本地缓存，不让用户干等
            this.goOffline();
          }
        })
        .onHttpErrorReceive((event) => {
          if (event && event.request.isMainFrame()) {
            this.clearWatch();
            this.clearGrace();
            this.clearOfflineWatch();
            this.endRefresh();
            const code = event.response.getResponseCode();
            hilog.error(DOMAIN, TAG, 'main frame http %{public}s code=%{public}d', event.request.getRequestUrl(), code);
            this.isLoading = false;
            this.loadFailed = true;
            if (this.cacheMode === CacheMode.Only) {
              this.errMsg = this.online ? '本地没有可用离线缓存' : '当前无网络，且该页面没有可用离线缓存';
              this.showFallback = true;
              this.showingOffline = true;
              this.offlineBanner = false;
              this.syncOfflineFlag();
              this.startRetryLoop();
              return;
            }
            this.errMsg = `服务器返回错误（${code}）`;
            this.goOffline();
          }
        })
        .onConsole((event) => {
          // H5 控制台日志转 hilog：诊断套壳页面卡加载/桥调用问题
          try {
            const m = event.message;
            if (m) {
              hilog.info(DOMAIN, 'WebTabJS', '[%{public}d] %{public}s @%{public}s:%{public}d',
                m.getMessageLevel(), m.getMessage(), m.getSourceId(), m.getLineNumber());
            }
          } catch (e) {
          }
          return false;
        })
        .onWindowNew((event) => {
          const u = event.targetUrl || '';
          if (isHttpUrl(u)) {
            Router.openSub(u);
          }
          event.handler.setWebController(null);
        })
        .onShowFileSelector((event) => {
          this.pickFile(event);
          return true;
        })
        .onGeolocationShow((event) => {
          try {
            event.geolocation.invoke(event.origin, true, false);
          } catch (e) {
          }
        })
        .onPermissionRequest((event) => {
          try {
            event.request.grant(event.request.getAccessibleResource());
          } catch (e) {
            event.request.deny();
          }
        })
        // 底栏收放：只读触摸、不消费手势，网页照常滑动
        .onTouch((e: TouchEvent) => {
          this.handleTouch(e);
        })
      }
      .layoutWeight(1)
      .width('100%')
      .refreshOffset(64)
      .pullDownRatio(0.55)
      .maxPullDownDistance(88)
      .onRefreshing(() => {
        this.startRefresh();
      })

      // 离线缓存条：明确告知当前内容来自缓存，可手动重连；联网后会自动消失
      if (this.offlineBanner && !this.showFallback) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.icloud_slash'))
            .fontSize(14)
            .fontColor(['#8A8A8A'])
          Text(this.online ? '本地缓存内容' : '离线缓存模式')
            .fontSize(12)
            .fontColor('#666666')
          Text('点击重连')
            .fontSize(12)
            .fontColor('#0A59F7')
            .fontWeight(FontWeight.Medium)
        }
        .height(30)
        .padding({ left: 14, right: 14 })
        .backgroundColor('#F2FFFFFF')
        .borderRadius(15)
        .border({ width: 0.5, color: '#33000000' })
        .position({ x: 12, y: 8 })
        .onClick(() => {
          this.manualRetry();
        })
      }

      if (this.showFallback) {
        // 原生兜底页：仅当在线与本地缓存都不可用时出现；后台仍在自动等在线恢复
        Column({ space: 14 }) {
          Text(this.online ? '页面加载失败' : '当前无网络')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
          Text(this.errMsg === '' ? '网络连接失败' : this.errMsg)
            .fontSize(13)
            .fontColor('#999999')
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
          Text(this.online ? '下拉或点击重试' : '网络恢复后会自动重新加载')
            .fontSize(12)
            .fontColor('#BBBBBB')
          Row({ space: 12 }) {
            Button('重试')
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor('#2D8CFA')
              .borderRadius(18)
              .height(36)
              .width(110)
              .onClick(() => {
                this.manualRetry();
              })
            // 有些页面在套壳里就是不兼容（老控件、站外跳转），给一个能出去的口子，
            // 总比让人对着兜底页反复点重试强
            if (isHttpUrl(this.rootUrl)) {
              Button('在浏览器打开')
                .fontSize(14)
                .fontColor('#2D8CFA')
                .backgroundColor('#1A2D8CFA')
                .borderRadius(18)
                .height(36)
                .width(130)
                .onClick(() => {
                  Router.openExternal(this.rootUrl);
                })
            }
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F7F8FA')
      }

      if (this.progress > 0 && this.progress < 100) {
        Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(2)
          .color('#2D8CFA')
          .backgroundColor(Color.Transparent)
          .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  private async saveImageFromUrl(url: string): Promise<void> {
    let ext = 'jpg';
    const clean = url.split('?')[0].toLowerCase();
    if (clean.endsWith('.png')) {
      ext = 'png';
    } else if (clean.endsWith('.webp')) {
      ext = 'webp';
    } else if (clean.endsWith('.gif')) {
      ext = 'gif';
    }
    const req = http.createHttp();
    try {
      const cookie = webview.WebCookieManager.fetchCookieSync(url) ?? '';
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': cookie, 'User-Agent': MOBILE_UA, 'Accept': 'image/*' },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error(`image http ${resp.responseCode}`);
      }
      const ctx = getContext(this) as common.UIAbilityContext;
      const dir = `${ctx.filesDir}/Download`;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const name = `image_${Date.now()}.${ext}`;
      const path = `${dir}/${name}`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, resp.result as ArrayBuffer);
      fs.closeSync(file);
      promptAction.showToast({ message: '图片已保存到下载目录', duration: 2000 });
      const info: filePreview.PreviewInfo = {
        uri: fileUri.getUriFromPath(path),
        title: name,
        mimeType: `image/${ext === 'jpg' ? 'jpeg' : ext}`
      };
      filePreview.openPreview(ctx, info).catch(() => {});
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save image failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '图片保存失败', duration: 1800 });
    } finally {
      req.destroy();
    }
  }

  private openSystem(action: string, uri: string): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const noHandler = (): void => {
      promptAction.showToast({ message: '未找到可处理的应用', duration: 1500 });
    };
    let viewRetried = false;
    // startAbility 找不到匹配应用时可能同步抛出而不是 reject，两种情况都要给出可见提示
    const fail = (): void => {
      if (action === 'ohos.want.action.dial' && !viewRetried) {
        viewRetried = true;
        try {
          ctx.startAbility({ action: 'ohos.want.action.viewData', uri: uri }).catch(noHandler);
          return;
        } catch (e) {
        }
      }
      noHandler();
    };
    try {
      const want: Want = { action: action, uri: uri };
      ctx.startAbility(want).catch(fail);
    } catch (e) {
      fail();
    }
  }

  // 通讯录 tel: 链接：优先走系统电话应用拨号页，不支持通话能力时退回 dial Want
  private async dialNumber(url: string): Promise<void> {
    const num = decodeURIComponent(url.substring(4)).replace(/[^0-9+*#,;]/g, '');
    if (num === '') {
      promptAction.showToast({ message: '号码无效', duration: 1500 });
      return;
    }
    try {
      if (call.hasVoiceCapability()) {
        await call.makeCall(num);
        return;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'makeCall failed %{public}s', JSON.stringify(e));
    }
    this.openSystem('ohos.want.action.dial', `tel:${num}`);
  }

  private pickFile(event: OnShowFileSelectorEvent): void {
    const docPicker = new picker.DocumentViewPicker();
    const opts = new picker.DocumentSelectOptions();
    const mode = event.fileSelector.getMode();
    opts.maxSelectNumber = (mode === FileSelectorMode.FileOpenMultipleMode) ? 9 : 1;
    docPicker.select(opts).then((uris: Array<string>) => {
      event.result.handleFileList(uris);
    }).catch(() => {
      event.result.handleFileList([]);
    });
  }

  /**
   * 底栏收放的滑动采样。
   *
   * 门户页面是虚拟滚动容器，JS 侧拿不到 scrollY（window.scrollY 恒为 0），
   * 所以直接在 ArkUI 层读触摸位移与采样间隔，只把「速度」报上去，
   * 方向判定和阈值留给 Index 统一处理。
   */
  private handleTouch(e: TouchEvent): void {
    if (e.type !== TouchType.Move) {
      if (e.type === TouchType.Down) {
        if (e.touches.length > 0) {
          this.touchY = e.touches[0].y;
          this.touchTs = e.timestamp;
        }
      } else {
        this.touchY = -1;
        this.touchTs = 0;
      }
      return;
    }
    if (this.touchY < 0 || e.touches.length === 0) {
      return;
    }
    const y: number = e.touches[0].y;
    const dy: number = this.touchY - y;
    const dtMs: number = (e.timestamp - this.touchTs) / 1000000;
    this.touchY = y;
    this.touchTs = e.timestamp;
    // 采样间隔过大（手指停顿过）就不算速度，避免误判
    if (dtMs <= 0 || dtMs > 120 || Math.abs(dy) < 3) {
      return;
    }
    this.onSwipeEvent(dy, dtMs);
  }
}

// 注册进 WebView 的原生桥（window.__dshNative）
class DshBridge {
  private scrollCb: (y: number) => void;
  private routeCb: (u: string) => void;
  private logoutCb: () => void;
  private scanCb: () => void;
  private fileCb: (payload: string) => void;

  constructor(scrollCb: (y: number) => void, routeCb: (u: string) => void,
    logoutCb: () => void, scanCb: () => void, fileCb: (payload: string) => void) {
    this.scrollCb = scrollCb;
    this.routeCb = routeCb;
    this.logoutCb = logoutCb;
    this.scanCb = scanCb;
    this.fileCb = fileCb;
  }

  onScroll(y: number): void {
    this.scrollCb(y);
  }

  onRoute(url: string): void {
    this.routeCb(url);
  }

  openWith(url: string): void {
    // H5 说“打开一个页面”，但给的可能是附件直链（学生手册/时刻表就是这种），
    // 所以统一交给 Opener 判断：网页进子页、附件下载后预览、本地页走 rawfile。
    Opener.openSmart(getContext() as common.UIAbilityContext, url, '');
  }

  closePage(): void {
    Router.pop();
  }

  // 网页里的「退出登录」/桥方法 exitLogin、logout、gotoLogin
  onLogout(_msg: string): void {
    this.logoutCb();
  }

  // 网页里的扫码（scan / scanCode / scanQRCode ...），子页面同样生效
  onScan(_msg: string): void {
    this.scanCb();
  }

  // 网页要打开附件：payload 为 {"u":"地址","n":"文件名"}
  onOpenFile(payload: string): void {
    this.fileCb(payload);
  }

  // 网页要求用外部浏览器打开（下载站、第三方系统登录等）
  onOpenBrowser(url: string): void {
    if (url && (url.startsWith('http://') || url.startsWith('https://'))) {
      Router.openExternal(url);
    }
  }

  // 我的页“APP分享”：原版跳浏览器官方下载页
  onShareApp(): void {
    Router.openExternal(OFFICIAL_APK_URL);
  }

  // 我的页“版本检测”：原版弹提示，这里用当前包版本号做 toast
  onCheckVersion(): void {
    let name = '';
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      name = info.versionName;
    } catch (e) {
    }
    promptAction.showToast({ message: name === '' ? '当前已是最新版本' : `当前已是最新版本 V${name}`, duration: 2000 });
  }

  // H5 调了未知桥方法时落日志，便于定位“点击无反应”
  onJsBridge(msg: string): void {
    hilog.warn(DOMAIN, TAG, 'jsBridge call %{public}s', msg);
  }
}
