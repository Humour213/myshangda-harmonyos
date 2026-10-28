/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { PrefsStore, NAV_STYLE_CLASSIC, NAV_STYLE_NATIVE } from '../common/PrefsStore';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { common, Want, bundleManager } from '@kit.AbilityKit';
import { Router, BarUtil } from '../common/Nav';
import { preferences } from '@kit.ArkData';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import { ClassicHeader } from '../view/ClassicHeader';
import { OFFICIAL_APK_URL, COMMUNITY_URL } from '../common/Constants';
import { Session } from '../service/Session';

// 设置页：恢复接手机前的鸿蒙原生分组列表样式
// 组 1 原版 App 功能；组 2 通用工具；组 3 社区隐私与说明
@Component
export struct SettingsPage {
  @StorageLink('dsh_nav_style') navStyle: string = 'native';
  /** 版本号统一从包信息读，避免改版本还要手改界面文案 */
  @State appVersion: string = '';

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = `V${info.versionName}`;
    } catch (e) {
      this.appVersion = '';
    }
  }

  async doClearCache(): Promise<void> {
    try {
      webview.WebStorage.deleteAllData();
    } catch (e) {
    }
    promptAction.showToast({ message: '缓存已清除', duration: 1500 });
  }

  openPermission(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // 系统设置「应用详情」页：显式拉起设置应用，pushParams 指定本应用包名
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'application_info_entry',
      parameters: {
        pushParams: ctx.abilityInfo.bundleName
      }
    };
    ctx.startAbility(want).catch(() => {
      promptAction.showToast({ message: '请前往 系统设置-应用-我的商大', duration: 1800 });
    });
  }

  @Builder
  settingRow(label: string, trailing: string, onTap: () => void) {
    ListItem() {
      Row() {
        Text(label)
          .fontSize(16)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        if (trailing !== '') {
          Text(trailing)
            .fontSize(14)
            .fontColor('#999999')
            .margin({ right: 2 })
        } else {
          Image($r('app.media.arrow_next'))
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .margin({ right: 2 })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .onClick(() => {
        onTap();
      })
    }
  }

  @Builder
  settingDivider() {
    Divider()
      .color('#F0F0F0')
      .strokeWidth(0.5)
      .margin({ left: 16 })
  }

  // 单独 builder 直接读 navStyle，保证切换后尾标即时刷新（@Builder 按值传参不刷新）
  @Builder
  styleTrailing() {
    Text(this.navStyle === NAV_STYLE_CLASSIC ? '原版App' : '鸿蒙原生')
      .fontSize(14)
      .fontColor('#999999')
      .margin({ right: 2 })
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          ClassicHeader({
            title: '设置',
            onBack: () => {
              Router.pop();
            }
          })
        }
        List({ space: 9 }) {
          // 组 1：原版 App 设置
          ListItemGroup() {
            this.settingRow('版本检测', this.appVersion, () => {
              promptAction.showToast({ message: `当前已是最新版本 ${this.appVersion}`, duration: 1800 });
            })
            this.settingDivider()
            this.settingRow('APP分享', '', () => {
              Router.stack.pushPathByName('setting_sub', 'share', true);
            })
            this.settingDivider()
            this.settingRow('首页自动打开应用', '', () => {
              Router.stack.pushPathByName('setting_sub', 'auto', true);
            })
            this.settingDivider()
            this.settingRow('摇一摇设置', '', () => {
              Router.stack.pushPathByName('setting_sub', 'shake', true);
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(12)
          .clip(true)

          // 组 2：应用工具
          ListItemGroup() {
            this.settingRow('权限管理', '', () => {
              this.openPermission();
            })
            this.settingDivider()
            this.settingRow('清除缓存', '', () => {
              this.doClearCache();
            })
            this.settingDivider()
            ListItem() {
              Row() {
                Text('界面样式')
                  .fontSize(16)
                  .fontColor('#1A1A1A')
                  .layoutWeight(1)
                this.styleTrailing()
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
              .backgroundColor(Color.White)
              .onClick(() => {
                Router.stack.pushPathByName('setting_sub', 'style', true);
              })
            }
          }
          .backgroundColor(Color.White)
          .borderRadius(12)
          .clip(true)

          // 组 3：社区第三方隐私与说明
          ListItemGroup() {
            this.settingRow('隐私政策', '', () => {
              Router.openSub('$rawfile/privacy.html');
            })
            this.settingDivider()
            this.settingRow('社区适配声明', '', () => {
              Router.stack.pushPathByName('about', '', true);
            })
            this.settingDivider()
            // 下载站 / 开源仓库 / 作者联系方式都收在这一页
            this.settingRow('下载与源码', '', () => {
              Router.stack.pushPathByName('community', '', true);
            })
          }
          .backgroundColor(Color.White)
          .borderRadius(12)
          .clip(true)

          // 退出登录：沿用原版红色独立按钮
          ListItemGroup() {
            ListItem() {
              Text('退出登录')
                .fontSize(16)
                .fontColor('#EA2500')
                .width('100%')
                .height(52)
                .textAlign(TextAlign.Center)
                .backgroundColor(Color.White)
                .onClick(() => {
                  // 走二次确认，别让人误触就把账号密码和网页登录态一起清掉
                  Session.confirmAndClear();
                })
            }
          }
          .backgroundColor(Color.White)
          .borderRadius(12)
          .clip(true)

          ListItem() {
            Column() {
              Text('ICP备案号：浙ICP备05073962号-6A >')
                .fontSize(12)
                .fontColor('#808080')
                .width('100%')
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  Router.openSub('https://beian.miit.gov.cn');
                })
              Text(`我的商大 社区适配版 ${this.appVersion}`)
                .fontSize(12)
                .fontColor('#ABABAB')
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 6, bottom: 10 })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 12, bottom: 9 })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')
    }
    .titleBar({
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          backgroundStyle: {
            backgroundColor: '#F7F8FA'
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: { mainTitle: '设置' }
      }
    })
    .hideTitleBar(this.navStyle === NAV_STYLE_CLASSIC)
    .onShown(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
    .onHidden(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
  }
}

// 二级页：auto=功能设置 / shake=摇一摇设置 / share=APP分享
// 原生 HdsNavDestination 标题栏，内容使用分组卡片
@Component
export struct SettingSubPage {
  @State type: string = 'auto';
  @State autoCampus: boolean = false;
  @State autoCard: boolean = false;
  @State autoAi: boolean = false;
  @State autoJwxt: boolean = false;
  @State shakeOn: boolean = false;
  @StorageLink('dsh_nav_style') navStyle: string = 'native';

  pageTitle(): string {
    if (this.type === 'auto') {
      return '功能设置';
    }
    if (this.type === 'shake') {
      return '摇一摇设置';
    }
    if (this.type === 'style') {
      return '界面样式';
    }
    return 'APP分享';
  }

  loadPrefs(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    PrefsStore.getStore(ctx).then((store) => {
      store.get('auto_open_campus', false).then((v: preferences.ValueType) => {
        this.autoCampus = v === true;
      });
      store.get('auto_open_card', false).then((v: preferences.ValueType) => {
        this.autoCard = v === true;
      });
      store.get('auto_open_ai', false).then((v: preferences.ValueType) => {
        this.autoAi = v === true;
      });
      store.get('auto_open_jwxt', false).then((v: preferences.ValueType) => {
        this.autoJwxt = v === true;
      });
      store.get('pref_shake', false).then((v: preferences.ValueType) => {
        this.shakeOn = v === true;
      });
    });
  }

  async setPref(key: string, val: boolean): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const store = await PrefsStore.getStore(ctx);
    await store.put(key, val);
    await store.flush();
  }

  openLink(url: string): void {
    Router.openSub(url);
  }

  @Builder
  linkRow(label: string, url: string, external: boolean = false) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
      Image($r('app.media.arrow_next'))
        .width(14)
        .height(14)
        .objectFit(ImageFit.Contain)
        .margin({ right: 2 })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .onClick(() => {
      if (external) {
        Router.openExternal(url);
      } else {
        this.openLink(url);
      }
    })
  }

  @Builder
  styleRow(label: string, sub: string, value: string) {
    Row() {
      Column({ space: 3 }) {
        Text(label)
          .fontSize(16)
          .fontColor('#1A1A1A')
        Text(sub)
          .fontSize(12)
          .fontColor('#999999')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      if (this.navStyle === value) {
        Text('✓')
          .fontSize(18)
          .fontColor('#2D8CFA')
          .margin({ right: 4 })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .onClick(() => {
      if (this.navStyle !== value) {
        AppStorage.setOrCreate('dsh_nav_style', value);
      }
    })
  }

  @Builder
  divider() {
    Divider()
      .color('#F0F0F0')
      .strokeWidth(0.5)
      .margin({ left: 16 })
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          ClassicHeader({
            title: this.pageTitle(),
            onBack: () => {
              Router.pop();
            }
          })
        }
        Column() {
          if (this.type === 'auto') {
            Column() {
              SwitchRow({ label: '教务系统', on: $autoJwxt, onChange: (v: boolean) => {
                this.setPref('auto_open_jwxt', v);
              } })
              this.divider()
              SwitchRow({ label: '校园码', on: $autoCampus, onChange: (v: boolean) => {
                this.setPref('auto_open_campus', v);
              } })
              this.divider()
              SwitchRow({ label: '校园卡', on: $autoCard, onChange: (v: boolean) => {
                this.setPref('auto_open_card', v);
              } })
              this.divider()
              SwitchRow({ label: 'AI学伴', on: $autoAi, onChange: (v: boolean) => {
                this.setPref('auto_open_ai', v);
              } })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .clip(true)
          } else if (this.type === 'shake') {
            Column() {
              SwitchRow({ label: '开启摇一摇功能', on: $shakeOn, onChange: (v: boolean) => {
                this.setPref('pref_shake', v);
              } })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .clip(true)
          } else if (this.type === 'style') {
            Column() {
              this.styleRow('鸿蒙原生导航栏和标题栏样式', '系统标题栏与转场，浅色分组卡片', NAV_STYLE_NATIVE)
              this.divider()
              this.styleRow('原版App样式', '蓝色沉浸顶栏与原版悬浮底栏', NAV_STYLE_CLASSIC)
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .clip(true)
          } else {
            Column() {
              this.linkRow('官方版本', OFFICIAL_APK_URL, true)
              this.divider()
              this.linkRow('社区版本', COMMUNITY_URL)
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .clip(true)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 12, right: 12, top: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')
    }
    .titleBar({
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          backgroundStyle: {
            backgroundColor: '#F7F8FA'
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: { mainTitle: this.pageTitle() }
      }
    })
    .hideTitleBar(this.navStyle === NAV_STYLE_CLASSIC)
    .onReady((ctx: NavDestinationContext) => {
      const p: string | undefined = (ctx.pathInfo.param !== null && typeof ctx.pathInfo.param === 'string')
        ? ctx.pathInfo.param as string : undefined;
      if (p !== undefined) {
        this.type = p;
      }
      this.loadPrefs();
    })
    .onShown(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
    .onHidden(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
  }
}

// 开关行：@Link 双向绑定，异步 loadPrefs 回来后即时刷新（@Builder 按值传参不会刷新）
@Component
struct SwitchRow {
  label: string = '';
  @Link on: boolean;
  onChange: (v: boolean) => void = (_v: boolean) => {};

  build() {
    Row() {
      Text(this.label)
        .fontSize(16)
        .fontColor('#1A1A1A')
        .padding({ left: 16 })
      Blank()
      Toggle({ type: ToggleType.Switch, isOn: this.on })
        .selectedColor('#2D8CFA')
        .margin({ right: 8 })
        .onChange((v: boolean) => {
          this.on = v;
          this.onChange(v);
        })
    }
    .width('100%')
    .height(52)
    .backgroundColor(Color.White)
  }
}
