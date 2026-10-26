/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { TabDef } from '../common/Constants';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct NavDock {
  @Prop tabs: TabDef[] = [];
  @Prop current: number = 0;
  onSelect: (id: number) => void = (_id: number) => {};

  build() {
    Row() {
      ForEach(this.tabs, (tab: TabDef) => {
        Column({ space: 3 }) {
          Image(this.current === tab.id ? tab.iconOn : tab.iconOff)
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
            .draggable(false)
          Text(tab.label)
            .fontSize(10)
            .fontWeight(this.current === tab.id ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.current === tab.id ? '#2D8CFA' : '#C1C1C1')
            .maxLines(1)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .height('100%')
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onClick(() => {
          hilog.info(0x0001, 'NavDock', 'dock clicked %{public}d', tab.id);
          this.onSelect(tab.id);
        })
      }, (tab: TabDef) => `${tab.id}`)
    }
    .width('100%')
    .height('100%')
    .borderRadius(30)
    .backgroundColor('rgba(255,255,255,0.78)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .shadow({ radius: 18, color: 'rgba(23,43,99,0.16)', offsetY: 4 })
    .border({ width: 0.6, color: 'rgba(255,255,255,0.65)' })
  }
}
