// Web implementation of the PDF download.
// Creates a Blob from the bytes, an <a download> tag, and triggers a
// synthetic click. Works in every browser.

import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  // Bytes -> Blob with MIME type application/pdf
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  // Create an object URL for the blob (temporary, in the browser)
  final url = web.URL.createObjectURL(blob);
  // Create an <a> element, trigger the download, remove it again
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  // `body` can legitimately be absent very early in the document lifecycle;
  // the null-assertion operator would throw there. `?.` degrades to "no
  // download" instead of an exception.
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Release the URL object again (no memory leak) - but NOT synchronously.
  // Safari and older Firefox abort the download when the object URL is
  // revoked in the same task as the click; the browser has not started
  // reading the blob yet at that point.
  Future.delayed(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
