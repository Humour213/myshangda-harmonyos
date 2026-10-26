import { TabDef, buildTabs, BASE_URL } from '../common/Constants';
import { WebTab } from '../view/WebTab';
import { TabTitleBar } from '../view/TabTitleBar';
import { SubPage } from './SubPage';
import { AboutPage } from './AboutPage';
import { NativeApi } from '../common/NativeApi';
import { GuidePage } from './GuidePage';
import { SettingsPage, SettingSubPage } from './SettingsPage';
import { HdsTabs, HdsNavigation, HdsNavigationMenuItemOptions, HdsNavigationTitleMode, hdsMaterial } from '@kit.UIDesignKit';
import { Router, WebRegistry, BarUtil } from '../common/Nav';
import { PrefsStore, SavedLogin, NAV_STYLE_CLASSIC } from '../common/PrefsStore';
import { preferences } from '@kit.ArkData';
import { promptAction } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { notificationManager } from '@kit.NotificationKit';
import { sensor } from '@kit.SensorServiceKit';
import { connection } from '@kit.NetworkKit';

const DOCK_ROOTS: string[][] = [
  [`${BASE_URL}/message/index`, `${BASE_URL}/message/index2`],
  [`${BASE_URL}/message/approveList`],
  [`${BASE_URL}/home/index`, `${BASE_URL}/home/unlogIndex`, `${BASE_URL}/menhu`],
  ['https://txl.zjgsu.edu.cn'],
  [`${BASE_URL}/my/index`]
];

@Entry
@Component
struct Index {
  @State tabs: TabDef[] = buildTabs();
  @State currentTab: number = 2;
  @State gateLoading: boolean = true;
  @State needGate: boolean = false;
  @State gateUser: string = '';
  @State gatePass: string = '';
  @State gateBusy: boolean = false;
  @State dockVisible: boolean = true;
  @State tabUrls: string[] = ['', '', '', '', '', ''];
  @State tabTitles: string[] = ['', '', '', '', '', ''];
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageLink('dsh_last_todo') lastTodoCount: number = 0;
  @StorageLink('dsh_nav_style') @Watch('onNavStyleChange') navStyle: string = 'native';
  @State lastScrollY: number = 0;
  @State routeHanding: boolean = false;
  @State agreeTerms: boolean = false;
  @State rememberPw: boolean = true;
  @State pwVisible: boolean = false;
  @State showGuide: boolean = false;
  @State showPrivacy: boolean = false;
  private privacySuspended: boolean = false;
  private privacyWatchTimer: number = -1;
  private netConn: connection.NetConnection | undefined = undefined;
  @StorageLink('dsh_targetUrl') @Watch('onTargetUrl') targetUrl: string = '';
  @StorageLink('dsh_session_ready') @Watch('onSessionReady') sessionReadyTs: number = 0;

  setupNotifications(): void {
    try {
      notificationManager.isNotificationEnabled().then((en: boolean) => {
        if (!en) {
          notificationManager.requestEnableNotification().catch(() => {});
        }
      });
    } catch (e) {
    }
  }

