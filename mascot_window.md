# Mascot Window Overlay Documentation

This document describes the configuration, permissions, window properties, and frontend routing system implemented to support the floating mascot overlay window.

---

## 1. Window Properties & Setup
The companion window is created programmatically on application setup inside the Rust module `src-tauri/src/window.rs`. It is configured with the following properties:

```rust
pub fn setup_mascot_window(app: &AppHandle) -> Result<tauri::webview::WebviewWindow, tauri::Error> {
    WebviewWindowBuilder::new(app, "mascot", WebviewUrl::default())
        .title("Cursor Mascot")
        .inner_size(80.0, 87.0) // Matches Codex mascot dimensions
        .visible(true)          // visible on desktop
        .resizable(false)
        .always_on_top(true)    // floats on top of other applications
        .decorations(false)     // hides titlebar and border controls
        .transparent(true)      // enables transparent webview backgrounds
        .shadow(false)          // removes OS window drop shadow
        .build()
}
```

---

## 2. Window Capabilities & Security Permissions
Tauri v2 requires strict capabilities to authorize secondary windows and client-side actions. The configuration file `src-tauri/capabilities/default.json` has been updated to authorize the mascot window and grant window-dragging rights:

```json
{
  "windows": [
    "main",
    "mascot"
  ],
  "permissions": [
    "core:default",
    "opener:default",
    "core:window:allow-start-dragging"
  ]
}
```
*   `"windows": ["main", "mascot"]`: Registers both the main statistics window and the floating mascot window, allowing both to communicate with the Rust backend.
*   `"core:window:allow-start-dragging"`: Grants permission to call the native OS window dragging API from JavaScript.

---

## 3. React Multi-Window Routing
The frontend dynamically detects which window context it is rendering using the `@tauri-apps/api/window` library.
*   If the current window label is `"main"`, the full usage dashboard is rendered.
*   If the current window label is `"mascot"`, the dashboard is bypassed entirely and only the transparent animated Mascot component is displayed:

```typescript
const [windowLabel, setWindowLabel] = useState<string>("main");

useEffect(() => {
  try {
    setWindowLabel(getCurrentWindow().label);
  } catch (e) {
    console.error("Failed to get window label", e);
  }
}, []);

if (windowLabel === "mascot") {
  return (
    <div className="mascot-overlay-window">
      {activePet !== "unknown" && (
        <Mascot petId={activePet} width="80px" height="87px" />
      )}
    </div>
  );
}
```

---

## 4. Desktop Drag-to-Move Capability
To support positioning the companion pet anywhere on the desktop, the Mascot element in `src/App.tsx` has been configured with:
*   `data-tauri-drag-region`: A custom HTML attribute that binds mouse drag events directly to Tauri's native window moving actions.
*   `cursor: 'grab'`: Inline CSS to indicate click-and-drag capability to the user.

```html
<div
  className="mascot-sprite"
  data-tauri-drag-region
  style={{
    backgroundImage: `url(${spritesheet})`,
    cursor: 'grab'
  }}
  onClick={handleClick}
/>
```
