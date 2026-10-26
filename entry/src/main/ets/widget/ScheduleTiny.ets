/**
 * 迷你卡片 1×2：只回答一个问题——"现在（或下一节）上什么"。
 *
 * 1×2 高度太矮，套不进"浅底 + 白卡"两层结构（会看成一个奇怪的内框），
 * 所以这里退成单层：状态色浅底 + 左侧竖色条，标签和时间同一行，课名一行收尾。
 */
@Entry
@Component
struct ScheduleTiny {
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('heroTag') heroTag: string = '';
  @LocalStorageProp('heroName') heroName: string = '';
  @LocalStorageProp('heroTime') heroTime: string = '';
  @LocalStorageProp('accent') accent: string = '#8A94A6';
  @LocalStorageProp('tint') tint: string = '#F0F2F6';
  @LocalStorageProp('ink') ink: string = '#232A36';

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
          Blank()
          if (this.heroTime.length > 0) {
            Text(this.heroTime)
              .fontSize(9)
              .fontColor('#8A91A0')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')

        Text(this.heroName)
          .fontSize(15)
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
