# 03 — Data Model & Cursor API Integration

This is the most important technical document: it defines exactly where data
comes from, how it maps into the app, and how it's cached.

**Phase 0 validated (2026-06-15):** the dashboard cookie source works for this
account. Sanitized fixtures live in
[`Tests/BilledCoreTests/Fixtures/`](../Tests/BilledCoreTests/Fixtures/).

---

## Data source (v1): Cursor dashboard endpoints

- Base URL: `https://cursor.com`
- Auth: **`WorkosCursorSessionToken` cookie** (`<userId>::<jwt>`). Sent as
  `Cookie: WorkosCursorSessionToken=<value>`.
- Also send `Origin: https://cursor.com` and
  `Referer: https://cursor.com/dashboard/usage`.
- **Unofficial** — reverse-engineered from the dashboard UI; may change without
  notice. See [risks](00-overview.md#risks--mitigations).
- **Scope:** returns *my* usage automatically (no team-wide filter needed).

### Auth source (validated 2026-06-15)

**Local Cursor app token (zero-config) — the only auth path.** The signed-in
Cursor IDE stores its auth token locally; we read it directly so the user never
pastes anything. There is no manual-cookie fallback.

- File: `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
  (SQLite). Opened **read-only + `immutable=1`** so we never lock/mutate it.
- Table `ItemTable` (key/value). Keys we read:
  - `cursorAuth/accessToken` — a JWT. Its `sub` is `auth0|user_xxx`.
  - `cursorAuth/cachedEmail`, `cursorAuth/stripeMembershipType` — for display.
- Build the cookie as **`<userId>::<jwt>`** where `userId` = `sub` minus the
  `auth0|` prefix. Confirmed: raw JWT alone → `401`; `userId::jwt` → `200`.
- The JWT `exp` gives expiry (~2 months); when expired we prompt the user to
  re-sign-in to the Cursor app.
- The token is read **fresh on each refresh** and is **never persisted** by us.

If the Cursor app isn't installed or signed in, the app reports "not connected"
and asks the user to sign into Cursor; it does not accept a pasted credential.

### Endpoints we use

| Endpoint | Method | Why we use it |
| --- | --- | --- |
| `/api/usage-summary` | GET | Billing cycle window, plan/membership type, included vs on-demand counters, team pooled quota. |
| `/api/dashboard/get-filtered-usage-events` | POST | Core data: per-event model + token usage + cost. Already scoped to the authenticated user. |

Optional later: `GET /api/auth/me` for display name/email in the panel header.

---

## Endpoint details (validated in Phase 0)

### `GET /api/usage-summary`

No request body. Response (observed for an enterprise team account):

| Field | Type | Use |
| --- | --- | --- |
| `billingCycleStart` | ISO 8601 string | Cycle start for range selector / projection. |
| `billingCycleEnd` | ISO 8601 string | Cycle end / reset date. |
| `membershipType` | string | e.g. `"enterprise"`. |
| `limitType` | string | e.g. `"team"` (pooled team quota vs individual). |
| `isUnlimited` | bool | Plan flag. |
| `individualUsage.overall.used` | number | Individual included-usage counter (units TBD — not tokens). |
| `teamUsage.pooled.used` / `.limit` / `.remaining` | number | Team pooled quota (observed: limit `36000000`). |
| `teamUsage.onDemand.used` | number | On-demand spend counter this cycle. |
| `autoModelSelectedDisplayMessage` | string | Human-readable included-usage hint. |
| `namedModelSelectedDisplayMessage` | string | Human-readable API-usage hint. |

Maps to internal `UsageSummarySnapshot` (cycle dates + quota/spend counters).

### `POST /api/dashboard/get-filtered-usage-events`

Request body (date fields are **strings** of epoch milliseconds):

```json
{
  "startDate": "1780919582153",
  "endDate": "1781519582153",
  "page": 1,
  "pageSize": 100
}
```

- Omit `teamId` / `userId` for personal usage (defaults to authenticated user).
- Paginate with `page` (1-based) and `pageSize`. Response includes
  `totalUsageEventsCount`; continue while collected count < total.
- **Important:** events array key is **`usageEventsDisplay`**, not
  `usageEvents` (Admin API uses `usageEvents`). Decoder must accept both.

Response top-level keys (observed):

- `totalUsageEventsCount` — int
- `usageEventsDisplay` — array of event objects

Per-event fields (observed):

| Field | Type | Use |
| --- | --- | --- |
| `timestamp` | string (epoch ms) | Bucketing by day/hour, ordering. |
| `model` | string | Model breakdown (e.g. `claude-opus-4-8-thinking-high`). |
| `kind` | string | Billing category enum, e.g. `USAGE_EVENT_KIND_INCLUDED_IN_BUSINESS`. Map to friendly labels in UI. |
| `isTokenBasedCall` | bool | Whether `tokenUsage` is present. |
| `isChargeable` | bool | Whether this event incurs charge. |
| `isHeadless` | bool | Background-agent requests. |
| `tokenUsage.inputTokens` | number | Token totals. |
| `tokenUsage.outputTokens` | number | Token totals. |
| `tokenUsage.cacheWriteTokens` | number | Token totals. |
| `tokenUsage.cacheReadTokens` | number | Token totals (often dominates total count). |
| `tokenUsage.totalCents` | number | Model cost (pre Cursor token fee). |
| `chargedCents` | number | **Authoritative charge** (model + Cursor token fee). Sum this for cost roll-ups. |
| `cursorTokenFee` | number? | Cursor Token Rate component. |
| `requestsCosts` | number | Request-unit cost (legacy/request-based plans). |
| `usageBasedCosts` | string | Display hint (e.g. `"-"` when not usage-based). |
| `owningUser` | string | Numeric user ID (sanitized in fixtures). |
| `owningTeam` | string | Numeric team ID. |
| `serviceAccountId` | string | Service account or `"null"` string literal. |

**Nuances (confirmed in spike):**

- `tokenUsage` absent when `isTokenBasedCall == false` — decode optional.
- Cost roll-ups sum **`chargedCents`**, not `tokenUsage.totalCents`.
- Cache read tokens are huge and cheap — show split distinctly in UI.
- `kind` uses protobuf-style enum strings; normalize for display.

**Phase 0 sample (7 days, 90 events):** ~164.5M tokens, ~$191.42 charged;
top model `claude-opus-4-8-thinking-high` (53 reqs, ~132.5M tokens, ~$149).

---

## Fallback: Cursor Admin API (optional, not v1)

If a proper **Team Admin** key (`admin:*` scope from Team Settings — *not* the
personal `crsr_` Cloud Agents key) becomes available, implement
`CursorAdminAPIClient` behind the same `UsageDataSource` protocol.

- Base URL: `https://api.cursor.com`
- Auth: HTTP Basic, API key as username, empty password.
- Endpoints: `/teams/filtered-usage-events`, `/teams/spend`, `/teams/members`,
  `/teams/daily-usage-data`.
- Team-scoped: must filter by configured email/userId.
- Rate limit: 20 req/min; poll ≤ 1×/hour.

Wire shapes are similar but differ in details (`usageEvents` vs
`usageEventsDisplay`, `kind` string format, date params as numbers not strings).
See git history of this doc or Cursor's [Admin API docs](https://cursor.com/docs/account/teams/admin-api).

---

## App data model

Wire-agnostic internal types (UI depends on these only):

```swift
struct UsageEvent {
    let timestamp: Date
    let model: String
    let kind: BillingKind            // .includedInSubscription / .usageBased / .other(String)
    let isTokenBased: Bool
    let isHeadless: Bool
    let tokens: TokenUsage?          // nil when !isTokenBased
    let chargedCents: Double         // authoritative cost
    let cursorTokenFee: Double?
}

struct TokenUsage {
    let input: Int
    let output: Int
    let cacheWrite: Int
    let cacheRead: Int
    var total: Int { input + output + cacheWrite + cacheRead }
}

struct UsageSummarySnapshot {
    let cycleStart: Date
    let cycleEnd: Date
    let membershipType: String?
    let limitType: String?           // "team" | "individual" | …
    let teamPooledUsed: Int?
    let teamPooledLimit: Int?
    let teamPooledRemaining: Int?
    let onDemandUsed: Double?        // from teamUsage.onDemand.used
    let individualOverallUsed: Int?
}

struct DailyAggregate {              // derived from events
    let day: Date
    let tokens: TokenUsage
    let chargedCents: Double
    let eventCount: Int
    let byModel: [String: ModelRollup]
}

struct ModelRollup {
    let model: String
    let tokens: TokenUsage
    let chargedCents: Double
    let requestCount: Int
}
```

### Derived metrics

- **Tokens today / 7d / 30d / cycle** — sum `tokens` over events in range.
- **Model breakdown** — group by `model`; sort by tokens / cost / count.
- **Spend this cycle** — sum `chargedCents` over cycle-range events *or*
  `teamUsage.onDemand.used` from summary (confirm units match dashboard).
- **Burn rate / projection** — linear extrapolation from cycle elapsed days.
- **Token split** — input / output / cacheWrite / cacheRead percentages.
- **Daily trend** — bucket events by local calendar day → `DailyAggregate`.

---

## Caching & persistence

- **Store:** Application Support dir; JSON for MVP (SQLite later if needed).
- **Cache:** `UsageEvent`s (rolling ~90 days), latest `UsageSummarySnapshot`,
  computed `DailyAggregate`s, fetch metadata (`lastSuccessfulFetch`).
- **Incremental fetch:** track max `timestamp`; request `[last+1ms, now]`, merge.
- **Never cached:** the local-app token — read fresh each refresh, held in memory
  only.

## Refresh strategy

- **Automatic:** every 60 minutes (configurable). Coalesce on wake from sleep.
- **Manual:** refresh button, debounced.
- **Backoff:** on 401 (expired cookie), 429, 5xx — show cached data + reason.
- **Cycle rollover:** detect when `billingCycleStart` changes.

## Error handling matrix

| Condition | Behavior |
| --- | --- |
| 401 / `not_authenticated` | "Session expired — sign in to the Cursor app again"; keep cache. |
| 429 / 5xx / network | Backoff; show cached data with timestamp. |
| Empty range | Zero-states, not errors. |
| Schema drift | Optional decoding; degrade affected metric only. |
| Wrong events array key | Try `usageEventsDisplay`, then `usageEvents`, then `events`. |

## Test fixtures

Sanitized samples from Phase 0 (no PII):

- `Tests/BilledCoreTests/Fixtures/usage-summary.sample.json`
- `Tests/BilledCoreTests/Fixtures/get-filtered-usage-events.sample.json`

These back the decoding/rollup unit tests.
