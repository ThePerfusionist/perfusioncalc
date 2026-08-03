// Mobile/desktop implementation of the PDF "download".
// Opens a system save dialog (Android: Storage Access Framework,
// iOS: Files app). The user chooses the location and optionally the
// filename, then file_picker writes the PDF there.
//
// Advantages over a share sheet:
//   - Clear "save" behavior, no confusion with sharing
//   - Works without storage permissions on Android 10+
//   - Same UX on Android and iOS

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  // saveFile() opens the system save dialog.
  // - bytes: the PDF as a Uint8List is written directly (mobile)
  // - fileName: suggested filename (the user can edit it)
  // - dialogTitle: dialog header
  // - type: filters for PDF in the save dialog
  //
  // Return value: path of the saved file, or null (user cancelled).
  // We don't use the path further, so it's ignored.
  // FilePicker.saveFile(), nicht FilePicker.platform.saveFile(): v11.0.0 hat
  // die Klasse auf statische Methoden umgestellt und den instanzbasierten
  // Zugriff ueber .platform entfernt. Signatur gegen die Quelle von v11.0.3
  // geprueft - alle hier uebergebenen Parameter existieren unveraendert.
  await FilePicker.saveFile(
    dialogTitle: 'Save PDF',
    fileName: filename,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
}
