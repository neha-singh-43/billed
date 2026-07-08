# Walkthrough - Cursor Companion Menubar App

We have fully implemented and optimized the Cursor Companion application. Here is a summary of the achievements:

## Capabilities Implemented

### 1. Standalone Focus
Removed the tab switcher buttons from the footer to focus the app purely on Cursor:
*   **Branding Footer**: Replaced the workspace selection tabs (`Cursor`, `Codex`, `Antigravity`, etc.) with a clean, low-profile `"Cursor Usage"` text label aligned to the left of the footer.
*   **Code Cleanliness**: Removed all unused `WorkspaceType` definitions, states, and CSS selectors (`.workspace-tabs-container`, `.workspace-tab-btn`) from the codebase.

### 2. Active Cursor Request Detection
*   **Background Monitoring**: Configured a `8s` background polling loop in React.
*   **Request Detection**: Tracks the total event count from the API. When a new usage event occurs, it immediately triggers active mascot animation sequences.
*   **Cross-Window Tauri Events**: Utilizes Tauri's event bus (`emit` and `listen` from `@tauri-apps/api/event`) to broadcast `"cursor-agent-status"` transitions.
*   **Animation Transitions**: Mascot transitions to `running` for 3 seconds when processing, and then performs a celebratory `jumping` cycle before returning to idle.
*   **All Animation Poses Supported**: Added mapping and duration configurations for `running`, `waiting`, and `failed` rows in the React animation engine.

### 3. Zero-Config Local Authentication
*   **Database Querying**: Safely queries the SQLite database at `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` strictly in read-only and immutable mode.
*   **JWT Decoding**: Extracts `cursorAuth/accessToken` and decodes the JWT payload to retrieve the `sub` claim (user ID).
*   **Cookie Formulation**: Dynamically constructs the session cookie `WorkosCursorSessionToken` in the format `<userId>::<jwt>`.

### 4. Multi-Endpoint API Integration
*   Queries `GET https://cursor.com/api/usage-summary` with session cookies to authoritatively fetch:
    *   Billing Cycle Start/End dates
    *   Membership Type (e.g. Free, Pro)
    *   Quota limits and progress messages
*   Queries `POST https://cursor.com/api/dashboard/get-filtered-usage-events` (POST request with `startDate` and `endDate` ranges) to retrieve individual usage statistics.

### 5. Fully Standalone & Decoupled Architecture
We completely decoupled the companion app from Codex files, making it 100% self-contained:
*   **Local Asset Bundling**: Mapped and loaded all WebP mascot spritesheets directly via Vite from the project's [src/assets/sprites/](file:///Users/achuth/Developer/billed/src/assets/sprites/) folder. No file system scanning or backend base64 loading required.
*   **LocalStorage State Synchronization**: Saved active mascot state (`activeMascot`) in HTML5 `localStorage`.
*   **Cross-Window Sync**: Listening to `"storage"` events in React ensures both the main window and the floating mascot window stay instantly in sync when the user changes the mascot.
*   **Simplified Rust Backend**: Removed all `~/.codex/config.toml` read/write logic and file system scanners from Rust.

### 6. Interactive Mascot Switcher
You can now select and switch active mascots dynamically:
*   **Interactive Dropdown**: Clicking the mascot wrapper next to the settings button opens a list of default mascots (`codex`, `seedy`, `fireball`, `hoots`, `dewey`, `rocky`, `stacky`, `bsod`, `null-signal`).

### 7. Companion Mascot Window Overlay
Just like Codex's animated overlay window, your app now has:
*   **Transparent Overlay Window**: Configures a secondary window (`mascot`) via Rust in `window.rs` styled at `80x87` pixels, decoration-free, transparent, and always-on-top.
*   **Window Drag-to-Move**: Added the `data-tauri-drag-region` attribute and set `cursor: grab` on the Mascot element. This lets you drag and position the pet anywhere on your desktop.
*   **Authorized Capabilities**: Added `"mascot"` to the `"windows"` list and granted `"core:window:allow-start-dragging"` in [capabilities/default.json](file:///Users/achuth/Developer/billed/src-tauri/capabilities/default.json) so the mascot window has full permission to invoke core Tauri capabilities (like window dragging).
*   **Multi-Window React Routing**: Automatically detects the window label at startup via `@tauri-apps/api/window`. If the window label is `"mascot"`, it renders ONLY the large mascot animation (`80px` by `87px`).
*   **Interactivity**: Allows you to click the mascot on the screen to trigger random animations (`jumping`, `waving`, `review`) that play for 3 cycles before returning to idle.

### 8. Pixel-Perfect Mockup UI Recreation
We matched the exact design provided in the user's screenshots:
*   **Header Bar**: Adds a custom "Launch at login" checkbox alongside settings and quit buttons.
*   **Range Segment Controls**: Supports toggling between `Today`, `7D`, `30D`, and `Cycle` ranges to filter metrics dynamically.
*   **Dual Primary Cards**: Showcases real-time aggregate **Tokens** (formatted in K/M) and **Cost** (summed from events).
*   **Detailed Metrics**: Displays billing cycle date spans and **Projected Spend** calculated by scaling current cycle spend.
*   **Token Split Progress Bar**: Features segment indicators and legend markers for **In**, **Out**, **Cache W**, and **Cache R** percentages.
*   **Activity Grid**: Embeds cards tracking total requests (interactive splits), background agent hits, average/mean charge per request, and cache read ratios.
*   **Busiest Day**: Displays a card identifying the day with the highest token activity and its total.
*   **Daily Trend Bar Chart**: Dynamically renders an SVG histogram representing day-by-day stats with grid lines, y-axis labels, and a segmented toggle selector for `Tokens` vs. `Cost`.
*   **Time of Day Activity Grid**: Visualizes a 24-column hourly grid highlighting hours with activity during the selected range.
*   **Models Split list**: Progress rows tracking total tokens consumed per model.
*   **Footer Selection Bar**: Embeds a profile tab selector (`Cursor`, `Codex`, `Antigravity`, `Opencode`, `Claude`) and refresh options.

### 9. Interactive UX & Architectural Refactoring
*   **State-Aware Toggle**: Added a custom `WindowState` manager containing an `AtomicU64` to store the millisecond timestamp of the last blur event. This resolves the toggle race condition on macOS.
*   **Programmatic Window Creation**: Moved the window configurations out of `tauri.conf.json` and into a dedicated Rust module [window.rs](file:///Users/achuth/Developer/billed/src-tauri/src/window.rs).

---

## Verification
*   Ran `cargo check` and `yarn build` successfully. All code is compiler-safe and built cleanly.
