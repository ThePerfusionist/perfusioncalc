// PerfusionCalc Service Worker
// ==============================
// Makes the app offline capable and installable as a PWA.
//
// Strategy: precache the build, then cache-first at runtime
//   1. On installation: the complete build is written into the cache (see
//      BUILD_ASSETS below) — not only what has been visited.
//   2. On later visits: cache-first — the browser gets resources straight
//      from the cache, offline included. Network only on a cache miss.
//   3. Navigation requests (HTML) use a network-first strategy with an
//      offline fallback, so updates arrive immediately while online.
//
// Cache invalidation: the cache name carries the commit SHA of the build
// (BUILD_ID, stamped in by CI). Every deployment therefore creates a new
// cache; 'activate' deletes all older ones. No manual version counter.

'use strict';

// CACHE INVALIDATION (audit 4.1)
// ==============================
// VERSION used to be incremented by hand — tied to renderer changes, not to
// app versions. The consequence: anyone who had opened perfusioncalc.de
// before a deployment kept being served the old build indefinitely, without
// noticing. On a clinical machine that is the most unpleasant failure mode
// there is — worse than a visible crash.
//
// BUILD_ID is now replaced with the commit SHA by CI (deploy.yml and
// release.yml, step "Stamp service worker build id"). Every deployment
// therefore creates a new cache name; 'activate' deletes all old ones.
// Locally the placeholder stays, which keeps the dev build's cache stable.
//
// IMPORTANT: the placeholder string below must not be changed without
// adjusting the sed pattern in all three workflows. The workflows verify
// after the substitution that it took effect, and abort otherwise.
//
// History of the earlier manual versions:
// v2: switch to the WASM build (skwasm renderer) — old CanvasKit caches have
//     to be discarded entirely so no mix of old and new renderer assets
//     survives.
// v3: new PWA icons (maskable with safe zone) plus a corrected manifest.
//     Discard old icon caches so the right app icon appears.
// v4: CSS splash plus a slimmed-down bundle (icon.png removed) and
//     compressed assets. Rebuild the cache so the splash takes effect.
// v5: cross-origin isolation (COOP/COEP) injected by the service worker so
//     that SharedArrayBuffer becomes available and the skwasm renderer runs
//     MULTI-THREADED (rendering on its own worker thread -> noticeably
//     smoother interaction). On GitHub Pages those headers cannot be set
//     server-side, hence the SW route (the "coi-serviceworker" principle,
//     integrated into the existing worker rather than added as a second one).
// v6: COOP/COEP REMOVED AGAIN. A performance trace showed the headers
//     disabled WebGL on the target device (webGLVersion -1), so CanvasKit
//     fell back to CPU rendering -> slower than without. GPU rendering is the
//     bigger lever. This version discards the responses cached with COI
//     headers in v5.
const BUILD_ID = '211b5661fe3858b51e8723736810c1eb9ec4aa4d';
const VERSION = `pcalc-${BUILD_ID}`;
const CACHE_NAME = `perfusioncalc-${VERSION}`;

// =============================================================================
// NOTE: cross-origin isolation (COOP/COEP) has been REMOVED again.
// =============================================================================
// Earlier versions (v5) injected COOP/COEP headers to unlock
// SharedArrayBuffer and multi-threaded skwasm. A performance trace showed,
// however, that those headers prevented the creation of the WebGL context on
// the target device ("webGLVersion is -1"), so CanvasKit fell back to pure
// CPU rendering — which was SLOWER than before.
//
// On phones, GPU rendering (CanvasKit via WebGL) is by far the bigger
// performance lever than multi-threading. Responses are therefore passed
// through UNCHANGED (no more COOP/COEP).
//
// The passThrough() function that used to live here had been a pure identity
// function ever since that rollback and was called in seven places —
// removed (audit 4.8). Should COOP/COEP ever return, the header manipulation
// belongs exactly here.

// Cache same-origin requests only; anything foreign goes straight to the
// network.
//
// The former rationale ("e.g. gstatic.com for CanvasKit") no longer holds:
// CanvasKit comes from our own origin thanks to --no-web-resources-cdn, and
// Roboto has been bundled since v0.4.3. The release build fetches nothing
// foreign at all. The rule is still right — foreign responses do not belong
// in a cache whose lifecycle we manage.
const ORIGIN = self.location.origin;

