/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */

/**
 * 主题注册表 —— 全应用唯一的主题数据源。
 *
 * 加一个新主题只需要两步：
 *   1. 在下面 PALETTES / THEMES 里加一条记录（配色 token + 文案 + 开关 + 图标）；
 *   2. 把贴纸图片丢进 base/media，在 Mascot.ets 的池子里挂一行（有贴纸的主题才需要）。
 * 颜色、状态栏、标题栏、网页染色、桌面卡片色值都从这里读，不用再翻各个页面。
 *
 * 两张正交的表：
 *   - PALETTES：外壳配色的 7 个 token（页面底/标题栏/底栏/文字/强调/主按钮）。
 *   - THEMES：主题的展示信息 + 行为开关 + 卡片色板。
 *
 * 关于「吉蛙」：色值从最终 13 张贴纸采样后调和处理
 *（体色 #7BFB3C 太亮，大面积铺会刺眼，所以页面用它的淡彩，强调色取压暗版本；
 * 勾线墨 #21321E 直接做正文色，嘴部粉只留在卡片色块里点缀）。
 */

export const THEME_DEFAULT: string = 'default';
export const THEME_DOUNI: string = 'douni';
export const THEME_JIWA: string = 'jiwa';

/** 外壳配色的 7 个 token；顺序与 Palette 的 7 个方法一一对应 */
export interface PaletteTokens {
  page: string;
  bar: string;
  barSoft: string;
  ink: string;
  subInk: string;
  accent: string;
  primary: string;
  /** 网页边框中性色：按原边框深浅分三档映射，避免所有灰边被压成同一个强调色 */
  line: string;
  lineSoft: string;
  lineFaint: string;
}

/** 桌面卡片某个状态下的三色：整卡底 / 强调 / 正文 */
export interface CardStateTint {
  tint: string;
  accent: string;
  ink: string;
}

/** 桌面卡片配色板：按 state 给色 + 课程字色 + 贴纸/白卡等细节色 */
export interface CardPalette {
  now: CardStateTint;
  next: CardStateTint;
  tomorrow: CardStateTint;
  done: CardStateTint;
  none: CardStateTint;
  /** 课程列表字色（按课序轮换，8 色） */
  courseFg: string[];
  /** 明天预告字色 */
  tomorrowFg: string;
  /** 此刻卡的主视觉块底色（"白卡"，主题下换成暖白/绿白） */
  heroSurface: string;
  /** 列表卡的课程色块底色（8 色） */
  listBlock: string[];
  /** 列表卡明天预告色块底 */
  listTomorrow: string;
  /** 列表卡明天胶囊的字色 / 底色 */
  pillInk: string;
  pillBg: string;
  /** 列表卡次文字色 */
  subInk: string;
  /** 列表卡整卡底色（非明天状态） */
  surface: string;
  /** 列表卡明天状态的整卡底色 */
  tomorrowSurface: string;
}

/** 一个主题的完整定义 */
export interface ThemeDef {
  id: string;
  /** 设置页显示名 */
  label: string;
  /** 设置页副标题 */
  sub: string;
  /** 设置页左侧图标（默认主题用应用 logo，装饰主题用各自的贴纸） */
  thumbnail: Resource;
  /** 是否显示贴纸/装饰文案（默认主题=false，保持原版观感） */
  decorated: boolean;
  /** 网页是否需要染色（默认主题=false） */
  needsTint: boolean;
  /** 登录页等待文案（插画主题替换成角色相关的可爱说法） */
  loginHint: string;
  /** 冷启动加载文案 */
  loadingHint: string;
  /** 关于页贴纸脚注（装饰主题才有贴纸） */
  aboutCaption: string;
  /** 标题栏是否用 accent 当底色并反白文字（原生样式下） */
  titleOnAccent: boolean;
  /** 状态栏图标是否反白（深色状态栏配白图标） */
  statusBarLight: boolean;
  /** classic 底栏选中图标（按 tab 顺序：消息/审批/主页/通讯录/我的） */
  tabIcons: Resource[];
  /** 桌面卡片配色板 */
  card: CardPalette;
}

/* ============================ 外壳配色 ============================ */

const DEF: PaletteTokens = {
  page: '#F7F8FA',
  bar: '#F7F8FA',
  barSoft: '#F4F5F7',
  ink: '#1A1A1A',
  subInk: '#8A8F99',
  accent: '#2D8CFA',
  primary: '#3D6BE5',
  line: '#C9D2DF',
  lineSoft: '#DCE3ED',
  lineFaint: '#EAEFF6'
};

