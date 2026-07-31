# PerfusionCalc offline auf einem Windows-PC ohne Internet

Kurzanleitung, um die Webapp von einem PC **mit** Internet auf einen PC
**ohne** Internet zu übertragen — z. B. auf Arbeitsplätze im Klinik-Netz.

---

## Der einfachste Weg: fertiges Paket herunterladen

Es muss **nichts gebaut werden**. GitHub Actions erzeugt ein fertiges Paket:

1. Im Repo auf **Releases** gehen
2. Beim gewünschten Release unter **Assets** die Datei
   `PerfusionCalc-Offline-Windows-vX.Y.Z.zip` herunterladen

Sie liegt dort direkt neben der Android-APK.

> Für einen Zwischenstand ohne Release: **Actions → „Offline Windows Bundle
> (manual)" → Run workflow**, danach das Paket unter *Artifacts* laden.

Danach: ZIP entpacken, Ordner auf den Zielrechner kopieren, **`start.bat`**
doppelklicken. Der Browser öffnet sich, ein Webserver ist bereits enthalten.

> Die Schritte weiter unten werden nur gebraucht, wenn das Paket selbst gebaut
> werden soll — etwa mit einem noch nicht veröffentlichten Stand.

---

## Wichtig vorab: ein Doppelklick auf `index.html` funktioniert nicht

Flutter-Webapps laden ihre Module über HTTP. Beim direkten Öffnen einer Datei
(`file://`) blockiert der Browser das, die Seite bleibt weiß. Es wird also ein
**kleiner lokaler Webserver** benötigt — der läuft aber komplett offline auf
dem Zielrechner, es besteht zu keinem Zeitpunkt eine Internetverbindung.

> **Einfachere Alternative:** Für reine Offline-Nutzung ist die **Android-App**
> (APK) unkomplizierter — installieren und fertig, kein Server nötig.
> Die folgende Anleitung lohnt sich, wenn es ein Windows-PC sein muss.

---

## Schritt 1 — Auf dem PC mit Internet: Webapp bauen

```powershell
flutter build web --release --no-web-resources-cdn --base-href / --pwa-strategy offline-first
```

⚠️ **`--no-web-resources-cdn` ist für den Offline-Betrieb entscheidend.** Ohne
diesen Schalter lädt die App die CanvasKit-Grafikbibliothek von einem CDN nach
und bleibt ohne Internet leer.

Ergebnis liegt in: `build\web\`

## Schritt 2 — Webserver besorgen

Eine einzelne portable EXE genügt, z. B. **Caddy**
(<https://caddyserver.com/download> → Windows / amd64 → `caddy_windows_amd64.exe`).

Alternativ ist **Python** oft schon auf dem Zielrechner vorhanden — dann wird
keine zusätzliche Datei gebraucht (siehe Schritt 4, Variante B).

## Schritt 3 — USB-Stick packen

```
PerfusionCalc\
├── web\              ← kompletter Inhalt von build\web\
├── caddy.exe         ← nur bei Variante A
└── start.bat
```

Die Dateien `start.bat`, `serve.ps1` und `LIESMICH.txt` liegen im Repo unter
`tool/offline/` — einfach mitkopieren. Wer sie selbst schreiben will, findet
hier eine Minimalfassung.

Inhalt von `start.bat`:

```bat
@echo off
cd /d "%~dp0"
start "" http://localhost:8080
caddy.exe file-server --root web --listen :8080
```

Für **Variante B (Python statt Caddy)**:

```bat
@echo off
cd /d "%~dp0web"
start "" http://localhost:8080
python -m http.server 8080
```

## Schritt 4 — Auf dem Zielrechner starten

Ordner vom Stick auf die Festplatte kopieren (z. B. nach `C:\PerfusionCalc`),
dann `start.bat` doppelklicken. Der Browser öffnet sich auf
`http://localhost:8080`.

Zum Beenden das schwarze Konsolenfenster schließen.

---

## Hinweise

**Windows-Firewall:** Beim ersten Start kann eine Abfrage erscheinen.
„Abbrechen" genügt — für `localhost` wird keine Freigabe benötigt.

**Als App installieren:** Im Browser über das Installations-Symbol in der
Adresszeile (Chrome/Edge) lässt sich PerfusionCalc als eigenständiges Fenster
ohne Adressleiste einrichten. Der Server muss dennoch laufen.

**Benachrichtigungen (Kardioplegie-Timer):** Funktionieren auf `localhost`,
weil Browser das als sicheren Kontext behandeln. Der **Tab muss geöffnet
bleiben** — im Gegensatz zur Android-App, die auch im Hintergrund meldet.

**Aktualisieren:** Neu bauen, den Ordner `web\` ersetzen, fertig. Falls die
alte Version im Browser hängen bleibt: Strg+Shift+R, oder Verlauf →
Browserdaten löschen → zwischengespeicherte Dateien.

**Port belegt?** In `start.bat` und in der URL `8080` durch z. B. `8081`
ersetzen.
