# Billed

A small, native macOS app that lives in your menu bar and shows your personal
[Cursor](https://cursor.com) usage at a glance — token consumption, model usage
patterns, and spend — without having to open the Cursor dashboard in a browser.

> Status: **Phase 2 complete.** Daily trend chart + UI polish. Now a focused,
> **read-only menu bar monitor** (no alerts, no widget) — next up is richer
> activity stats. See the [roadmap](docs/05-roadmap.md).

> [!IMPORTANT]
> **Internal tool — company use only.** This is an unofficial side project, not a
> Cursor product. It reads your usage from **unofficial `cursor.com` endpoints**
> using your own signed-in session — so it may be subject to Cursor's Terms of
> Service and can break without notice. It is **not** signed by a registered
> Apple developer or notarized, so macOS will warn on first launch (see
> [Install](#install)). Please don't share it outside the company. See
> [`LICENSE`](LICENSE).

## What it is

- A **menu bar** app (SwiftUI + AppKit) that shows a compact summary in the
  status bar and a richer dropdown panel on click.
- A personal tool for a single user, running on one Mac. Not multi-user, not
  App Store software (at least not initially).
- Data is pulled from the **Cursor dashboard API** — your own usage, no team
  admin key required. Auth is **zero-config**: it reads the signed-in Cursor
  app's token from its local database. Nothing to paste, nothing to configure.

## What it tracks (v1)

- **Tokens** — input / output / cache, over time.
- **Model usage patterns** — which models you use and how much.
- **Cost / spend** — on-demand spend this billing cycle and burn rate.
- **Activity** — requests, background-agent requests, cache-read share, average
  spend per request, and busiest day.

It's a **passive monitor**: no notifications, no widget, no main window. Editor
productivity metrics (lines of code / Tab accepts) are not available from the
cookie data — see the [roadmap](docs/05-roadmap.md) for why.

## Documentation

| Doc | Purpose |
| --- | --- |
| [`docs/00-overview.md`](docs/00-overview.md) | Vision, goals, glossary, key assumptions & risks |
| [`docs/01-product-spec.md`](docs/01-product-spec.md) | Product requirements, personas, user stories |
| [`docs/02-architecture.md`](docs/02-architecture.md) | Technical design, components, module layout |
| [`docs/03-data-and-api.md`](docs/03-data-and-api.md) | Dashboard API integration + local data model |
| [`docs/04-ui-spec.md`](docs/04-ui-spec.md) | Menu bar UX, panel layout |
| [`docs/05-roadmap.md`](docs/05-roadmap.md) | Phased delivery plan + open questions |

## Install

Requires **macOS 14 (Sonoma) or later**. Runs on **Apple Silicon** Macs (and on
Intel too, when the build was produced with full Xcode — see
[Build from source](#build-from-source-developers)). You do **not** need Xcode to
*run* it.

1. **Get the app.** Grab `Billed.zip` from whoever shared it with you,
   double-click to unzip, and move `Billed.app` to `/Applications`.
2. **First launch (clears Apple's warning).** Because the app isn't notarized,
   macOS blocks it the first time. **Right-click the app → Open**, then click
   **Open** in the dialog. You only need to do this once.
   - On recent macOS, if there's no "Open" button, go to
     **System Settings → Privacy & Security**, scroll down, and click
     **"Open Anyway"**.
   - Command-line alternative:
     ```bash
      xattr -dr com.apple.quarantine /Applications/Billed.app
      open /Applications/Billed.app
     ```
3. **Done.** A small icon appears in your menu bar. If you're signed into the
   Cursor app, there's nothing to configure — it reads your login automatically.
   Open **Settings → Launch at login** if you want it to start with your Mac.

> [!NOTE]
> The app has no Dock icon or main window — it lives entirely in the menu bar.
> Click the menu bar item to see the panel; the gear opens Settings.

## Build from source (developers)

Requires the **Swift toolchain** (full **Xcode** is needed for `swift test`).

```bash
make run      # quit old instance, rebuild, open (usual workflow)
make build    # build the release .app bundle (universal if full Xcode)
make open     # build (if needed) and open
make zip      # build + zip the .app for sharing with a teammate
make kill     # quit a running instance
```

Or manually:

```bash
./scripts/build-app.sh
open .build/Billed.app
```

**Note:** Rebuilding does not update an already-running instance — `make run`
handles that by quitting first.

```bash
swift build --product Billed    # debug binary only (shows in Dock)
swift test                               # requires Xcode for XCTest
```

## Troubleshooting

- **"App is damaged / can't be opened" or "unidentified developer".** Expected —
  it's not notarized. Follow [Install](#install) step 2 (right-click → Open, or
  clear the quarantine flag).
- **Menu bar shows `!` / "Not connected".** Billed needs the Cursor app
   signed in on this Mac. Open Cursor, sign in, then reopen the panel and hit
   *Retry* — it reads your login automatically.
- **"Session expired".** Your login token lapsed (~2 months). Re-open Cursor and
  sign in; the app picks the fresh token up on the next refresh.
- **Numbers look stale.** Data refreshes hourly (60 min minimum). The dot next to
  the menu bar value means it's showing cached data; open the panel to refresh.

## Uninstall

```bash
# 1. Quit it
osascript -e 'quit app "Billed"' 2>/dev/null || killall Billed 2>/dev/null
# 2. Remove the app and its local cache
rm -rf /Applications/Billed.app
rm -rf ~/Library/Application\ Support/Billed
```

That's everything — the app keeps no other state on disk (it reads your Cursor
login on demand and stores no credentials). If you enabled *Launch at login*,
turn it off in the app first (or it'll be cleared automatically once the app is
gone).

## Project layout

```
Sources/BilledCore/       Domain, API client, local-auth reader, cache, metrics
Sources/BilledApp/  SwiftUI menu bar UI
Tests/BilledCoreTests/    Decoding + metrics tests (+ sanitized fixtures)
docs/                        Specifications
scripts/build-app.sh         Wraps the release binary in .app + Info.plist
```

Data comes from **unofficial dashboard endpoints** at `cursor.com`. Auth is
derived from the Cursor app's local token (`cursorAuth/accessToken` in
`state.vscdb`), read **read-only** and never persisted. See
[`docs/03-data-and-api.md`](docs/03-data-and-api.md).

**No secrets are written to the filesystem by this app.** The local token is read
fresh each refresh and held in memory only — the app stores no credentials of its
own. See [`docs/02-architecture.md`](docs/02-architecture.md#security).

Optional later: Team Admin API (`api.cursor.com`) behind the same data-source
protocol if a proper `admin:*` key is available.
