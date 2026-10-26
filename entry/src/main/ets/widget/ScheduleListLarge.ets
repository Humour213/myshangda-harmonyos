/**
 * 列表卡 2×4（旧版白底 + 彩色块的版式，保留原样）。
 *
 * 比小卡多给地点和「共几节 · 还剩几节」；同样不判断"上课中/下节"，
 * 只是把还没上完的课按时间排下来，上完一节少一条，全上完切成明天。
 */

const L_BLOCK_BG: string[] = ['#D6E9FF', '#D6F5EA', '#D6E4FF', '#FFE7D1',
  '#E3DDFF', '#D9F7D0', '#FFD9D9', '#FFE9B8'];
const L_TM_BG: string = '#E5EBFA';

@Entry
@Component
struct ScheduleListLarge {
  @LocalStorageProp('head') head: string = '';
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('listLabel') listLabel: string = '';
  @LocalStorageProp('summary') summary: string = '';

  @LocalStorageProp('t0') t0: string = ''; @LocalStorageProp('n0') n0: string = '';
  @LocalStorageProp('p0') p0: string = ''; @LocalStorageProp('f0') f0: string = '';

  @LocalStorageProp('t1') t1: string = ''; @LocalStorageProp('n1') n1: string = '';
  @LocalStorageProp('p1') p1: string = ''; @LocalStorageProp('f1') f1: string = '';

  @LocalStorageProp('t2') t2: string = ''; @LocalStorageProp('n2') n2: string = '';
  @LocalStorageProp('p2') p2: string = ''; @LocalStorageProp('f2') f2: string = '';

  @LocalStorageProp('t3') t3: string = ''; @LocalStorageProp('n3') n3: string = '';
  @LocalStorageProp('p3') p3: string = ''; @LocalStorageProp('f3') f3: string = '';

  @LocalStorageProp('t4') t4: string = ''; @LocalStorageProp('n4') n4: string = '';
  @LocalStorageProp('p4') p4: string = ''; @LocalStorageProp('f4') f4: string = '';

  @LocalStorageProp('t5') t5: string = ''; @LocalStorageProp('n5') n5: string = '';
  @LocalStorageProp('p5') p5: string = ''; @LocalStorageProp('f5') f5: string = '';

  @LocalStorageProp('t6') t6: string = ''; @LocalStorageProp('n6') n6: string = '';
  @LocalStorageProp('p6') p6: string = ''; @LocalStorageProp('f6') f6: string = '';

  @LocalStorageProp('t7') t7: string = ''; @LocalStorageProp('n7') n7: string = '';
  @LocalStorageProp('p7') p7: string = ''; @LocalStorageProp('f7') f7: string = '';

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

  private ff(i: number): string {
    if (i === 0) { return this.f0; } else if (i === 1) { return this.f1; }
    else if (i === 2) { return this.f2; } else if (i === 3) { return this.f3; }
    else if (i === 4) { return this.f4; } else if (i === 5) { return this.f5; }
    else if (i === 6) { return this.f6; }
    return this.f7;
  }

  private fb(i: number): string {
    if (this.state === 'tomorrow') {
      return L_TM_BG;
    }
    return L_BLOCK_BG[i % L_BLOCK_BG.length];
  }

  @Builder
  block(i: number) {
    Column() {
      Row() {
        Text(this.ft(i))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.ff(i))
          .opacity(0.9)
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
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.ff(i))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.fb(i))
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Text(this.head)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.state === 'tomorrow' ? '#2E4A7D' : '#1A1A1A')
        Blank()
        Text(this.summary)
          .fontSize(11)
          .fontColor('#A8B0BC')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 6 })

      if (this.state === 'tomorrow') {
        Row() {
          Text(this.listLabel)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A568C')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#DCE5F8')
            .borderRadius(7)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 2, bottom: 2 })
      }

      List({ space: 7 }) {
        ListItem() {
          Column({ space: 7 }) {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
              if (this.fn(i).length > 0) {
                this.block(i)
              }
            }, (i: number) => String(i))
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 6, bottom: 14 })
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
