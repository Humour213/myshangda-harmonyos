import { common, Want } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { fileIo } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { filePreview } from '@kit.PreviewKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MOBILE_UA } from '../common/Constants';
import { Router } from '../common/Nav';

const DOMAIN = 0x0000;
const TAG = 'Opener';

/** 走「下载后系统预览」的文档类型 */
const DOC_EXT: string[] = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'wps', 'et', 'dps',
  'txt', 'csv', 'zip', 'rar', '7z'
];

/**
 * 统一的「打开外部资源」入口。
 *
 * 为什么要单独一层：门户里「学生手册」「校车时刻表」这类条目传给 H5 壳的不是网页，
 * 而是附件地址（pdf/doc/zip）。原版 Android 客户端拿到后是下载 + 系统预览，
 * 套壳里若直接把附件地址丢给 WebView，只会加载失败并提示「无效的文件参数」。
 */
export class Opener {
  /** 把 Android 壳里的本地路径映射成鸿蒙可用的资源路径 */
  static resolveLocal(url: string): string {
    if (url.startsWith('file:///android_asset/')) {
      return `resource://rawfile/${url.substring('file:///android_asset/'.length)}`;
    }
    return url;
  }

  static isHttp(url: string): boolean {
    const u = url.toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  /** 是否是「应该下载后预览」的附件地址 */
  static isAttachment(url: string): boolean {
    if (!Opener.isHttp(url)) {
      return false;
    }
    let path: string = url;
    const q: number = path.indexOf('?');
    if (q >= 0) {
      path = path.substring(0, q);
    }
    const h: number = path.indexOf('#');
    if (h >= 0) {
      path = path.substring(0, h);
    }
    const dot: number = path.lastIndexOf('.');
    if (dot < 0) {
      return false;
    }
    const ext: string = path.substring(dot + 1).toLowerCase();
    return DOC_EXT.indexOf(ext) >= 0;
  }

  /** 去掉文件名里不能落盘的字符（否则 openSync 直接失败） */
  private static sanitize(name: string): string {
    let out: string = '';
    for (let i = 0; i < name.length; i++) {
      const c: string = name.charAt(i);
      if ('\\/:*?"<>|\n\r\t'.indexOf(c) >= 0) {
        out += '_';
      } else {
        out += c;
      }
    }
    const t: string = out.trim();
    return t.length === 0 ? `download_${Date.now()}` : t;
  }

  /** 从地址里猜一个像样的文件名 */
  static guessName(url: string): string {
    let path: string = url;
    const q: number = path.indexOf('?');
    if (q >= 0) {
      path = path.substring(0, q);
    }
    const slash: number = path.lastIndexOf('/');
    let name: string = slash >= 0 ? path.substring(slash + 1) : path;
    try {
      name = decodeURIComponent(name);
    } catch (e) {
      // 保持原样
    }
    return Opener.sanitize(name);
  }

  /** Content-Type → 扩展名。地址里没有后缀时（下载接口常见）靠它补 */
  private static extOfType(type: string): string {
    const t: string = type.toLowerCase();
    if (t.indexOf('pdf') >= 0) {
      return 'pdf';
    }
    if (t.indexOf('wordprocessingml') >= 0) {
      return 'docx';
    }
    if (t.indexOf('msword') >= 0) {
      return 'doc';
    }
    if (t.indexOf('spreadsheetml') >= 0) {
      return 'xlsx';
    }
    if (t.indexOf('ms-excel') >= 0) {
      return 'xls';
    }
    if (t.indexOf('presentationml') >= 0) {
      return 'pptx';
    }
    if (t.indexOf('ms-powerpoint') >= 0) {
      return 'ppt';
    }
    if (t.indexOf('zip') >= 0) {
      return 'zip';
    }
    if (t.indexOf('text/plain') >= 0) {
      return 'txt';
    }
    return '';
  }

  private static hasExt(name: string): boolean {
    const dot: number = name.lastIndexOf('.');
    return dot > 0 && name.length - dot <= 6;
  }

  /**
   * 有些入口不直接给附件地址，而是给一个「预览器」页面，真正的文件在 file 参数里：
   *   /xxx/view?file=https%3A%2F%2F...%2Fnotice.pdf&name=学生手册
   * 这种地址塞进 WebView 一样白屏，先把里面的真实地址抠出来。
   */
  static extractDocUrl(url: string): string {
    const lower: string = url.toLowerCase();
    const idx: number = lower.indexOf('file=');
    if (idx < 0) {
      return '';
    }
    let v: string = url.substring(idx + 5);
    const amp: number = v.indexOf('&');
    if (amp >= 0) {
      v = v.substring(0, amp);
    }
    try {
      v = decodeURIComponent(v);
    } catch (e) {
      return '';
    }
    return Opener.isAttachment(v) ? v : '';
  }

  private static downloadPath(ctx: common.UIAbilityContext, name: string): string {
    return `${Opener.downloadDir(ctx)}/${name}`;
  }

  private static downloadDir(ctx: common.UIAbilityContext): string {
    const dir: string = `${ctx.filesDir}/Download`;
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (e) {
      // 已存在
    }
    return dir;
  }

  /** 交给系统处理（拨号、邮件、浏览器等） */
  static openExternal(action: string, uri: string): void {
    const ctx = getContext() as common.UIAbilityContext;
    try {
      const want: Want = { action: action, uri: uri };
      ctx.startAbility(want).catch(() => {
        promptAction.showToast({ message: '未找到可处理的应用', duration: 1500 });
      });
    } catch (e) {
      promptAction.showToast({ message: '未找到可处理的应用', duration: 1500 });
    }
  }

  /**
   * 下载附件并用系统预览打开。
   *
   * 关键点：必须带上 WebView 里的 Cookie，否则学校附件接口一律 401/302 到登录页，
   * 这也是「明明在内网也加载不出来」的常见原因。
   */
  static async openAttachment(ctx: common.UIAbilityContext, url: string, name: string): Promise<void> {
    let fileName: string = Opener.sanitize(name.length > 0 ? name : Opener.guessName(url));
    let cookie: string = '';
    try {
      cookie = webview.WebCookieManager.fetchCookieSync(url) ?? '';
    } catch (e) {
      cookie = '';
    }
    const req = http.createHttp();
    try {
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: { 'Cookie': cookie, 'User-Agent': MOBILE_UA },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        throw new Error(`http ${resp.responseCode}`);
      }
      // 下载接口常常是 /download?id=123 这种没有后缀的地址，配上服务器给的
      // Content-Type 才能让系统预览知道用什么打开，否则会报“没有能打开该文件的应用”
      if (!Opener.hasExt(fileName)) {
        let ctype: string = '';
        try {
          const h: Record<string, string> = resp.header as Record<string, string>;
          ctype = h['Content-Type'] ?? h['content-type'] ?? '';
        } catch (e) {
          ctype = '';
        }
        const ext: string = Opener.extOfType(ctype);
        if (ext !== '') {
          fileName = `${fileName}.${ext}`;
        }
      }
      const path: string = Opener.downloadPath(ctx, fileName);
      const file = fileIo.openSync(path,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, resp.result as ArrayBuffer);
      fileIo.closeSync(file);
      hilog.info(DOMAIN, TAG, 'attachment saved %{public}s', path);
      await Opener.preview(ctx, path, fileName);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'attachment failed %{public}s %{public}s', url, JSON.stringify(e));
      promptAction.showToast({ message: '附件下载失败，请检查网络或登录状态', duration: 2200 });
    } finally {
      req.destroy();
    }
  }

  /** 系统预览（文件已经在沙箱里） */
  static async preview(ctx: common.UIAbilityContext, path: string, name: string): Promise<void> {
    try {
      const info: filePreview.PreviewInfo = {
        uri: fileUri.getUriFromPath(path),
        title: name,
        mimeType: ''
      };
      await filePreview.openPreview(ctx, info);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'preview failed %{public}s', JSON.stringify(e));
      promptAction.showToast({ message: '没有能打开该文件的应用', duration: 1800 });
    }
  }

  /**
   * 统一分发：H5 给的地址可能是网页、可能是附件、也可能是 android_asset 里的本地页。
   * 所有「点一下就打不开」的入口最终都走这里。
   */
  static openSmart(ctx: common.UIAbilityContext, rawUrl: string, name: string): void {
    let url: string = Opener.resolveLocal(rawUrl);
    if (url.length === 0) {
      return;
    }
    // 预览器页面 → 直接取里面的真实文件地址
    const inner: string = Opener.extractDocUrl(url);
    if (inner !== '') {
      hilog.info(DOMAIN, TAG, 'unwrap viewer page %{public}s', inner);
      url = inner;
    }
    if (url.startsWith('resource://rawfile/') || url.startsWith('$rawfile/')) {
      Router.openSub(url);
      return;
    }
    if (Opener.isAttachment(url)) {
      Opener.openAttachment(ctx, url, name);
      return;
    }
    if (Opener.isHttp(url)) {
      Router.openSub(url);
      return;
    }
    // tel: / mailto: / 其它自定义 scheme 交给系统
    Opener.openExternal('ohos.want.action.viewData', url);
  }
}
