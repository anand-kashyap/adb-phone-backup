#!/bin/bash

# Default remote and local folders
REMOTE_FOLDER="sdcard"
LOCAL_FOLDER="$HOME/phone/iqoo7_16aug25"
FILTERED_FOLDERS=".|Android|cache|torrent" # . for folders starting with .

# Usage
usage() {
  echo "Usage: $0 [-r remote_folder] [-l local_folder]"
  echo "  -r: Set the remote folder path on the Android device (default: $REMOTE_FOLDER)"
  echo "  -l: Set the local folder path to save files (default: $LOCAL_FOLDER)"
  echo "  -v: Run in validation mode (only checks if all remote files/folders exist locally)"
  exit 1
}

# Parse command-line arguments
VALIDATION_MODE=false
while getopts "r:l:vh" opt; do
  case $opt in
    r) REMOTE_FOLDER="$OPTARG" ;;
    l) LOCAL_FOLDER="$OPTARG" ;;
    v) VALIDATION_MODE=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Check dependencies
check_dependencies() {
  if ! command -v adb &>/dev/null; then
    echo "Error: adb is not installed. Install it first."
    exit 1
  else
    echo "ADB cli tool found."
    adb devices | grep -q "device" || { echo "Error: No Android device found. Connect android device and enable USB/WiFi ADB debugging."; exit 1; }
  fi
}

convert_to_ignore_opts() {
  echo "excluded folders: $FILTERED_FOLDERS"

  CONVERTED_IGNORE_OPTS=""
  IFS='|' read -ra patterns <<< "$FILTERED_FOLDERS"
  for pattern in "${patterns[@]}"; do
    CONVERTED_IGNORE_OPTS+=" -not -path \"*${pattern}*/*\""
  done # -not -path "*foo*/*" -not -path "*bar*/*"
}

# List files on Android device
list_android_files() {
  convert_to_ignore_opts

  adb shell "find '$REMOTE_FOLDER/' -type f $CONVERTED_IGNORE_OPTS" | sed "s|^$REMOTE_FOLDER/||" > $LOCAL_FOLDER/android.files
  FILE_COUNT=$(wc -l < $LOCAL_FOLDER/android.files)  # Get total file count
}

# List local files
list_local_files() {
  find "$LOCAL_FOLDER" -type f | sed "s|^$LOCAL_FOLDER/||" > $LOCAL_FOLDER/local.files
}

# Generate update list
generate_update_list() {
  echo "Preparing update list. This might take few minutes based on number files in the TARGET folder..."
  rm -f $LOCAL_FOLDER/update.files
  touch $LOCAL_FOLDER/update.files
  MISSING_COUNT=0

  while IFS= read -r line; do
    # Remove non-printable characters
    clean_line=$(echo "$line" | sed 's/[^[:print:]]//')
    # If file doesn't exist locally, add to update list
    if ! grep -qF "$clean_line" $LOCAL_FOLDER/local.files; then
      ((MISSING_COUNT++))
      echo "$clean_line" >> $LOCAL_FOLDER/update.files
    fi
  done < $LOCAL_FOLDER/android.files
  echo "Update list created."

  if [ "$MISSING_COUNT" -eq 0 ]; then
    echo "All remote files are present locally!!"
    return;
  fi

  echo "ADB Pull needed: $MISSING_COUNT files are missing locally."
}

# Download files by checking missing files
download_files() {
  echo "Starting File download..."
  PROGRESS=0
  while IFS= read -r line; do
    clean_line=$(echo "$line" | sed 's/[^[:print:]]//')
    echo "Downloading ($((++PROGRESS))/$FILE_COUNT): $clean_line"
    adb pull "$REMOTE_FOLDER/$clean_line" "$LOCAL_FOLDER/$clean_line"
  done < "$LOCAL_FOLDER/update.files"
  echo "Download complete!"
}

main() {
  check_dependencies
  list_android_files
  list_local_files
  generate_update_list
  if [ "$VALIDATION_MODE" = false ]; then
    download_files
  fi
}

main