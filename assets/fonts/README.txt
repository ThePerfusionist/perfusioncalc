Roboto fonts for the PDF export
================================

These three TTF files are required for the PDF export (the standard PDF
fonts have no Unicode support for m², °, ·, —, subscripts and the like).

Since v0.4.3 the same files also serve as the app's font family (see the
`fonts:` block in pubspec.yaml), so CanvasKit no longer fetches Roboto from
fonts.gstatic.com at runtime. That is what makes the offline distribution
render text at all.

FILES THAT MUST BE HERE:
  Roboto-Regular.ttf
  Roboto-Bold.ttf
  Roboto-Italic.ttf

WHERE TO GET THEM:
  Option 1 (simplest): https://fonts.google.com/specimen/Roboto
    -> click "Get font" in the top right
    -> download the ZIP
    -> only three files are needed from it:
       - static/Roboto-Regular.ttf
       - static/Roboto-Bold.ttf
       - static/Roboto-Italic.ttf
    -> copy those three files into this folder

  Option 2: GitHub
    https://github.com/googlefonts/roboto/tree/main/src/hinted

LICENCE:
  Apache License 2.0 - Roboto may be used freely in any application,
  including commercial ones. See LICENSE.txt in the Roboto download.
