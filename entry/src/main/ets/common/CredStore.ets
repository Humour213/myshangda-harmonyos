/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'CredStore';
/** 一条凭据整体存成一条资产（账号 + 密码 JSON），键名固定 */
const ALIAS = 'myshangda_cred_v1';

/** 账号密码对 */
export class CredPair {
  user: string = '';
  pass: string = '';
}

function u8(s: string): Uint8Array {
  return new util.TextEncoder().encodeInto(s);
}

function fromU8(v: Uint8Array | undefined): string {
  if (v === undefined || v.length === 0) {
    return '';
  }
  return new util.TextDecoder('utf-8').decodeToString(v);
}

/**
 * 账号密码的系统级存储（Asset Store Kit）。
 *
 * 为什么不继续用 HUKS 自己拼 AES-GCM：那条路在这台实测设备上**从来没成功过** ——
 * 加密能返回密文，但解一次就回不来，往返校验永远不过。0.2.21 之前之所以「记得住」，
 * 是因为校验失败时会退回 preferences 明文存一份；0.2.22 把明文兜底掐掉之后，
 * 记住密码就彻底失效了（登录提示「本机加密不可用，密码未保存」）。
 *
 * Asset Store 是系统专门给密钥、令牌、密码这类小秘密准备的接口：密钥由系统托管，
 * 应用只看到别名，拿不到也不需要拿到密钥材料；设备解锁后即可读取（不同步、不上云）。
 * 这比自己拼 HUKS 参数稳，也比明文安全。
 *
 * 注意：`SECRET` 是二进制，这里存的是 `{"user":"...","pass":"..."}` 的 UTF-8 字节。
 */
export class CredStore {
  /** 存一份账号密码（整条覆盖）。真存下才返回 true */
  static async save(user: string, pass: string): Promise<boolean> {
    const pair = new CredPair();
    pair.user = user;
    pair.pass = pass;
    const payload: string = JSON.stringify(pair);
    // add 遇到同别名会报「已存在」，先删干净再写，等价于覆盖
    await CredStore.clear();
    const attr: asset.AssetMap = new Map();
    attr.set(asset.Tag.ALIAS, u8(ALIAS));
    attr.set(asset.Tag.SECRET, u8(payload));
    // 设备首次解锁后可读：不需要每次都在指纹/密码上再点一次，与「记住密码」的体验一致；
    // 又不至于像 ALWAYS 那样锁屏状态下也能被读。
    attr.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    try {
      await asset.add(attr);
      return true;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'asset add failed: %{public}s', CredStore.errText(err));
      return false;
    }
  }

  /** 读回账号密码；没有、读不出、内容不成形，都返回空对象 */
  static async load(): Promise<CredPair> {
    const out = new CredPair();
    const q: asset.AssetMap = new Map();
    q.set(asset.Tag.ALIAS, u8(ALIAS));
    // 不加这个只回属性、不回 SECRET，读出来永远是空的
    q.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const res: asset.AssetMap[] = await asset.query(q);
      if (res === undefined || res.length === 0) {
        return out;
      }
      const raw: string = fromU8(res[0].get(asset.Tag.SECRET) as Uint8Array);
      if (raw === '') {
        return out;
      }
      const o = JSON.parse(raw) as Record<string, string>;
      out.user = o['user'] ?? '';
      out.pass = o['pass'] ?? '';
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'asset query failed: %{public}s', CredStore.errText(err));
    }
    return out;
  }

  static async clear(): Promise<void> {
    const q: asset.AssetMap = new Map();
    q.set(asset.Tag.ALIAS, u8(ALIAS));
    try {
      await asset.remove(q);
    } catch (err) {
      // 本来就没这条记录时也会抛，属正常
      hilog.info(DOMAIN, TAG, 'asset remove: %{public}s', CredStore.errText(err));
    }
  }

  /** 把 BusinessError 压成一句「码 + 原因」，别让日志只剩 [object Object] */
  private static errText(err: Object): string {
    const e = err as Record<string, Object>;
    if (e === null || e === undefined) {
      return 'unknown';
    }
    const code: Object | undefined = e['code'];
    const msg: Object | undefined = e['message'];
    return `${code === undefined ? '?' : String(code)} ${msg === undefined ? '' : String(msg)}`;
  }
}
