/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
// 原版 App 样式的子页/设置页蓝色工具栏：返回 | 标题 | (关闭)
// 与 TabTitleBar 同构：真全屏下自避让状态栏
@Component
export struct ClassicHeader {
  @Prop title: string = '';
  @Prop showClose: boolean = false;
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  onBack: () => void = () => {};
  onClose: () => void = () => {};

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
        Text(this.title)
          .fontSize(17)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '80%' })
      }
      .layoutWeight(1)
      .height('100%')

      Stack({ alignContent: Alignment.Center }) {
        if (this.showClose) {
          Text('✕')
            .fontSize(18)
            .fontColor(Color.White)
            .onClick(() => this.onClose())
        }
      }
      .width(52)
      .height('100%')
    }
    .width('100%')
    .height(this.statusBarHeight + 52)
    .padding({ top: this.statusBarHeight })
    .backgroundColor('#2D8CFA')
  }
}