// =============================================================================
// Install: precache the app shell.
//
// WHY THE GENERATED LIST BELOW IS NECESSARY
// -----------------------------------------
// This used to hold only "stable, predictable core files" and everything
// else arrived through runtime caching. That stops working as soon as the
// cache name is tied to the commit SHA:
//
//   deploy -> new CACHE_NAME -> install() creates an EMPTY cache and fills
//   only the shell -> activate() deletes the old cache together with
//   main.dart.js and canvaskit.wasm -> the already-loaded tab does not
//   request those files again -> they are missing from the new cache ->
//   white screen offline.
//
// That is exactly what happened: canvaskit still came from the cache,
// main.dart.js failed with ERR_FAILED. Runtime caching fills a fresh cache
// only with what is requested again after the takeover.
//
// BUILD_ASSETS is generated by CI from the actual contents of build/web
// (step "Stamp service worker build id"). The precache is therefore complete
// and stays complete even when Flutter changes file names — nobody has to
// remember to maintain a list.
// skipWaiting makes the new worker take over immediately.
// =============================================================================

// Replaced by CI. The placeholder string must not be changed without
// adjusting the pattern in the workflow; the workflow verifies after the
// substitution that it took effect and aborts otherwise.
const BUILD_ASSETS = [
  "./.last_build_id",
  "./anatomy.html",
  "./assets/AssetManifest.bin",
  "./assets/AssetManifest.bin.json",
  "./assets/FontManifest.json",
  "./assets/NOTICES",
  "./assets/assets/coronary_arteries.jpg",
  "./assets/assets/coronary_arteries.svg",
  "./assets/assets/finck_va.jpg",
  "./assets/assets/finck_vv.jpg",
  "./assets/assets/fonts/Roboto-Bold.ttf",
  "./assets/assets/fonts/Roboto-Italic.ttf",
  "./assets/assets/fonts/Roboto-Regular.ttf",
  "./assets/assets/heart_anterior.jpg",
  "./assets/assets/heart_cross_section.jpg",
  "./assets/assets/heart_posterior.jpg",
  "./assets/assets/o2_chart.png",
  "./assets/fonts/MaterialIcons-Regular.otf",
  "./assets/packages/flutter_local_notifications_web/web/notifications_service_worker.js",
  "./assets/shaders/ink_sparkle.frag",
  "./assets/shaders/stretch_effect.frag",
  "./cannulas.html",
  "./canvaskit/canvaskit.js",
  "./canvaskit/canvaskit.wasm",
  "./canvaskit/chromium/canvaskit.js",
  "./canvaskit/chromium/canvaskit.wasm",
  "./canvaskit/skwasm.js",
  "./canvaskit/skwasm.wasm",
  "./canvaskit/skwasm_heavy.js",
  "./canvaskit/skwasm_heavy.wasm",
  "./canvaskit/wimp.js",
  "./canvaskit/wimp.wasm",
  "./flutter.js",
  "./flutter_bootstrap.js",
  "./flutter_service_worker.js",
  "./main.dart.js",
  "./main.dart.mjs",
  "./main.dart.wasm",
  "./privacy.html",
  "./version.json",
];

const CORE_SHELL = [
  './',
  './index.html',
  './flutter_bootstrap.js',
  './manifest.json?v=9',
  './favicon.ico?v=9',
  './icons/Icon-192.png?v=9',
  './icons/Icon-512.png?v=9',
  './icons/Icon-maskable-192.png?v=9',
  './icons/Icon-maskable-512.png?v=9',
  './apple-touch-icon.png?v=9',

  // Standalone pages outside the Flutter app. They used to be cached ONLY
  // if someone had opened them once — taking the app offline without having
  // visited the anatomy or cannula page first produced an error page there.
  // On an OR tablet without network that is precisely the moment they are
  // needed.
  './anatomy.html',
  './cannulas.html',
  './privacy.html',

  // The images those pages use. Without them the page would be there
  // offline but empty — and the anatomy page consists of nothing else.
  './assets/assets/heart_anterior.jpg',
  './assets/assets/heart_posterior.jpg',
  './assets/assets/heart_cross_section.jpg',
  './assets/assets/coronary_arteries.svg',
  './assets/assets/finck_va.jpg',
  './assets/assets/finck_vv.jpg',
];

