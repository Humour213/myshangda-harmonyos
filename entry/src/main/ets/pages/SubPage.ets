import { WebTab } from '../view/WebTab';
import { Router, WebRegistry, BarUtil } from '../common/Nav';
import { NAV_STYLE_CLASSIC } from '../common/PrefsStore';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';

@Component
export struct SubPage {
  @State url: string = '';
  @State destId: string = '';
  @State title: string = '';
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageLink('dsh_nav_style') navStyle: string = 'native';

  build() {
    HdsNavDestination() {
      Column() {
        // 原版样式的自绘蓝色工具栏：返回 | 标题 | 关闭；自避让状态栏
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
          Text('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .width(48)
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
          if (this.url !== '') {
            WebTab({
              tabId: `sub-${this.destId}`,
              rootUrl: this.url,
              needLogin: false,
              loadNow: true,
              active: true,
              onTitleEvent: (t: string) => {
                this.title = t;
              }
            })
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
        title: { mainTitle: this.title === '' ? '加载中…' : this.title }
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
        this.url = p;
      }
    })
  }
}
