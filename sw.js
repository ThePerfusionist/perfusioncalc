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
const VERSION = 'pcalc-v1';
const CACHE_NAME = `perfusioncalc-${VERSION}`;

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
// Install: nichts Spezielles. Wir nutzen Runtime-Caching, kein Pre-Cache.
// skipWaiting sorgt dafuer, dass der neue SW sofort aktiv wird, ohne dass der
// Nutzer alle Tabs schliessen muss.
// =============================================================================
self.addEventListener('install', (event) => {
  self.skipWaiting();
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
        return fresh;
      } catch (e) {
        const cached = await caches.match(request);
        if (cached) return cached;
        // Letzter Fallback: index.html aus dem Cache.
        const indexFallback = await caches.match('./');
        if (indexFallback) return indexFallback;
        throw e;
      }
    })());
    return;
  }

  // Alle anderen Ressourcen (JS/WASM/PNG/etc.): Cache-First.
  // Wenn im Cache: direkt liefern (auch offline). Sonst: aus Netzwerk holen
  // und fuer naechstes Mal in den Cache schreiben.
  event.respondWith((async () => {
    const cached = await caches.match(request);
    if (cached) return cached;

    try {
      const fresh = await fetch(request);
      // Nur erfolgreiche Antworten cachen. 404/500 nicht cachen, sonst
      // bekommen Nutzer dauerhaft Fehlerseiten.
      if (fresh && fresh.ok) {
        const cache = await caches.open(CACHE_NAME);
        cache.put(request, fresh.clone());
      }
      return fresh;
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
