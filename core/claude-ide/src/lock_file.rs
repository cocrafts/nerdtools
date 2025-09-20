use anyhow::{anyhow, Result};
use dirs;
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize)]
pub struct LockFileData {
    pub pid: u32,
    #[serde(rename = "workspaceFolders")]
    pub workspace_folders: Vec<String>,
    #[serde(rename = "ideName")]
    pub ide_name: String,
    pub transport: String,
    #[serde(rename = "authToken")]
    pub auth_token: String,
}

pub struct LockFileManager;

impl LockFileManager {
    pub fn new() -> Self {
        Self
    }

    /// Get the lock file directory
    fn get_lock_dir() -> Result<PathBuf> {
        // Check for CLAUDE_CONFIG_DIR environment variable first
        if let Ok(claude_config_dir) = env::var("CLAUDE_CONFIG_DIR") {
            let lock_dir = PathBuf::from(claude_config_dir).join("ide");
            return Ok(lock_dir);
        }

        // Fall back to ~/.claude/ide
        let home_dir = dirs::home_dir()
            .ok_or_else(|| anyhow!("Could not determine home directory"))?;
        let lock_dir = home_dir.join(".claude").join("ide");
        Ok(lock_dir)
    }

    /// Create a lock file for the given port and auth token
    pub fn create_lock_file(&self, port: u16, auth_token: &str, workspace_folder: Option<&str>) -> Result<()> {
        let lock_dir = Self::get_lock_dir()?;

        // Create directory if it doesn't exist
        fs::create_dir_all(&lock_dir)
            .map_err(|e| anyhow!("Failed to create lock directory: {}", e))?;

        let lock_file_path = lock_dir.join(format!("{}.lock", port));

        let workspace_dir = if let Some(provided_workspace) = workspace_folder {
            // Use the provided workspace folder from Neovim
            provided_workspace.to_string()
        } else {
            // Fallback to current directory logic for backwards compatibility
            let current_dir = env::current_dir()
                .map_err(|e| anyhow!("Failed to get current directory: {}", e))?;

            // Use parent directory since Claude Code runs from the project root, not core/
            let workspace_dir = if current_dir.file_name() == Some(std::ffi::OsStr::new("core")) {
                current_dir.parent()
                    .ok_or_else(|| anyhow!("Failed to get parent directory"))?
                    .to_path_buf()
            } else {
                current_dir
            };
            workspace_dir.to_string_lossy().to_string()
        };

        let lock_data = LockFileData {
            pid: std::process::id(),
            workspace_folders: vec![workspace_dir],
            ide_name: "Neovim".to_string(),
            transport: "ws".to_string(),
            auth_token: auth_token.to_string(),
        };

        let json_content = serde_json::to_string_pretty(&lock_data)
            .map_err(|e| anyhow!("Failed to serialize lock file data: {}", e))?;

        fs::write(&lock_file_path, json_content)
            .map_err(|e| anyhow!("Failed to write lock file: {}", e))?;

        tracing::info!("Created lock file: {}", lock_file_path.display());
        Ok(())
    }

    /// Remove the lock file for the given port
    pub fn remove_lock_file(&self, port: u16) -> Result<()> {
        let lock_dir = Self::get_lock_dir()?;
        let lock_file_path = lock_dir.join(format!("{}.lock", port));

        if lock_file_path.exists() {
            fs::remove_file(&lock_file_path)
                .map_err(|e| anyhow!("Failed to remove lock file: {}", e))?;
            tracing::debug!("Removed lock file: {}", lock_file_path.display());
        }

        Ok(())
    }

    /// Read a lock file for the given port
    pub fn read_lock_file(&self, port: u16) -> Result<LockFileData> {
        let lock_dir = Self::get_lock_dir()?;
        let lock_file_path = lock_dir.join(format!("{}.lock", port));

        let content = fs::read_to_string(&lock_file_path)
            .map_err(|e| anyhow!("Failed to read lock file: {}", e))?;

        let lock_data: LockFileData = serde_json::from_str(&content)
            .map_err(|e| anyhow!("Failed to parse lock file: {}", e))?;

        Ok(lock_data)
    }