// 豆泥：从素材采样（体色奶油 #F0E4D8 / 毛发灰棕 #9C846C / 勾线墨 #2E2A26）
const DOUNI: PaletteTokens = {
  page: '#FAF4EC',
  bar: '#FDF8F2',
  barSoft: '#F2E9DC',
  ink: '#3A322B',
  subInk: '#8B7C6B',
  accent: '#9A7855',
  primary: '#94714C',
  line: '#C9B8A3',
  lineSoft: '#DED0BC',
  lineFaint: '#EFE5D6'
};

// 吉蛙：从贴纸采样（体色 #7BFB3C / 勾线墨 #21321E / 嘴粉 #F60258）。
// 体色原值太荧光，只留在贴纸上；页面取淡彩，强调色压暗到可读的叶绿。
const JIWA: PaletteTokens = {
  // 网页底色刻意比豆泥的奶油色更绿，避免两个装饰主题刷出来看着一样
  page: '#E8F6DC',
  bar: '#F2FAEA',
  barSoft: '#DCEFCB',
  ink: '#21321E',
  subInk: '#6B7D63',
  accent: '#5A9A38',
  primary: '#4A8130',
  line: '#B7CEAA',
  lineSoft: '#D2E3C5',
  lineFaint: '#E6F0DC'
};

/* ============================ 卡片配色 ============================ */

const DEF_CARD: CardPalette = {
  now: { tint: '#E9F5EE', accent: '#2E9E63', ink: '#16301F' },
  next: { tint: '#ECF0FC', accent: '#4A5CD0', ink: '#1A2138' },
  tomorrow: { tint: '#E8EEF9', accent: '#3A568C', ink: '#22304D' },
  done: { tint: '#EDF0F6', accent: '#6B7A99', ink: '#232A36' },
  none: { tint: '#F0F2F6', accent: '#8A94A6', ink: '#232A36' },
  courseFg: ['#1E63B4', '#12806A', '#2B57C6', '#B4531A', '#5A3EBA',
    '#3F7A22', '#B02A2A', '#8A5B00'],
  tomorrowFg: '#3A568C',
  heroSurface: '#FFFFFF',
  listBlock: ['#D6E9FF', '#D6F5EA', '#D6E4FF', '#FFE7D1',
    '#E3DDFF', '#D9F7D0', '#FFD9D9', '#FFE9B8'],
  listTomorrow: '#E5EBFA',
  pillInk: '#3A568C',
  pillBg: '#DCE5F8',
  subInk: '#8A8F98',
  surface: '#FFFFFF',
  tomorrowSurface: '#F4F7FE'
};

const DOUNI_CARD: CardPalette = {
  now: { tint: '#F5EBE2', accent: '#9A7855', ink: '#3A322B' },
  next: { tint: '#FAF4EC', accent: '#9A7855', ink: '#3A322B' },
  tomorrow: { tint: '#F2E9DC', accent: '#8A8178', ink: '#3A322B' },
  done: { tint: '#EDE4DA', accent: '#8A8178', ink: '#3A322B' },
  none: { tint: '#FAF4EC', accent: '#9A7855', ink: '#3A322B' },
  courseFg: ['#8C6E55', '#7A6A50', '#8F6A45', '#A06A45', '#7A6248',
    '#6E6448', '#956A55', '#8A6A48'],
  tomorrowFg: '#8A8178',
  heroSurface: '#FDF8F2',
  listBlock: ['#F5EBE2', '#F0E9DC', '#F7EDE0', '#F2E6D8',
    '#EFE7DA', '#F5EAD8', '#F1E4D6', '#F7EEE2'],
  listTomorrow: '#EDE4DA',
  pillInk: '#9A7855',
  pillBg: '#EDE4DA',
  subInk: '#8B7C6B',
  surface: '#FAF4EC',
  tomorrowSurface: '#FAF4EC'
};

