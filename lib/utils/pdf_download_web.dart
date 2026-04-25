// Web-Implementierung des PDF-Downloads.
// Erzeugt einen Blob aus den Bytes, einen <a download>-Tag, und triggert
// einen synthetischen Klick. Funktioniert in jedem Browser.

import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadPdf(Uint8List bytes, String filename) {
  // Bytes -> Blob mit MIME-Type application/pdf
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  // Object-URL für den Blob erzeugen (zeitweilig im Browser)
  final url = web.URL.createObjectURL(blob);
  // <a>-Element erzeugen, herunterladen, wieder entfernen
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // URL-Objekt wieder freigeben (kein Memory-Leak)
  web.URL.revokeObjectURL(url);
}
