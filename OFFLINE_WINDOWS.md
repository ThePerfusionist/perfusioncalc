# PerfusionCalc offline on a Windows PC without internet

Short guide for moving the web app from a machine **with** internet to one
**without** — for example onto workstations inside a hospital network.

---

## The simplest route: download the ready-made package

**Nothing has to be built.** GitHub Actions produces a finished package:

1. Go to **Releases** in the repository
2. Under **Assets** of the release you want, download
   `PerfusionCalc-Offline-Windows-vX.Y.Z.zip`

It sits right next to the Android APK.

> For an intermediate state without a release: **Actions → "Offline Windows
> Bundle (manual)" → Run workflow**, then download the package under
> *Artifacts*.

After that: unpack the ZIP, copy the folder onto the target machine,
double-click **`start.bat`**. The browser opens and a web server is already
included.

> The steps below are only needed if you want to build the package yourself —
> for instance from an unreleased state.

---

## First things first: double-clicking `index.html` does not work

Flutter web apps load their modules over HTTP. Opening a file directly
(`file://`) is blocked by the browser and the page stays blank. A **small
local web server** is therefore required — but it runs entirely offline on the
target machine; at no point is there an internet connection.

> **Simpler alternative:** for pure offline use the **Android app** (APK) is
> less trouble — install and done, no server needed. The guide below is worth
> it when it has to be a Windows PC.

---

## Step 1 — On the machine with internet: build the web app

```powershell
flutter build web --release --no-web-resources-cdn --base-href / --pwa-strategy=none
```

⚠️ **`--no-web-resources-cdn` is essential for offline operation.** Without it
the app fetches the CanvasKit graphics library from a CDN and stays blank when
there is no internet.

⚠️ **`--pwa-strategy=none` is equally essential.** With `offline-first` Flutter
generates its own service worker, which `flutter_bootstrap.js` registers in the
same scope `/` as the project's `web/sw.js`. Two registrations for one scope
cannot coexist; the later one replaces the earlier. Online this goes
unnoticed — offline the app breaks.

The result is in `build\web\`.

## Step 2 — Obtain a web server

A single portable EXE is enough, for instance **Caddy**
(<https://caddyserver.com/download> → Windows / amd64 →
`caddy_windows_amd64.exe`).

Alternatively **Python** is often already present on the target machine, in
which case no additional file is needed (see step 4, variant B).

### Checksums of the bundled Caddy

The bundles built by GitHub Actions (`PerfusionCalc-Offline-Windows-*.zip`)
contain a firmly pinned Caddy version. Version and hash live in
`.github/workflows/release.yml` and `offline-bundle.yml`; without the pin two
builds of the same tag would not be bit-identical and a delivered bundle could
not be verified afterwards.

| | |
|---|---|
| Version | **2.11.4** |
| File | `caddy_2.11.4_windows_amd64.zip` |
| SHA-256 | `1708333f79e274c7697285afe6d592ab39314e0b131e9ec6bea08ad27df62ebf` |
| SHA-512 | `cd5ccfd86a4b40732cf715890d0dca5bf3f63adefec5a7914de85adf240c60ce7e5d2791631b88ef9758e46b23bb1730e020b9c5d696889740b284ffd4788e35` |

The SHA-512 can be checked against the vendor's official list:
`https://github.com/caddyserver/caddy/releases/download/v2.11.4/caddy_2.11.4_checksums.txt`

Verifying on Windows (PowerShell):

```powershell
(Get-FileHash caddy_2.11.4_windows_amd64.zip -Algorithm SHA256).Hash.ToLower()
```

In hospital environments this chain of evidence is often the precondition for
the IT department to approve an unknown `.exe` at all. Anyone not permitted to
run the EXE takes variant B (the PowerShell or Python server) — then
`caddy.exe` is not needed.

## Step 3 — Pack the USB stick

```
PerfusionCalc\
├── web\              ← the complete contents of build\web\
├── caddy.exe         ← variant A only
└── start.bat
```

`start.bat`, `serve.ps1` and `LIESMICH.txt` live in the repository under
`tool/offline/` — just copy them along. `LIESMICH.txt` is deliberately in
German: it is read by staff at the clinical workstation, not by developers.

Anyone wanting to write the launcher themselves will find a minimal version
here. Note that the shipped `start.bat` does considerably more: it probes each
server option before starting it, so a `caddy.exe` blocked by AppLocker or
SmartScreen falls through to PowerShell and then to Python.

Contents of a minimal `start.bat`:

```bat
@echo off
cd /d "%~dp0"
start "" http://localhost:8080
caddy.exe file-server --root web --listen :8080
```

For **variant B (Python instead of Caddy)**:

```bat
@echo off
cd /d "%~dp0web"
start "" http://localhost:8080
python -m http.server 8080
```

> **On variant B:** `python -m http.server` determines the content type via
> the `mimetypes` module. Whether `.wasm` maps to `application/wasm` there
> depends on the Python version — older versions lack the entry and deliver
> `application/octet-stream` instead. The app still runs: the CanvasKit loader
> has an `arrayBuffer()` fallback for `WebAssembly.instantiateStreaming`. The
> **start does take noticeably longer**, though, because the module is no
> longer compiled while it downloads. A slow first start under variant B is
> therefore expected and not a defect. The variants `start.bat` prefers
> (Caddy, `serve.ps1`) set the type correctly.

## Step 4 — Start on the target machine

Copy the folder from the stick to the hard disk (e.g. to `C:\PerfusionCalc`),
then double-click `start.bat`. The browser opens at `http://localhost:8080`.

To stop, close the black console window.

---

## Notes

**Windows firewall:** a prompt may appear on first start. "Cancel" is enough —
no exception is needed for `localhost`.

**Install as an app:** using the install icon in the address bar (Chrome/Edge),
PerfusionCalc can be set up as a standalone window without an address bar. The
server still has to be running.

**Notifications (cardioplegia timer):** these work on `localhost`, because
browsers treat it as a secure context. The **tab has to stay open** — unlike
the Android app, which also notifies in the background.

**Updating:** rebuild, replace the `web\` folder, done. If the old version
sticks in the browser: Ctrl+Shift+R, or History → Clear browsing data → cached
files.

**Port taken?** Replace `8080` with e.g. `8081` in `start.bat` and in the URL.
The shipped `start.bat` already searches for a free port among 8080, 8081,
8082 and 8090 by itself.

**Security review:** `serve.ps1` carries a note for hospital IT in its header,
including the manual counter-check for path traversal. The automated version
of that check is `tool/offline/test-serve.ps1`.
