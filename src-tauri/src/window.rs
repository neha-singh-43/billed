use tauri::{webview::WebviewWindowBuilder, AppHandle, WebviewUrl};

pub fn setup_window(app: &AppHandle) -> Result<tauri::webview::WebviewWindow, tauri::Error> {
    WebviewWindowBuilder::new(app, "main", WebviewUrl::default())
        .title("")
        .inner_size(360.0, 150.0)
        .max_inner_size(360.0, 850.0)
        .visible(false)
        .resizable(false)
        .closable(false)
        .minimizable(false)
        .always_on_top(true)
        .title_bar_style(tauri::TitleBarStyle::Overlay)
        .transparent(true)
        .build()
}

pub fn setup_mascot_window(app: &AppHandle) -> Result<tauri::webview::WebviewWindow, tauri::Error> {
    WebviewWindowBuilder::new(app, "mascot", WebviewUrl::default())
        .title("")
        .inner_size(80.0, 87.0)
        .visible(true)
        .resizable(false)
        .always_on_top(true)
        .decorations(false)
        .transparent(true)
        .shadow(false)
        .build()
}
