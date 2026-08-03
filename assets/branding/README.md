# Icon-Quellen

Hier liegen die Icon-Varianten aus der Neuerzeugung für Version 8 (das `v8`
im Dateinamen entspricht dem Cache-Buster `?v=8`, mit dem `anatomy.html` und
`cannulas.html` das Favicon anfordern).

**Nicht in `pubspec.yaml` als Asset eingetragen** und damit nicht Teil eines
Builds. Der Ordner ist Ablage, kein Auslieferungspfad.

## Wichtig: das sind Kopien, kein Original

Alle drei Dateien sind **byte-identisch** mit Dateien, die bereits
ausgeliefert werden:

| Datei hier | identisch mit |
|---|---|
| `pcalc-icon-v8.png` (32×32) | `web/favicon.png` |
| `pcalc-icon-v8.ico` | `web/favicon.ico` |
| `pcalc-icon-v8-192.png` | `web/icons/Icon-192.png` |

Sie lagen bis v0.4.15 in `web/` und wurden von dort seit v0.4.6 in den harten
Precache aufgenommen — jeder Web-Besucher lud sie bei jedem Deploy neu, ohne
dass irgendetwas sie je angefordert hätte. Deshalb sind sie hier.

Wer sie löschen möchte, verliert nichts: jedes Byte existiert unverändert
unter den oben genannten Pfaden. Wer eine echte Icon-Quelle in höherer
Auflösung sucht, findet sie unter `assets/icon.png` bzw.
`assets/icon_foreground.png` — daraus erzeugt `flutter_launcher_icons` die
Plattformvarianten.

## Wenn Icons neu erzeugt werden

Den Cache-Buster in `web/anatomy.html`, `web/cannulas.html`,
`web/privacy.html` und `web/index.html` mit anheben (`?v=8` → `?v=9`), sonst
zeigen Browser das alte Icon weiter. Die Dateinamen hier sollten dann
denselben Zähler tragen.
