# 01 — Product Specification

## Summary

Billed is a personal macOS menu bar app that surfaces my own Cursor
usage — tokens, model mix, spend, and activity — pulled from the Cursor dashboard
endpoints (session cookie) and scoped to my account. It is a **read-only,
passive monitor**: the only surface is the menu bar; there are no notifications
and no widget.

## Scope at a glance

| Area | v1 (must) | Later (nice) |
| --- | --- | --- |
| Surfaces | Menu bar icon + dropdown panel | — (menu bar is the product) |
| Metrics | Tokens, model breakdown, cost, activity stats | Time-of-day patterns, forecasting |
| Data source | Cursor dashboard (cookie) | On-device data for LOC/Tab-accepts (investigation) |
| Config | Refresh interval, menu bar display (auth is automatic) | — |
| Notifications | — (out of scope) | — (out of scope) |

## User stories

### Must have (v1)

- **US-1 — Ambient token count.** As the user, I see a compact usage figure in
  the menu bar (e.g. today's total tokens or this-cycle spend) so I have ambient
  awareness without clicking anything.
- **US-2 — Open for detail.** When I click the menu bar icon, a panel opens
  showing today / this cycle: total tokens (split input/output/cache), spend,
  and a top-models list.
- **US-3 — Model patterns.** In the panel I can see which models I've used most
  (by tokens, by request count, and by cost) over a selectable range
  (today / 7d / 30d / cycle).
- **US-4 — Token breakdown.** I can see the split between input, output, cache
  write, and cache read tokens, because cache behavior materially affects cost.
- **US-5 — Spend & cycle.** I can see on-demand spend for the current billing
  cycle and how far through the cycle I am (with a simple projected end-of-cycle
  figure).
- **US-6 — Trend over time.** I can see a small chart of daily usage (tokens
  and/or spend) for the last N days.
- **US-7 — First-run setup.** On first launch, if I'm already signed into the
  Cursor app Billed connects automatically with nothing to configure. If
  I'm not, it tells me to sign into Cursor and offers a *Retry* button.
- **US-8 — Manual refresh.** I can force a refresh, and I can see when data was
  last updated and whether the last fetch succeeded.
- **US-9 — Launch at login.** I can opt to have the app start automatically when
  I log in.
- **US-10 — Quit / settings.** The panel gives me access to settings and quit.

- **US-11 — Activity stats.** In the panel I can see request counts, how many
  were background-agent (headless) requests, my cache-read share, average spend
  per request, and my busiest day — derived from the same usage events.

### Should have (post-v1)

- **US-12 — Editor productivity metrics (investigation).** If reachable, show
  lines of code accepted / Tab acceptances. Not available from the cookie data;
  pending an on-device data spike (see roadmap).

### Out of scope

- ~~Desktop / Notification Center widget~~ — dropped; the menu bar is enough.
- ~~Spend / anomaly notifications~~ — dropped; this is a passive monitor.
- ~~Full main window with history/heatmap/export~~ — not needed for a glance tool.

### Could have (later)

- Time-of-day / day-of-week heatmap of activity.
- Acceptance metrics (lines added/accepted, tabs shown/accepted) — already in
  `/teams/daily-usage-data`.
- Export to CSV / JSON.
- Multiple saved identities or API keys.

## Functional requirements

- **FR-1** The app MUST run as a menu bar (status bar) item with no Dock icon by
  default (`LSUIElement`-style accessory app).
- **FR-2** The app MUST NOT persist any credential. The Cursor app's local token
  is read read-only on demand, held in memory only, and never written to logs,
  UserDefaults, plist files, the cache, or the Keychain.
- **FR-3** The app MUST show only the authenticated user's usage (token-scoped;
  no team-wide data in v1).
- **FR-4** The app MUST poll the Cursor API no more than once per hour by default
  for automatic refreshes, honoring documented rate limits.
- **FR-5** The app MUST cache the most recent successful data locally so the menu
  bar shows last-known values when offline or rate-limited, with a clear
  "as of <time>" indicator.
- **FR-6** The app MUST degrade gracefully on API/auth errors: show a clear
  status, never crash, and offer a retry.
- **FR-7** The app SHOULD support a configurable "primary metric" shown in the
  menu bar (e.g. tokens today vs spend this cycle).
- **FR-8** The app SHOULD support light/dark mode and look native in both.

## Non-functional requirements

- **NFR-1 — Performance.** Idle CPU ~0%; memory footprint small (target < 100 MB).
  No busy-polling; use timers/scheduling.
- **NFR-2 — Battery.** Network activity batched to the hourly poll; no background
  work when the panel is closed beyond the scheduled refresh.
- **NFR-3 — Privacy.** All data stays on-device. No third-party analytics, no
  telemetry. The only network calls are to `api.cursor.com` (and, if a fallback
  is ever enabled, `cursor.com`).
- **NFR-4 — Resilience.** Network failures, throttling, and partial data must be
  handled without data loss of the local cache.
- **NFR-5 — Maintainability.** Networking, data, and UI cleanly separated so the
  data source can be swapped (e.g. fallback) behind a protocol.

## Success criteria

- I stop opening the Cursor dashboard in a browser to check usage.
- The menu bar number is something I actually glance at and trust.
- Setup takes under two minutes from first launch.

## Out of scope (restated)

Team management, spend-limit editing, multi-user views, non-macOS platforms, and
public distribution are all out of scope for the foreseeable roadmap.