// The two lists are deliberately NOT merged any more: since the two-stage
// precache below, each has its own failure semantics. CORE_SHELL entries
// carry query strings (?v=9), which is how the app actually requests them;
// the filtering there removes duplicates.

/**
 * Loads a list into the cache STRICTLY: any failure throws.
 *
 * Why not cache.addAll(): addAll accepts NO fetch options and therefore goes
 * through the browser's normal HTTP cache. GitHub Pages serves with
 * `Cache-Control: max-age=600` — within those ten minutes addAll would have
 * written the OLD file into the NEW cache after a deployment. For the hashed
 * Flutter assets that would be harmless, but flutter_bootstrap.js and
 * main.dart.js carry no hash in their names: the user would run an outdated
 * clinical build offline, and the SHA-tied cache name was meant to prevent
 * exactly that.
 *
 * `cache: 'reload'` bypasses the HTTP cache; the explicit throw preserves the
 * strict failure semantics that addAll was chosen for in the first place.
 */
async function precacheStrict(cache, urls) {
  await Promise.all(urls.map(async (url) => {
    const resp = await fetch(url, { cache: 'reload' });
    if (!resp || !resp.ok) {
      throw new Error('Precache failed: ' + url +
                      ' (' + (resp ? resp.status : 'no response') + ')');
    }
    await cache.put(url, resp);
  }));
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);

    // TWO-STAGE, and the difference is the whole point (audit N-2).
    //
    // Everything used to run fault-tolerantly. The idea was right —
    // cache.addAll() fails completely over a single missing file, and a
    // missing icon must not block the installation. Only, that tolerance did
    // not distinguish between an icon and main.dart.js.
    //
    // If a critical fetch failed transiently (a Wi-Fi handover on the ward
    // tablet — exactly the typical moment), the worker activated anyway,
    // activate() deleted the old cache, and offline the user faced a white
    // screen. Same end state as v0.4.6, different cause.
    //
    // Stage 1: BUILD_ASSETS (generated by CI from build/web, containing
    // flutter_bootstrap.js, main.dart.* and canvaskit) strictly. Throws on
    // any failure -> install() rejects -> the worker does NOT activate ->
    // the old one stays in service together with its cache. A failed update
    // is a non-event; half an update is a white screen.
    //
    // './' and './index.html' belong here too, although they do not come
    // from BUILD_ASSETS (audit R-1): './' is not a file in the build
    // directory, and 'index.html' sits in the CI generator's skip_exact list
    // because CORE_SHELL already lists it. Those two were therefore the last
    // critical entries with tolerant semantics — and without them of all
    // things the rest of the cache is useless: the navigation fallback below
    // falls back on caches.match('./').
    await precacheStrict(cache, ['./', './index.html']);
    if (BUILD_ASSETS.length > 0) {
      await precacheStrict(cache, BUILD_ASSETS);
    }

    // Stage 2: the static extras stay tolerant. If something is missing
    // here, an icon is blurry or a secondary page is unavailable offline —
    // annoying, but the app starts.
    const hard = new Set(['./', './index.html', ...BUILD_ASSETS]);
    const optional = CORE_SHELL.filter((url) => !hard.has(url));
    await Promise.all(optional.map(async (url) => {
      try {
        const resp = await fetch(url, { cache: 'reload' });
        if (resp && resp.ok) await cache.put(url, resp);
      } catch (_) { /* a single file is missing - ignore */ }
    }));

    self.skipWaiting();
  })());
});

// =============================================================================
// Activate: delete caches left over from earlier versions.
// clients.claim makes the new worker take control of all open tabs
// immediately.
// =============================================================================
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((k) => k.startsWith('perfusioncalc-') && k !== CACHE_NAME)
        .map((k) => caches.delete(k))
    );
    await self.clients.claim();
  })());
});

