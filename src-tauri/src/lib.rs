use tauri::{
    tray::{TrayIconBuilder, TrayIconEvent},
    Manager, PhysicalPosition,
};
use std::time::{SystemTime, UNIX_EPOCH};
use std::sync::atomic::{AtomicU64, Ordering};

mod window;

struct WindowState {
    last_blur_time: AtomicU64,
}

fn get_cursor_token() -> Result<String, String> {
    // 1. Get home dir
    let home = std::env::var("HOME").map_err(|_| "Could not find HOME environment variable".to_string())?;
    
    // 2. Database path
    let db_path = format!("{}/Library/Application Support/Cursor/User/globalStorage/state.vscdb", home);
    if !std::path::Path::new(&db_path).exists() {
        return Err("Cursor state database not found. Please make sure Cursor is logged in.".to_string());
    }
    
    // 3. Open DB in read-only mode
    let conn = rusqlite::Connection::open_with_flags(
        &db_path,
        rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY,
    ).map_err(|e| format!("Failed to open Cursor database: {}", e))?;
    
    // 4. Query token
    let mut stmt = conn.prepare("SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'")
        .map_err(|e| format!("Failed to prepare SQL statement: {}", e))?;
    
    let token: String = stmt.query_row([], |row| row.get(0))
        .map_err(|e| format!("Could not retrieve Cursor access token from database: {}", e))?;
        
    Ok(token)
}

fn get_user_id_from_jwt(token: &str) -> Result<String, String> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() < 2 {
        return Err("Invalid JWT format".to_string());
    }
    let payload_b64 = parts[1];
    
    use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
    let decoded = URL_SAFE_NO_PAD.decode(payload_b64)
        .map_err(|e| format!("Failed to base64 decode JWT payload: {}", e))?;
        
    let json: serde_json::Value = serde_json::from_slice(&decoded)
        .map_err(|e| format!("Failed to parse JWT payload JSON: {}", e))?;
        
    let sub = json.get("sub")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "JWT missing 'sub' claim".to_string())?;
        
    Ok(sub.to_string())
}

#[tauri::command]
fn quit(app: tauri::AppHandle) {
    app.exit(0);
}

#[tauri::command]
async fn get_cursor_usage() -> Result<serde_json::Value, String> {
    let token = get_cursor_token()?;
    let user_id = get_user_id_from_jwt(&token)?;
    let cookie_value = format!("{}::{}", user_id, token);
        
    let client = reqwest::Client::new();
    
    // 1. Fetch usage-summary
    let summary_res = client.get("https://cursor.com/api/usage-summary")
        .header("Cookie", format!("WorkosCursorSessionToken={}", cookie_value))
        .header("Origin", "https://cursor.com")
        .header("Referer", "https://cursor.com/dashboard/usage")
        .send()
        .await
        .map_err(|e| format!("Failed to request usage-summary: {}", e))?;
        
    if !summary_res.status().is_success() {
        return Err(format!("usage-summary API returned status {}", summary_res.status()));
    }
    
    let summary_data: serde_json::Value = summary_res.json()
        .await
        .map_err(|e| format!("Failed to parse usage-summary JSON: {}", e))?;

    // 2. Fetch last 90 days of filtered usage events
    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_millis();
    let ninety_days_ago_ms = now_ms - (90 * 24 * 60 * 60 * 1000);
    
    let payload = serde_json::json!({
        "startDate": ninety_days_ago_ms,
        "endDate": now_ms
    });

    let events_res = client.post("https://cursor.com/api/dashboard/get-filtered-usage-events")
        .header("Cookie", format!("WorkosCursorSessionToken={}", cookie_value))
        .header("Origin", "https://cursor.com")
        .header("Referer", "https://cursor.com/dashboard/usage")
        .json(&payload)
        .send()
        .await
        .map_err(|e| format!("Failed to request usage events: {}", e))?;

    let events_data: serde_json::Value = if events_res.status().is_success() {
        events_res.json().await.unwrap_or(serde_json::json!({}))
    } else {
        serde_json::json!({})
    };

    Ok(serde_json::json!({
        "summary": summary_data,
        "events": events_data
    }))
}

