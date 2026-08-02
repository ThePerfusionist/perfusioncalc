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

### Prüfsummen des mitgelieferten Caddy

Die von GitHub Actions gebauten Bundles (`PerfusionCalc-Offline-Windows-*.zip`)
enthalten eine fest gepinnte Caddy-Version. Version und Hash stehen in
`.github/workflows/release.yml` und `offline-bundle.yml`; ohne Pin wären zwei
Builds desselben Tags nicht bitgleich und ein ausgeliefertes Bundle
nachträglich nicht überprüfbar.

| | |
|---|---|
| Version | **2.11.4** |
| Datei | `caddy_2.11.4_windows_amd64.zip` |
| SHA-256 | `1708333f79e274c7697285afe6d592ab39314e0b131e9ec6bea08ad27df62ebf` |
| SHA-512 | `cd5ccfd86a4b40732cf715890d0dca5bf3f63adefec5a7914de85adf240c60ce7e5d2791631b88ef9758e46b23bb1730e020b9c5d696889740b284ffd4788e35` |

Der SHA-512 ist gegen die offizielle Liste des Herstellers prüfbar:
`https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_checksums.txt`

Prüfung unter Windows (PowerShell):

```powershell
(Get-FileHash caddy_2.11.4_windows_amd64.zip -Algorithm SHA256).Hash.ToLower()
```

In Klinikumgebungen ist genau diese Nachweiskette oft Voraussetzung dafür,
dass die IT-Abteilung eine unbekannte `.exe` freigibt. Wer die EXE gar nicht
ausführen darf, nimmt Variante B (PowerShell-/Python-Server) — dann wird
`caddy.exe` nicht gebraucht.

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

> **Zu Variante B:** `python -m http.server` bestimmt den Content-Type über das
> `mimetypes`-Modul. Ob `.wasm` dort auf `application/wasm` abgebildet ist,
> hängt an der Python-Version — in älteren Versionen fehlt der Eintrag, und
> dann wird `application/octet-stream` geliefert. Die App läuft trotzdem: der
> CanvasKit-Loader hat für `WebAssembly.instantiateStreaming` einen
> `arrayBuffer()`-Rückfallweg. Der **Start dauert dann aber spürbar länger**,
> weil das Modul nicht mehr während des Downloads kompiliert wird. Ein
> langsamer erster Start unter Variante B ist also erwartbar und kein Defekt.
> Die von `start.bat` bevorzugten Varianten (Caddy, `serve.ps1`) setzen den
> Typ korrekt.

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
