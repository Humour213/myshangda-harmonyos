import { NativeApi } from '../common/NativeApi';
import { Router } from '../common/Nav';
import { BASE_URL } from '../common/Constants';

@Component
export struct NativeApprovalPage {
  @State segment: number = 0;
  @State todoCount: number = 0;
  @State loading: boolean = true;
  private segNames: string[] = ['我的待办', '我的申请', '我的已办'];

  aboutToAppear(): void {
    NativeApi.fetchTodoCount().then((n: number) => {
      this.todoCount = n;
      this.loading = false;
    });
    setTimeout(() => {
      this.loading = false;
    }, 8000);
  }

  build() {
    Column() {
      // 分段 Tab
      Row() {
        ForEach(this.segNames, (name: string, idx: number) => {
          Column({ space: 7 }) {
            Text(idx === 0 ? `${name}(${this.todoCount})` : name)
              .fontSize(16)
              .fontColor(this.segment === idx ? '#3296FA' : '#333333')
              .fontWeight(this.segment === idx ? FontWeight.Medium : FontWeight.Normal)
            Divider()
              .width(64)
              .strokeWidth(3)
              .color(this.segment === idx ? '#3296FA' : Color.Transparent)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 14, bottom: 10 })
          .onClick(() => {
            this.segment = idx;
          })
        }, (name: string) => name)
      }
      .width('100%')
      .backgroundColor('#F0F0F0')

      // 搜索框 + 筛选
      Row({ space: 10 }) {
        Row({ space: 8 }) {
          Text('🔍')
            .fontSize(14)
            .fontColor('#B0B6BE')
          Text('事项名称、申请人')
            .fontSize(14)
            .fontColor('#B0B6BE')
        }
        .layoutWeight(1)
        .height(40)
        .borderRadius(6)
        .backgroundColor(Color.White)
        .padding({ left: 12 })
        .onClick(() => {
          Router.openSub(`${BASE_URL}/message/approveList`);
        })

        Text('⛃')
          .fontSize(20)
          .fontColor('#333333')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#F0F0F0')

      // 列表区
      Column() {
        if (this.loading) {
          LoadingProgress().width(28).height(28).color('#2D8CFA')
            .margin({ top: 60 })
        } else {
          Text('没有更多了！')
            .fontSize(15)
            .fontColor('#999999')
            .margin({ top: 60 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
