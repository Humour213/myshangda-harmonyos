/**
 * 迷你卡片 1×2：只回答一个问题——"现在（或下一节）上什么"。
 * 没有列表，整卡浅色打底 + 一张白卡，和小卡/大卡是同一套语言。
 */
@Entry
@Component
struct ScheduleTiny {
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('heroTag') heroTag: string = '';
  @LocalStorageProp('heroName') heroName: string = '';
  @LocalStorageProp('heroTime') heroTime: string = '';
  @LocalStorageProp('heroNote') heroNote: string = '';
  @LocalStorageProp('accent') accent: string = '#8A94A6';
  @LocalStorageProp('tint') tint: string = '#F0F2F6';

  build() {
    Column() {
      Column() {
        Row() {
          Row()
            .width(5)
            .height(5)
            .backgroundColor(this.accent)
            .borderRadius(3)
          Text(this.heroTag)
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent)
            .margin({ left: 4 })
          Blank()
          Text(this.heroNote)
            .fontSize(9)
            .fontColor('#9DA3B0')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Text(this.heroName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#10141A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })

        if (this.heroTime.length > 0) {
          Text(this.heroTime)
            .fontSize(9)
            .fontColor('#767E8C')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 1 })
        }
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 9 })
      .backgroundColor('#FFFFFF')
      .borderRadius(11)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .justifyContent(FlexAlign.Center)
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
