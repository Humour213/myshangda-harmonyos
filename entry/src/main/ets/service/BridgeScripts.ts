// 注入到每个页面的 document-start 脚本：滚动/路由桥接。
// 优先使用 registerJavaScriptProxy 注入的 window.__dshNative；注册晚于脚本执行时先排队。
export const PAGE_BRIDGE_JS = `(function(){
  // 页面 JS 异常转 console，方便 hilog 侧定位 H5 点击无反应的根因
  try {
    window.addEventListener('error', function(e){
      try { console.log('[dsh-err] ' + (e && e.message) + ' @' + (e && e.filename) + ':' + (e && e.lineno)); } catch (x) {}
    });
    window.addEventListener('unhandledrejection', function(e){
      try { console.log('[dsh-rej] ' + (e && e.reason)); } catch (x) {}
    });
  } catch (e) {}
  // zfsoft H5 的 isAppType 分支会调原生桥（flutter_inappwebview/WebViewJavascriptBridge），
  // 有 window.android 时转给它执行，没有则记到原生日志，避免点击被吞
  function forward(name, arg, cb){
    try {
      var a = window.android;
      if (a && typeof a[name] === 'function') {
        if (arg && arg.length !== undefined) { a[name].apply(a, arg); } else if (arg !== undefined) { a[name](arg); } else { a[name](); }
      } else if (window.__dshNative && typeof window.__dshNative.onJsBridge === 'function') {
        window.__dshNative.onJsBridge(name + ' ' + JSON.stringify(arg === undefined ? null : arg));
      }
    } catch (e) {}
    if (typeof cb === 'function') { cb(undefined); }
  }
  try {
    if (!window.flutter_inappwebview) {
      window.flutter_inappwebview = { callHandler: function(name, arg){ forward(name, arg); return Promise.resolve(undefined); } };
    }
    if (!window.WebViewJavascriptBridge) {
      window.WebViewJavascriptBridge = { callHandler: function(n, d, cb){ forward(n, d, cb); }, registerHandler: function(){}, init: function(){}, send: function(){}, ready: function(){ if (typeof arguments[0] === 'function') { arguments[0](); } } };
    }
  } catch (e) {}
  function nativeReady(){ return typeof window.__dshNative !== 'undefined' && window.__dshNative; }
  var queue = [];
  function send(method, arg){
    if (nativeReady()) {
      try { window.__dshNative[method](arg); } catch (e) {}
    } else {
      queue.push([method, arg]);
    }
  }
  window.__dshNav = {
    onScroll: function(y){ send('onScroll', y); },
    onRoute: function(u){ send('onRoute', u); }
  };
  window.addEventListener('scroll', function(){
    try { window.__dshNav.onScroll(window.scrollY || document.documentElement.scrollTop || 0); } catch (e) {}
  }, { passive: true });
  function route(){ try { window.__dshNav.onRoute(location.href); } catch (e) {} }
  try {
    var hs = window.history;
    if (hs && hs.pushState) {
      var op = hs.pushState.bind(hs);
      hs.pushState = function(){ var r = op.apply(null, arguments); setTimeout(route, 80); return r; };
      var orp = hs.replaceState.bind(hs);
      hs.replaceState = function(){ var r = orp.apply(null, arguments); setTimeout(route, 80); return r; };
    }
  } catch (e) {}
  window.addEventListener('popstate', function(){ setTimeout(route, 80); });
  window.addEventListener('load', function(){ setTimeout(route, 150); });
  var timer = setInterval(function(){
    if (nativeReady()) {
      for (var i = 0; i < queue.length; i++) {
        try { window.__dshNative[queue[i][0]](queue[i][1]); } catch (e) {}
      }
      queue = [];
      clearInterval(timer);
    }
  }, 300);
  setTimeout(function(){ clearInterval(timer); }, 8000);
})();`;

