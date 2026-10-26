/**
 * 迷你卡片 1×2：只回答一个问题——"现在（或下一节）上什么"。
 *
 * 1×2 高度只有两行，套不进"浅底 + 白卡"两层结构（会看成一个奇怪的内框），
 * 所以退成单层：状态色浅底 + 左侧竖色条。
 * 第一行放「状态标签 …… 时间 · 地点」，课名独占第二行，字号按范围自适应。
 */
@Entry
@Component
struct ScheduleTiny {
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('heroTag') heroTag: string = '';
  @LocalStorageProp('heroName') heroName: string = '';
  @LocalStorageProp('heroTime') heroTime: string = '';
  @LocalStorageProp('heroPlace') heroPlace: string = '';
  @LocalStorageProp('accent') accent: string = '#8A94A6';
  @LocalStorageProp('tint') tint: string = '#F0F2F6';
  @LocalStorageProp('ink') ink: string = '#232A36';

  /** 1×2 只有两行，时间地点必须挤成一行小字放右上 */
  private tp(): string {
    if (this.heroTime.length > 0 && this.heroPlace.length > 0) {
      return `${this.heroTime} · ${this.heroPlace}`;
    }
    if (this.heroTime.length > 0) {
      return this.heroTime;
    }
    return this.heroPlace;
  }

  /**
   * 卡片不支持 heightAdaptivePolicy，所以自己估一个字号：
   * 汉字按 1em、ASCII 按 0.55em 估宽度，能一行放下就用最大字号，放不下逐级缩到 min。
   */
  private nameSize(max: number, min: number, boxW: number): number {
    let w: number = 0;
    for (let i = 0; i < this.heroName.length; i++) {
      w += this.heroName.charCodeAt(i) > 127 ? 1.05 : 0.56;
    }
    if (w <= 0) {
      return max;
    }
    let s: number = Math.floor(boxW / w);
    if (s > max) {
      s = max;
    }
    if (s < min) {
      s = min;
    }
    return s;
  }

  build() {
    Row() {
      // 左侧竖条：替代白卡，用一条色带说明"此刻"
      Row()
        .width(3)
        .height('100%')
        .backgroundColor(this.accent)
        .borderRadius(2)

      Column() {
        Row() {
          Text(this.heroTag)
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent)
          Text(this.tp())
            .fontSize(10)
            .fontColor('#8A91A0')
            .maxLines(1)
            .textAlign(TextAlign.End)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Text(this.heroName)
          .fontSize(this.nameSize(15, 12, 138))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 9 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 11, right: 11, top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.tint)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'tab': '2' }
      });
    })

  }
}
