// Web-spezifische Implementierung fuer BrowserSafeImage.
// Registriert eine viewFactory, die einen <img>-Tag im DOM erzeugt.
//
// Wird ueber conditional import nur auf Web geladen
// (siehe common.dart: 'browser_image_stub.dart' if (dart.library.js_interop)
//  'browser_image_web.dart').

import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

/// Registriert eine HtmlElementView-Factory, die einen <img>-Tag erzeugt.
/// Mehrfaches Registrieren mit demselben viewType ist okay - Flutter
/// ueberschreibt einfach die alte Factory.
void registerImageFactory(String viewType, String url, String objectFit) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId, {Object? params}) {
      final img = web.HTMLImageElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = objectFit
        ..style.display = 'block'
        // alt-Text fuer Screenreader (Accessibility)
        ..alt = 'image'
        // Lazy loading - browser entscheidet selbst, wann es geladen wird
        ..loading = 'lazy'
        // Kein Drag-and-Drop des Bildes
        ..draggable = false;
      return img;
    },
  );
}
