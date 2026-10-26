/**
 * 迷你卡片 1×2：只显示"此刻"——上课中，或下节课；今天结束后切换成"明天预告"。
 * 不放列表、也不放状态点，把宽度全留给文字。
 */
@Entry
@Component
struct ScheduleTiny {
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('status') status: string = '';
  @LocalStorageProp('detail') detail: string = '';
  @LocalStorageProp('tmTime') tmTime: string = '';
  @LocalStorageProp('tmName') tmName: string = '';

  build() {
    Column({ space: 3 }) {
      if (this.state === 'tomorrow') {
        // 「明天」做成小胶囊 + 第一节时间，课名放第二行，一眼看出这是预告
        Row({ space: 5 }) {
          Text('明天')
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A568C')
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor('#DCE5F8')
            .borderRadius(4)
          Text(this.tmTime)
            .fontSize(10)
            .fontColor('#7C8BAE')
        }
        .width('100%')

        Text(this.tmName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2E4A7D')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      } else {
        Text(this.status)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.state === 'done' || this.state === 'none' ? '#8A8F98' : '#1A1A1A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.detail.length > 0) {
          Text(this.detail)
            .fontSize(10)
            .fontColor('#8A8F98')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.state === 'tomorrow' ? '#F4F7FE' : '#FFFFFF')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'tab': '2' }
      });
    })

  }
}
