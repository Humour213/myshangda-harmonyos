/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { THEME_JIWA, themeDef } from './ThemeConfig';

/**
 * 小豆泥素材池
 *
 * 设计意图：页面不直接引用具体图片，只声明"这是什么语义的时刻"，由池子决定放哪只。
 * 好处是加图不用改页面 —— 新图丢进 base/media、在下面加一行，第二天自动生效。
 *
 * 槽位（8 个，语义固定、图可增减；括号内为当前张数）：
 *   passive  待着     默认、引导页、关于页            8 张
 *   empty    空了     列表无数据                      2 张
 *   rest     没事干   今日无课、周末                  2 张
 *   loading  在忙     加载中、同步                    1 张
 *   error    出问题   网络失败、登录失败              3 张
 *   success  成了     登录成功、保存成功              6 张
 *   praise   厉害了   全勤、连续打卡                  4 张
 *   notify   提醒你   提醒相关（不能做通知图标，见下）  1 张
 *
 * 注：上课提醒走 ReminderRequestAlarm，它的字段里没有大图标位，
 * 硬改成 notificationManager.publish 会丢掉"每周固定重复"的能力，得不偿失。
 * notify 槽位暂时只给应用内使用。
 *
 * 每个槽位的图按「槽位名 + 本次启动的种子」哈希轮换：
 * 一次运行内始终是同一只（不会刷一下换一张，那会显得很吵），
 * **杀掉重开就换一只**。种子由 EntryAbility.onCreate 写入，冷启动一次一个。
 * 取不到种子（比如组件被单独预览）时退回按日期，行为跟以前一致。
 */
const PASSIVE: Resource[] = [
  $r('app.media.douni_passive_01'),
  $r('app.media.douni_passive_02'),
  $r('app.media.douni_passive_03'),
  // 新批次：倒立钻、大眼坐、奔跑、推购物车、挥绒球
  $r('app.media.douni_passive_04'),
  $r('app.media.douni_passive_05'),
  $r('app.media.douni_passive_06'),
  $r('app.media.douni_passive_07'),
  $r('app.media.douni_passive_08')
  // 原来的第 4 张（举爪子贴嘴那只）已按用户意见剔除：
  // 缩小到标题栏尺寸后动作读不出来，只剩一团说不清的形状，反而显脏。
  // 原图和抠好的 PNG 都还在「主题-小豆泥/抠图成品-v6」，要用随时能捞回来。
];
const EMPTY: Resource[] = [
  $r('app.media.douni_empty_01'),
  $r('app.media.douni_empty_02')
];
const REST: Resource[] = [
  $r('app.media.douni_rest_01'),
  $r('app.media.douni_rest_02') // 新批次：趴睡 ZZZ
];
// 原来的 douni_loading_01 原图（OIP-C (2).jpg）是 250x175 宽幅构图，
// 头顶耳朵和身体下半截在原始画布里就被切平了，放加载页看着像被裁。
// 换成 passive_01（抱脚坐）：四周都不贴边、身体完整，安静等待的姿态也配「正在翻课表」。
const LOADING: Resource[] = [$r('app.media.douni_passive_01')];
const ERROR: Resource[] = [
  $r('app.media.douni_error_01'),
  $r('app.media.douni_error_02'), // 新批次：生气发抖
  $r('app.media.douni_error_03')  // 新批次：大哭（自带粉色装饰块）
];
const SUCCESS: Resource[] = [
  $r('app.media.douni_success_01'),
  $r('app.media.douni_success_02'),
  $r('app.media.douni_success_03'),
  // 新批次：举红心、双举小鱼、抱大红心
  $r('app.media.douni_success_04'),
  $r('app.media.douni_success_05'),
  $r('app.media.douni_success_06')
];
const PRAISE: Resource[] = [
  $r('app.media.douni_praise_01'),
  $r('app.media.douni_praise_02'),
  $r('app.media.douni_praise_03'), // 新批次：抱西瓜
  $r('app.media.douni_praise_04')  // 新批次：吐舌鬼脸
];
const NOTIFY: Resource[] = [$r('app.media.douni_notify_01')];

/**
 * 按主题索引的贴纸池。key 是主题 id，value 是该主题 8 个槽位的资源数组。
 *
 * 加新主题贴纸：把抠好的 PNG 放进 base/media，在下面加一条 Map 记录即可，
 * 页面代码不用动。吉蛙 13 张已按语义挂进 8 个槽位。
 */
type SlotPools = Map<string, Resource[]>;

const DOUNI_POOLS: SlotPools = new Map<string, Resource[]>([
  ['passive', PASSIVE], ['empty', EMPTY], ['rest', REST], ['loading', LOADING],
  ['error', ERROR], ['success', SUCCESS], ['praise', PRAISE], ['notify', NOTIFY]
]);
/* 吉蛙：13 张成品按语义复用，同一张图可以出现在多个时刻 */
const JIWA_PASSIVE: Resource[] = [
  $r('app.media.jiwa_01'), $r('app.media.jiwa_02'), $r('app.media.jiwa_03'),
  $r('app.media.jiwa_09'), $r('app.media.jiwa_12')
];
const JIWA_EMPTY: Resource[] = [
  $r('app.media.jiwa_04'), $r('app.media.jiwa_11')
];
const JIWA_REST: Resource[] = [
  $r('app.media.jiwa_05'), $r('app.media.jiwa_13')
];
const JIWA_LOADING: Resource[] = [$r('app.media.jiwa_03')];
const JIWA_ERROR: Resource[] = [
  $r('app.media.jiwa_06'), $r('app.media.jiwa_11'), $r('app.media.jiwa_05')
];
const JIWA_SUCCESS: Resource[] = [
  $r('app.media.jiwa_08'), $r('app.media.jiwa_12'),
  $r('app.media.jiwa_10'), $r('app.media.jiwa_07')
];
const JIWA_PRAISE: Resource[] = [
  $r('app.media.jiwa_07'), $r('app.media.jiwa_10'), $r('app.media.jiwa_08')
];
const JIWA_NOTIFY: Resource[] = [$r('app.media.jiwa_04')];

