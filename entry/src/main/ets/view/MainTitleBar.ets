/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
// 主界面自绘标题栏（HDS MINI 规格）：
// 白底延伸到状态栏，56vp 内容区，22fp 加粗标题，
// 右侧圆形底板(#F1F3F5)+24vp 图标按钮（HDS 一级页图标按钮规格）
@Component
export struct MainTitleBar {
  @StorageLink('dsh_tab_title') title: string = '我的商大';
  @StorageLink('dsh_tab_menu') menuType: string = 'none';
  onMenu: () => void = () => {};
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;

  @Builder
  menuButton(icon: Resource, label: string) {
    Stack() {
      Circle()
        .width(40)
        .height(40)
        .fill('#F1F3F5')
      Image(icon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
    }
    .width(40)
    .height(40)
    .margin({ right: 14 })
    .onClick(() => {
      this.onMenu();
    })
    .accessibilityText(label)
  }

  build() {
    Column() {
      // 状态栏避让区（白底延伸）
      Row()
        .width('100%')
        .height(this.statusBarHeight)

      Row() {
        Text(this.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#000000')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (this.menuType === 'scan') {
          this.menuButton($r('app.media.top_scan_dark'), '扫一扫')
        } else if (this.menuType === 'settings') {
          this.menuButton($r('app.media.top_setting_dark'), '设置')
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 2 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(Color.White)
  }
}