#[tauri::command]
fn get_opencode_usage() -> Result<serde_json::Value, String> {
    let home = std::env::var("HOME").map_err(|_| "Could not find HOME directory".to_string())?;
    let db_path = std::path::Path::new(&home).join(".local/share/opencode/opencode.db");
    
    if !db_path.exists() {
        return Err("opencode.db not found".to_string());
    }
    
    let conn = rusqlite::Connection::open(&db_path)
        .map_err(|e| format!("Failed to open opencode.db: {}", e))?;
        
    let mut stmt = conn.prepare(
        "SELECT data FROM event WHERE type='message.updated.1' AND json_extract(data, '$.info.role')='assistant' AND json_extract(data, '$.info.time.completed') IS NOT NULL"
    ).map_err(|e| format!("Failed to prepare query: {}", e))?;
        
    let rows = stmt.query_map([], |row| {
        let data_str: String = row.get(0)?;
        Ok(data_str)
    }).map_err(|e| format!("Query failed: {}", e))?;
    
    let mut events = Vec::new();
    
    for row in rows {
        if let Ok(data_str) = row {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&data_str) {
                let info = &val["info"];
                let completed_ms = info["time"]["completed"].as_i64().unwrap_or(0);
                
                let model = info["modelID"].as_str()
                    .or_else(|| info["model"]["modelID"].as_str())
                    .unwrap_or("deepseek-v4-flash-free").to_string();
                    
                let agent = info["agent"].as_str().unwrap_or("chat");
                let is_headless = agent != "chat";
                
                let tokens = &info["tokens"];
                let input = tokens["input"].as_i64().unwrap_or(0);
                let output = tokens["output"].as_i64().unwrap_or(0);
                let cache_read = tokens["cache"]["read"].as_i64().unwrap_or(0);
                let cache_write = tokens["cache"]["write"].as_i64().unwrap_or(0);
                
                let cost_cents = (info["cost"].as_f64().unwrap_or(0.0) * 100.0) as i64;
                
                events.push(serde_json::json!({
                    "timestamp": completed_ms.to_string(),
                    "model": model,
                    "kind": "chat",
                    "requestsCosts": cost_cents as f64 / 100.0,
                    "isTokenBasedCall": true,
                    "tokenUsage": {
                        "inputTokens": input,
                        "outputTokens": output,
                        "cacheReadTokens": cache_read,
                        "cacheWriteTokens": cache_write,
                        "totalCents": cost_cents
                    },
                    "isHeadless": is_headless,
                    "chargedCents": cost_cents
                }));
            }
        }
    }
    
    let events_count = events.len();
    
    let summary = serde_json::json!({
        "billingCycleStart": "2026-06-29T16:18:00Z",
        "billingCycleEnd": "2026-07-29T16:18:00Z",
        "membershipType": "OpenCode",
        "limitType": "Free",
        "isUnlimited": true,
        "autoModelSelectedDisplayMessage": "OpenCode local/api usage details.",
        "namedModelSelectedDisplayMessage": "",
        "individualUsage": {
            "plan": {
                "included": 0,
                "bonus": 0,
                "total": 0
            }
        }
    });
    
    Ok(serde_json::json!({
        "summary": summary,
        "events": {
            "totalUsageEventsCount": events_count,
            "usageEventsDisplay": events
        }
    }))
}

#[tauri::command]
fn resize_window(window: tauri::WebviewWindow, height: f64) -> Result<(), String> {
    window.set_size(tauri::LogicalSize::new(360.0, height))
        .map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![get_cursor_usage, quit, resize_window, get_opencode_usage])
        .setup(|app| {
            // Hide the dock icon on macOS (runs as accessory menu bar app)
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Register state to track last blur time
            app.manage(WindowState {
                last_blur_time: AtomicU64::new(0),
            });

            // Create windows programmatically
            window::setup_window(app.handle())?;
            window::setup_mascot_window(app.handle())?;

            // Load the tray icon from compiled bytes (32x32 PNG)
            let icon = tauri::image::Image::from_bytes(include_bytes!("../icons/32x32.png"))
                .expect("failed to load icon");

            // Setup tray icon
            let _tray = TrayIconBuilder::with_id("tray")
                .icon(icon)
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: tauri::tray::MouseButton::Left,
                        rect,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let state = app.state::<WindowState>();
                            let last_blur = state.last_blur_time.load(Ordering::SeqCst);
                            let now = SystemTime::now()
                                .duration_since(UNIX_EPOCH)
                                .unwrap_or_default()
                                .as_millis() as u64;

                            // If we clicked within 150ms of the window losing focus, it means the click was on the tray icon itself,
                            // which already triggered a blur and hid the window. We should NOT show it again.
                            if now - last_blur > 150 {
                                if !window.is_visible().unwrap_or(false) {
                                    // Calculate position below the tray icon
                                    let scale_factor = window.scale_factor().unwrap_or(1.0);
                                    
                                    let (rect_pos_x, rect_pos_y) = match rect.position {
                                        tauri::Position::Physical(p) => (p.x as f64, p.y as f64),
                                        tauri::Position::Logical(l) => (l.x * scale_factor, l.y * scale_factor),
                                    };
                                    
                                    let (rect_size_w, rect_size_h) = match rect.size {
                                        tauri::Size::Physical(s) => (s.width as f64, s.height as f64),
                                        tauri::Size::Logical(l) => (l.width * scale_factor, l.height * scale_factor),
                                    };
                                    
                                    // Window dimensions match tauri.conf.json
                                    let win_width = 360.0;
                                    
                                    let x = rect_pos_x + (rect_size_w / 2.0) - ((win_width * scale_factor) / 2.0);
                                    let y = rect_pos_y + rect_size_h;
                                    
                                    let _ = window.set_position(PhysicalPosition::new(x as i32, y as i32));
                                    let _ = window.show();
                                    let _ = window.set_focus();
                                }
                            }
                        }
                    }
                })
                .build(app)?;

            // Setup focus blur listener to hide the window
            if let Some(window) = app.get_webview_window("main") {
                let window_clone = window.clone();
                let app_handle = app.handle().clone();
                window.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        let _ = window_clone.hide();
                        
                        let state = app_handle.state::<WindowState>();
                        let now = SystemTime::now()
                            .duration_since(UNIX_EPOCH)
                            .unwrap_or_default()
                            .as_millis() as u64;
                        state.last_blur_time.store(now, Ordering::SeqCst);
                    }
                });
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_id_from_jwt() {
        // A valid JWT payload: {"sub": "user_12345"}
        // header: {"alg":"HS256","typ":"JWT"} -> eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9
        // payload: {"sub":"user_12345"} -> eyJzdWIiOiJ1c2VyXzEyMzQ1In0
        // signature: mock -> signature
        let mock_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEyMzQ1In0.signature";
        
        let result = get_user_id_from_jwt(mock_jwt);
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "user_12345");
    }

    #[test]
    fn test_get_user_id_from_invalid_jwt() {
        let invalid_jwt = "invalidjwttoken";
        let result = get_user_id_from_jwt(invalid_jwt);
        assert!(result.is_err());
    }
}
