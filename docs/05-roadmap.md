# 05 — Roadmap & Open Questions

## Guiding principle

De-risk the data source first. Everything else (UI polish, extra stats) is
worthless if we can't reliably read my usage. So Phase 0 is a spike, not UI.

## Phase 0 — Feasibility spike (data source) ✅

**Goal:** prove we can read *my* tokens / models / spend.

- [x] Cookie source validated.
- [x] `GET /api/usage-summary` — billing cycle, team pooled quota, membership.
- [x] `POST /api/dashboard/get-filtered-usage-events` — 90 events / 7 days;
      array key is **`usageEventsDisplay`** (not `usageEvents`).
- [x] Token/model/cost roll-ups match expectations (~164.5M tokens, ~$191, 5 models).
- [x] Sanitized fixtures captured in `Tests/BilledCoreTests/Fixtures/`.
- [ ] Admin API spike (`cursor_api_spike.swift`) — deferred; needs Team Admin key
      (personal `crsr_` key returns 401).

**Exit criteria met:** 2026-06-15.

## Phase 1 — Menu bar MVP ✅ (initial)

**Goal:** the thing I actually wanted — a glanceable menu bar number + panel.

- [x] `BilledCore`: models, `DashboardClient`, `LocalAuthReader`,
      JSON cache, `MetricsCalculator`.
- [x] `MenuBarExtra` app shell (via `scripts/build-app.sh` + `LSUIElement`).
- [x] Zero-config auth from the local Cursor app (sole auth source).
- [x] Panel: headline tokens + spend, token split, top models, range selector.
- [x] Hourly refresh + manual refresh + last-updated + cached/error states.
- [x] Launch at login (`SMAppService`).
- [x] Unit tests for metrics + fixture decoding (run with full Xcode).

 **Exit criteria:** build and run locally — `./scripts/build-app.sh && open .build/Billed.app`

## Phase 2 — Trends & polish ✅

- [x] Daily trend chart (Swift Charts) with tokens/cost toggle.
- [x] Configurable primary metric; spend projection for cycle (Phase 1, retained).
- [x] Visual polish: side-by-side metric cards, team pool banner, membership label.
- [x] Accessibility: VoiceOver labels on metrics, chart, menu bar, model rows.
- [ ] SQLite cache — **deferred**; JSON is sufficient at current event volume (~90/7d).

## Phase 3 — Richer read-only stats

This is a **read-only monitor** — no alerts, no widget. The focus is showing more
of *my* activity at a glance, derived from the cookie data we already have.

- [x] Derived activity stats in the panel: total requests, background-agent
      (headless) requests, cache-read share, busiest day, average spend per
      request.
- [x] Time-of-day heatmap: requests bucketed by local hour of day.
- [x] Per-model cost efficiency ($ / Mtok) as a model sort + row detail.
- [ ] SQLite cache — **deferred**; JSON is sufficient at current volume (~90/7d).

## Editor productivity metrics (lines of code / Tab accepts) — investigation

These are the stats the tool would ideally show, but they are **not** in the
cookie data (which is tokens/requests/models/cost only). Two possible sources:

1. **Enterprise Analytics API** (`api.cursor.com/analytics/by-user/*`) — exposes
   `total_lines_accepted`, `total_accepts`, agent edits, etc. **Requires a team
   Analytics API key** (Enterprise). Not available with a personal cookie.
2. **On-device data** — Cursor computes line counts locally; they may live in the
   local app state (`~/Library/Application Support/Cursor`). Needs a discovery
   spike to confirm a stable, readable shape.

**Decision needed** (see open questions) before building either.

## Dropped from scope

- ~~Desktop / Notification Center widget~~ — removed; menu bar is enough.
- ~~Spend-threshold / anomaly notifications~~ — removed; this is a passive monitor.
- ~~Full main window with history/heatmap/export~~ — not needed for a glance tool.

## Open questions

These are the decisions I'd like to lock before/early in implementation:

1. ~~**Data source?**~~ — **Resolved: dashboard cookie (Phase 0 validated).**
2. **Default primary metric** for the menu bar: tokens today vs spend this cycle?
   (Spec currently assumes **tokens today**.)
3. **Minimum macOS version** — 14 (Sonoma)? 13 (Ventura)? Affects `MenuBarExtra`
   and Swift Charts APIs. (Spec assumes **14**.)
4. **Cache format** — start with JSON and migrate to SQLite later, or SQLite from
   the start? (Spec assumes **JSON for MVP**.)
5. **Cost display** — show `chargedCents` (matches dashboard) as the cost number
   everywhere? **Resolved in Phase 0: yes, `chargedCents` is authoritative.**
6. **Retention window** — 90 days of events locally? More/less?
7. **Editor productivity metrics** — is it worth pursuing LOC/Tab-accept stats via
   the on-device data spike, given they're unavailable from the cookie? Or stay
   with the cookie-derived token/request/cost stats only?
8. **Repo/project name** — keep `cursor-mac-companion` / "Cursor Companion" (now
   renamed to "Billed"), or something else (and is "Cursor" in the name a
   trademark concern if ever shared)?

## Decision log

Record decisions here as they're made (date — decision — rationale).

- **2026-06-15 — Dashboard cookie is the primary (v1) data source.** Phase 0
  validation confirmed `/api/usage-summary` and `/api/dashboard/get-filtered-usage-events`.
  Events array key is `usageEventsDisplay`. Fixtures in `Tests/BilledCoreTests/Fixtures/`.
- **2026-06-15 — Session cookie stored in macOS Keychain only, never on the
  filesystem.** Service `dev.billed.sessionCookie`. Hidden input on paste.
- **2026-06-15 — Admin API deferred.** Personal `crsr_` user keys do not work on
  `/teams/*` (401). Team Admin key remains optional fallback.
- **2026-06-15 — Phase 2 shipped.** Daily Swift Charts trend (tokens/cost toggle),
  UI polish, accessibility labels. SQLite cache deferred at current volume.
- **2026-06-15 — Menu bar display split into two prefs.** `MenuBarUnit`
  (tokens/dollars) × `MenuBarPeriod` (today/cycle), default dollars + cycle.
- **2026-06-15 — Pivoted to a read-only monitor.** Removed the spend-threshold
  alerts (built then reverted) and dropped the WidgetKit widget from scope. The
  app stays a passive glance tool. The throwaway Phase 0 spike scripts have since
  been removed; the sanitized fixtures they produced now live in the test target.
- **2026-06-15 — Zero-config auth from the local Cursor app.** Read
  `cursorAuth/accessToken` from `state.vscdb` (read-only) and build the cookie as
  `userId::jwt` (userId = JWT `sub` minus `auth0|`). Verified: raw JWT → 401,
  `userId::jwt` → 200. Manual cookie paste demoted to a fallback. Token is read
  fresh each refresh and never persisted.
- **2026-06-15 — Removed the manual-cookie fallback entirely.** Zero-config auth
  from the signed-in Cursor app proved reliable, so the paste-a-cookie path,
  `KeychainStore`, and the sign-out/clear-session flow were deleted. The app now
  stores **no credentials of its own**; when the Cursor app isn't signed in it
  simply shows "not connected" and prompts the user to sign in. Supersedes the
  earlier "session cookie in Keychain" decision below.
- **2026-06-15 — LOC/Tab-accept metrics are not reachable via the cookie.** They
  require the Enterprise Analytics API (team key) or an on-device data spike.
  Parked pending decision; enriched the panel instead with cookie-derived stats:
  activity tiles (requests/agents/avg-cost/cache-share/busiest-day), a time-of-day
  heatmap, and per-model cost efficiency ($/Mtok).