// 离线数据缓存：在线时记录 GET 的 fetch/XHR 响应，离线时直接回放。
// 门户/校园码这类“壳能缓存、数据请求失败”的页面，靠它保住最后一次可用的内容。
export const NET_CACHE_JS = `(function(){
  if (window.__dshNetCache) { return; }
  window.__dshNetCache = true;
  var PREFIX = '__dsh_http_cache_v1__';
  var MAX_ENTRIES = 40;
  var MAX_BODY = 400 * 1024;
  function absUrl(u){
    try { return new URL(u, location.href).href; } catch (e) { return u; }
  }
  function offline(){
    try { return navigator.onLine === false || window.__dshOffline === true; } catch (e) { return false; }
  }
  function cacheGet(u){
    try { var s = localStorage.getItem(PREFIX + u); return s ? JSON.parse(s) : null; } catch (e) { return null; }
  }
  function prune(){
    try {
      var arr = [];
      for (var i = 0; i < localStorage.length; i++) {
        var k = localStorage.key(i);
        if (k && k.indexOf(PREFIX) === 0) {
          var v = cacheGet(k.substring(PREFIX.length));
          arr.push([k, v ? v.t : 0]);
        }
      }
      if (arr.length <= MAX_ENTRIES) { return; }
      arr.sort(function(a, b){ return a[1] - b[1]; });
      var del = arr.length - MAX_ENTRIES;
      for (var j = 0; j < del; j++) { localStorage.removeItem(arr[j][0]); }
    } catch (e) {}
  }
  function cachePut(u, body, status, type){
    try {
      if (!u || !body || body.length > MAX_BODY) { return; }
      localStorage.setItem(PREFIX + u, JSON.stringify({ t: Date.now(), s: status || 200, c: type || '', b: body }));
      if (Math.random() < 0.2) { prune(); }
    } catch (e) {}
  }
  var of = window.fetch;
  if (of) {
    window.fetch = function(input, init){
      var url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
      var method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase();
      if (method !== 'GET' || !url) { return of.apply(this, arguments); }
      url = absUrl(url);
      var hit = cacheGet(url);
      if (hit && offline()) {
        return Promise.resolve(new Response(hit.b, {
          status: hit.s, headers: { 'Content-Type': hit.c || 'application/json' }
        }));
      }
      return of.apply(this, arguments).then(function(r){
        try {
          if (r && r.ok) {
            r.clone().text().then(function(t){ cachePut(url, t, r.status, r.headers.get('content-type')); }).catch(function(){});
          }
        } catch (e) {}
        return r;
      }).catch(function(err){
        var c = cacheGet(url);
        if (c) {
          return new Response(c.b, { status: c.s, headers: { 'Content-Type': c.c || 'application/json' } });
        }
        throw err;
      });
    };
  }
  var X = window.XMLHttpRequest;
  if (X && X.prototype) {
    var origOpen = X.prototype.open;
    var origSend = X.prototype.send;
    X.prototype.open = function(method, url){
      try { this.__dshUrl = absUrl(url); this.__dshMethod = (method || 'GET').toUpperCase(); } catch (e) {}
      return origOpen.apply(this, arguments);
    };
    X.prototype.send = function(body){
      var xhr = this;
      var url = this.__dshUrl;
      var method = this.__dshMethod;
      var hit = (method === 'GET' && url) ? cacheGet(url) : null;
      if (hit && offline()) {
        setTimeout(function(){
          try {
            var parsed = (xhr.responseType === 'json') ? JSON.parse(hit.b) : hit.b;
            Object.defineProperty(xhr, 'readyState', { configurable: true, get: function(){ return 4; } });
            Object.defineProperty(xhr, 'status', { configurable: true, get: function(){ return hit.s; } });
            Object.defineProperty(xhr, 'statusText', { configurable: true, get: function(){ return 'OK'; } });
            Object.defineProperty(xhr, 'responseText', { configurable: true, get: function(){ return hit.b; } });
            Object.defineProperty(xhr, 'response', { configurable: true, get: function(){ return parsed; } });
            Object.defineProperty(xhr, 'responseURL', { configurable: true, get: function(){ return url; } });
            xhr.getAllResponseHeaders = function(){ return 'content-type: ' + (hit.c || 'application/json') + '\\r\\n'; };
            xhr.getResponseHeader = function(n){ return (n && n.toLowerCase() === 'content-type') ? (hit.c || 'application/json') : null; };
            xhr.dispatchEvent(new Event('readystatechange'));
            xhr.dispatchEvent(new ProgressEvent('load'));
            xhr.dispatchEvent(new ProgressEvent('loadend'));
          } catch (e) {}
        }, 0);
        return;
      }
      if (method === 'GET' && url) {
        xhr.addEventListener('load', function(){
          try {
            if (xhr.status >= 200 && xhr.status < 300) {
              var body = (xhr.responseType === 'json') ? JSON.stringify(xhr.response) : xhr.responseText;
              cachePut(url, body, xhr.status, xhr.getResponseHeader('content-type'));
            }
          } catch (e) {}
        });
      }
      return origSend.apply(xhr, arguments);
    };
  }
})();`;

