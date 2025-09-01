#!/bin/bash
# example to call this script:
# ./qbt_selective_injector.sh -m magnet:?xt=urn:btih:2fff... -s /home/user/ROMSETS/MAME -F my_rom_list.txt

# This script injects a magnet URL into qBittorrent via its Web UI API,
# then selectively downloads only the specified files.

# --- SCRIPT SETUP ---
QBT_HOST="localhost"
QBT_PORT="8080"
QBT_USER="admin"
QBT_PASS="adminadmin" #Change this!
CHUNK_SIZE=500 # Number of file indices to process per API call

# --- FUNCTIONS ---
helpFunction() {
  echo "Usage: $0 -m magnet_url -s save_path [-f file1 [file2]... | -F filename]"
  echo "-m magnet_url to inject in qBittorrent (mandatory)"
  echo "-s save_path to save data (mandatory)"
  echo "-f list of files to download (optional, space-separated)"
  echo "-F file with a list of files to download (optional, one filename per line)"
  echo "You must use either -f or -F."
  exit 1
}

# --- PARAMETER PARSING ---
files_to_select=()
file_list_path=""

while getopts ":m:s:f:F:?" opt; do
  case "$opt" in
    m) magnet_url="$OPTARG" ;;
    s) save_path="$OPTARG" ;;
    f) files_to_select=("$OPTARG") ;; # Store the first file to select
    F) file_list_path="$OPTARG" ;;
    \?) helpFunction ;;
  esac
done

# If -f was used, get the rest of the arguments
if [ -n "$files_to_select" ]; then
  shift $((OPTIND - 1))
  files_to_select+=("$@")
fi

# Check for mandatory parameters
if [ -z "$magnet_url" ] || [ -z "$save_path" ]; then
  echo "Error: Both -m and -s parameters are mandatory."
  helpFunction
fi

