# Icon sources

The icon variants from the version 8 regeneration (the `v8` in the file name
matches the cache buster `?v=8` with which `anatomy.html` and `cannulas.html`
request the favicon).

**Not listed as an asset in `pubspec.yaml`** and therefore not part of any
build. This folder is storage, not a delivery path.

## Important: these are copies, not originals

All three files are **byte-identical** to files that are already shipped:

| File here | identical to |
|---|---|
| `pcalc-icon-v8.png` (32×32) | `web/favicon.png` |
| `pcalc-icon-v8.ico` | `web/favicon.ico` |
| `pcalc-icon-v8-192.png` | `web/icons/Icon-192.png` |

They used to live in `web/`, and from there they went into the hard precache
from v0.4.6 onwards — every web visitor downloaded them again on every
deployment although nothing ever requested them. That is why they are here.

Deleting them loses nothing: every byte exists unchanged at the paths above.
If you are looking for a genuine icon source at higher resolution, that is
`assets/icon.png` and `assets/icon_foreground.png`, from which
`flutter_launcher_icons` generates the platform variants.

## When icons are regenerated

Raise the cache buster in `web/anatomy.html`, `web/cannulas.html`,
`web/privacy.html` and `web/index.html` along with them (`?v=8` → `?v=9`),
otherwise browsers keep showing the old icon. The file names here should
carry the same counter.
