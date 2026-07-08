# Verification Testcases Guide

This guide outlines the automated and manual testcases designed to verify the Cursor API integration and the Mascot companion overlay window features.

---

## 1. Automated Rust Backend Tests
We have implemented Rust unit tests to verify the core JWT sub-claim extraction utility in isolation.

### Running Rust Tests
Execute the following command in your terminal:
```bash
cargo test --manifest-path src-tauri/Cargo.toml
```

### Testcases Configured:
1.  **JWT Sub Claim Extraction (`test_get_user_id_from_jwt`)**:
    *   **Goal**: Ensure that a valid JWT token is successfully split, decoded from Base64, and the user's `sub` claim is parsed.
    *   **Input**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEyMzQ1In0.signature` (mock token with payload `{"sub":"user_12345"}`)
    *   **Expected Output**: `Ok("user_12345")`
2.  **Invalid JWT Handling (`test_get_user_id_from_invalid_jwt`)**:
    *   **Goal**: Verify the helper safely rejects garbage tokens instead of crashing.
    *   **Input**: `invalidjwttoken`
    *   **Expected Output**: `Err(...)`

---

## 2. Frontend Integration & Manual Testcases

### Testcase 2.1: Zero-Config Local Authentication
*   **Action**: Start the application with `yarn tauri dev`.
*   **Verification Steps**:
    1.  The app should read the token at `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`.
    2.  If the token exists, it should automatically proceed to fetch metrics and bypass authentication pages.
    3.  If the database file is missing or contains no token, the dashboard should display the custom "Authentication Required" card.

### Testcase 2.2: Mascot Cross-Window Syncing
*   **Action**: Change the active mascot using the dropdown selector beside the settings gear icon in the main statistics window.
*   **Verification Steps**:
    1.  Click the mascot name/badge in the header.
    2.  Select a different mascot (e.g. `seedy` -> `hoots`).
    3.  Confirm the spritesheet and name update instantly in the main window.
    4.  Confirm the separate floating mascot overlay window automatically updates its mascot spritesheet to match your selection.

### Testcase 2.3: Cursor Request Detection (Active Agent States)
*   **Action**: Open Cursor and trigger a chat request or code generation event.
*   **Verification Steps**:
    1.  Within 8 seconds, the background polling loop should detect the increased usage event count.
    2.  The main window should broadcast a `"cursor-agent-status"` event.
    3.  The floating mascot should transition to the `running` (typing/working) animation row.
    4.  After 3 seconds, the mascot should play a celebratory `jumping` cycle before returning to the default `idle` pose.

### Testcase 2.4: Window Dragging & Interactivity
*   **Action**: Interact with the mascot companion overlay window.
*   **Verification Steps**:
    1.  Hover over the mascot window; confirm the cursor changes to a `grab` hand.
    2.  Click and drag the mascot; confirm you can position it anywhere on the screen.
    3.  Single-click the mascot; confirm it triggers a random action state animation (`jumping`, `waving`, or `review`).
