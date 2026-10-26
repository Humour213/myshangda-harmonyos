/**
 * 小卡片 2×2：整卡用状态色的浅调打底，唯一一张白卡承载"此刻"（上课中/下节/明天第一节），
 * 白卡下方的剩余课程只剩圆点 + 课名 + 时间，退为次要信息。
 */
@Entry
@Component
struct ScheduleSmall {
  @LocalStorageProp('head') head: string = '';
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('heroTag') heroTag: string = '';
  @LocalStorageProp('heroName') heroName: string = '';
  @LocalStorageProp('heroTime') heroTime: string = '';
  @LocalStorageProp('heroPlace') heroPlace: string = '';
  @LocalStorageProp('heroNote') heroNote: string = '';
  @LocalStorageProp('progress') progress: number = -1;
  @LocalStorageProp('restLabel') restLabel: string = '';
  @LocalStorageProp('accent') accent: string = '#8A94A6';
  @LocalStorageProp('tint') tint: string = '#F0F2F6';
  @LocalStorageProp('ink') ink: string = '#232A36';

  @LocalStorageProp('t0') t0: string = ''; @LocalStorageProp('n0') n0: string = '';
  @LocalStorageProp('f0') f0: string = '';

  @LocalStorageProp('t1') t1: string = ''; @LocalStorageProp('n1') n1: string = '';
  @LocalStorageProp('f1') f1: string = '';

  @LocalStorageProp('t2') t2: string = ''; @LocalStorageProp('n2') n2: string = '';
  @LocalStorageProp('f2') f2: string = '';

  @LocalStorageProp('t3') t3: string = ''; @LocalStorageProp('n3') n3: string = '';
  @LocalStorageProp('f3') f3: string = '';

  @LocalStorageProp('t4') t4: string = ''; @LocalStorageProp('n4') n4: string = '';
  @LocalStorageProp('f4') f4: string = '';

  @LocalStorageProp('t5') t5: string = ''; @LocalStorageProp('n5') n5: string = '';
  @LocalStorageProp('f5') f5: string = '';

  @LocalStorageProp('t6') t6: string = ''; @LocalStorageProp('n6') n6: string = '';
  @LocalStorageProp('f6') f6: string = '';

  @LocalStorageProp('t7') t7: string = ''; @LocalStorageProp('n7') n7: string = '';
  @LocalStorageProp('f7') f7: string = '';

  private ft(i: number): string {
    if (i === 0) { return this.t0; } else if (i === 1) { return this.t1; }
    else if (i === 2) { return this.t2; } else if (i === 3) { return this.t3; }
    else if (i === 4) { return this.t4; } else if (i === 5) { return this.t5; }
    else if (i === 6) { return this.t6; }
    return this.t7;
  }

  private fn(i: number): string {
    if (i === 0) { return this.n0; } else if (i === 1) { return this.n1; }
    else if (i === 2) { return this.n2; } else if (i === 3) { return this.n3; }
    else if (i === 4) { return this.n4; } else if (i === 5) { return this.n5; }
    else if (i === 6) { return this.n6; }
    return this.n7;
  }

  private ff(i: number): string {
    if (i === 0) { return this.f0; } else if (i === 1) { return this.f1; }
    else if (i === 2) { return this.f2; } else if (i === 3) { return this.f3; }
    else if (i === 4) { return this.f4; } else if (i === 5) { return this.f5; }
    else if (i === 6) { return this.f6; }
    return this.f7;
  }

  /** 时间只留开始时刻，2×2 宽度经不起完整时段 */
  private hm(t: string): string {
    if (t.length >= 5) {
      return t.substring(0, 5);
    }
    return t;
  }

  @Builder
  row(i: number) {
    Row({ space: 7 }) {
      Row()
        .width(6)
        .height(6)
        .backgroundColor(this.ff(i))
        .borderRadius(3)
      Text(this.fn(i))
        .fontSize(12)
        .fontColor(this.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text(this.hm(this.ft(i)))
        .fontSize(10)
        .fontColor('#8A91A0')
    }
    .width('100%')
    .height(23)
  }

  build() {
    Column() {
      // 主视觉：全卡唯一一张白卡，"此刻"的答案就落在这里
      Column() {
        Row() {
          Text(this.heroTag)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent)
          Blank()
          Text(this.head)
            .fontSize(9)
            .fontColor('#9DA3B0')
            .maxLines(1)
        }
        .width('100%')

        Text(this.heroName)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#10141A')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })

        if (this.heroTime.length > 0) {
          Row() {
            Text(this.heroTime)
              .fontSize(10)
              .fontColor('#767E8C')
            if (this.heroPlace.length > 0) {
              Text(' · ' + this.heroPlace)
                .fontSize(10)
                .fontColor('#767E8C')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
          }
          .width('100%')
          .margin({ top: 2 })
        }

        if (this.progress >= 0) {
          Row() {
            Row()
              .width(`${this.progress}%`)
              .height(3)
              .backgroundColor(this.accent)
              .borderRadius(2)
          }
          .width('100%')
          .height(3)
          .backgroundColor('#EBEEF3')
          .borderRadius(2)
          .margin({ top: 6 })
        } else if (this.heroNote.length > 0) {
          Text(this.heroNote)
            .fontSize(10)
            .fontColor(this.accent)
            .margin({ top: 3 })
        }
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 9 })
      .backgroundColor('#FFFFFF')
      .borderRadius(11)
      .alignItems(HorizontalAlign.Start)

      // 次要信息：之后还有的课
      List({ space: 1 }) {
        ListItem() {
          Column() {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
              if (this.fn(i).length > 0) {
                this.row(i)
              }
            }, (i: number) => String(i))
          }
          .width('100%')
          .padding({ top: 6, bottom: 2 })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)

      if (this.restLabel.length > 0) {
        Text(this.restLabel)
          .fontSize(9)
          .fontColor(this.accent)
          .opacity(0.9)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 10, right: 10, top: 9, bottom: 8 })
    .backgroundColor(this.tint)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'tab': '2' }
      });
    })

  }
}
