import { NativeApi } from '../common/NativeApi';
import { Router } from '../common/Nav';
import { BASE_URL } from '../common/Constants';

class MsgEntry {
  title: string = '';
  sub: string = '';
  color: string = '#4CAF50';
  icon: Resource | null = null;
  url: string = '';
}

@Component
export struct NativeMsgPage {
  @State todoCount: number = 0;
  @State today: string = '';
  @State loading: boolean = true;
  @StorageLink('dsh_session_ready') @Watch('onSessionReady') sessionReady: number = 0;

  onSessionReady(): void {
    NativeApi.fetchTodoCount().then((n: number) => {
      this.todoCount = n;
      this.loading = false;
    });
  }

  aboutToAppear(): void {
    const d = new Date();
    this.today = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    NativeApi.fetchTodoCount().then((n: number) => {
      this.todoCount = n;
      this.loading = false;
    });
    setTimeout(() => {
      this.loading = false;
    }, 8000);
  }

  @Builder
  msgCard(title: string, sub: string, color: string, url: string) {
    Row({ space: 14 }) {
      Stack() {
        Circle()
          .width(54)
          .height(54)
          .fill(color)
        Text(title.substring(0, 1))
          .fontSize(22)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(54)
      .height(54)

      Column({ space: 5 }) {
        Text(title)
          .fontSize(17)
          .fontColor('#222222')
          .fontWeight(FontWeight.Medium)
        Text(sub)
          .fontSize(13)
          .fontColor('#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
    .onClick(() => {
      if (url !== '') {
        Router.openSub(url);
      }
    })
  }

  build() {
    Scroll() {
      Column() {
        Grid() {
          GridItem() {
            this.msgCard('校务消息', this.todoCount > 0 ? `您有${this.todoCount}条待办待处…` : '暂无新的通知', '#4CAF50',
              `${BASE_URL}/xxzx/html/todo-list.html`)
          }
          GridItem() {
            this.msgCard('预约消息', '标题：座位预约成…', '#4CAF50', `${BASE_URL}/message/index2`)
          }
          GridItem() {
            this.msgCard('导学沟通', '暂无新的通知', '#29B6F6', `${BASE_URL}/message/index2`)
          }
          GridItem() {
            this.msgCard('日程消息', '您明日有1个日程,…', '#4CAF50', `${BASE_URL}/message/scheduleRemind`)
          }
          GridItem() {
            this.msgCard('未读邮件', '您有0条未读邮件', '#FF9800', `${BASE_URL}/my/email-center`)
          }
        }
        .columnsTemplate('1fr 1fr')
        .width('100%')
        .backgroundColor(Color.White)

        Divider().color('#F2F2F2').strokeWidth(8)

        Row() {
          Text(this.today)
            .fontSize(16)
            .fontColor('#333333')
          Blank()
          Text('全部日程')
            .fontSize(15)
            .fontColor('#333333')
          Text(' >')
            .fontSize(15)
            .fontColor('#333333')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .backgroundColor(Color.White)
        .onClick(() => {
          Router.openSub(`${BASE_URL}/message/holeCalendar`);
        })

        Column() {
          if (this.loading) {
            LoadingProgress().width(26).height(26).color('#2D8CFA')
          } else {
            Text('没有更多了！')
              .fontSize(14)
              .fontColor('#999999')
          }
        }
        .width('100%')
        .padding({ top: 60 })
        .alignItems(HorizontalAlign.Center)
      }
      .constraintSize({ minWidth: '100%' })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
