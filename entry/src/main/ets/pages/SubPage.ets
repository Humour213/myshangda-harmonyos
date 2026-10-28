/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { WebTab } from '../view/WebTab';
import { Router, WebRegistry, BarUtil } from '../common/Nav';
import { NAV_STYLE_CLASSIC } from '../common/PrefsStore';
import { HdsNavDestination, HdsNavigationMenuItemOptions, hdsMaterial } from '@kit.UIDesignKit';
import { Scanner } from '../service/Scanner';
import { Opener } from '../service/Opener';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SubPage {
  @State url: string = '';
  @State destId: string = '';
  @State title: string = '';
  /** 附件类地址：不进 WebView，直接下载后系统预览 */
  @State asAttachment: boolean = false;
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageLink('dsh_nav_style') navStyle: string = 'native';

  // 原生样式下把「扫一扫」放进系统标题栏菜单；与主页顶栏同一套类型写法
  scanMenu(): Array<HdsNavigationMenuItemOptions> {
    const items: Array<HdsNavigationMenuItemOptions> = [];
    const scanItem: HdsNavigationMenuItemOptions = {
      content: {
        icon: $r('app.media.top_scan_dark'),
        label: '扫一扫',
        action: () => {
          this.doScan();
        }
      }
    };
    items.push(scanItem);
    return items;
  }

  /** 子页面里也要能扫码：H5 里的扫码入口和这里的按钮走同一套原生能力 */
  private async doScan(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const v: string = await Scanner.scan(ctx);
    if (v === '') {
      return;
    }
    const c = WebRegistry.controllerOf(`sub-${this.destId}`);
    if (c) {
      const lit: string = JSON.stringify(v);
      try {
        const r: string = await c.runJavaScript(
          `(function(){try{if(typeof window.__dshScanCallback==="function"){window.__dshScanCallback(${lit});return "cb";}` +
          `if(typeof window.__dshScanResult==="function"){window.__dshScanResult(${lit});return "evt";}}catch(e){}return "none";})()`
        ) as string;
        if (String(r).indexOf('none') < 0) {
          return;
        }
      } catch (e) {
        // 页面未就绪，走下面的兜底
      }
    }
    if (/^https?:\/\//i.test(v)) {
      Router.openSub(v);
    } else {
      promptAction.showToast({ message: v, duration: 2500 });
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 原版样式的自绘蓝色工具栏：返回 | 标题 | 扫一扫 | 关闭；自避让状态栏
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          Row() {
          Text('<')
            .fontSize(24)
            .fontColor(Color.White)
            .width(48)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              const c = WebRegistry.controllerOf(`sub-${this.destId}`);
              if (c) {
                try {
                  if (c.accessBackward()) {
                    c.backward();
                    return;
                  }
                } catch (e) {
                }
              }
              Router.pop();
            })
          Text(this.title === '' ? '加载中…' : this.title)
            .fontSize(16)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('⌗')
            .fontSize(18)
            .fontColor(Color.White)
            .width(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.doScan();
            })
          Text('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .width(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              Router.pop();
            })
        }
          .width('100%')
          .height(this.statusBarHeight + 52)
          .padding({ top: this.statusBarHeight })
          .backgroundColor('#2D8CFA')
        }

        Stack() {
          if (this.url !== '' && !this.asAttachment) {
            WebTab({
              tabId: `sub-${this.destId}`,
              rootUrl: this.url,
              // 子页面同样要能自动登录：门户会话过期时二级页会跳 CAS，
              // 这里若关掉，页面只会永远转圈，看起来就像“打不开”
              needLogin: true,
              loadNow: true,
              active: true,
              onTitleEvent: (t: string) => {
                this.title = t;
              }
            })
          }
          if (this.asAttachment) {
            // 附件直链：WebView 加载不了，给一个明确的出口
            Column({ space: 12 }) {
              Text('文件')
                .fontSize(13)
                .fontColor('#9AA0A6')
                .width(56)
                .height(56)
                .textAlign(TextAlign.Center)
                .borderRadius(14)
                .backgroundColor('#EEF1F5')
              Text('该链接是附件，需要用系统应用打开')
                .fontSize(15)
                .fontColor('#1A1A1A')
              Text(this.url)
                .fontSize(11)
                .fontColor('#9AA0A6')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ left: 32, right: 32 })
              Button('下载并打开')
                .height(38)
                .fontSize(14)
                .fontColor(Color.White)
                .backgroundColor('#2D8CFA')
                .borderRadius(19)
                .onClick(() => {
                  Opener.openAttachment(getContext(this) as common.UIAbilityContext, this.url, '');
                })
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    // 原生样式用系统标题栏，经典样式用自绘蓝条
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
        title: { mainTitle: this.title === '' ? '…' : this.title },
        // 与主页顶栏同一套写法：原生样式下也能手动扫码
        menu: { value: this.scanMenu() }
      }
    })
    .hideTitleBar(this.navStyle === NAV_STYLE_CLASSIC)
    .onShown(() => {
      if (this.navStyle === NAV_STYLE_CLASSIC) {
        BarUtil.blue();
      } else {
        BarUtil.gray();
      }
    })
    .onHidden(() => {
      if (this.navStyle === NAV_STYLE_CLASSIC) {
        BarUtil.blue();
      } else {
        BarUtil.gray();
      }
    })
    .onReady((ctx: NavDestinationContext) => {
      this.destId = `${ctx.navDestinationId ?? ''}`;
      const p: string | undefined = (ctx.pathInfo.param !== null && typeof ctx.pathInfo.param === 'string')
        ? ctx.pathInfo.param as string : undefined;
      if (p !== undefined) {
        const target: string = Opener.resolveLocal(p);
        if (Opener.isAttachment(target)) {
          // 附件类：不再创建 WebView，直接走下载预览，避免“加载失败/离线缓存”的误导
          this.asAttachment = true;
          this.url = target;
          this.title = Opener.guessName(target);
          setTimeout(() => {
            Opener.openAttachment(getContext(this) as common.UIAbilityContext, target, '');
          }, 300);
          return;
        }
        this.url = target;
      }
    })
  }
}