// 吉蛙卡片：叶绿为主，勾线墨做正文；两处淡粉回应嘴部颜色
const JIWA_CARD: CardPalette = {
  now: { tint: '#E4F2D8', accent: '#5A9A38', ink: '#21321E' },
  next: { tint: '#F3FAEE', accent: '#5A9A38', ink: '#21321E' },
  tomorrow: { tint: '#EAF2E2', accent: '#6B7D63', ink: '#21321E' },
  done: { tint: '#EDF2E8', accent: '#7A8A72', ink: '#21321E' },
  none: { tint: '#F3FAEE', accent: '#6B7D63', ink: '#21321E' },
  courseFg: ['#3E7A2A', '#4A7A45', '#5A7A22', '#9A3A5E', '#5A6A2A',
    '#3A6A42', '#6A6A1E', '#2F6A3E'],
  tomorrowFg: '#4A6B52',
  heroSurface: '#F2FAEA',
  listBlock: ['#DCEFD2', '#D6EAD8', '#E0EED0', '#F7D9E4',
    '#D2E8CC', '#E4F0D0', '#F9E1EA', '#EAF2D6'],
  listTomorrow: '#E3EFD9',
  pillInk: '#5A9A38',
  pillBg: '#E3EFD9',
  subInk: '#6B7D63',
  surface: '#E8F6DC',
  tomorrowSurface: '#E8F6DC'
};

/* ============================ 主题注册表 ============================ */

const PALETTES: Map<string, PaletteTokens> = new Map<string, PaletteTokens>([
  [THEME_DEFAULT, DEF],
  [THEME_DOUNI, DOUNI],
  [THEME_JIWA, JIWA]
]);

const THEME_LIST: ThemeDef[] = [
  {
    id: THEME_DEFAULT,
    label: '默认',
    sub: '清爽原版风格，不加装饰',
    thumbnail: $r('app.media.app_logo'),
    decorated: false,
    needsTint: false,
    loginHint: '正在验证账号密码，请稍候…',
    loadingHint: '正在翻课表…',
    aboutCaption: '',
    titleOnAccent: false,
    statusBarLight: false,
    tabIcons: [
      $r('app.media.tab_msg_on'), $r('app.media.tab_approve_on'),
      $r('app.media.tab_home_on'), $r('app.media.tab_contact_on'),
      $r('app.media.tab_me_on')
    ],
    card: DEF_CARD
  },
  {
    id: THEME_DOUNI,
    label: '豆泥的一天',
    sub: '换成暖色，多一只小豆泥陪着你',
    thumbnail: $r('app.media.douni_passive_01'),
    decorated: true,
    needsTint: true,
    loginHint: '豆泥在帮你敲门…',
    loadingHint: '豆泥正在翻课表…',
    aboutCaption: '豆泥陪你上课',
    titleOnAccent: true,
    statusBarLight: true,
    tabIcons: [
      $r('app.media.tab_msg_on_douni'), $r('app.media.tab_approve_on_douni'),
      $r('app.media.tab_home_on_douni'), $r('app.media.tab_contact_on_douni'),
      $r('app.media.tab_me_on_douni')
    ],
    card: DOUNI_CARD
  },
  {
    id: THEME_JIWA,
    label: '审美吉蛙',
    sub: '换成清爽的绿色，多一只吉蛙陪着你',
    thumbnail: $r('app.media.jiwa_01'),
    decorated: true,
    needsTint: true,
    loginHint: '吉蛙在帮你敲门…',
    loadingHint: '吉蛙正在翻课表…',
    aboutCaption: '吉蛙陪你上课',
    titleOnAccent: true,
    statusBarLight: true,
    tabIcons: [
      $r('app.media.tab_msg_on_jiwa'), $r('app.media.tab_approve_on_jiwa'),
      $r('app.media.tab_home_on_jiwa'), $r('app.media.tab_contact_on_jiwa'),
      $r('app.media.tab_me_on_jiwa')
    ],
    card: JIWA_CARD
  }
];

/** 全部主题（设置页按这个顺序渲染选项） */
export function allThemes(): ThemeDef[] {
  return THEME_LIST;
}

/** 合法主题 id 集合（PrefsStore 值域校验用） */
export function isKnownTheme(id: string): boolean {
  return PALETTES.has(id);
}

/** 取主题定义；未知 id 一律退到默认主题，保证不崩 */
export function themeDef(id: string): ThemeDef {
  for (let i = 0; i < THEME_LIST.length; i++) {
    if (THEME_LIST[i].id === id) {
      return THEME_LIST[i];
    }
  }
  return THEME_LIST[0];
}

/** 是否装饰主题（有贴纸、需要染色）；未知 id 退默认=false */
export function isDecoratedTheme(id: string): boolean {
  return themeDef(id).decorated;
}

/** 取外壳配色 token；未知 id 退到默认 */
export function themePalette(id: string): PaletteTokens {
  const p: PaletteTokens | undefined = PALETTES.get(id);
  return p === undefined ? DEF : p;
}
