# 02 — Architecture & Technical Design

## Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI, with AppKit where needed for menu bar behavior.
- **Menu bar:** `MenuBarExtra` (SwiftUI, macOS 13+) using the `.window` style for
  a rich custom panel. Fall back to `NSStatusItem` + `NSPopover` if we need finer
  control (e.g. custom dynamic title rendering).
- **Charts:** Swift Charts (`import Charts`).
- **Persistence:** local cache (JSON for MVP, SQLite/GRDB if event volume
  warrants). Decision tracked in [open questions](05-roadmap.md#open-questions).
- **Secrets:** none stored. Auth is the Cursor app's own local token, read
  read-only on demand and held in memory only.
- **Concurrency:** Swift Concurrency (`async/await`, actors for the data store).
- **Build:** Xcode project; Swift Package Manager for any dependencies.
- **Min target:** macOS 14 (assumed; confirm in open questions).

### Why native Swift (not Electron/Tauri)

Menu bar ergonomics, secure local-state access, low memory/battery, and native
look are all first-class in Swift and awkward-to-impossible elsewhere.

## High-level architecture

Layered, with a one-way dependency flow (UI → domain → data). The data source
sits behind a protocol so the dashboard client can be swapped for Admin API later.

```
┌─────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI)                                   │
│  MenuBarExtra label · Panel views · Settings             │
└───────────────▲─────────────────────────────────────────┘
                │ observes
┌───────────────┴─────────────────────────────────────────┐
│ Domain / ViewModels                                      │
│  UsageStore (actor) · MetricsCalculator · RefreshScheduler│
└───────────────▲─────────────────────────────────────────┘
                │ uses
┌───────────────┴─────────────────────────────────────────┐
│ Data                                                     │
│  UsageDataSource (protocol)                              │
│   └─ CursorDashboardClient  (cookie auth, v1 primary)    │
│  Auth: LocalAuthReader (Cursor app token, read-only)     │
│  LocalCache (JSON)                                       │
└──────────────────────────────────────────────────────────┘
```

## Modules / targets

| Module | Kind | Responsibility |
| --- | --- | --- |
| `BilledApp` | App target | App lifecycle, `MenuBarExtra`, settings, wiring. |
| `BilledCore` | Swift package/framework | Domain models, data sources, cache, metrics. |
| `CompanionUI` | (optional) package | Reusable SwiftUI views (panel rows, charts, badges). |

Keeping domain + data in `BilledCore` keeps networking/parsing testable and
separate from the UI.

## Key components

### `UsageDataSource` (protocol)

```swift
protocol UsageDataSource {
    func usageSummary() async throws -> UsageSummarySnapshot
    func usageEvents(since: Date, until: Date) async throws -> [UsageEvent]
}
```

`CursorDashboardClient` is the v1 implementation (cookie auth to
`cursor.com`). `CursorAdminAPIClient` is optional later. Both map wire DTOs →
the same domain models.

### `CursorDashboardClient`

- Sends `Cookie: WorkosCursorSessionToken=…` plus `Origin` / `Referer`.
- `GET /api/usage-summary` → `UsageSummarySnapshot`.
- `POST /api/dashboard/get-filtered-usage-events` with string epoch-ms dates;
  paginates; reads events from **`usageEventsDisplay`** (fallback keys:
  `usageEvents`, `events`).
- Maps `kind` enum strings to `BillingKind`; optional `tokenUsage`.
- Surfaces typed errors (`.sessionExpired`, `.rateLimited`, `.transport`, `.decoding`).

### `CursorAdminAPIClient` (optional)

- Builds Basic-auth requests to `api.cursor.com`. Team-scoped; filter by identity.
- Not used in v1 (personal `crsr_` keys do **not** work here — need Team Admin key).

### `UsageStore` (actor)

- Single source of truth for cached domain data.
- Merges incremental fetches, prunes retention window, recomputes aggregates.
- Publishes snapshots the UI observes (`@Observable` / `ObservableObject`).

### `RefreshScheduler`

- Hourly timer + manual trigger; coalesces on wake/sleep.
- Enforces minimum interval and backoff; never exceeds rate limits.

### `MetricsCalculator`

- Pure functions: range sums, model roll-ups, token splits, burn-rate projection.
- Easy to unit-test in isolation.

### `LocalAuthReader`

- Reads the Cursor app's token from `state.vscdb` (read-only, `immutable=1`) via
  the system `SQLite3` library; decodes the JWT to build the `userId::jwt` cookie
  and surface email / membership / expiry. Read into memory at request time only;
  **never persisted**.

## Security

- **The app stores no credentials.** Auth is the Cursor app's own local token,
  read read-only from `state.vscdb` on each refresh and held in memory only. It
  MUST NOT be written to UserDefaults, plists, App Group prefs, the JSON/SQLite
  cache, environment files, or logs. There is no app-managed cookie, Keychain
  item, or other secret on disk.
  - **No fallback paste flow.** If the Cursor app isn't signed in, the app simply
    reports "not connected" and prompts the user to sign into Cursor — it never
    accepts or stores a pasted credential.
  - Optional **Team Admin API key** (if ever enabled) would be a separate concern
    and would use the macOS Keychain (`dev.billed.adminApiKey`,
    `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- **Network egress** limited to `cursor.com` (v1). Optional `api.cursor.com` if
  Admin API is enabled later. HTTPS only (ATS defaults).
- **No telemetry / analytics.** Zero third-party SDKs that phone home.
- **Other users' data** dropped at ingestion; never persisted.
- **At-rest cache** contains only my own usage; acceptable in the app container,
  but avoid storing more than the retention window.

## App lifecycle & packaging

- Accessory app (`LSUIElement` / `.accessory` activation policy): menu bar only,
  no Dock icon.
- Launch-at-login via `SMAppService` (ServiceManagement).
- Sandboxed if practical; entitlement: outgoing network. Reading Cursor's
  `state.vscdb` needs read access to `~/Library/Application Support/Cursor` —
  trivial for the unsigned/non-sandboxed v1 build; a future sandboxed build would
  need a security-scoped bookmark (there is no longer a cookie fallback to drop
  to). Personal/unsigned local build is fine for v1; notarization is out of scope.

## Testing strategy

- **Unit:** `MetricsCalculator`, DTO decoding (incl. missing `tokenUsage`),
  cache merge/prune, identity filtering.
- **Contract:** record sample API responses (sanitized) as fixtures; decode them
  in tests so schema drift is caught.
- **Integration (manual):** a debug mode that hits the real API with a test key
  and prints normalized output.
- **UI:** light snapshot/preview coverage of panel states (loading, empty, error,
  populated).

## Error & state model (UI-facing)

A single observable `AppState` enum-ish surface drives the UI:
`needsSetup` · `loading` · `loaded(asOf:Date)` · `staleCached(asOf:Date, reason)`
· `error(kind)`. See [UI spec](04-ui-spec.md) for how each renders.