// 页面加载完成后再装 android 兼容桥：document-start 装会让 zfsoft H5 进入半初始化的原生分支导致白屏。
// H5 点击时才会读取 window.android，因此 onPageEnd 注入既不影响首屏渲染，又能恢复点击。
export const ANDROID_BRIDGE_JS = `(function(){
  if (window.__dshAndroidInstalled) { return 'ok'; }
  window.__dshAndroidInstalled = true;
  var pending = [];
  var timer = 0;
  function flush(){
    timer = 0;
    if (!window.__dshNative) {
      if (pending.length > 0) { timer = setTimeout(flush, 200); }
      return;
    }
    for (var i = 0; i < pending.length; i++) {
      try { window.__dshNative[pending[i][0]](pending[i][1]); } catch (e) {}
    }
    pending = [];
  }
  function call(method, arg){
    try {
      if (window.__dshNative && typeof window.__dshNative[method] === 'function') {
        window.__dshNative[method](arg);
        return;
      }
    } catch (e) {}
    pending.push([method, arg]);
    if (!timer) { timer = setTimeout(flush, 200); }
  }
  function openWeb(title, url){
    if (typeof url !== 'string' || !url) { return; }
    try { url = new URL(url, location.href).href; } catch (e) {}
    call('openWith', url);
  }
  var bridge = {
    openWeb: function(title, url){ openWeb(title, url); },
    openWebWithRefresh: function(title, url){ openWeb(title, url); },
    openWebWithFlag: function(title, url){ openWeb(title, url); },
    GoBack: function(){ try { window.history.back(); } catch (e) {} },
    closeOrigin: function(){ call('closePage', ''); },
    closeOriginWithMsg: function(){ call('closePage', ''); },
    openSetting: function(){},
    openAppOrSmallProgram: function(){},
    addDesktop: function(){},
    APPShare: function(){ call('onShareApp', ''); },
    checkVersion: function(){ call('onCheckVersion', ''); },
    createCalendar: function(){},
    exitLogin: function(){},
    gotoLogin: function(){},
    setBadge: function(){},
    updateBadgeNew: function(){}
  };
  try { window.android = bridge; } catch (e) {}
  return 'ok';
})();`;

// 课表页面周表容器高度修复（ArkWeb 渲染与原壳不一致导致格子重叠/裁切）
export const SCHEDULE_FIX_JS = `(function(){
  try {
    var dds = document.querySelectorAll('dl.week dd');
    if (!dds || dds.length === 0) { return; }
    var maxB = 0;
    for (var i = 0; i < dds.length; i++) {
      var r = dds[i].getBoundingClientRect();
      var b = r.top + (window.scrollY || 0) + r.height;
      if (b > maxB) { maxB = b; }
    }
    if (maxB <= 0) { return; }
    var host = document.querySelector('.schedule-stu-area') || document.body;
    var top = host.getBoundingClientRect().top + (window.scrollY || 0);
    var need = maxB + 12 - top;
    var cur = parseFloat(getComputedStyle(host).height) || 0;
    if (need > cur) { host.style.height = need + 'px'; }
  } catch (e) {}
})();`;

// CAS 登录页自动填充并提交（占位符由 ArkTS 侧替换）
export const AUTO_LOGIN_JS = `(function(){
  try {
    if (window.__dshAutoDone) { return 'ok'; }
    var u = document.getElementById('username');
    var p = document.getElementById('ppassword') || document.getElementById('password');
    if (!u || !p) { return 'no-form'; }
    window.__dshAutoDone = true;
    var setV = function(el, v){
      var d = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
      d.set.call(el, v);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    };
    setV(u, '__DSH_USER__');
    setV(p, '__DSH_PASS__');
    // 等页面自己的 RSA 公钥（v2/getPubKey）就绪后再提交；过早点击会被 checkForm 的校验挡下且无任何报错
    var tries = 0;
    var submit = function(){
      try {
        var rsaReady = (typeof Modulus !== 'undefined' && Modulus) &&
          (typeof public_exponent !== 'undefined' && public_exponent);
        var cap = document.getElementById('kaptcha');
        var capVisible = false;
        if (cap) {
          var cs = window.getComputedStyle(cap);
          capVisible = cs.display !== 'none' && cs.visibility !== 'hidden';
        }
        if (rsaReady && !capVisible) {
          var b = document.getElementById('dl');
          if (b) {
            b.click();
            console.log('[dsh] auto-login submitted');
          }
          return;
        }
        if (tries++ < 30) {
          setTimeout(submit, 200);
        } else {
          console.log('[dsh] auto-login blocked rsa=' + !!rsaReady + ' captcha=' + capVisible);
        }
      } catch (e) {
        console.log('[dsh] auto-login error ' + e);
      }
    };
    setTimeout(submit, 150);
    return 'ok';
  } catch (e) { return 'err'; }
})();`;
