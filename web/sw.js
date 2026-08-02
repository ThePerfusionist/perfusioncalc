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
// Cache-Invalidierung: Der Cache-Name enthaelt die Commit-SHA des Builds
// (BUILD_ID, im CI eingestempelt). Jeder Deploy erzeugt damit automatisch
// einen neuen Cache; 'activate' loescht alle aelteren. Kein manuelles
// Hochzaehlen mehr.

'use strict';

// CACHE-INVALIDIERUNG (Audit 4.1)
// ================================
// Frueher wurde VERSION von Hand hochgezaehlt - gekoppelt an Renderer-
// Umstellungen, nicht an App-Versionen. Folge: Wer perfusioncalc.de vor einem
// Deploy geoeffnet hatte, bekam den alten Build unbegrenzt weiter geliefert,
// ohne es zu merken. Bei einem klinischen Rechner ist das der unangenehmste
// Fehlerfall ueberhaupt - schlimmer als ein sichtbarer Absturz.
//
// BUILD_ID wird jetzt im CI durch die Commit-SHA ersetzt (deploy.yml und
// release.yml, Schritt "Stamp service worker build id"). Jeder Deploy erzeugt
// damit einen neuen Cache-Namen; 'activate' loescht alle alten. Lokal bleibt
// der Platzhalter stehen, dann ist der Cache im Dev-Build stabil.
//
// WICHTIG: Der Platzhalter-String unten darf nicht veraendert werden, ohne
// das sed-Muster in beiden Workflows mit anzupassen. Die Workflows pruefen
// nach der Ersetzung, ob sie gegriffen hat, und brechen sonst ab.
//
// Historie der frueheren manuellen Versionen:
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
// v6: COOP/COEP WIEDER ENTFERNT. Ein Performance-Trace zeigte, dass die Header
//     auf dem Zielgerät WebGL deaktivierten (webGLVersion -1) und CanvasKit
//     dadurch auf CPU-Rendering zurückfiel -> langsamer als ohne. GPU-Rendering
//     ist der größere Hebel. Diese Version verwirft die mit COI-Headern
//     gecachten Responses aus v5.
const BUILD_ID = 'DEV';
const VERSION = `pcalc-${BUILD_ID}`;
const CACHE_NAME = `perfusioncalc-${VERSION}`;

// =============================================================================
// HINWEIS: Cross-Origin-Isolation (COOP/COEP) wurde wieder ENTFERNT.
// =============================================================================
// Frühere Versionen (v5) injizierten COOP/COEP-Header, um SharedArrayBuffer
// und multi-threaded skwasm freizuschalten. Ein Performance-Trace hat aber
// gezeigt, dass diese Header auf dem Zielgerät die Erstellung des WebGL-
// Kontexts verhindert haben ("webGLVersion is -1"), wodurch CanvasKit auf
// reines CPU-Rendering zurückfiel - das war LANGSAMER als vorher.
//
// GPU-Rendering (CanvasKit über WebGL) ist auf Smartphones der mit Abstand
// größere Performance-Hebel als Multi-Threading. Daher reichen wir Responses
// jetzt UNVERÄNDERT durch (kein COOP/COEP mehr).
//
// Die frueher hier stehende Funktion passThrough() war seit diesem Rueckbau
// eine reine Identitaetsfunktion und wurde an sieben Stellen aufgerufen -
// entfernt (Audit 4.8). Sollten COOP/COEP je zurueckkehren, gehoert die
// Header-Manipulation an genau diese Stelle.

// Nur Same-Origin-Requests cachen, alles Fremde direkt aus dem Netz.
//
// Die fruehere Begruendung ("z.B. gstatic.com fuer CanvasKit") stimmt nicht
// mehr: CanvasKit kommt durch --no-web-resources-cdn vom eigenen Origin und
// Roboto ist seit v0.4.3 gebuendelt. Der Release-Build laedt ueberhaupt
// nichts Fremdes. Die Regel bleibt trotzdem richtig - fremde Antworten
// gehoeren nicht in einen Cache, dessen Lebenszyklus wir verwalten.
const ORIGIN = self.location.origin;

