#!/bin/bash
# example to call this script: ./download_mame_romset_updates.sh -v 0.275 -s /home/user/ROMSETS/MAME -u https://pleasuredome.github.io/pleasuredome/mame/index.html
# script to check regularly if a specific version of romset is available
# and if available we inject it in qbittorent to be downloaded immediately

# Check if required tool is installed
if ! [ $(command -v curl) ] ; then
  echo "Error: Please install curl before running this script."
  exit 1
fi
# Check if required ool is installed
if ! [ $(command -v wget) ] ; then
  echo "Error: Please install wget before running this script."
  exit 1
fi

#to manage mandatory parameters
helpFunction()
{
   echo "Usage: $0 -v mame_version -s save_path -u updates_list_url"
   echo "-v mame_version to check (mandatory to find specific romset from version)"
   echo "-s save_path to save updates (mandatory to store data to download)"
   echo "-u updates_list_url to have updates list (mandatory to download)"
   exit 1 # Exit script after printing help
}

while getopts ":s:u:v:?" opt; do
   case "$opt" in
      # Define type of update: could be pre-release/release
      s ) save_path="$OPTARG" ;;
      u ) updates_list_url="$OPTARG" ;;
      v ) mame_version="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$mame_version" ] || [ -z "$save_path" ] || [ -z "$updates_list_url" ]
then
   echo "Some or all of the parameters are empty"
   helpFunction
fi

# Define variables (replace with your details)
URL_TO_PARSE=${updates_list_url}
MAME_VERSION_TO_FIND=${mame_version} 
FILE_TO_SAVE="mame.html"
SAVE_PATH=${save_path}

# remove existing html systematically to redownlaod it
rm ${FILE_TO_SAVE}
# download html page to parse it
wget -N --no-cache -O ${FILE_TO_SAVE} ${URL_TO_PARSE}
# Print success or error message
if [ $? -eq 0 ]; then
  echo "saved as ${FILE_TO_SAVE} file !"
else
  echo "${URL_TO_PARSE} file downloaded not available !"
  exit 1
fi

# check if directory already exists
# as "MAME - Update ROMSs (v0.274 to v0.275)"
# and using patterns
pattern="MAME*Update*ROM*to*${MAME_VERSION_TO_FIND}*"
if find $SAVE_PATH -maxdepth 1 -type d -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
  echo "Directory matching '$pattern' already exists - no new download to do"
else
  echo "Directory matching '$pattern' does not exist."
  MAGNET_UPDATE_ROMS=$(cat ${FILE_TO_SAVE} | grep -i "Set:" | grep -i "Update ROMs" | grep -i "${VERSION_TO_FIND}" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
  echo "MAGNET_UPDATE_ROMS: $MAGNET_UPDATE_ROMS"
  echo  "$MAGNET_UPDATE_ROMS" > magnet_update_roms.txt
  if [[ "$MAGNET_UPDATE_ROMS" == magnet* ]]; then
    echo "MAGNET_UPDATE_ROMS contains 'magnet'."
    bash ../tools/qbt_inject_magnet.sh -m $MAGNET_UPDATE_ROMS -s $SAVE_PATH
    if [ $? -eq 0 ]; then
      echo "inject magnet to update roms in qbittorent successful!"
    else
      echo "inject magnet to update roms in qbittorent failed!"
      exit 1
    fi
  else
    echo "MAGNET_UPDATE_ROMS does not contain 'magnet'."
  fi
fi

# check if directory already exists
# as "MAME - Update CHDs (v0.274 to v0.275)"
# and using patterns
pattern="MAME*Update*CHD*to*${MAME_VERSION_TO_FIND}*"
if find $SAVE_PATH -maxdepth 1 -type d -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
  echo "Directory matching '$pattern' already exists - no new download to do"
else
  echo "Directory matching '$pattern' does not exist."
  MAGNET_UPDATE_CHDS=$(cat ${FILE_TO_SAVE} | grep -i "Set:" | grep -i "Update CHDs" | grep -i "${VERSION_TO_FIND}" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
  echo "MAGNET_UPDATE_CHDS: $MAGNET_UPDATE_CHDS"
  echo  "$MAGNET_UPDATE_CHDS" > magnet_update_chds.txt
  if [[ "$MAGNET_UPDATE_CHDS" == magnet* ]]; then
    echo "MAGNET_UPDATE_CHDS contains 'magnet'."
    bash ../tools/qbt_inject_magnet.sh -m $MAGNET_UPDATE_CHDS -s $SAVE_PATH
    if [ $? -eq 0 ]; then
      echo "inject magnet to update chds in qbittorent successful!"
    else
      echo "inject magnet to update chds in qbittorent failed!"
      exit 1
    fi
  else
    echo "MAGNET_UPDATE_CHDS does not contain 'magnet'."
  fi
fi
