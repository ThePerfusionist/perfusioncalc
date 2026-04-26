// Mobile/Desktop-Implementierung des PDF-"Downloads".
// Auf Mobile gibt es kein "Download" wie im Browser. Stattdessen oeffnen
// wir das System-Share-Sheet, sodass der Nutzer das PDF
//   - in einer beliebigen App speichern kann (Files, Drive, Dropbox, etc.)
//   - per E-Mail / Messenger versenden kann
//   - oeffnen / drucken kann
//
// Das ist die uebliche Erwartung von iOS- und Android-Nutzern beim
// "Exportieren" einer Datei.

import 'dart:typed_data';
import 'package:printing/printing.dart';

void downloadPdf(Uint8List bytes, String filename) {
  // sharePdf gibt ein Future<void> zurueck, das wir hier nicht awaiten -
  // der UI-Thread blockiert nicht und der Share-Dialog erscheint.
  Printing.sharePdf(bytes: bytes, filename: filename);
}
