// PerfusionCalc Service Worker
// ==============================
// Macht die App offline-fähig und als PWA installierbar.
//
// Strategie: Runtime Caching mit Cache-First
//   1. Beim ersten Besuch: Alle vom Browser angeforderten Ressourcen werden
//      transparent in den Cache geschrieben.
//   2. Bei späteren Besuchen: Cache-First - der Browser bekommt Ressourcen
//      sofort aus dem Cache, auch wenn offline. Netzwerk nur bei Cache-Miss.
//   3. Navigations-Requests (HTML) haben eine Network-First-Strategie mit
//      Offline-Fallback, damit Updates sofort ankommen wenn online.
//
// Warum nicht Pre-Cache? Flutter erzeugt bei jedem Build neue Dateinamen
// (z.B. main.dart.js hat keinen Hash, aber canvaskit.js.map aendert sich
// inhaltlich). Eine feste Liste waere nach jedem Deploy veraltet. Runtime-
// Caching passt sich automatisch an.
//
// Cache-Invalidierung: Wenn sich dieser Service Worker aendert (Version
// hochzaehlen!), werden alle alten Caches geloescht und neu befuellt.

'use strict';

// Bei jedem groesseren Release hochzaehlen, damit Client-Caches
// vollstaendig invalidiert werden.
// v2: Umstellung auf WASM-Build (skwasm-Renderer) - alte CanvasKit-Caches
//     muessen vollstaendig verworfen werden, damit kein Mix aus altem und
//     neuem Renderer-Assets entsteht.
// v3: Neue PWA-Icons (maskable mit Safe-Zone) + korrigiertes Manifest.
//     Alte Icon-Caches verwerfen, damit das richtige App-Icon erscheint.
// v4: CSS-Splash + entschlacktes Bundle (icon.png entfernt) + komprimierte
//     Assets. Cache neu aufbauen, damit der Splash sofort greift.
// v5: Cross-Origin-Isolation (COOP/COEP) wird vom Service Worker injiziert,
//     damit SharedArrayBuffer verfügbar wird und der skwasm-Renderer
//     MULTI-THREADED läuft (Rendering auf eigenem Worker-Thread -> deutlich
//     flüssigere Interaktion). Auf GitHub Pages sind diese Header serverseitig
//     nicht setzbar, daher der SW-Weg ("coi-serviceworker"-Prinzip, hier
//     direkt in den bestehenden SW integriert statt als zweiter Worker).
const VERSION = 'pcalc-v5';
const CACHE_NAME = `perfusioncalc-${VERSION}`;

// =============================================================================
// Cross-Origin-Isolation Header-Injektion
// =============================================================================
// Fügt jeder Response die Header hinzu, die der Browser braucht, um
// SharedArrayBuffer (und damit multi-threaded WASM) freizuschalten:
//   - Cross-Origin-Opener-Policy: same-origin
//   - Cross-Origin-Embedder-Policy: credentialless
// "credentialless" wird gegenüber "require-corp" bevorzugt, weil es keine
// CORP-Header auf jeder einzelnen Subresource erzwingt - robuster, falls doch
// mal eine Ressource ohne CORP geladen wird (z.B. CanvasKit-CDN-Fallback).
function withCoiHeaders(response) {
  // Opaque/fehlerhafte Responses unverändert durchreichen (sonst Exception).
  if (!response || response.status === 0) return response;
  const headers = new Headers(response.headers);
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'credentialless');
  // Eigene Ressourcen als same-origin markieren, damit sie unter COEP geladen
  // werden dürfen.
  headers.set('Cross-Origin-Resource-Policy', 'same-origin');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

// Nur Same-Origin-Requests cachen. Alles von externen Hosts
// (z.B. gstatic.com fuer CanvasKit) direkt aus dem Netzwerk laden.
const ORIGIN = self.location.origin;

// URLs, die niemals gecacht werden sollen (falls wir mal dynamische
// Endpoints hinzufuegen, hier ausschliessen).
const NEVER_CACHE = [
  // Beispiele fuer spaeter:
  // '/api/',
];