// =============================================================================
// Fetch: the actual caching.
// =============================================================================
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Cache GET requests only. POST/PUT/DELETE are irrelevant here (the app
  // has no backend), but stated explicitly for safety.
  if (request.method !== 'GET') return;

  // Do not cache cross-origin — see the comment on ORIGIN.
  const url = new URL(request.url);
  if (url.origin !== ORIGIN) return;

  // Navigation requests (a new tab opening "/") get network-first: when
  // online, fetch fresh HTML; on failure (offline), fall back to the cache.
  // Users therefore see the last cached version offline but receive updates
  // immediately once the network is back.
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(request);
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, fresh.clone());
        return fresh;
      } catch (e) {
        const cached = await caches.match(request);
        if (cached) return cached;
        // Last resort: index.html from the cache.
        const indexFallback = await caches.match('./');
        if (indexFallback) return indexFallback;
        throw e;
      }
    })());
    return;
  }

  // The bootstrap and the main bundle carry NO hash in their file names and
  // therefore fell into the cache-first branch below — after the first visit
  // they were never revalidated again (audit 4.1). The commit-SHA-tied cache
  // name already solves that; network-first is the second bolt for the case
  // where a browser has not yet replaced the old sw.js. Offline the cache
  // still applies.
  const isEntryPoint = /\/(flutter_bootstrap\.js|main\.dart\.js)$/.test(url.pathname);
  if (isEntryPoint) {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(request, { cache: 'no-cache' });
        if (fresh && fresh.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, fresh.clone());
        }
        return fresh;
      } catch (e) {
        const cached = await caches.match(request);
        if (cached) return cached;
        throw e;
      }
    })());
    return;
  }

  // Static, non-critical assets (images, fonts): stale-while-revalidate.
  // Serves from the cache immediately (fastest perceived performance) and
  // refreshes the file in the background for the next call.
  const isStaticAsset = /\.(png|jpe?g|gif|webp|svg|ico|woff2?|ttf|otf)$/i
      .test(url.pathname);
  if (isStaticAsset) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);
      const cached = await cache.match(request);
      const networkFetch = fetch(request).then((fresh) => {
        if (fresh && fresh.ok) cache.put(request, fresh.clone());
        return fresh;
      }).catch(() => null);
      // Serve from cache immediately if present, otherwise await network.
      const resp = cached || (await networkFetch);
      return resp || Response.error();
    })());
    return;
  }

  // All other resources (JS/WASM/etc.): cache-first.
  // Deliberately cache-first for engine assets so that no inconsistent mix
  // of old and new engine/app versions can arise. Updates arrive cleanly as
  // a whole via the cache name (above).
  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;

    try {
      const fresh = await fetch(request);
      // Cache successful responses only. Not caching 404/500 avoids serving
      // users a permanent error page.
      if (fresh && fresh.ok) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, fresh.clone());
      }
      return fresh;
    } catch (e) {
      // Offline and not cached -> pass the network error to the browser.
      throw e;
    }
  })());
});

// =============================================================================
// Message channel: lets the app tell the service worker to "please activate
// now" (e.g. from an "update available" button). Currently unused, but
// prepared for later.
// =============================================================================
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// =============================================================================
// Notification click (audit NEU-1)
// =============================================================================
// web_notifications_web.dart has two delivery paths. On the constructor path
// the Dart code sets n.onclick and brings the window to the front. On the
// service worker path that is structurally impossible: the click is
// delivered to the worker, not to the page. Without this handler nothing at
// all happened on Chrome for Android — precisely the platform this delivery
// path was built for. The user sees the cardioplegia reminder, taps it, ends
// up nowhere, and has to find the app by hand in the middle of a case.
//
// Behaviour: focus an existing window, otherwise open one.
// includeUncontrolled: true is required because a tab opened before this
// worker activated is not yet controlled by it.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const all = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    for (const client of all) {
      if ('focus' in client) return client.focus();
    }
    if (self.clients.openWindow) return self.clients.openWindow('./');
  })());
});
