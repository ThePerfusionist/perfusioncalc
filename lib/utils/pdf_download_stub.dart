// Stub fuer Mobile/Desktop. Der PDF-Export ist primaer fuer Web gedacht
// (PerfusionCalc ist eine Web-App). Auf Mobile/Desktop wuerde man
// path_provider + share_plus nutzen - nicht implementiert, weil aktuell
// nicht gebraucht.

import 'dart:typed_data';

void downloadPdf(Uint8List bytes, String filename) {
  // No-op auf Nicht-Web-Plattformen
}
