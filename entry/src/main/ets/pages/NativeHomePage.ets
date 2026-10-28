/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { NativeApi, CarouselItem, ServiceItem } from '../common/NativeApi';
import { Router } from '../common/Nav';
import { promptAction } from '@kit.ArkUI';

@Component
export struct NativeHomePage {
  @State carousel: CarouselItem[] = [];
  @State services: ServiceItem[] = [];
  @State section: number = 0;
  @State loading: boolean = true;
  @StorageLink('dsh_session_ready') @Watch('onSessionReady') sessionReady: number = 0;
  private sectionNames: string[] = ['常用查询', '常用服务', '常用链接', '我的服务'];
  private sectionIds: number[] = [2, 3, 4, 1];

  aboutToAppear(): void {
    this.loadData();
  }

  onSessionReady(): void {
    this.loadData();
  }

  loadData(): void {
    this.loading = true;
    NativeApi.fetchCarousel().then((c: CarouselItem[]) => {
      this.carousel = c;
    });
    NativeApi.fetchServices(2).then((s: ServiceItem[]) => {
      this.services = s;
      this.loading = false;
    });
  }

  loadSection(idx: number): void {
    this.section = idx;
    if (idx === 0) {
      NativeApi.fetchServices(2).then((s: ServiceItem[]) => {
        this.services = s;
      });
    } else {
      NativeApi.fetchServices(this.sectionIds[idx]).then((s: ServiceItem[]) => {
        this.services = s;
      });
    }
  }

  build() {
    Column() {
      // 轮播
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.carousel.length > 0) {
          Swiper() {
            ForEach(this.carousel, (c: CarouselItem) => {
              Image(c.img)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .onClick(() => {
                  if (c.url !== '') {
                    Router.openSub(c.url);
                  }
                })
            }, (c: CarouselItem) => c.img)
          }
          .width('100%')
          .height(190)
          .autoPlay(true)
          .interval(4000)
          .indicator(new DotIndicator())
        } else {
          Column() {
            Image($r('app.media.app_logo_color'))
              .width(64)
              .height(64)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height(190)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#2D8CFA')
        }

        // 搜索框悬浮于轮播底部
        Row({ space: 8 }) {
          Text('🔍')
            .fontSize(15)
          Text('搜索应用、通知')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.85)')
        }
        .width('92%')
        .height(40)
        .borderRadius(20)
        .border({ width: 1, color: 'rgba(255,255,255,0.7)' })
        .margin({ bottom: 14 })
        .onClick(() => {
          Router.openSub(`${'https://myapp.zjgsu.edu.cn'}/home/search`);
        })
      }
      .width('100%')

      // 四分区 Tab
      Row() {
        ForEach(this.sectionNames, (name: string, idx: number) => {
          Column() {
            Text(name)
              .fontSize(15)
              .fontColor(this.section === idx ? '#3296FA' : '#333333')
              .fontWeight(this.section === idx ? FontWeight.Medium : FontWeight.Normal)
            Divider()
              .width(this.section === idx ? 48 : 0)
              .strokeWidth(3)
              .color('#3296FA')
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 10, bottom: 8 })
          .onClick(() => {
            this.loadSection(idx);
          })
        }, (name: string) => name)
      }
      .width('100%')
      .backgroundColor('#F7F8FA')

      // 服务宫格
      Scroll() {
        if (this.loading && this.services.length === 0) {
          Column() {
            LoadingProgress().width(30).height(30).color('#2D8CFA')
            Text('加载中…')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else if (this.services.length === 0) {
          Column() {
            Text('没有更多了！')
              .fontSize(14)
              .fontColor('#999999')
          }
          .width('100%')
          .padding({ top: 60 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Grid() {
            ForEach(this.services, (sv: ServiceItem) => {
              GridItem() {
                Column({ space: 8 }) {
                  Image(sv.icon)
                    .width(52)
                    .height(52)
                    .borderRadius(26)
                    .objectFit(ImageFit.Cover)
                  Text(sv.name)
                    .fontSize(13)
                    .fontColor('#333333')
                    .maxLines(2)
                    .textAlign(TextAlign.Center)
                    .lineHeight(17)
                }
                .width('100%')
                .padding({ top: 14, bottom: 10, left: 6, right: 6 })
                .onClick(() => {
                  if (sv.url !== '') {
                    Router.openSub(sv.url);
                  } else {
                    promptAction.showToast({ message: '该服务暂未开放', duration: 1800 });
                  }
                })
              }
            }, (sv: ServiceItem) => sv.name + sv.url)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .rowsGap(8)
          .width('100%')
          .padding({ bottom: 90 })
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
  }
}
