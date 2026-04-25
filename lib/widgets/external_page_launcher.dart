// External page launcher: öffnet eine HTML-Seite aus dem web/-Ordner
// in einem neuen Browser-Tab. Funktioniert nur im Web-Build; auf Mobile
// gibt es keinen Effekt (die Seiten existieren dort nicht).

import 'launcher_stub.dart'
    if (dart.library.js_interop) 'launcher_web.dart';

/// Öffnet eine relative URL (z.B. 'anatomy.html') in einem neuen Browser-Tab.
/// Übergibt die aktuell aktive Sprache als Query-Parameter, damit die externe
/// Seite die gleiche Sprache vorauswählt.
void openExternalPage(String relativeUrl) => launchExternal(relativeUrl);