  async notifyNewTodos(count: number): Promise<void> {
    if (count > this.lastTodoCount) {
      const req: notificationManager.NotificationRequest = {
        id: 1001,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '我的商大',
            text: `您有${count}条待办消息待处理`,
            additionalText: '社区适配版'
          }
        },
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
      };
      try {
        await notificationManager.publish(req);
        notificationManager.setBadgeNumber(count).catch(() => {});
      } catch (e) {
      }
    }
    this.lastTodoCount = count;
    AppStorage.setOrCreate('dsh_last_todo', count);
  }

  currentTitle(): string {
    const t = this.tabs[this.currentTab];
    return t ? t.title : '我的商大';
  }

  // HDS 原生图标菜单（HdsNavigationBadgeIconOptions.content.icon 支持 SymbolGlyphModifier）
  titleMenuItems(): Array<HdsNavigationMenuItemOptions> {
    const items: Array<HdsNavigationMenuItemOptions> = [];
    if (this.currentTab === 2) {
      const scanContent: HdsNavigationMenuItemOptions = {
        content: {
          icon: $r('app.media.top_scan_dark'),
          label: '扫一扫',
          action: () => {
            this.doScan();
          }
        }
      };
      items.push(scanContent);
    } else if (this.currentTab === 4) {
      const setContent: HdsNavigationMenuItemOptions = {
        content: {
          icon: $r('sys.symbol.gearshape'),
          label: '设置',
          action: () => {
            Router.stack.pushPathByName('settings', '', true);
          }
        }
      };
      items.push(setContent);
    }
    return items;
  }

  onSessionReady(): void {
    NativeApi.fetchTodoCount().then((n: number) => {
      this.notifyNewTodos(n);
    });
  }

  onTargetUrl(): void {
    if (this.targetUrl && !this.gateLoading && !this.needGate) {
      if (this.targetUrl === 'dsh://scan') {
        this.doScan();
      } else {
        Router.openSub(this.targetUrl);
      }
      AppStorage.set('dsh_targetUrl', '');
    }
  }

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // 先建立网络状态源：WebTab 通过 dsh_online 决定首次加载走在线还是离线缓存
    this.registerNetwork();
    PrefsStore.getLogin(ctx).then((l: SavedLogin) => {
      this.needGate = l.user === '' || l.pass === '';
      this.gateLoading = false;
      this.syncStatusBar();
      this.onTargetUrl();
      if (!this.needGate) {
        // 已登录：进入主界面后按「功能设置」自动打开对应功能
        setTimeout(() => {
          this.tryAutoOpen();
        }, 2500);
      }
    });
    PrefsStore.isStatementAgreed(ctx).then((agreed: boolean) => {
      if (!agreed) {
        // 首启隐私弹窗：页面级自定义弹窗（跳转协议页不消失、拦截侧滑/返回）
        this.openPrivacyDialog();
      }
    });
    PrefsStore.getNavStyle(ctx).then((s: string) => {
      AppStorage.setOrCreate('dsh_nav_style', s);
      this.applyWindowStyle();
    });
    PrefsStore.getStore(ctx).then((store) => {
      store.get('guide_shown', false).then((v: preferences.ValueType) => {
        this.showGuide = !(v === true);
        this.applyWindowStyle();
      });
    });
    try {
      window.getLastWindow(ctx).then((win: window.Window) => {
        // 全屏切换会改变避让区，监听变化保证 dsh_statusBar 始终为真实状态栏高度
        win.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            AppStorage.setOrCreate('dsh_statusBar', px2vp(data.area.topRect.height));
          }
        });
        const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        AppStorage.setOrCreate('dsh_statusBar', px2vp(area.topRect.height));
      });
    } catch (e) {
    }
    this.applyWindowStyle();
    this.setupNotifications();
    // 启动始终落在主页（底栏顺序：消息、审批、主页、通讯录、我的）
    WebRegistry.setActive('tab-2');
    this.registerShakeSensor();
  }

  aboutToDisappear(): void {
    this.clearPrivacyWatch();
    this.unregisterNetwork();
  }

  // 全局网络状态：netAvailable/netLost 事件驱动，WebTab 监听后即时切换在线/离线
  registerNetwork(): void {
    try {
      this.netConn = connection.createNetConnection();
      this.netConn.register(() => {
        let online = true;
        try {
          online = connection.hasDefaultNetSync();
        } catch (e) {
        }
        AppStorage.setOrCreate('dsh_online', online);
      });
      this.netConn.on('netAvailable', (_h: connection.NetHandle) => {
        AppStorage.setOrCreate('dsh_online', true);
      });
      this.netConn.on('netLost', (_h: connection.NetHandle) => {
        let online = false;
        try {
          online = connection.hasDefaultNetSync();
        } catch (e) {
        }
        AppStorage.setOrCreate('dsh_online', online);
      });
      let online = true;
      try {
        online = connection.hasDefaultNetSync();
      } catch (e) {
      }
      AppStorage.setOrCreate('dsh_online', online);
    } catch (e) {
      AppStorage.setOrCreate('dsh_online', true);
    }
  }

  private unregisterNetwork(): void {
    if (this.netConn === undefined) {
      return;
    }
    try {
      this.netConn.unregister(() => {
      });
    } catch (e) {
    }
    this.netConn = undefined;
  }

  // 摇一摇（开启后摇手机打开校园码）：加速度突变检测 + 3s 防抖
  registerShakeSensor(): void {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        const x = data.x ?? 0;
        const y = data.y ?? 0;
        const z = data.z ?? 0;
        const amp = Math.sqrt(x * x + y * y + z * z);
        if (amp < 25) {
          return;
        }
        const now = Date.now();
        const last = AppStorage.get<number>('dsh_last_shake') ?? 0;
        if (now - last < 3000) {
          return;
        }
        AppStorage.setOrCreate('dsh_last_shake', now);
        const ctx = getContext(this) as common.UIAbilityContext;
        PrefsStore.getStore(ctx).then((store) => {
          store.get('pref_shake', false).then((v: preferences.ValueType) => {
            if (v === true && !this.needGate && !this.showGuide) {
              Router.openSub('https://xym.zjgsu.edu.cn/yzy/index.html?yhlx=aa&version=5.1');
            }
          });
        });
      });
    } catch (e) {
    }
  }

  // 首页自动打开应用（功能设置二级页里开启的项）
  tryAutoOpen(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    PrefsStore.getStore(ctx).then((store) => {
      store.get('auto_open_campus', false).then((v: preferences.ValueType) => {
        if (v === true) {
          Router.openSub('https://xym.zjgsu.edu.cn/yzy/index.html?yhlx=aa&version=5.1');
        }
      });
      store.get('auto_open_card', false).then((v: preferences.ValueType) => {
        if (v === true) {
          Router.openSub('https://xyk.zjgsu.edu.cn/easytong_app/h5/h5FunctionList/SSO2H5');
        }
      });
      store.get('auto_open_ai', false).then((v: preferences.ValueType) => {
        if (v === true) {
          Router.openSub('https://xueban.zjgsu.edu.cn/zsxb/?v4.1.22');
        }
      });
      store.get('auto_open_jwxt', false).then((v: preferences.ValueType) => {
        if (v === true) {
          Router.openSub('https://jwxt.zjgsu.edu.cn/jwglxt/xtgl/index_initMenu.html');
        }
      });
    });
  }

  syncStatusBar(): void {
    this.applyWindowStyle();
  }

  // 两种界面样式的窗口策略：
  // native = 非全屏布局（系统避让状态栏）+ 状态栏随页面染色；
  // classic = 真全屏沉浸（蓝色自绘顶栏自己避让状态栏），状态栏图标白色、浅色页黑色
  applyWindowStyle(): void {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      window.getLastWindow(ctx).then((win: window.Window) => {
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          // 该 promise 在部分模拟器上永不 resolve：染色与避让高度都不能依赖它的 then
          win.setWindowLayoutFullScreen(true).catch((e: BusinessError) => {
            hilog.error(0x0000, 'DSH', 'fullscreen on failed: %{public}s', JSON.stringify(e));
          });
          win.setWindowSystemBarProperties({
            // 经典样式不依赖 setWindowLayoutFullScreen 是否生效：状态栏底色直接染成顶栏蓝，视觉无缝
            statusBarColor: (this.needGate || this.showGuide) ? '#FFFFFF' : '#2D8CFA',
            statusBarContentColor: (this.needGate || this.showGuide) ? '#000000' : '#FFFFFF'
          });
        } else {
          win.setWindowLayoutFullScreen(false).catch((e: BusinessError) => {
            hilog.error(0x0000, 'DSH', 'fullscreen off failed: %{public}s', JSON.stringify(e));
          });
          // 手势导航条区域颜色由窗口底层绘制；染成与悬浮 Tab 一致的浅灰，消除小白条。
          // 引导/登录页仍是纯白页面，保持白底不突兀。
          win.setWindowBackgroundColor((this.needGate || this.showGuide || this.showPrivacy) ? '#FFFFFF' : '#F4F5F7');
          BarUtil.gray();
        }
      });
    } catch (e) {
    }
  }

  onNavStyleChange(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    PrefsStore.setNavStyle(ctx, this.navStyle);
    this.applyWindowStyle();
  }

  // 系统半模态（bindSheet）：等宿主节点挂载后再拉起，否则首帧 setState 不生效
  openPrivacyDialog(): void {
    if (this.showPrivacy) {
      return;
    }
    setTimeout(() => {
      this.showPrivacy = true;
    }, 350);
  }

  closePrivacyDialog(): void {
    this.showPrivacy = false;
    this.applyWindowStyle();
  }

  // 半模态不支持路由跳转：先收起，读完协议返回时再拉起
  openPrivacyDoc(url: string): void {
    this.privacySuspended = true;
    this.showPrivacy = false;
    setTimeout(() => {
      Router.openSub(url, () => {
        this.resumePrivacySheet();
      });
      this.watchPrivacyReturn();
    }, 220);
  }

  // HdsNavigation 的系统返回不一定触发 onPop，轮询路由栈归零作为兜底
  private watchPrivacyReturn(): void {
    this.clearPrivacyWatch();
    this.privacyWatchTimer = setInterval(() => {
      if (Router.stack.size() === 0) {
        this.clearPrivacyWatch();
        this.resumePrivacySheet();
      }
    }, 400);
  }

  private clearPrivacyWatch(): void {
    if (this.privacyWatchTimer >= 0) {
      clearInterval(this.privacyWatchTimer);
      this.privacyWatchTimer = -1;
    }
  }

  private resumePrivacySheet(): void {
    if (!this.privacySuspended) {
      return;
    }
    this.privacySuspended = false;
    this.clearPrivacyWatch();
    setTimeout(() => {
      this.showPrivacy = true;
    }, 260);
  }

  switchTab(idx: number, silent: boolean = false): void {
    hilog.info(0x0001, 'Index', 'switchTab to %{public}d', idx);
    if (idx === this.currentTab && !silent) {
      return;
    }
    this.currentTab = idx;
    WebRegistry.setActive(`tab-${idx}`);
    this.lastScrollY = 0;
    this.dockVisible = true;
  }

  // 精确判定：URL 是否为该 Tab 的根页面（原版一切非根内容都是独立子页）
  isRootUrl(tabIdx: number, url: string): boolean {
    if (!url) {
      return true;
    }
    const u = url.toLowerCase();
    let m = u.match(/^[a-z]+:\/\/([^\/]*)([^?#]*)/);
    if (!m) {
      return true;
    }
    const host = m[1];
    const path = m[2].replace(/\/$/, '');
    if (host.endsWith('uia.zjgsu.edu.cn')) {
      return true; // 登录流程不算离开
    }
    if (host.endsWith('txl.zjgsu.edu.cn')) {
      // 通讯录 H5 为 hash 路由（uni-app）：同域名内的 #/xxx 变化都视为留在根页，
      // 只有跳到其它域名（如常用电话的外链页）才算离开 → 独立子页
      return true;
    }
    if (host.endsWith('myapp.zjgsu.edu.cn')) {
      const roots = DOCK_ROOTS[tabIdx] ?? [];
      for (const r of roots) {
        const rp = r.toLowerCase().replace(/\/$/, '');
        const tail = u.substring(rp.length);
        if (u.startsWith(rp) && (tail === '' || tail.charAt(0) === '?' || tail.charAt(0) === '#')) {
          return true;
        }
      }
      return false;
    }
    return false;
  }

  dockVisibleFor(tabIdx: number, url: string): boolean {
    if (Router.stack.size() > 0) {
      return false;
    }
    if (!url) {
      return true;
    }
    return this.isRootUrl(tabIdx, url);
  }

  onBackPress(): boolean {
    if (this.showPrivacy) {
      return true;
    }
    if (Router.stack.size() > 0) {
      Router.pop();
      return true;
    }
    const c = WebRegistry.activeController();
    if (c) {
      try {
        if (c.accessBackward()) {
          c.backward();
          return true;
        }
      } catch (e) {
      }
    }
    return false;
  }

  doScan(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    const opts: scanBarcode.ScanOptions = { scanTypes: [scanCore.ScanType.QR_CODE] };
    scanBarcode.startScanForResult(ctx, opts).then((res: scanBarcode.ScanResult) => {
      const v = res.originalValue;
      if (v && /^https?:\/\//i.test(v)) {
        Router.openSub(v);
      } else if (v) {
        promptAction.showToast({ message: v, duration: 2000 });
      }
    }).catch(() => {
    });
  }

  async gateSubmit(): Promise<void> {
    if (this.gateBusy) {
      return;
    }
    if (!this.agreeTerms) {
      promptAction.showToast({ message: '请先阅读并勾选同意下方说明', duration: 2000 });
      return;
    }
    const u = this.gateUser.trim();
    const p = this.gatePass;
    if (u === '' || p === '') {
      promptAction.showToast({ message: '请输入学号和密码', duration: 1800 });
      return;
    }
    this.gateBusy = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    if (this.rememberPw) {
      await PrefsStore.saveLogin(ctx, u, p);
      AppStorage.setOrCreate('dsh_session_user', u);
      AppStorage.setOrCreate('dsh_session_pass', p);
    } else {
      AppStorage.setOrCreate('dsh_session_user', u);
      AppStorage.setOrCreate('dsh_session_pass', p);
      await PrefsStore.clearLogin(ctx);
    }
    this.gateBusy = false;
    this.needGate = false;
    this.syncStatusBar();
    // 首次登录成功后也执行「首页自动打开应用」，避免只在冷启动已登录时生效
    setTimeout(() => {
      this.tryAutoOpen();
    }, 2500);
  }

  async agreeStatement(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await PrefsStore.setStatementAgreed(ctx);
    this.closePrivacyDialog();
  }

  declineStatement(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    this.closePrivacyDialog();
    ctx.terminateSelf();
  }

  @Builder
  subPageBuilder(name: string) {
    if (name === 'web') {
      SubPage()
    } else if (name === 'about') {
      AboutPage()
    } else if (name === 'settings') {
      SettingsPage()
    } else if (name === 'setting_sub') {
      SettingSubPage()
    }
  }

  // 复刻原版 activity_login.xml：login_background 全屏底图 + 校徽54圆图 + 黑标题
  // 下划线输入区(#393939/#E3E3E3) + 记住密码/忘记密码 + 使用帮助/首次登录
  // 登录按钮 #4B7DD9 圆角5 + 协议勾选行 11fp
  @Builder
  gatePage() {
    Stack() {
      Image($r('app.media.login_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .hitTestBehavior(HitTestMode.None)

      Scroll() {
        Column() {
          // rl_top_text：marginTop 86，圆校徽 54 + 标题
          Column() {
            Image($rawfile('school_default.png'))
              .width(54)
              .height(54)
              .borderRadius(27)
              .clip(true)
            Text('我的商大')
              .fontSize(18)
              .fontColor('#000000')
              .margin({ top: 4 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          // 86dp 为 XML 原值；原版样式真全屏下需再让出状态栏实测高度
          .margin({ top: (this.navStyle === NAV_STYLE_CLASSIC ? this.statusBarHeight : 0) + 66, bottom: 30 })

          // 用户名（paddingTop26/paddingBottom18，14sp，#393939，无框）
          TextInput({ placeholder: '职工号/学号/手机号码', text: this.gateUser })
            .type(InputType.USER_NAME)
            .height(64)
            .width('100%')
            .backgroundColor(Color.Transparent)
            .padding({ left: 0, right: 0 })
            .border({ width: 0 })
            .placeholderColor('#393939')
            .fontColor('#393939')
            .fontSize(14)
            .caretColor('#4B7DD9')
            .maxLength(25)
            .onChange((v: string) => {
              this.gateUser = v;
            })
          Divider().color('#E3E3E3').strokeWidth(1).width('100%')

          // 密码行：输入框 + 原版眼睛图标切换可见性（icon_in/visiable_password.png）
          Stack({ alignContent: Alignment.End }) {
            TextInput({ placeholder: '请输入密码', text: this.gatePass })
              .type(this.pwVisible ? InputType.Normal : InputType.Password)
              .height(64)
              .width('100%')
              .backgroundColor(Color.Transparent)
              .padding({ left: 0, right: 34 })
              .border({ width: 0 })
              .placeholderColor('#393939')
              .fontColor('#393939')
              .fontSize(14)
              .caretColor('#4B7DD9')
              .maxLength(25)
              .showPasswordIcon(false)
              .onChange((v: string) => {
                this.gatePass = v;
              })
              .onSubmit(() => {
                this.gateSubmit();
              })
            if (this.gatePass !== '') {
              Image(this.pwVisible ? $r('app.media.icon_visiable_password') : $r('app.media.icon_invisiable_password'))
                .width(16)
                .height(16)
                .margin({ right: 4 })
                .objectFit(ImageFit.Contain)
                .onClick(() => {
                  this.pwVisible = !this.pwVisible;
                })
            }
          }
          .width('100%')
          Divider().color('#E3E3E3').strokeWidth(1).width('100%')

          // 记住密码 | 忘记密码
          Row() {
            Row() {
              Checkbox({ name: 'remember' })
                .select(this.rememberPw)
                .selectedColor('#C2C2C2')
                .unselectedColor('#C2C2C2')
                .width(20)
                .height(20)
                .onChange((v: boolean) => {
                  this.rememberPw = v;
                })
              Text('记住密码')
                .fontSize(14)
                .fontColor('#C2C2C2')
                .margin({ left: 5 })
            }
            Blank()
            Text('忘记密码')
              .fontSize(14)
              .fontColor('#2D8CFA')
              .onClick(() => {
                Router.openSub('https://uia.zjgsu.edu.cn/im/V3/securitycenter/findPwd/index.zf');
              })
          }
          .width('100%')
          .margin({ top: 14 })

          // 使用帮助 | 首次登录请设置密码
          Row() {
            Text('使用帮助')
              .fontSize(14)
              .fontColor('#C2C2C2')
              .margin({ left: 5 })
              .onClick(() => {
                Router.openSub('https://nic.zjgsu.edu.cn/2021/0910/c1198a96914/page.htm');
              })
            Blank()
            Text('首次登录请设置密码')
              .fontSize(14)
              .fontColor('#2D8CFA')
              .onClick(() => {
                Router.openSub('https://uia.zjgsu.edu.cn/im/V3/securitycenter/findPwd/index.zf');
              })
          }
          .width('100%')
          .margin({ top: 8 })

          Button(this.gateBusy ? '登录中…' : '登录')
            .width('100%')
            .height(50)
            .borderRadius(5)
            .backgroundColor('#4B7DD9')
            .fontSize(18)
            .fontColor(Color.White)
            .enabled(!this.gateBusy)
            .margin({ top: 22 })
            .onClick(() => {
              this.gateSubmit();
            })

          // 我已阅读《用户协议》和《隐私声明》
          Row() {
            Checkbox({ name: 'agree' })
              .select(this.agreeTerms)
              .selectedColor('#C2C2C2')
              .unselectedColor('#C2C2C2')
              .width(18)
              .height(18)
              .onChange((v: boolean) => {
                this.agreeTerms = v;
              })
            Text('我已阅读')
              .fontSize(11)
              .fontColor('#000000')
              .margin({ left: 5 })
            Text('《用户协议》')
              .fontSize(11)
              .fontColor('#2D8CFA')
              .onClick(() => {
                Router.openSub('$rawfile/protocol.html');
              })
            Text('和')
              .fontSize(11)
              .fontColor('#000000')
            Text('《隐私声明》')
              .fontSize(11)
              .fontColor('#2D8CFA')
              .onClick(() => {
                Router.openSub('$rawfile/privacy.html');
              })
          }
          .width('100%')
          .margin({ top: 92 })
        }
        .width('100%')
        .padding({ left: 26, right: 26 })
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  build() {
    HdsNavigation(Router.stack) {
      if (this.gateLoading) {
        Column() {
          LoadingProgress().width(32).height(32).color('#3D6BE5')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.showGuide) {
        GuidePage({
          onDone: () => {
            this.showGuide = false;
            this.applyWindowStyle();
          }
        })
      } else if (this.needGate) {
        this.gatePage()
      } else {
        Stack({ alignContent: Alignment.Bottom }) {
          if (this.navStyle === NAV_STYLE_CLASSIC) {
            // 原版 App 样式：自绘蓝色顶栏 + 悬浮底栏（真全屏沉浸）
            Column() {
              TabTitleBar({
                title: this.currentTitle(),
                action: this.currentTab === 2 ? 'scan' : (this.currentTab === 4 ? 'settings' : 'none'),
                onScan: () => {
                  this.doScan();
                },
                onSettings: () => {
                  Router.stack.pushPathByName('settings', '', true);
                }
              })
              Tabs({ index: this.currentTab, barPosition: BarPosition.End }) {
                ForEach(this.tabs, (tab: TabDef, idx: number) => {
                  TabContent() {
                    this.webTabFor(tab, idx)
                  }
                  .tabBar(BottomTabBarStyle.of(this.currentTab === idx ? tab.iconOnClassic : tab.iconOffClassic, tab.label)
                    .labelStyle({ selectedColor: '#2D8CFA', unselectedColor: '#C1C1C1' }))
                }, (tab: TabDef) => `${tab.id}`)
              }
              .layoutWeight(1)
              .barFloatingStyle({
                barWidth: { smallBarWidth: '72%', mediumBarWidth: 480, largeBarWidth: 560 },
                barSideMargin: 16,
                barBottomMargin: 12
              })
              .animationDuration(300)
              .scrollable(true)
              .onChange((i: number) => {
                this.switchTab(i);
              })
              .width('100%')
            }
            .width('100%')
            .height('100%')
          } else {
            HdsTabs({ index: this.currentTab, barPosition: BarPosition.End }) {
              ForEach(this.tabs, (tab: TabDef, idx: number) => {
                TabContent() {
                  this.webTabFor(tab, idx)
                }
                .tabBar(BottomTabBarStyle.of(this.currentTab === idx ? tab.iconOn : tab.iconOff, tab.label)
                  .labelStyle({ selectedColor: '#1A1A1A', unselectedColor: '#1A1A1A' }))
              }, (tab: TabDef) => `${tab.id}`)
            }
            .barOverlap(true)
            .animationDuration(300)
            .barFloatingStyle({
              barBottomMargin: 12,
              systemMaterialEffect: {
                materialType: hdsMaterial.MaterialType.IMMERSIVE,
                materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
              }
            })
            .scrollable(true)
            .onChange((i: number) => {
              this.switchTab(i);
            })
            .width('100%')
            .height('100%')
          }
        }
      }
    }
    .titleBar({
      // 官方示例：标题栏作为组件级安全区，Tab 内容不会钻到标题栏下方
      enableComponentSafeArea: true,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: '#F7F8FA'
          },
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            menuStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: $r('sys.color.icon_primary')
            }
          }
        }
      },
      content: {
        title: { mainTitle: this.currentTitle() },
        menu: { value: this.titleMenuItems() }
      }
    })
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .navDestination(this.subPageBuilder)
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .size({ width: '100%', height: '100%' })
    // 引导页/登录页无标题栏（原版为全屏页）；原版样式下标题栏自绘
    .hideTitleBar(this.gateLoading || this.showGuide || this.needGate || this.navStyle === NAV_STYLE_CLASSIC)
    .id('privacyRoot')
    // 官方系统半模态：大高度底部面板、浅灰底、无抓手/关闭按钮，未做选择前不可关闭
    .bindSheet($$this.showPrivacy, this.privacySheet(), {
      height: SheetSize.LARGE,
      width: '100%',
      preferType: SheetType.BOTTOM,
      backgroundColor: '#F2F3F5',
      maskColor: '#66000000',
      blurStyle: BlurStyle.NONE,
      dragBar: false,
      showClose: false,
      enableOutsideInteractive: false,
      shouldDismiss: (_d: SheetDismiss) => {
        // 必须点“同意/取消”，禁止下滑、点蒙层或返回键关闭
      }
    })
    // 真全屏下根节点默认仍避让状态栏，需显式扩展才能让自绘顶栏沉浸到状态栏下方
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  webTabFor(tab: TabDef, idx: number) {
    WebTab({
      tabId: `tab-${tab.id}`,
      rootUrl: tab.url,
      needLogin: true,
      active: this.currentTab === idx,
      onScrollEvent: (y: number) => {
        if (Router.stack.size() > 0) {
          return;
        }
      },
      onRouteEvent: (url: string) => {
        if (idx === this.currentTab) {
          this.tabUrls[idx] = url;
        }
        if (!this.isRootUrl(idx, url) && Router.stack.size() === 0 && !this.routeHanding) {
          this.routeHanding = true;
          this.tabUrls[idx] = tab.url;
          Router.openSub(url);
          const c = WebRegistry.controllerOf(`tab-${tab.id}`);
          if (c) {
            try {
              c.loadUrl(tab.url);
            } catch (e) {
            }
          }
          setTimeout(() => {
            this.routeHanding = false;
          }, 800);
        }
      },
      onTitleEvent: (t: string) => {
        this.tabTitles[idx] = t;
      }
    })
      .layoutWeight(1)
      .width('100%')
  }

  // 首启隐私声明：系统半模态样式（大圆角浅灰面板 + 图标 + 盾牌说明 + 胶囊双按钮）
  @Builder
  privacySheet() {
    Column() {
      Blank().layoutWeight(0.55)

      // 品牌区
      Column() {
        Stack() {
          Column()
            .width(76)
            .height(76)
            .borderRadius(20)
            .backgroundColor('#2D8CFA')
          Image($r('app.media.app_logo'))
            .width(58)
            .height(58)
            .objectFit(ImageFit.Contain)
        }
        .width(76)
        .height(76)
        .borderRadius(20)
        .clip(true)
        Text('我的商大')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .margin({ top: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank().layoutWeight(1.25)

      // 说明区：盾牌 + 隐私声明 + 官方胶囊按钮
      Column({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_shield_fill'))
          .fontSize(28)
          .fontColor(['#1F2329'])
          .margin({ bottom: 6 })

        Text() {
          Span('您可通过')
            .fontColor('#9B9B9B')
          Span('关于我的商大与隐私的声明')
            .fontColor('#4A4A4A')
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.openPrivacyDoc('$rawfile/privacy.html');
            })
          Span('了解我们为您提供的服务及个人信息处理范围、处理目的和方式等详细信息。\n点击“同意”，即表示您知悉并同意我们向您提供本服务。')
            .fontColor('#9B9B9B')
        }
        .width('100%')
        .fontSize(13)
        .lineHeight(21)
        .textAlign(TextAlign.Start)

        Row({ space: 16 }) {
          Button('取消')
            .layoutWeight(1)
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0A59F7')
            .backgroundColor(Color.White)
            .borderRadius(25)
            .shadow({ radius: 10, color: '#0A000000', offsetX: 0, offsetY: 2 })
            .onClick(() => {
              this.declineStatement();
            })
          Button('同意')
            .layoutWeight(1)
            .height(50)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#0A59F7')
            .borderRadius(25)
            .onClick(() => {
              this.agreeStatement();
            })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 24, right: 24, bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F3F5')
  }
}
