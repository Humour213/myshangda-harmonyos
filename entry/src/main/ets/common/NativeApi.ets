/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo } from '@kit.CoreFileKit';
import { BASE_URL, MOBILE_UA } from './Constants';

const TAG = 'NativeApi';
const DOMAIN = 0x0002;

export class ServiceItem {
  name: string = '';
  icon: string = '';
  url: string = '';
}

export class CarouselItem {
  img: string = '';
  url: string = '';
}

export class BasicInfo {
  name: string = '';
  avatar: string = '';
}

async function getCookie(url: string): Promise<string> {
  try {
    const c = webview.WebCookieManager.fetchCookieSync(url);
    return c ?? '';
  } catch (e) {
    return '';
  }
}

export async function apiGet(path: string): Promise<string> {
  const full = path.startsWith('http') ? path : `${BASE_URL}${path}`;
  const cookie = await getCookie(full);
  const req = http.createHttp();
  try {
    const resp = await req.request(full, {
      method: http.RequestMethod.GET,
      header: { 'Cookie': cookie, 'Accept': 'application/json', 'User-Agent': MOBILE_UA },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 15000
    });
    const body = resp.result as string;
    hilog.info(DOMAIN, TAG, 'apiGet %{public}s -> code %{public}d len %{public}d cookie:%{public}d', path, resp.responseCode, (body ?? '').length, cookie.length);
    return body ?? '';
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'get %{public}s failed %{public}s', path, JSON.stringify(e));
    return '';
  } finally {
    req.destroy();
  }
}

function pickStr(obj: Record<string, Object>, key: string): string {
  const v = obj[key];
  if (typeof v === 'string') {
    return v as string;
  }
  if (typeof v === 'number') {
    return `${v}`;
  }
  return '';
}

// 用户信息 /api/basic/info -> {data:{name|xm, avatar|tx, ...}}
export async function fetchBasicInfo(): Promise<BasicInfo> {
  const info = new BasicInfo();
  const body = await apiGet('/api/basic/info');
  try {
    fileIo.writeSync(fileIo.openSync(getContext().filesDir + '/basic.json',
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC).fd, body);
  } catch (e) {
  }
  if (body === '') {
    return info;
  }
  try {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'] as Record<string, Object>;
    if (data) {
      info.name = pickStr(data, 'nc') || pickStr(data, 'name') || pickStr(data, 'xm');
      info.avatar = pickStr(data, 'txdz') || pickStr(data, 'headPortrait') || pickStr(data, 'avatar');
      if (info.avatar !== '' && !info.avatar.startsWith('http')) {
        info.avatar = `${BASE_URL}${info.avatar}`;
      }
    }
  } catch (e) {
  }
  return info;
}

// 轮播 /api/personal/cytp?tplx=carousel
export async function fetchCarousel(): Promise<CarouselItem[]> {
  const list: CarouselItem[] = [];
  const body = await apiGet('/api/personal/cytp?tplx=carousel');
  if (body === '') {
    return list;
  }
  try {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'] as Array<Record<string, Object>>;
    if (data) {
      for (const item of data) {
        const c = new CarouselItem();
        c.img = pickStr(item, 'img') || pickStr(item, 'pic') || pickStr(item, 'tp');
        c.url = pickStr(item, 'url') || pickStr(item, 'lj');
        if (c.img !== '') {
          if (!c.img.startsWith('http')) {
            c.img = `${BASE_URL}${c.img}`;
          }
          list.push(c);
        }
      }
    }
  } catch (e) {
  }
  return list;
}

// 服务宫格 /api/service/linksByYhjs?ljlx=n&sfyd=1  ljlx: 2常用查询 3常用服务 4常用链接 1我的服务
export async function fetchServices(ljlx: number): Promise<ServiceItem[]> {
  const list: ServiceItem[] = [];
  hilog.info(DOMAIN, TAG, 'fetchServices %{public}d start', ljlx);
  const body = await apiGet(`/api/service/linksByYhjs?ljlx=${ljlx}&sfyd=1`);
  if (body === '') {
    hilog.error(DOMAIN, TAG, 'fetchServices body empty');
    return list;
  }
  try {
    hilog.info(DOMAIN, TAG, 'fetchServices body head %{public}s', body.substring(0, 200));
    const root = JSON.parse(body) as Record<string, Object>;
    let data = root['data'] as Array<Record<string, Object>>;
    if (!data) {
      hilog.error(DOMAIN, TAG, 'fetchServices data field missing, keys: %{public}s', Object.keys(root).join(','));
    }
    if (!data) {
      data = root['rows'] as Array<Record<string, Object>>;
    }
    if (data) {
      for (const item of data) {
        const sv = new ServiceItem();
        sv.name = pickStr(item, 'ljmc') || pickStr(item, 'name') || pickStr(item, 'mc') || pickStr(item, 'title');
        sv.icon = pickStr(item, 'imgSrc') || pickStr(item, 'icon') || pickStr(item, 'tb') || pickStr(item, 'img');
        sv.url = pickStr(item, 'ljdz') || pickStr(item, 'url') || pickStr(item, 'lj') || pickStr(item, 'link');
        if (sv.name !== '') {
          if (sv.icon !== '' && !sv.icon.startsWith('http')) {
            sv.icon = `${BASE_URL}${sv.icon}`;
          }
          if (sv.url !== '' && !sv.url.startsWith('http')) {
            sv.url = `${BASE_URL}${sv.url}`;
          }
          list.push(sv);
        }
      }
    }
  } catch (e) {
  }
  return list;
}

// 待办数量 /api/xxzx2.0/todo/queryList?currentPage=1&pageSize=1
export async function fetchTodoCount(): Promise<number> {
  const body = await apiGet('/api/xxzx2.0/todo/queryList?currentPage=1&pageSize=1&hasmobile=1');
  try {
    fileIo.writeSync(fileIo.openSync(getContext().filesDir + '/todo.json',
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC).fd, body);
  } catch (e) {
  }
  if (body === '') {
    return 0;
  }
  try {
    const root = JSON.parse(body) as Record<string, Object>;
    const data = root['data'] as Record<string, Object>;
    if (data) {
      const total = data['totalCount'] ?? data['total'] ?? data['count'];
      if (typeof total === 'number') {
        return total as number;
      }
      if (typeof total === 'string') {
        return Number(total) || 0;
      }
    }
  } catch (e) {
  }
  return 0;
}

// 兼容命名导入
export class NativeApi {
  static fetchBasicInfo: (path?: never) => Promise<BasicInfo> = fetchBasicInfo;
  static fetchCarousel = fetchCarousel;
  static fetchServices = fetchServices;
  static fetchTodoCount = fetchTodoCount;
}