const JIWA_POOLS: SlotPools = new Map<string, Resource[]>([
  ['passive', JIWA_PASSIVE], ['empty', JIWA_EMPTY], ['rest', JIWA_REST],
  ['loading', JIWA_LOADING], ['error', JIWA_ERROR], ['success', JIWA_SUCCESS],
  ['praise', JIWA_PRAISE], ['notify', JIWA_NOTIFY]
]);

function poolsOf(theme: string): SlotPools {
  return theme === THEME_JIWA ? JIWA_POOLS : DOUNI_POOLS;
}

function listOf(theme: string, slot: string): Resource[] {
  const pools: SlotPools = poolsOf(theme);
  const found: Resource[] | undefined = pools.get(slot);
  return found === undefined ? [] : found;
}

/**
 * 某个槽位没图时的退化路线。
 * 兜底到 passive 而不是留白 —— 宁可放一张通用图，也不要让界面出现空洞。
 */
function fallbackOf(slot: string): string {
  switch (slot) {
    case 'rest':
      return 'empty';
    case 'notify':
      return 'success';
    case 'empty':
    case 'loading':
    case 'error':
    case 'success':
    case 'praise':
      return 'passive';
    default:
      return '';
  }
}

function dayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

/**
 * 本次启动的轮换种子。
 *
 * 想让"每次打开都不一样"，种子就必须在冷启动时变一次、且在一次运行里保持不变 ——
 * 直接用 Date.now() 当种子会让每次重绘都换图（太吵），而按日期又一天才换一次（太死）。
 * 所以由 EntryAbility.onCreate 写一个种子进 AppStorage，这里只负责读。
 */
function launchSeed(): string {
  const s: string | undefined = AppStorage.get<string>('dsh_launch_seed');
  return (s === undefined || s === '') ? dayKey() : s;
}

/** 稳定哈希：只要求同一输入结果稳定，不要求分布均匀 */
function hash(text: string): number {
  let h = 5381;
  for (let i = 0; i < text.length; i++) {
    h = (h * 33 + text.charCodeAt(i)) % 2147483647;
  }
  return h;
}

export class MascotPool {
  /**
   * 取某个主题、某个槽位今天该用的图。
   * 槽位名写错会退到 passive；该主题没有贴纸池时返回 undefined（组件就不渲染）。
   */
  static pick(theme: string, slot: string): Resource | undefined {
    let cur = slot;
    let guard = 0;
    while (cur !== '' && guard < 8) {
      const arr = listOf(theme, cur);
      if (arr.length > 0) {
        return arr[hash(`${cur}#${launchSeed()}`) % arr.length];
      }
      cur = fallbackOf(cur);
      guard++;
    }
    return undefined;
  }
}

/**
 * 统一出口。所有页面都只用它，不直接用 Image 贴图 ——
 * 以后要调尺寸规则、加柔光、做深色适配，只改这一个组件。
 *
 * 默认主题（decorated=false）或该主题没有贴纸池时整块不渲染，
 * Stack 无子节点 → 0 尺寸，不会给界面留下空位。
 */
@Component
export struct Mascot {
  @Prop slot: string = 'passive';
  @Prop side: number = 120;
  @StorageProp('dsh_theme') theme: string = 'default';

  build() {
    Stack() {
      if (themeDef(this.theme).decorated && MascotPool.pick(this.theme, this.slot) !== undefined) {
        Image(MascotPool.pick(this.theme, this.slot))
          .width(this.side)
          .height(this.side)
          // 原图是白底喷绘，抠出来边缘偏硬，透明底上直接放会显得"像贴上去的"。
          // 96% 不是随手取的：全不透明会太抢，再低又会透出后面的内容显脏。
          .opacity(0.96)
          .objectFit(ImageFit.Contain)
          // 只是装饰，绝不能吃掉父容器的点击（登录按钮、列表项都可能是它的邻居）
          .hitTestBehavior(HitTestMode.None)
          .draggable(false)
      }
    }
  }
}

/**
 * 插画 + 一句话。空状态/错误页用这个，省得每处都拼一遍间距和字号。
 */
@Component
export struct MascotNote {
  @Prop slot: string = 'empty';
  @Prop side: number = 140;
  @Prop caption: string = '';
  @StorageProp('dsh_theme') theme: string = 'default';

  build() {
    Column({ space: 10 }) {
      Mascot({ slot: this.slot, side: this.side })
      if (themeDef(this.theme).decorated && this.caption !== '') {
        Text(this.caption)
          .fontSize(13)
          .fontColor('#8A8178')
          .textAlign(TextAlign.Center)
      }
    }
    .justifyContent(FlexAlign.Center)
  }
}
