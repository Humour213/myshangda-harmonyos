/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { Palette } from '../common/Palette';
import { BarUtil } from '../common/Nav';

// 原版 App 样式的子页/设置页工具栏：返回 | 标题 | (关闭)
// 与 TabTitleBar 同构：真全屏下自避让状态栏
@Component
export struct ClassicHeader {
  @Prop title: string = '';
  @Prop showClose: boolean = false;
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageProp('dsh_theme') theme: string = 'default';
  onBack: () => void = () => {};
  onClose: () => void = () => {};

  // 这个顶栏一出现就把状态栏染成和它同色，这样从任何入口进来（含冷启动/通知拉起）
  // 都不会出现"深棕顶栏 + 蓝状态栏"的错配。默认主题下设的还是品牌蓝，观感零改动。
  aboutToAppear(): void {
    BarUtil.topBar(this.theme);
  }

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
    // 默认主题 accent=品牌蓝，和原来写死的 #2D8CFA 一模一样，观感零改动；
    // 豆泥主题 accent=毛发深棕，配合状态栏/网页构成上下两段。
    .backgroundColor(Palette.accent(this.theme))
  }
}