// =============================================================================
// Install: App-Shell vorab cachen.
//
// WARUM DIE GENERIERTE LISTE UNTEN NOETIG IST
// -------------------------------------------
// Frueher standen hier nur "stabile, vorhersehbare Kern-Dateien" und alles
// andere kam per Runtime-Caching dazu. Das funktioniert nicht, sobald der
// Cache-Name an die Commit-SHA gekoppelt ist:
//
//   Deploy -> neuer CACHE_NAME -> install() legt einen LEEREN Cache an und
//   fuellt nur die Shell -> activate() loescht den alten Cache mitsamt
//   main.dart.js und canvaskit.wasm -> der bereits geladene Tab fragt diese
//   Dateien nicht erneut an -> sie fehlen im neuen Cache -> offline weiss.
//
// Genau das ist passiert: canvaskit kam noch aus dem Cache, main.dart.js
// schlug mit ERR_FAILED fehl. Runtime-Caching fuellt einen frischen Cache
// eben nur mit dem, was nach der Uebernahme noch einmal angefragt wird.
//
// BUILD_ASSETS wird im CI aus dem tatsaechlichen Inhalt von build/web
// erzeugt (Schritt "Stamp service worker build id"). Damit ist der Precache
// vollstaendig und bleibt es auch, wenn Flutter Dateinamen aendert -
// niemand muss daran denken, eine Liste nachzupflegen.
// skipWaiting sorgt dafuer, dass der neue SW sofort aktiv wird.
// =============================================================================

// Wird im CI ersetzt. Der Platzhalter-String darf nicht veraendert werden,
// ohne das Muster im Workflow mit anzupassen; der Workflow prueft nach der
// Ersetzung, ob sie gegriffen hat, und bricht sonst ab.
const BUILD_ASSETS = [];

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

  // Eigenstaendige Seiten ausserhalb der Flutter-App. Sie wurden bisher nur
  // gecacht, WENN sie jemand einmal geoeffnet hatte - wer die App offline
  // nahm, ohne vorher die Anatomie- oder Kanuelenseite besucht zu haben,
  // bekam dort eine Fehlerseite. Auf einem OP-Tablet ohne Netz ist das
  // genau der Moment, in dem man sie braucht.
  './anatomy.html',
  './cannulas.html',
  './privacy.html',

  // Die Bilder dieser Seiten. Ohne sie waere die Seite offline zwar da,
  // aber leer - und der einzige Inhalt der Anatomieseite sind die Bilder.
  './assets/assets/heart_anterior.jpg',
  './assets/assets/heart_posterior.jpg',
  './assets/assets/heart_cross_section.jpg',
  './assets/assets/coronary_arteries.svg',
  './assets/assets/finck_va.jpg',
  './assets/assets/finck_vv.jpg',
];

// Die beiden Listen werden bewusst NICHT mehr zu einer verschmolzen: seit
// dem zweistufigen Precache unten hat jede eine eigene Fehlersemantik.
// CORE_SHELL-Eintraege tragen Query-Strings (?v=9), unter denen die App sie
// auch tatsaechlich anfragt; die Filterung dort entfernt Doppel.

/**
 * Laedt eine Liste HART in den Cache: jeder Fehlschlag wirft.
 *
 * Warum nicht cache.addAll(): addAll erlaubt KEINE fetch-Optionen und holt
 * daher ueber den normalen HTTP-Cache des Browsers. GitHub Pages liefert mit
 * `Cache-Control: max-age=600` aus - innerhalb dieser zehn Minuten haette
 * addAll nach einem Deploy die ALTE Datei in den NEUEN Cache geschrieben.
 * Bei den gehashten Flutter-Assets waere das folgenlos, aber
 * flutter_bootstrap.js und main.dart.js tragen keinen Hash im Namen: der
 * Nutzer liefe offline auf einem veralteten klinischen Build, und der
 * SHA-gekoppelte Cache-Name haette genau das verhindern sollen.
 *
 * `cache: 'reload'` umgeht den HTTP-Cache; der explizite Wurf erhaelt die
 * harte Fehlersemantik, um derentwillen addAll ueberhaupt gewaehlt wurde.
 */
