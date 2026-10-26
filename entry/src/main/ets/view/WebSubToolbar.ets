/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { common, Want } from '@kit.AbilityKit';

// 主 Tab 内 H5 离开根路由后的子页工具栏（对应原版 simple_web_toolbar）
@Component
export struct WebSubToolbar {
  @Prop title: string = '';
  onBack: () => void = () => {};
  onClose: () => void = () => {};
  onRefresh: () => void = () => {};
  url: string = '';

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Text('<')
          .fontSize(24)
          .fontColor(Color.White)
          .onClick(() => this.onBack())
      }
      .width(52)
      .height('100%')

      Stack({ alignContent: Alignment.Center }) {
        Text(this.title === '' ? '加载中…' : this.title)
          .fontSize(17)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '92%' })
      }
      .layoutWeight(1)
      .height('100%')

      Stack({ alignContent: Alignment.Center }) {
        Row({ space: 12 }) {
          Text('⋮')
            .fontSize(20)
            .fontColor(Color.White)
            .bindMenu(this.menuBuilder())
          Text('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .onClick(() => this.onClose())
        }
      }
      .padding({ right: 14 })
      .height('100%')
    }
    .width('100%')
    .height(56)
    .backgroundColor('#2D8CFA')
  }

  @Builder
  menuBuilder() {
    Menu() {
      MenuItem({ content: '刷新' })
        .onClick(() => {
          this.onRefresh();
        })
      MenuItem({ content: '复制链接' })
        .onClick(() => {
          const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.url);
          pasteboard.getSystemPasteboard().setData(data);
          promptAction.showToast({ message: '链接已复制', duration: 1500 });
        })
      MenuItem({ content: '在浏览器中打开' })
        .onClick(() => {
          if (this.url !== '') {
            try {
              const ctx = getContext(this) as common.UIAbilityContext;
              const want: Want = { action: 'ohos.want.action.viewData', uri: this.url };
              ctx.startAbility(want).catch(() => {
                promptAction.showToast({ message: '打开失败', duration: 1500 });
              });
            } catch (e) {
              promptAction.showToast({ message: '打开失败', duration: 1500 });
            }
          }
        })
    }
  }
}
