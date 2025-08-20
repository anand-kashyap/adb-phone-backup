#!/bin/bash

# Default remote and local folders
REMOTE_FOLDER="sdcard"
LOCAL_FOLDER=""
FILTERED_FOLDERS=".|Android|cache|torrent" # . for folders starting with .

# Usage
usage() {
  echo "Usage: $0 [-r remote_folder] [-l local_folder]"
  echo "  -r: Set the remote folder path on the Android device (default: $REMOTE_FOLDER)"
  echo "  -l: Set the local folder path to save files (required)"
  echo "  -v: Run in validation mode (only checks if all remote files/folders exist locally)"
  echo ""
  echo "Examples:"
  echo "  $0 -r sdcard -l ~/phone/backup"
  echo "  $0 -r sdcard/DCIM -l ~/Desktop/photos"
  echo "  $0 -r sdcard/Download -l ~/Downloads/phone -v"
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

# Add validation for required argument
if [ -z "$LOCAL_FOLDER" ]; then
  echo "Error: local (-l) folder path is required"
  usage
fi


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

  #include android media always
  adb shell "find '$REMOTE_FOLDER/Android/media/' -type f" | sed "s|^$REMOTE_FOLDER/||" > $LOCAL_FOLDER/android.files
  adb shell "find '$REMOTE_FOLDER/' -type f $CONVERTED_IGNORE_OPTS" | sed "s|^$REMOTE_FOLDER/||" >> $LOCAL_FOLDER/android.files
  FILE_COUNT=$(wc -l < $LOCAL_FOLDER/android.files)  # Get total file count
}

# List local files
list_local_files() {
  if [ -s "$LOCAL_FOLDER/local.files" ]; then
    echo "Using existing local.files as it is present and non-empty."
  else
    find "$LOCAL_FOLDER" -type f | sed "s|^$LOCAL_FOLDER/||" > $LOCAL_FOLDER/local.files
  fi
}

# Generate update list
generate_update_list() {
  echo "Preparing update list. This might take few minutes based on number files in the TARGET folder..."
  rm -f $LOCAL_FOLDER/update.files
  touch $LOCAL_FOLDER/update.files
  MISSING_COUNT=0

  while IFS= read -r line; do
    # If file doesn't exist locally, add to update list
    if ! grep -qF "$line" $LOCAL_FOLDER/local.files; then
      ((MISSING_COUNT++))
      echo "$line" >> $LOCAL_FOLDER/update.files
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
    echo "Downloading ($((++PROGRESS))/$FILE_COUNT): $line"

    # Extract directory path and create it if it doesn't exist
    dir_path=$(dirname "$LOCAL_FOLDER/$line")
    mkdir -p "$dir_path"

    # Perform adb pull
    adb pull "$REMOTE_FOLDER/$line" "$LOCAL_FOLDER/$line"
  done < "$LOCAL_FOLDER/update.files"
  echo "Download complete!"

  # Update local.files after download completes
  cat "$LOCAL_FOLDER/update.files" >> "$LOCAL_FOLDER/local.files"
  echo "local.files updated with downloaded files."
}

main() {
  check_dependencies
  list_android_files
  list_local_files
  generate_update_list
  if [ "$VALIDATION_MODE" = false ] && [ "$MISSING_COUNT" -gt 0 ]; then
    download_files
  fi
}

main