// =============================================================================
// Install: App-Shell vorab cachen, damit der erste Re-Open der installierten
// PWA sofort flüssig startet (kein Warten auf Runtime-Caching). Nur stabile,
// vorhersehbare Kern-Dateien werden vorgeladen; die hash-benannten Flutter-
// Assets kommen weiterhin per Runtime-Caching dazu.
// skipWaiting sorgt dafuer, dass der neue SW sofort aktiv wird.
// =============================================================================
const APP_SHELL = [
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
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    // addAll schlägt fehl, wenn auch nur eine Datei nicht lädt - daher
    // einzeln und fehlertolerant cachen, damit ein fehlendes Icon nicht
    // die ganze Installation blockiert.
    await Promise.all(APP_SHELL.map(async (url) => {
      try {
        const resp = await fetch(url, { cache: 'reload' });
        if (resp && resp.ok) await cache.put(url, resp);
      } catch (_) { /* einzelne Datei fehlt - ignorieren */ }
    }));
    self.skipWaiting();
  })());
});

// =============================================================================
// Activate: alte Caches aus frueheren Versionen loeschen.
// clients.claim sorgt dafuer, dass der neue SW sofort Kontrolle ueber alle
// offenen Tabs uebernimmt.
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
// Fetch: das eigentliche Caching.
// =============================================================================
self.addEventListener('fetch', (event) => {
  const request = event.request;

  // Nur GET-Requests cachen. POST/PUT/DELETE sind hier irrelevant
  // (die App hat kein Backend), aber zur Sicherheit explizit.
  if (request.method !== 'GET') return;

  // Cross-Origin nicht cachen (CanvasKit wird ggf. von gstatic.com geladen).
  const url = new URL(request.url);
  if (url.origin !== ORIGIN) return;

  // Blacklist pruefen.
  if (NEVER_CACHE.some((path) => url.pathname.includes(path))) return;

  // Navigations-Requests (ein neuer Tab oeffnet "/") bekommen Network-First:
  // Wenn online, hole frisches HTML. Bei Fehler (offline): Fallback auf Cache.
  // So sehen Nutzer zwar die zuletzt gecachte Version offline, bekommen aber
  // sofort Updates, wenn Internet wieder da ist.
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(request);
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, fresh.clone());
        // COI-Header injizieren -> aktiviert SharedArrayBuffer auf der Seite.
        return withCoiHeaders(fresh);
      } catch (e) {
        const cached = await caches.match(request);
        if (cached) return withCoiHeaders(cached);
        // Letzter Fallback: index.html aus dem Cache.
        const indexFallback = await caches.match('./');
        if (indexFallback) return withCoiHeaders(indexFallback);
        throw e;
      }
    })());
    return;
  }

  // Statische, unkritische Assets (Bilder, Fonts): stale-while-revalidate.
  // Liefert sofort aus dem Cache (schnellste gefühlte Performance) und
  // aktualisiert die Datei parallel im Hintergrund für den nächsten Aufruf.
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
      // Sofort aus Cache liefern wenn vorhanden, sonst auf Netzwerk warten.
      const resp = cached || (await networkFetch);
      return resp ? withCoiHeaders(resp) : Response.error();
    })());
    return;
  }

  // Alle anderen Ressourcen (JS/WASM/etc.): Cache-First.
  // Bewusst Cache-First für Engine-Assets, damit nie eine inkonsistente
  // Mischung aus alter und neuer Engine-/App-Version entsteht. Updates
  // kommen über die SW-VERSION (oben) sauber als Ganzes.
  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return withCoiHeaders(cached);

    try {
      const fresh = await fetch(request);
      // Nur erfolgreiche Antworten cachen. 404/500 nicht cachen, sonst
      // bekommen Nutzer dauerhaft Fehlerseiten.
      if (fresh && fresh.ok) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, fresh.clone());
      }
      return withCoiHeaders(fresh);
    } catch (e) {
      // Offline und nicht im Cache -> Netzwerk-Fehler zum Browser durchreichen.
      throw e;
    }
  })());
});

// =============================================================================
// Message-Channel: erlaubt der App, dem Service Worker zu sagen "Bitte neu
// aktivieren" (z.B. ueber einen "Update verfuegbar"-Button). Wird aktuell
// nicht genutzt, ist aber fuer spaeter vorbereitet.
// =============================================================================
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
