/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { PrefsStore } from '../common/PrefsStore';
import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';

// 复刻原版 activity_guide.xml + fragment_guide.xml（zfsoft V7）
// 指示器用系统 Swiper Indicator.dot()（官方 create-looping 文档写法）：
// 未选圆点 10vp / 选中胶囊 28vp，全灰 #9B9B9B，距底 116vp（=原版 按钮区上方 20vp）
class GuideItem {
  title: string = '';
  sub: string = '';
  img: Resource = $rawfile('guide_img_1.png');
}

@Component
export struct GuidePage {
  onDone: () => void = () => {};
  @State curIndex: number = 0;
  @StorageLink('dsh_statusBar') statusBarHeight: number = 36;
  @StorageLink('dsh_nav_style') navStyle: string = 'native';

  private guides: GuideItem[] = (() => {
    const g1 = new GuideItem();
    g1.title = '方便快捷';
    g1.sub = '师生沟通零距离';
    g1.img = $rawfile('guide_img_1.png');
    const g2 = new GuideItem();
    g2.title = '温馨预约';
    g2.sub = '丰富多样实用化';
    g2.img = $rawfile('guide_img_2.png');
    const g3 = new GuideItem();
    g3.title = '流程明晰';
    g3.sub = '高效实时全方位';
    g3.img = $rawfile('guide_img_3.png');
    return [g1, g2, g3];
  })();

  async finish(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    const store = await PrefsStore.getStore(ctx);
    await store.put('guide_shown', true);
    await store.flush();
    this.onDone();
  }

  @Builder
  guideSlide(item: GuideItem) {
    Column() {
      Image(item.img)
        .width(263)
        .height(280)
        .objectFit(ImageFit.Fill)
        .margin({ top: 120 })
      Text(item.title)
        .fontSize(20)
        .fontColor('#3866FA')
        .margin({ top: 18 })
      Text(item.sub)
        .fontSize(16)
        .fontColor('#9B9B9B')
        .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Swiper() {
        ForEach(this.guides, (item: GuideItem) => {
          this.guideSlide(item)
        }, (item: GuideItem) => item.title)
      }
      .index(this.curIndex)
      .indicator(new DotIndicator()
        .itemWidth(10)
        .itemHeight(10)
        .selectedItemWidth(28)
        .selectedItemHeight(10)
        .color('#9B9B9B')
        .selectedColor('#9B9B9B')
        .bottom(LengthMetrics.vp(116), true))
      .loop(false)
      .width('100%')
      .height('100%')
      .onChange((i: number) => {
        this.curIndex = i;
      })

      Button('立即体验')
        .id('guide_btn')
        .backgroundColor('#1467FF')
        .borderRadius(5)
        .fontSize(18)
        .fontColor(Color.White)
        .padding({ left: 38, right: 38, top: 13, bottom: 12 })
        .margin({ bottom: 50 })
        .opacity(this.curIndex === this.guides.length - 1 ? 1 : 0)
        .animation({ duration: 300, curve: Curve.EaseOut })
        .onClick(() => {
          this.finish();
        })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.navStyle === 'classic' ? this.statusBarHeight : 0 })
    .backgroundColor('#FAFAFA')
  }
}
