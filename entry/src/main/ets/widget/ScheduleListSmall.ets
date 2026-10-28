/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
/**
 * 列表卡 2×2（旧版白底 + 彩色块的版式，保留原样）。
 *
 * 和此刻卡的区别：不判断"上课中/下节"，只按时间顺序列出还没上完的课，
 * 每上完一节就少一条；今天的课上完以后整卡切到明天（淡蓝底 + 「明天」胶囊）。
 */

/** 彩色块的底色，按索引轮转；文字色由数据层给（f*），两边同索引即同一套配色 */
const S_BLOCK_BG: string[] = ['#D6E9FF', '#D6F5EA', '#D6E4FF', '#FFE7D1',
  '#E3DDFF', '#D9F7D0', '#FFD9D9', '#FFE9B8'];
/** 明天预告统一淡靛蓝，整组看成一件事 */
const S_TM_BG: string = '#E5EBFA';

@Entry
@Component
struct ScheduleListSmall {
  @LocalStorageProp('head') head: string = '';
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('listLabel') listLabel: string = '';

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
      return S_TM_BG;
    }
    return S_BLOCK_BG[i % S_BLOCK_BG.length];
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
      Text(this.head)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.state === 'tomorrow' ? '#2E4A7D' : '#1A1A1A')
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 4 })

      // 原来放"上课中/下节"的位置，现在只报还剩几节（不判断在上什么）
      Row() {
        if (this.state === 'tomorrow') {
          Text(this.listLabel)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A568C')
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor('#DCE5F8')
            .borderRadius(6)
        } else {
          Text(this.listLabel)
            .fontSize(11)
            .fontColor('#8A8F98')
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 2, bottom: 2 })

      // 还没上完的课：上完一节就少一条
      //
      // 留白与弧度：外面这层 Column 负责"留白"（左/右/下各 8vp，和上、左、右的留白等宽），
      // 里面那层 List 才是被裁切的滚动区。卡片外弧半径按 16 算，滚动区整体内缩 8vp，
      // 所以裁切弧取 16 - 8 = 8 —— 两条弧同心，留白处处等宽，弧线切的是课程内容本身，
      // 而不是把留白吃掉、让内容顶到卡片底边。
      Column() {
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
            .padding({ top: 6, bottom: 0 })
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .borderRadius({ bottomLeft: 8, bottomRight: 8 })
        .clip(true)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8, bottom: 8 })
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
