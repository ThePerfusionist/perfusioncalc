// PerfusionCalc – Custom Flutter Bootstrap
// Disables the service worker entirely and unregisters any old service workers
// that might be caching outdated favicon.ico / favicon.png / assets.
// This guarantees fresh asset loads on every visit.

// 1) Aggressively clean up any previously-registered Flutter service workers.
//    The app is an offline calculator and doesn't need SW caching –
//    the absence of a SW eliminates the favicon-caching issue entirely.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then((registrations) => {
    for (const registration of registrations) {
      registration.unregister().then((ok) => {
        if (ok) {
          console.log('[PerfusionCalc] Unregistered old service worker:', registration.scope);
        }
      });
    }
  });

  // Also purge the Flutter cache buckets just in case
  if ('caches' in window) {
    caches.keys().then((names) => {
      names.forEach((name) => {
        if (name.startsWith('flutter-') || name.includes('temp-') || name.includes('dynamic-')) {
          caches.delete(name).then(() => {
            console.log('[PerfusionCalc] Purged cache:', name);
          });
        }
      });
    });
  }
}

// 2) Start Flutter WITHOUT a service worker.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  // Explicitly no serviceWorkerSettings → Flutter won't register any SW
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
