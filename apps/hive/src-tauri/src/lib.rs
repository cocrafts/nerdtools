extern crate core_foundation;
extern crate core_graphics;
extern crate objc;

use core_foundation::array::CFArray;
use core_foundation::base::{CFType, TCFType};
use core_foundation::string::{CFString, CFStringRef};
use objc::runtime::{Class, Object};
use objc::{msg_send, sel, sel_impl};
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Debug, Serialize, Deserialize)]
struct Process {
    id: String,
    focused: bool,
    name: String,
}

#[tauri::command]
fn process_list() -> Result<Vec<Process>, String> {
    let mut results: Vec<Process> = Vec::new();

    unsafe {
        let workspace: *mut Object = msg_send![Class::get("NSWorkspace").unwrap(), sharedWorkspace];
        let apps: *mut Object = msg_send![workspace, runningApplications];
        let generic_apps: CFArray<CFType> = CFArray::wrap_under_get_rule(apps as *mut _);

        for i in 0..generic_apps.len() {
            let generic_app: &CFType = &generic_apps.get(i).unwrap();
            let app: *mut Object = generic_app.as_CFTypeRef() as *mut Object;
            let raw_bundle_id: *mut Object = msg_send![app, bundleIdentifier];
            let raw_name: *mut Object = msg_send![app, localizedName];
            let mut bundle_id = "".to_string();
            let mut name = "".to_string();

            if !raw_name.is_null() {
                let cf: CFString = TCFType::wrap_under_get_rule(raw_name as CFStringRef);
                name = cf.to_string();
            }

            if !raw_bundle_id.is_null() {
                let cf: CFString = TCFType::wrap_under_get_rule(raw_bundle_id as CFStringRef);
                bundle_id = cf.to_string();
            }

            results.push(Process {
                id: bundle_id,
                focused: false,
                name,
            })
        }
    }

    Ok(results)
}

#[tauri::command]
fn get_focused_application() -> Option<Process> {
    unsafe {
        let workspace: *mut Object = msg_send![Class::get("NSWorkspace").unwrap(), sharedWorkspace];
        let app: *mut Object = msg_send![workspace, frontmostApplication];
        if app.is_null() {
            return None;
        }

        let raw_bundle_id: *mut Object = msg_send![app, bundleIdentifier];
        let raw_name: *mut Object = msg_send![app, localizedName];
        let mut bundle_id = "".to_string();
        let mut name = "".to_string();

        if !raw_name.is_null() {
            let cf: CFString = TCFType::wrap_under_get_rule(raw_name as CFStringRef);
            name = cf.to_string();
        }

        if !raw_bundle_id.is_null() {
            let cf: CFString = TCFType::wrap_under_get_rule(raw_bundle_id as CFStringRef);
            bundle_id = cf.to_string();
        }

        Some(Process {
            id: bundle_id,
            focused: true,
            name,
        })
    }
}

#[tauri::command]
fn set_focused_application(process: Process) {
    let mut script = "".to_string();

    if !process.id.is_empty() {
        script = format!(
            r#"tell application "System Events"
               set frontmost of the first process whose bundle identifier is "{}" to true
           end tell"#,
            process.id
        );
    } else if !process.name.is_empty() {
        script = format!(
            r#"tell application "System Events"
               set frontmost of the first process whose name is "{}" to true
           end tell"#,
            process.name
        );
    }

    Command::new("osascript")
        .arg("-e")
        .arg(script)
        .output()
        .expect("Failed to execute AppleScript");
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            greet,
            process_list,
            get_focused_application,
            set_focused_application,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
