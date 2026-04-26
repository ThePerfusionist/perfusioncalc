// Mobile/Desktop-Implementierung des PDF-"Downloads".
// Oeffnet einen System-Save-Dialog (Android: Storage Access Framework,
// iOS: Files-App). Der Nutzer waehlt Speicherort und ggf. Dateinamen,
// dann schreibt file_picker das PDF dorthin.
//
// Vorteile gegenueber Share-Sheet:
//   - Klares "Speichern"-Verhalten, keine Verwirrung mit teilen
//   - Funktioniert ohne Storage-Permissions auf Android 10+
//   - Selbe UX auf Android und iOS

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  // saveFile() oeffnet den System-Save-Dialog.
  // - bytes: das PDF als Uint8List wird direkt geschrieben (Mobile)
  // - fileName: Vorschlag fuer den Dateinamen (Nutzer kann editieren)
  // - dialogTitle: Header des Dialogs
  // - type: filtert auf PDF im Speichern-Dialog
  //
  // Rueckgabe: Pfad der gespeicherten Datei oder null (Nutzer hat
  // abgebrochen). Wir nutzen den Pfad nicht weiter, daher ignorieren.
  await FilePicker.platform.saveFile(
    dialogTitle: 'Save PDF',
    fileName: filename,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
}
