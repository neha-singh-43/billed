use tauri::Manager;
fn test(app: &tauri::AppHandle) {
    if let Some(tray) = app.tray_by_id("tray") {
        let _ = tray.set_title(Some("Hello"));
    }
}