    /// List all existing lock files
    pub fn list_lock_files(&self) -> Result<Vec<u16>> {
        let lock_dir = Self::get_lock_dir()?;

        if !lock_dir.exists() {
            return Ok(Vec::new());
        }

        let mut ports = Vec::new();

        let entries = fs::read_dir(&lock_dir)
            .map_err(|e| anyhow!("Failed to read lock directory: {}", e))?;

        for entry in entries {
            let entry = entry.map_err(|e| anyhow!("Failed to read directory entry: {}", e))?;
            let path = entry.path();

            if let Some(file_name) = path.file_name() {
                if let Some(file_name_str) = file_name.to_str() {
                    if file_name_str.ends_with(".lock") {
                        let port_str = &file_name_str[..file_name_str.len() - 5]; // Remove ".lock"
                        if let Ok(port) = port_str.parse::<u16>() {
                            ports.push(port);
                        }
                    }
                }
            }
        }

        ports.sort();
        Ok(ports)
    }

    /// Check if a lock file exists for the given port
    pub fn lock_file_exists(&self, port: u16) -> bool {
        let lock_dir = match Self::get_lock_dir() {
            Ok(dir) => dir,
            Err(_) => return false,
        };

        let lock_file_path = lock_dir.join(format!("{}.lock", port));
        lock_file_path.exists()
    }

    /// Clean up stale lock files (where the process no longer exists)
    pub fn cleanup_stale_locks(&self) -> Result<Vec<u16>> {
        let ports = self.list_lock_files()?;
        let mut cleaned_ports = Vec::new();

        for port in ports {
            if let Ok(lock_data) = self.read_lock_file(port) {
                // Check if process is still running (basic check)
                if !self.is_process_running(lock_data.pid) {
                    if let Err(e) = self.remove_lock_file(port) {
                        tracing::warn!("Failed to remove stale lock file for port {}: {}", port, e);
                    } else {
                        tracing::info!("Cleaned up stale lock file for port {}", port);
                        cleaned_ports.push(port);
                    }
                }
            }
        }

        Ok(cleaned_ports)
    }

    /// Check if a process is still running (basic implementation)
    #[cfg(unix)]
    fn is_process_running(&self, pid: u32) -> bool {
        // On Unix systems, we can check if the process exists
        unsafe {
            libc::kill(pid as i32, 0) == 0
        }
    }

    #[cfg(windows)]
    fn is_process_running(&self, _pid: u32) -> bool {
        // On Windows, this would require more complex implementation
        // For now, assume process is running
        true
    }

    #[cfg(not(any(unix, windows)))]
    fn is_process_running(&self, _pid: u32) -> bool {
        // For other platforms, assume process is running
        true
    }
}

impl Default for LockFileManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_create_and_read_lock_file() {
        let temp_dir = TempDir::new().unwrap();
        env::set_var("CLAUDE_CONFIG_DIR", temp_dir.path());

        let lock_manager = LockFileManager::new();
        let port = 12345;
        let auth_token = "test-token-123";

        // Create lock file
        lock_manager.create_lock_file(port, auth_token).unwrap();

        // Read lock file
        let lock_data = lock_manager.read_lock_file(port).unwrap();
        assert_eq!(lock_data.auth_token, auth_token);
        assert_eq!(lock_data.ide_name, "Neovim");
        assert_eq!(lock_data.transport, "ws");

        // Check if exists
        assert!(lock_manager.lock_file_exists(port));

        // List lock files
        let ports = lock_manager.list_lock_files().unwrap();
        assert!(ports.contains(&port));

        // Remove lock file
        lock_manager.remove_lock_file(port).unwrap();
        assert!(!lock_manager.lock_file_exists(port));

        env::remove_var("CLAUDE_CONFIG_DIR");
    }
}