# Check if either -f or -F was used
if [ -z "$file_list_path" ] && [ ${#files_to_select[@]} -eq 0 ]; then
  echo "Error: You must specify a list of files to select using either -f or -F."
  helpFunction
fi

# Read files from the specified file if -F was used
if [ -n "$file_list_path" ]; then
  if [ -f "$file_list_path" ]; then
    while IFS= read -r line; do
      # Remove leading/trailing whitespace and skip empty lines
      trimmed_line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ -n "$trimmed_line" ]; then
        files_to_select+=("$trimmed_line".zip)
      fi
    done < "$file_list_path"
  else
    echo "Error: File '$file_list_path' not found."
    exit 1
  fi
fi

# Check again if the array is empty after reading from file
if [ ${#files_to_select[@]} -eq 0 ]; then
  echo "Error: No valid filenames were found to select."
  exit 1
fi

# --- MAIN WORKFLOW ---
if ! pgrep -x "qbittorrent" > /dev/null; then
  echo "Error: qBittorrent is not running. Please start it first."
  exit 1
fi

echo "Logging into qBittorrent Web UI and creating cookies.txt..."
# Login to get a cookie and save it to a file
curl -s -X POST \
  -d "username=$QBT_USER&password=$QBT_PASS" \
  "http://$QBT_HOST:$QBT_PORT/api/v2/auth/login" \
  -c cookies.txt > /dev/null

if [ ! -s cookies.txt ]; then
  echo "Error: Failed to log in to qBittorrent. Check your username/password."
  exit 1
fi

echo "Adding magnet link to qBittorrent...in pause for the moment"
#echo "save_path : $save_path"
curl -s -X POST -b cookies.txt \
  --data-urlencode "urls=$magnet_url" \
  --data-urlencode "savepath=$save_path" \
  "http://$QBT_HOST:$QBT_PORT/api/v2/torrents/add" > /dev/null

# Get info hash from magnet link
TORRENT_HASH=$(echo "$magnet_url" | grep -o "btih:[a-zA-Z0-9]*" | cut -d':' -f2)
if [ -z "$TORRENT_HASH" ]; then
  echo "Error: Could not extract hash from magnet link."
  rm cookies.txt
  exit 1
fi

echo "Waiting for info metadata to be downloaded..."
metadata_retrieved=false
while [ "$metadata_retrieved" != "true" ]; do
  sleep 1 # Poll every 1 second
  # Log the raw response for debugging
  echo "Polling for info metadata..."
  torrent_info=$(curl -s -X GET -b cookies.txt \
    "http://$QBT_HOST:$QBT_PORT/api/v2/torrents/info?hashes=$TORRENT_HASH")
  
  # Log the raw torrent info to help with debugging
  echo "TORRENT_HASH to find: $TORRENT_HASH"
  echo "Raw torrent info response:"
  echo "$torrent_info"
  
  if echo "$torrent_info" | grep -q $TORRENT_HASH; then
    echo "Info Metadata retrieved."
    metadata_retrieved=true
  else
    echo "Still waiting for Info metadata... (Press Ctrl+C to stop)"
  fi
done

echo "Waiting for files metadata to be downloaded..."
metadata_retrieved=false
while [ "$metadata_retrieved" != "true" ]; do
  sleep 1 # Poll every 1 second
  # Log the raw response for debugging
  echo "Getting file list from torrent..."
  files_json=$(curl -s -X GET -b cookies.txt \
    "http://$QBT_HOST:$QBT_PORT/api/v2/torrents/files?hash=$TORRENT_HASH")
 
  # Log the raw file list response for debugging
  echo "Raw file list response (100 first chars only):"
  echo "$files_json" | head -c 100
  
  if echo "$files_json" | head -c 100 | grep -q "availability"; then
    echo "Files Metadata retrieved. Proceeding with file selection."
    metadata_retrieved=true
  else
    echo "Still waiting for files metadata... (Press Ctrl+C to stop)"
  fi
done

echo "--- Set in pause asap to let to unselect files ---"
curl -b cookie.txt -d "hashes=$TORRENT_HASH" http://$QBT_HOST:$QBT_PORT/api/v2/torrents/pause
#echo "curl -b cookie.txt -d 'hashes=$TORRENT_HASH' http://$QBT_HOST:$QBT_PORT/api/v2/torrents/pause"



declare -a files_to_download_ids=()
declare -a files_to_skip_ids=()

nb_files=$(echo "$files_json" | grep -o '"availability"' | wc -l)
echo "Number of files: $nb_files"

echo "Setting file priorities..."

# This is the optimization for huge number of files
# Use jq to directly build the comma-separated lists
# `jq` is much more efficient than grep/cut/tr
files_to_select_json=$(printf '%s\n' "${files_to_select[@]}" | jq -R . | jq -s .)
#echo "files_to_select_json : $files_to_select_json"

# Build the list of file indices to download (priority 1)
download_indices=$(echo "$files_json" | jq -r --argjson select_list "$files_to_select_json" '[.[] | select((.name | split("/")[-1]) as $filename | any($select_list[]; . == $filename)) | .index] | join("|")')
#echo "download_indices : $download_indices"
# Display the count of files to download
if [ -n "$download_indices" ]; then
  download_count=$(echo "$download_indices" | tr '|' '\n' | wc -l)
  echo "Number of files to download: $download_count"
fi

# Build the list of file indices to skip (priority 0)
skip_indices=$(echo "$files_json" | jq -r --argjson select_list "$files_to_select_json" '[.[] | select((.name | split("/")[-1]) as $filename | any($select_list[]; . == $filename) | not) | .index] | join("|")')
#echo "skip_indices : $skip_indices"
# Display the count of files to skip
if [ -n "$skip_indices" ]; then
  skip_count=$(echo "$skip_indices" | tr '|' '\n' | wc -l)
  echo "Number of files to skip: $skip_count"
fi

# Split the index strings into arrays
IFS='|' read -r -a skip_array <<< "$skip_indices"
IFS='|' read -r -a download_array <<< "$download_indices"

# --- Process Skipped Files in Chunks ---
if [ ${#skip_array[@]} -gt 0 ]; then
  echo "Splitting 'skip' requests into chunks of $CHUNK_SIZE..."
  for (( i=0; i<${#skip_array[@]}; i+=$CHUNK_SIZE )); do
    chunk_indices=$(
      IFS='|'
      echo "${skip_array[*]:$i:$CHUNK_SIZE}"
    )
    echo "Sending 'skip' chunk for indices starting at ${skip_array[$i]}..."
    curl -b cookie.txt -d "hash=$TORRENT_HASH&id=$chunk_indices&priority=0" http://$QBT_HOST:$QBT_PORT/api/v2/torrents/filePrio
  done
fi

# --- Process Downloaded Files in Chunks ---
if [ ${#download_array[@]} -gt 0 ]; then
  echo "Splitting 'download' requests into chunks of $CHUNK_SIZE..."
  for (( i=0; i<${#download_array[@]}; i+=$CHUNK_SIZE )); do
    chunk_indices=$(
      IFS='|'
      echo "${download_array[*]:$i:$CHUNK_SIZE}"
    )
    echo "Sending 'download' chunk for indices starting at ${download_array[$i]}..."
    curl -b cookie.txt -d "hash=$TORRENT_HASH&id=$chunk_indices&priority=1" http://$QBT_HOST:$QBT_PORT/api/v2/torrents/filePrio
  done
fi

echo "File priorities set. qBittorrent should now be downloading your selected files."

echo "--- Set in resume asap to start finally downlaod of select files ---"
curl -b cookie.txt -d "hashes=$TORRENT_HASH" http://$QBT_HOST:$QBT_PORT/api/v2/torrents/resume

# Cleanup the cookie file
rm cookies.txt
