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

// 兼容命名导入：目前只有 fetchTodoCount 在用（Index 拿待办数推通知、亮角标）。
// 原生日首页/我的页已删除，轮播/服务九宫格/用户资料那几个接口封装也一并清掉。
export class NativeApi {
  static fetchTodoCount = fetchTodoCount;
}
