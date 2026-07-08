# 00 — Overview, Vision & Assumptions

## Vision

A lightweight, always-available window into my own Cursor usage. Instead of
opening a browser and navigating the Cursor dashboard, I glance at my menu bar
and immediately see how many tokens I've burned, which models I'm leaning on,
and how my spend is tracking against the billing cycle.

The app should feel like a native macOS citizen: fast, quiet, low memory,
respectful of battery, and visually at home next to the system status items.

## Goals

1. **At-a-glance awareness** — a compact metric always visible in the menu bar.
2. **Pattern insight** — understand *how* I use Cursor: model mix, token split
   (input vs output vs cache), time-of-day / day-of-week patterns.
3. **Cost control** — see on-demand spend for the current billing cycle and a
   simple burn-rate / projection.
4. **Zero friction** — reuse the signed-in Cursor app's token automatically; no
   setup, no cookie paste at all.

## Non-goals (v1)

- Multi-user / team dashboards. This is a *personal* tool; team-wide views are
  out of scope even though the underlying API is team-scoped.
- Editing Cursor settings, spend limits, or managing team members (the Admin API
  supports some of this; we deliberately stay read-only).
- Historical backfill beyond what the API exposes, or acting as a long-term data
  warehouse (though we do cache locally — see [data spec](03-data-and-api.md)).
- App Store distribution, notarized public release, auto-update infrastructure.
- Windows / Linux / web. macOS only.

## Target platform

- **macOS 14 (Sonoma) or later** assumed, to use modern SwiftUI, Swift Charts and
  `MenuBarExtra`. (Confirm minimum target — see open questions.)
- Apple Silicon first; Intel support is free via universal binary if desired.

## Personas

There is exactly one persona: **me, the owner-operator**. A developer who uses
Cursor daily and wants ambient awareness of usage without context-switching to a
browser — ideally with no setup at all.

## Glossary

| Term | Meaning |
| --- | --- |
| **Usage event** | A single billable/loggable Cursor request. Exposed via `/api/dashboard/get-filtered-usage-events` (cookie auth). |
| **Token usage** | `inputTokens`, `outputTokens`, `cacheWriteTokens`, `cacheReadTokens` on token-based events. |
| **Spend / cost** | `chargedCents` per event (authoritative). Cycle quota from `/api/usage-summary`. |
| **Included vs usage-based** | `kind` enum string, e.g. `USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS`. |
| **Billing cycle** | `billingCycleStart` / `billingCycleEnd` from `/api/usage-summary`. |
| **Session cookie** | `WorkosCursorSessionToken` (`<userId>::<jwt>`) — dashboard auth credential, derived from the Cursor app's local token. Sent on each request; never stored by this app. |
| **Local app token** | `cursorAuth/accessToken` JWT in Cursor's `state.vscdb`; read read-only to build the cookie with no user setup. The only auth source. |

## Key assumptions

1. **Confirmed (Phase 0):** the **dashboard cookie** source works for my account.
   `/api/usage-summary` and `/api/dashboard/get-filtered-usage-events` return
   billing-cycle info and per-event tokens/models/cost. This is the **primary**
   v1 data source.
2. **Confirmed (2026-06-15):** the cookie can be derived from the locally
   signed-in Cursor app (`cursorAuth/accessToken` in `state.vscdb`, built as
   `userId::jwt`). This is the **primary, zero-config** auth path; a manually
   user signs into the Cursor app on this Mac (there is no manual-cookie fallback).
3. The dashboard endpoints remain stable enough for a personal tool (unofficial,
   but validated 2026-06-15).
4. Polling **at most once per hour** is acceptable freshness.

## Risks & mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| **Dashboard endpoints are unofficial.** | Can break on any dashboard deploy. | Defensive decoding; fixtures + unit tests; optional Admin API fallback behind `UsageDataSource`; graceful "data unavailable" states. |
| **Token expires** (JWT `exp`, ~2 months). | 401 until re-auth. | Local token refreshes itself while the Cursor app stays signed in; on 401 fall back / prompt; show cached data with stale indicator. |
| **Auth token is a secret.** | Account takeover if leaked. | Local token read read-only and **never persisted** (held in memory only; never UserDefaults, plists, cache, logs, or Keychain). The app stores no credentials of its own. See [architecture security](02-architecture.md#security). |
| **Local DB shape changes** (key names / path). | Zero-config auth breaks. | Show "not connected" and prompt the user to re-sign-in to Cursor; keys validated 2026-06-15 (`cursorAuth/accessToken`). |
| **Undocumented response shapes** (e.g. `usageEventsDisplay` not `usageEvents`). | Zero events parsed, wrong UI. | **Resolved in Phase 0:** decode multiple array keys; fixtures in `Tests/BilledCoreTests/Fixtures/`. |
| Rate limits unknown. | Throttling. | Poll ≤ 1×/hour; backoff; manual refresh debounced. |
| API schema drift / fields removed. | Crashes or wrong numbers. | Optional fields; degrade per-metric. |
| Token-based vs request-based billing. | Cost math wrong. | Sum `chargedCents`; treat `tokenUsage` as optional. |

## Spec-driven workflow

1. Change the relevant doc in `docs/` first.
2. Get the spec to a state you'd be happy to implement against.
3. Only then write code, referencing the spec section in the PR/commit.
4. Keep [`05-roadmap.md`](05-roadmap.md) open questions current.
