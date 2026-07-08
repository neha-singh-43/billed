# 04 — UI / UX Specification

## Surfaces

1. **Menu bar item** — always visible; compact primary metric. (v1)
2. **Dropdown panel** — opens on click; the main UI. (v1)
3. **Settings** — first-run + ongoing config. (v1)

This is a read-only monitor: the menu bar is the only surface. A desktop widget
and a full main window were considered and **dropped** (see roadmap).

## Menu bar item

- Shows an icon + a short dynamic value, e.g. a small glyph plus the **primary
  metric**. Default primary metric: **tokens today** (configurable to
  **spend this cycle**).
- Compact formatting: `1.2M`, `847K`, `$12.40`. Width kept stable to avoid
  jitter in the bar.
- States reflected subtly:
  - Normal: icon + value.
  - Stale/cached: dimmed value or a tiny dot indicator.
  - Error/needs setup: warning glyph only.
- Optional (later): color the value when spend crosses a threshold.

## Dropdown panel

Target size ~340–380 pt wide. Sections, top to bottom:

1. **Header**
   - Title / identity (my email, truncated).
   - Range selector segmented control: `Today · 7D · 30D · Cycle`.
   - Last-updated text ("Updated 14m ago") + refresh button.

2. **Headline metrics (cards)**
   - **Total tokens** for the selected range, with a small input/output/cache
     split bar beneath.
   - **Spend** — on-demand this cycle, plus projected end-of-cycle (when range =
     Cycle). For other ranges, show charged cost summed from events.
   - **Requests** count (optional secondary).

3. **Token split**
   - Horizontal stacked bar: input / output / cache-write / cache-read, with a
     legend and percentages. Cache read called out as "cheap context".

4. **Model breakdown**
   - List of top models for the range. Each row: model name, a usage bar, and a
     toggle of metric (tokens / cost / requests). Sorted desc by the chosen
     metric. Show top ~5 with "show all".

5. **Trend**
   - Small Swift Charts line/bar of daily tokens (or spend) over the range.

6. **Footer**
   - Settings, Launch-at-login toggle (or in settings), Quit.

### Range semantics

- `Today` — since local midnight.
- `7D` / `30D` — rolling windows ending now.
- `Cycle` — from `subscriptionCycleStart` to now; enables the spend projection.

## States

| State | Menu bar | Panel |
| --- | --- | --- |
| `needsSetup` | warning glyph | Setup CTA: "Connect your Cursor account" → settings. |
| `loading` (first) | icon + spinner/placeholder | Skeleton cards. |
| `loaded(asOf)` | icon + value | Full data, "Updated Xm ago". |
| `staleCached(asOf, reason)` | dimmed value | Banner: "Showing cached data (rate limited / offline) as of <time>". |
| `error(kind)` | warning glyph | Inline error + retry; keep last good data if any. |
| empty range | icon + `0` | Friendly zero-state ("No usage in this range"). |

## Settings

- **Session** — read-only status: "Connected via Cursor app (email)" or "Not
  connected". No credential input — auth is read automatically from the signed-in
  Cursor app.
- **Primary metric** — tokens today / spend this cycle.
- **Refresh interval** — default 60 min (min 60).
- **Launch at login** — toggle (`SMAppService`).
- **Data** — retention window; "clear cache" button.
- **About** — version, link to docs, privacy note ("data stays on device").

## First-run flow

1. Launch → if the Cursor app is signed in, Billed connects automatically
   and the first fetch runs; panel populates. Nothing to configure.
2. If the Cursor app isn't signed in, the panel shows "Connect your Cursor
   account" with a *Retry* button; the user signs into Cursor and retries.
3. Optional: choose primary metric (default per settings) and enable
   launch-at-login.

## Visual design

- Native macOS vibrancy/material for the panel background; system fonts; SF
  Symbols for icons.
- Full light/dark support; respect system accent.
- Numbers are the hero — large, tabular figures; supporting labels muted.
- Motion minimal: subtle transitions on range change; no distracting animation.
- Accessibility: Dynamic Type-friendly where possible, VoiceOver labels on
  metrics, sufficient contrast.

## Activity stats (panel)

A grid of compact tiles below the token split, derived from the same usage
events:

- **Requests** — total, with interactive (non-headless) count as detail.
- **Background agents** — count of headless requests.
- **Avg / request** — mean charge per request.
- **Cache reads** — cache-read tokens as a share of all tokens.
- **Busiest day** — the highest-token day in the selected range.

A **time-of-day heatmap** (requests bucketed by local hour, 0–23) sits below the
daily trend. The **Models** list can be sorted by **$ / Mtok** (cost efficiency)
alongside tokens, cost, and requests.

## Dropped surfaces

A desktop / Notification Center **widget** and a full **main window** (history,
heatmap, export) were considered and dropped — this is a read-only menu bar
monitor. See [roadmap](05-roadmap.md).
