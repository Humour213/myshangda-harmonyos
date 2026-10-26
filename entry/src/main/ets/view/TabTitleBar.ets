/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
// 原版 App 主界面顶栏（v6 方案）：真全屏沉浸下组件自己避让状态栏
// 总高 = 状态栏实测高度 + 56vp，蓝底延伸到状态栏下方，内容在 56vp 区垂直居中
@Component
export struct TabTitleBar {
  @Prop title: string = '';
  @Prop action: string = 'none';
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  onScan: () => void = () => {};
  onSettings: () => void = () => {};

  build() {
    Row() {
      // 左占位
      Stack({ alignContent: Alignment.Center }) {
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
    .backgroundColor('#2D8CFA')
  }
}
