/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { huks } from '@kit.UniversalKeystoreKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'CredVault';

/**
 * 账号密码的本地加密存储。
 *
 * 用鸿蒙的 HUKS（通用密钥库）：
 *   - AES-256-GCM 密钥由系统在安全环境中生成，别名 "myshangda_cred_v1"
 *   - 密钥**不可导出**，即使应用自身也拿不到明文密钥
 *   - 加密时每次生成随机 nonce（12 字节），与密文一起保存
 *
 * 这样即使有人拿到应用沙箱里的 preferences 文件，也无法解出密码。
 */
export class CredVault {
  private static readonly ALIAS: string = 'myshangda_cred_v1';
  private static keyReady: boolean = false;

  /** 构造 AES-GCM 的参数 */
  private static props(purpose: number, nonce?: Uint8Array): huks.HuksParam[] {
    const list: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
    ];
    if (nonce !== undefined) {
      list.push({ tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce });
    }
    return list;
  }

  /** 首次使用时生成密钥（已存在则忽略错误） */
  private static async ensureKey(): Promise<void> {
    if (CredVault.keyReady) {
      return;
    }
    const opts: huks.HuksOptions = {
      properties: [
        { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
        { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
        {
          tag: huks.HuksTag.HUKS_TAG_PURPOSE,
          value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
        },
        { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
        { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
      ]
    };
    try {
      await huks.generateKeyItem(CredVault.ALIAS, opts);
    } catch (err) {
      // 密钥已存在时会抛错，属正常情况。但也可能是真的失败（权限、参数不被支持），
      // 那种情况后面 initSession 一定失败 —— 所以错误码要留下来，不然只能看到「密码没记住」。
      hilog.info(DOMAIN, TAG, 'generateKeyItem returned: %{public}s', CredVault.errText(err));
    }
    CredVault.keyReady = true;
  }

  /**
   * 12 字节随机 nonce。
   *
   * 必须用系统的密码学随机源。之前用的是 Math.random()，它是伪随机、
   * 同一次启动内的序列可预测；而 GCM 一旦 nonce 重复，两条密文的异或会泄露明文关系，
   * 严重的能直接恢复出明文 —— 等于白加密。
   */
  private static randomNonce(): Uint8Array {
    const blob: cryptoFramework.DataBlob = cryptoFramework.createRandom().generateRandomSync(12);
    return new Uint8Array(blob.data);
  }

  /** 把 BusinessError 压成一句「码 + 原因」，避免日志里只剩 [object Object] */
  private static errText(err: Object): string {
    const e = err as Record<string, Object>;
    if (e === null || e === undefined) {
      return 'unknown';
    }
    const code: Object | undefined = e['code'];
    const msg: Object | undefined = e['message'];
    return `${code === undefined ? '?' : String(code)} ${msg === undefined ? '' : String(msg)}`;
  }

  /** 把明文补齐到 16 字节的整数倍（HUKS 的 NONE 填充要求） */
  private static pad(src: Uint8Array): Uint8Array {
    const need: number = (16 - (src.length % 16)) % 16;
    const out = new Uint8Array(src.length + need);
    out.set(src, 0);
    return out;
  }

  /**
   * 删掉现有密钥并重新生成一把。
   *
   * 用在「加密完解不回来」的时候：同一套参数下，老密钥（可能是更早版本用别的参数生成的）
   * 和现在的 initSession 对不上，往返校验就永远过不去，用户于是一直存不下密码。
   * 丢掉一把解不开的密钥没有损失 —— 它对应的密文本来也解不回来。
   */
  static async resetKey(): Promise<void> {
    const opts: huks.HuksOptions = { properties: [] };
    try {
      await huks.deleteKeyItem(CredVault.ALIAS, opts);
      hilog.info(DOMAIN, TAG, 'key deleted, will regenerate');
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'deleteKeyItem: %{public}s', CredVault.errText(err));
    }
    CredVault.keyReady = false;
    await CredVault.ensureKey();
  }

  /** 加密：返回 base64(nonce + 密文) */
  static async encrypt(plain: string): Promise<string> {
    try {
      await CredVault.ensureKey();
      const b64 = new util.Base64Helper();
      const raw: Uint8Array = new util.TextEncoder().encodeInto(plain);
      const data: Uint8Array = CredVault.pad(raw);
      const nonce: Uint8Array = CredVault.randomNonce();
      const opts: huks.HuksOptions = {
        properties: CredVault.props(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT, nonce),
        inData: data
      };
      const handle: huks.HuksSessionHandle = await huks.initSession(CredVault.ALIAS, opts);
      const result: huks.HuksReturnResult = await huks.finishSession(handle.handle, opts);
      const cipher: Uint8Array = result.outData as Uint8Array;
      const merged = new Uint8Array(12 + cipher.length);
      merged.set(nonce, 0);
      merged.set(cipher, 12);
      return b64.encodeToStringSync(merged);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'encrypt failed: %{public}s', CredVault.errText(err));
      throw err as Error;
    }
  }

  /** 解密：入参为 base64(nonce + 密文)，失败返回空串 */
  static async decrypt(packed: string): Promise<string> {
    if (packed.length === 0) {
      return '';
    }
    const b64 = new util.Base64Helper();
    const merged: Uint8Array = b64.decodeSync(packed);
    if (merged.length <= 12) {
      return '';
    }
    const nonce: Uint8Array = merged.slice(0, 12);
    const cipher: Uint8Array = merged.slice(12);
    const opts: huks.HuksOptions = {
      properties: CredVault.props(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT, nonce),
      inData: cipher
    };
    try {
      const handle: huks.HuksSessionHandle = await huks.initSession(CredVault.ALIAS, opts);
      const result: huks.HuksReturnResult = await huks.finishSession(handle.handle, opts);
      const out: Uint8Array = result.outData as Uint8Array;
      // 去掉尾部补齐的 0
      let end: number = out.length;
      while (end > 0 && out[end - 1] === 0) {
        end--;
      }
      return new util.TextDecoder('utf-8').decodeToString(out.slice(0, end));
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'decrypt failed: %{public}s', CredVault.errText(err));
      return '';
    }
  }
}
