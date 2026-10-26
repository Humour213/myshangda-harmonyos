/**
 * 小卡片 2×2：状态 + 剩余课程（可滚动）。
 * 不放"共几节/还剩几节"，把空间留给课程本身。
 */
@Entry
@Component
struct ScheduleSmall {
  @LocalStorageProp('date') date: string = '';
  @LocalStorageProp('weekday') weekday: string = '';
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('status') status: string = '';
  @LocalStorageProp('detail') detail: string = '';

  @LocalStorageProp('t0') t0: string = ''; @LocalStorageProp('n0') n0: string = '';
  @LocalStorageProp('p0') p0: string = ''; @LocalStorageProp('b0') b0: string = '';
  @LocalStorageProp('f0') f0: string = '';

  @LocalStorageProp('t1') t1: string = ''; @LocalStorageProp('n1') n1: string = '';
  @LocalStorageProp('p1') p1: string = ''; @LocalStorageProp('b1') b1: string = '';
  @LocalStorageProp('f1') f1: string = '';

  @LocalStorageProp('t2') t2: string = ''; @LocalStorageProp('n2') n2: string = '';
  @LocalStorageProp('p2') p2: string = ''; @LocalStorageProp('b2') b2: string = '';
  @LocalStorageProp('f2') f2: string = '';

  @LocalStorageProp('t3') t3: string = ''; @LocalStorageProp('n3') n3: string = '';
  @LocalStorageProp('p3') p3: string = ''; @LocalStorageProp('b3') b3: string = '';
  @LocalStorageProp('f3') f3: string = '';

  @LocalStorageProp('t4') t4: string = ''; @LocalStorageProp('n4') n4: string = '';
  @LocalStorageProp('p4') p4: string = ''; @LocalStorageProp('b4') b4: string = '';
  @LocalStorageProp('f4') f4: string = '';

  @LocalStorageProp('t5') t5: string = ''; @LocalStorageProp('n5') n5: string = '';
  @LocalStorageProp('p5') p5: string = ''; @LocalStorageProp('b5') b5: string = '';
  @LocalStorageProp('f5') f5: string = '';

  @LocalStorageProp('t6') t6: string = ''; @LocalStorageProp('n6') n6: string = '';
  @LocalStorageProp('p6') p6: string = ''; @LocalStorageProp('b6') b6: string = '';
  @LocalStorageProp('f6') f6: string = '';

  @LocalStorageProp('t7') t7: string = ''; @LocalStorageProp('n7') n7: string = '';
  @LocalStorageProp('p7') p7: string = ''; @LocalStorageProp('b7') b7: string = '';
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

  private fp(i: number): string {
    if (i === 0) { return this.p0; } else if (i === 1) { return this.p1; }
    else if (i === 2) { return this.p2; } else if (i === 3) { return this.p3; }
    else if (i === 4) { return this.p4; } else if (i === 5) { return this.p5; }
    else if (i === 6) { return this.p6; }
    return this.p7;
  }

  private fb(i: number): string {
    if (i === 0) { return this.b0; } else if (i === 1) { return this.b1; }
    else if (i === 2) { return this.b2; } else if (i === 3) { return this.b3; }
    else if (i === 4) { return this.b4; } else if (i === 5) { return this.b5; }
    else if (i === 6) { return this.b6; }
    return this.b7;
  }

  private ff(i: number): string {
    if (i === 0) { return this.f0; } else if (i === 1) { return this.f1; }
    else if (i === 2) { return this.f2; } else if (i === 3) { return this.f3; }
    else if (i === 4) { return this.f4; } else if (i === 5) { return this.f5; }
    else if (i === 6) { return this.f6; }
    return this.f7;
  }

  @Builder
  block(i: number) {
    Column() {
      Row() {
        Text(this.ft(i))
          .fontSize(10)
          .fontColor(this.ff(i))
          .opacity(0.85)
        Blank()
        Text(this.fp(i))
          .fontSize(10)
          .fontColor(this.ff(i))
          .opacity(0.75)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Text(this.fn(i))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.ff(i))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 1 })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .backgroundColor(this.fb(i))
    .borderRadius(9)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Text(this.date)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(' ' + this.weekday)
          .fontSize(11)
          .fontColor('#8A8F98')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 4 })

      // 状态行
      Row({ space: 6 }) {
        if (this.state === 'now') {
          Row()
            .width(7)
            .height(7)
            .backgroundColor('#3FBF6F')
            .borderRadius(4)
        }
        Text(this.status)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.state === 'done' || this.state === 'none' ? '#8A8F98' : '#1E63B4')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 2 })

      if (this.detail.length > 0) {
        Text(this.detail)
          .fontSize(10)
          .fontColor('#8A8F98')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 12, right: 12 })
      }

      // 剩余课程：可滚动，底部留白避免最后一块被裁
      List({ space: 5 }) {
        ListItem() {
          Column({ space: 5 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
              if (this.fn(i).length > 0) {
                this.block(i)
              }
            }, (i: number) => String(i))
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 6, bottom: 12 })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { 'tab': '2' }
      });
    })

  }
}
