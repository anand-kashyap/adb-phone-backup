# Android Storage Backup Script

A bash script to efficiently backup files from an Android device's storage to a local computer. The script compares existing local files with remote files to only download new or missing content.

## Features

- Selective backup from any folder on Android device
- Skips system folders like Android, cache, etc.
- Validation mode to check missing files without downloading
- Progress tracking for downloads
- Automatic creation of directory structure
- Efficient differential backup - only downloads missing files

## Prerequisites

- `adb` (Android Debug Bridge) installed on your system
- USB debugging enabled on Android device
- Device connected via USB or ADB over WiFi

## Usage

(caffeinate supported by mac & unix based only, for preventing sleep)
```bash
caffeinate -i ./pull_sdcard.sh [-r remote_folder] [-l local_folder] [-v]
```

### Options

- `-r`: Set the remote folder path on Android device (default: "sdcard")
- `-l`: Set the local folder path to save files (required)
- `-v`: Run in validation mode (only checks for missing files)
- `-h`: Show help message

### Examples

```bash
# Backup entire sdcard to ~/phone/backup
./pull_sdcard.sh -r sdcard -l ~/phone/backup

# Backup only camera photos
./pull_sdcard.sh -r sdcard/DCIM -l ~/Desktop/photos

# Check for missing files without downloading
./pull_sdcard.sh -r sdcard/Download -l ~/Downloads/phone -v
```

## How It Works

1. Checks for `adb` installation and device connectivity
2. Lists all files on the Android device (excluding filtered folders)
3. Lists existing files in the local backup folder
4. Compares both lists to identify missing files
5. Downloads only the missing files while preserving folder structure

## Filtered Folders

By default, the script ignores these folders:
- Hidden folders (starting with .)
- Android system folder
- Cache folders
- Torrent folders

## Error Handling

- Checks for required `adb` dependency
- Validates device connectivity
- Ensures local folder path is provided
- Creates missing directories as needed

## Notes

- Large backups may take significant time depending on file sizes
- Keep the device connected and screen on during backup
- USB debugging must remain enabled throughout the