async function precacheStrict(cache, urls) {
  await Promise.all(urls.map(async (url) => {
    const resp = await fetch(url, { cache: 'reload' });
    if (!resp || !resp.ok) {
      throw new Error('Precache fehlgeschlagen: ' + url +
                      ' (' + (resp ? resp.status : 'kein Response') + ')');
    }
    await cache.put(url, resp);
  }));
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);

    // ZWEISTUFIG, und der Unterschied ist der Punkt (Audit N-2).
    //
    // Frueher lief ALLES fehlertolerant durch. Die Idee war richtig -
    // cache.addAll() scheitert komplett an einer einzigen fehlenden Datei,
    // ein fehlendes Icon darf die Installation nicht blockieren. Nur
    // unterschied die Toleranz nicht zwischen einem Icon und main.dart.js.
    //
    // Scheitert ein kritischer Fetch transient (WLAN-Wechsel auf dem
    // Stationstablet - genau der typische Moment), aktivierte sich der
    // Worker trotzdem, activate() loeschte den alten Cache, und offline
    // stand der Nutzer vor einer weissen Seite. Derselbe Endzustand wie
    // v0.4.6, andere Ursache.
    //
    // Stufe 1: BUILD_ASSETS (im CI aus build/web erzeugt, enthaelt
    // flutter_bootstrap.js, main.dart.* und canvaskit) hart. Wirft bei
    // jedem Fehlschlag -> install() rejected -> der Worker aktiviert sich
    // NICHT -> der alte bleibt mitsamt seinem Cache in Betrieb. Ein
    // fehlgeschlagenes Update ist ein Nicht-Ereignis; ein halbes Update ist
    // eine weisse Seite.
    //
    // './' und './index.html' gehoeren mit dazu, obwohl sie nicht aus
    // BUILD_ASSETS kommen (Audit R-1): './' ist keine Datei im Build-
    // Verzeichnis, 'index.html' steht in der skip_exact-Liste des
    // CI-Generators, weil es schon in CORE_SHELL gefuehrt wird. Beide waren
    // damit die letzten kritischen Eintraege mit toleranter Semantik - und
    // ausgerechnet ohne sie nuetzt der Rest des Caches nichts: der
    // Navigations-Fallback unten greift auf caches.match('./') zurueck.
    await precacheStrict(cache, ['./', './index.html']);
    if (BUILD_ASSETS.length > 0) {
      await precacheStrict(cache, BUILD_ASSETS);
    }

    // Stufe 2: die statischen Zusatzdateien weiterhin tolerant. Fehlt hier
    // etwas, ist ein Icon unscharf oder eine Nebenseite offline nicht da -
    // aergerlich, aber die App startet.
    const hard = new Set(['./', './index.html', ...BUILD_ASSETS]);
    const optional = CORE_SHELL.filter((url) => !hard.has(url));
    await Promise.all(optional.map(async (url) => {
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

  // Cross-Origin nicht cachen - siehe Kommentar bei ORIGIN.
  const url = new URL(request.url);
  if (url.origin !== ORIGIN) return;

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

  // Der Bootstrap und das Haupt-Bundle tragen KEINEN Hash im Dateinamen und
  // fielen deshalb in den Cache-First-Zweig unten - sie wurden nach dem ersten
  // Besuch nie wieder revalidiert (Audit 4.1). Der an die Commit-SHA
  // gekoppelte Cache-Name loest das bereits; Network-First ist der zweite
  // Riegel fuer den Fall, dass ein Browser die alte sw.js noch nicht ersetzt
  // hat. Offline greift weiterhin der Cache.
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
      return resp || Response.error();
    })());
    return;
  }

  // Alle anderen Ressourcen (JS/WASM/etc.): Cache-First.
  // Bewusst Cache-First für Engine-Assets, damit nie eine inkonsistente
  // Mischung aus alter und neuer Engine-/App-Version entsteht. Updates
  // kommen über die SW-VERSION (oben) sauber als Ganzes.
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

// =============================================================================
// Notification-Klick (Audit NEU-1)
// =============================================================================
// web_notifications_web.dart hat zwei Zustellwege. Beim Konstruktor-Weg setzt
// der Dart-Code n.onclick und holt das Fenster nach vorn. Beim Service-Worker-
// Weg ist das strukturell unmoeglich: der Klick wird an den Worker zugestellt,
// nicht an die Seite. Ohne diesen Handler passierte auf Chrome fuer Android -
// also genau der Plattform, fuer die dieser Zustellweg gebaut wurde -
// schlicht nichts. Der Nutzer sieht die Kardioplegie-Erinnerung, tippt darauf,
// landet nirgends und muss die App mitten im Fall von Hand suchen.
//
// Verhalten: vorhandenes Fenster fokussieren, sonst eines oeffnen.
// includeUncontrolled: true ist noetig, weil ein Tab, der vor der Aktivierung
// dieses Workers geoeffnet wurde, noch nicht von ihm kontrolliert wird.
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
