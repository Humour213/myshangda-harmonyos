/**
 * 大卡片 2×4：整卡用状态色的浅调打底，顶部一张白卡承载"此刻"，
 * 下面是被降级的课程列表（圆点 + 课名 + 地点 + 开始时间）。
 * 信息比小卡更多：保留了地点和「共几节 · 还剩几节」。
 */
@Entry
@Component
struct ScheduleLarge {
  @LocalStorageProp('head') head: string = '';
  @LocalStorageProp('state') state: string = 'none';
  @LocalStorageProp('heroTag') heroTag: string = '';
  @LocalStorageProp('heroName') heroName: string = '';
  @LocalStorageProp('heroTime') heroTime: string = '';
  @LocalStorageProp('heroPlace') heroPlace: string = '';
  @LocalStorageProp('heroNote') heroNote: string = '';
  @LocalStorageProp('progress') progress: number = -1;
  @LocalStorageProp('summary') summary: string = '';
  @LocalStorageProp('accent') accent: string = '#8A94A6';
  @LocalStorageProp('tint') tint: string = '#F0F2F6';
  @LocalStorageProp('ink') ink: string = '#232A36';

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

  /** 数据里的 slots 含正在上/下一节那一门，此刻卡的主视觉已经展示了它，列表要跳过 */
  private off(): number {
    if (this.state === 'now' || this.state === 'next' || this.state === 'tomorrow') {
      return 1;
    }
    return 0;
  }

  private hm(t: string): string {
    if (t.length >= 5) {
      return t.substring(0, 5);
    }
    return t;
  }

  @Builder
  row(i: number) {
    Row({ space: 9 }) {
      Row()
        .width(7)
        .height(7)
        .backgroundColor(this.ff(i))
        .borderRadius(4)
      Column() {
        Text(this.fn(i))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.fp(i).length > 0) {
          Text(this.fp(i))
            .fontSize(10)
            .fontColor('#8A91A0')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.hm(this.ft(i)))
        .fontSize(10)
        .fontColor('#8A91A0')
    }
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  /**
   * 卡片不支持 heightAdaptivePolicy，所以自己估一个字号：
   * 汉字按 1em、ASCII 按 0.55em 估宽度，能一行放下就用最大字号，放不下逐级缩到 min。
   */
  private nameSize(max: number, min: number, boxW: number): number {
    let w: number = 0;
    for (let i = 0; i < this.heroName.length; i++) {
      w += this.heroName.charCodeAt(i) > 127 ? 1 : 0.55;
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
    Column() {
      // 卡片抬头：左边日期，右边今天上完了没
      Row() {
        Text(this.head)
          .fontSize(10)
          .fontColor('#8A93A6')
        Blank()
        Text(this.summary)
          .fontSize(10)
          .fontColor(this.accent)
          .opacity(0.9)
      }
      .width('100%')
      .margin({ bottom: 7 })

      // 主视觉：全卡唯一一张白卡
      Column() {
        Row() {
          Text(this.heroTag)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.accent)
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor(this.tint)
            .borderRadius(5)
          Blank()
          Text(this.heroNote)
            .fontSize(10)
            .fontColor('#9DA3B0')
        }
        .width('100%')

        Text(this.heroName)
          .fontSize(this.nameSize(20, 14, 150))
          .fontWeight(FontWeight.Medium)
          .fontColor('#10141A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 5 })

        if (this.heroTime.length > 0) {
          Text(this.heroPlace.length > 0 ? `${this.heroTime} · ${this.heroPlace}` : this.heroTime)
            .fontSize(11)
            .fontColor('#767E8C')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 3 })
        }

        if (this.progress >= 0) {
          Row() {
            Row()
              .width(`${this.progress}%`)
              .height(4)
              .backgroundColor(this.accent)
              .borderRadius(2)
          }
          .width('100%')
          .height(4)
          .backgroundColor('#EBEEF3')
          .borderRadius(2)
          .margin({ top: 9 })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 11 })
      .backgroundColor('#FFFFFF')
      .borderRadius(13)
      .alignItems(HorizontalAlign.Start)

      List({ space: 1 }) {
        ListItem() {
          Column() {
            ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
              if (i + this.off() < 8 && this.fn(i + this.off()).length > 0) {
                this.row(i + this.off())
              }
            }, (i: number) => String(i))
          }
          .width('100%')
          .padding({ top: 8, bottom: 2 })
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .borderRadius({ bottomLeft: 18, bottomRight: 18 })
      .clip(true)

    }
    .width('100%')
    .height('100%')
    .padding({ left: 13, right: 13, top: 11, bottom: 10 })
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
