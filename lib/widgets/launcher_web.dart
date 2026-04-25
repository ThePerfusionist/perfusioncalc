// Web-Implementierung: nutzt window.open(), um die HTML-Seite in einem
// neuen Tab zu öffnen. Hängt die aktuell aktive Sprache als ?lang=...
// Query-Parameter an, damit die externe Seite konsistent mit der App-UI ist.

import 'package:web/web.dart' as web;
import '../i18n/app_strings.dart';

void launchExternal(String relativeUrl) {
  final lang = LocaleNotifier.instance.current.code;
  final separator = relativeUrl.contains('?') ? '&' : '?';
  final url = '$relativeUrl${separator}lang=$lang';
  // _blank → neuer Tab. noopener,noreferrer für Sicherheit.
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
