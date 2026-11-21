/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { Palette } from '../common/Palette';
import { Mascot } from '../common/Mascot';

// 原版 App 主界面顶栏（v6 方案）：真全屏沉浸下组件自己避让状态栏
// 总高 = 状态栏实测高度 + 56vp，底色延伸到状态栏下方，内容在 56vp 区垂直居中
@Component
export struct TabTitleBar {
  @Prop title: string = '';
  @Prop action: string = 'none';
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageProp('dsh_theme') theme: string = 'default';
  onScan: () => void = () => {};
  onSettings: () => void = () => {};

  build() {
    Row() {
      // 左上角：豆泥主题时蹲一只小豆泥，和标题同一栏。
      // Mascot 组件在默认主题下自身不渲染（0 尺寸），所以这里默认主题等于原来的空占位，
      // 标题依旧精确居中、右侧动作不受影响。
      Stack({ alignContent: Alignment.Center }) {
        Mascot({ slot: 'passive', side: 34 })
      }
      .width(64)
      .height('100%')

      // 标题（Stack 绝对居中）
      Stack({ alignContent: Alignment.Center }) {
        Text(this.title)
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
      }
      .layoutWeight(1)
      .height('100%')

      // 右侧动作（Stack 居中）
      Stack({ alignContent: Alignment.Center }) {
        if (this.action === 'scan') {
          Column({ space: 2 }) {
            Image($r('app.media.scan'))
              .width(22)
              .height(22)
              .objectFit(ImageFit.Contain)
              .fillColor(Color.White)
            Text('扫一扫')
              .fontSize(9)
              .fontColor(Color.White)
          }
          .onClick(() => this.onScan())
        } else if (this.action === 'settings') {
          Image($r('app.media.top_setting'))
            .width(22)
            .height(20)
            .objectFit(ImageFit.Contain)
            .onClick(() => this.onSettings())
        }
      }
      .width(64)
      .height('100%')
    }
    .width('100%')
    .height(this.statusBarHeight + 56)
    .padding({ top: this.statusBarHeight })
    // 默认主题 accent=品牌蓝，与原来写死的 #2D8CFA 完全一致，观感零改动；
    // 豆泥主题 accent=毛发深棕，与状态栏/网页构成上下两段。
    .backgroundColor(Palette.accent(this.theme))
  }
}
