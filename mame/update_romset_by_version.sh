#!/bin/bash
# example to call this script: ./update_romset_by_version.sh -v 0.275 -s /home/user/ROMSETS/MAME -u https://pleasuredome.github.io/pleasuredome/mame/index.html
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
DATZIP_TO_SAVE="mame_update_rom_dat.zip"
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

# check if xml dat file already exists
# as "MAME - Update ROMSs (v0.274 to v0.275)"
# and using patterns
pattern="MAME*Update*ROM*to*${MAME_VERSION_TO_FIND}*.xml"
filefound=$(find ${SAVE_PATH} -maxdepth 1 -type f -name "$pattern" -print -quit 2>/dev/null)
echo "File found: $filefound"
if [ -n "$filefound" ]; then
  #if find . -maxdepth 1 -type f -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
  echo "File matching '$pattern' already exists - no new download to do"
else
  echo "File matching '$pattern' does not exist - download to do"
  #echo "cat ${FILE_TO_SAVE} | grep -i 'Datfile:' | grep -i 'Update ROMs' | grep -i '${MAME_VERSION_TO_FIND}'"
  #echo "cat mame.html | grep -i "Datfile:" | grep -i "Update ROMs" | grep -i "0.280" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')"
  DATZIP_URL=$(cat ${FILE_TO_SAVE} | grep -i "Datfile:" | grep -i "Update ROMs" | grep -i "${MAME_VERSION_TO_FIND}" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
  echo "DATZIP_URL: $DATZIP_URL"
  # remove existing zip systematically to redownlaod it
  rm ${DATZIP_TO_SAVE}
  # download html page to parse it
  wget -N --no-cache -O ${DATZIP_TO_SAVE} "${DATZIP_URL}"
  # Print success or error message
  if [ $? -eq 0 ]; then
    echo "saved as ${DATZIP_TO_SAVE} file !"
    # Add the unzip command here
    unzip -o ${DATZIP_TO_SAVE} -d ${SAVE_PATH}
    pattern="MAME*Update*ROM*to*${MAME_VERSION_TO_FIND}*.xml"
    filefound=$(find ${SAVE_PATH} -maxdepth 1 -type f -name "$pattern" -print -quit 2>/dev/null)
  else
    echo "${DATZIP_TO_SAVE} file downloaded not available !"
    exit 1
  fi
fi

# Parse the XML and create the list of names
# Using the grep/sed method for simplicity
if [ -n "$filefound" ]; then
  grep -o '<machine name="[^"]*"' "$filefound" | sed 's/<machine name="//; s/"//' > "machine_updated_names.txt"
else
  echo "no ${pattern} file unzipped !"
  exit 1
fi

# check if directory already exists
# as "MAME 0.280 ROMs (non-merged)"
# and using patterns
pattern="MAME*${MAME_VERSION_TO_FIND}*ROM*non-merged*"
if find $SAVE_PATH -maxdepth 1 -type d -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
  echo "Directory matching '$pattern' already exists - no new download to do"
else
  echo "Directory matching '$pattern' does not exist."
  #echo "cat ${FILE_TO_SAVE} | grep -i 'Set:' | grep -i 'Update ROMs' | grep -i '${MAME_VERSION_TO_FIND}'"
  MAGNET_FULLSET_ROMS=$(cat ${FILE_TO_SAVE} | grep -i "Set:" | grep -i "MAME " | grep -i "${MAME_VERSION_TO_FIND}" | grep -i "ROM" | grep -i "non-merged" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
  echo "MAGNET_FULLSET_ROMS: $MAGNET_FULLSET_ROMS"
  echo  "$MAGNET_FULLSET_ROMS" > magnet_fullset_roms.txt
  if [[ "$MAGNET_FULLSET_ROMS" == magnet* ]]; then
    echo "MAGNET_FULLSET_ROMS contains 'magnet'."
    bash ../tools/qbt_selective_injector.sh -m $MAGNET_FULLSET_ROMS -s $SAVE_PATH -F "machine_updated_names.txt"
    if [ $? -eq 0 ]; then
      echo "inject magnet to update roms in qbittorent successful!"
    else
      echo "inject magnet to update roms in qbittorent failed!"
      exit 1
    fi
  else
    echo "MAGNET_FULLSET_ROMS does not contain 'magnet' / should not exists for this version"
  fi
fi

#DEPREACATED / NOW I PREFER TO TAKE UPDATED FULL ROMS FROM NEW FULL ROMSET
# # check if directory already exists
# # as "MAME - Update ROMSs (v0.274 to v0.275)"
# # and using patterns
# pattern="MAME*Update*ROM*to*${MAME_VERSION_TO_FIND}*"
# if find $SAVE_PATH -maxdepth 1 -type d -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
#   echo "Directory matching '$pattern' already exists - no new download to do"
# else
#   echo "Directory matching '$pattern' does not exist."
#   #echo "cat ${FILE_TO_SAVE} | grep -i 'Set:' | grep -i 'Update ROMs' | grep -i '${MAME_VERSION_TO_FIND}'"
#   MAGNET_UPDATE_ROMS=$(cat ${FILE_TO_SAVE} | grep -i "Set:" | grep -i "Update ROMs" | grep -i "${MAME_VERSION_TO_FIND}" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
#   echo "MAGNET_UPDATE_ROMS: $MAGNET_UPDATE_ROMS"
#   echo  "$MAGNET_UPDATE_ROMS" > magnet_update_roms.txt
#   if [[ "$MAGNET_UPDATE_ROMS" == magnet* ]]; then
#     echo "MAGNET_UPDATE_ROMS contains 'magnet'."
#     bash ../tools/qbt_inject_magnet.sh -m $MAGNET_UPDATE_ROMS -s $SAVE_PATH
#     if [ $? -eq 0 ]; then
#       echo "inject magnet to update roms in qbittorent successful!"
#     else
#       echo "inject magnet to update roms in qbittorent failed!"
#       exit 1
#     fi
#   else
#     echo "MAGNET_UPDATE_ROMS does not contain 'magnet' / should not exists for this version"
#   fi
# fi

# check if directory already exists
# as "MAME - Update CHDs (v0.274 to v0.275)"
# and using patterns
pattern="MAME*Update*CHD*to*${MAME_VERSION_TO_FIND}*"
if find $SAVE_PATH -maxdepth 1 -type d -name "$pattern" -print -quit 2>/dev/null | grep -q .; then
  echo "Directory matching '$pattern' already exists - no new download to do"
else
  echo "Directory matching '$pattern' does not exist."
  #echo "cat ${FILE_TO_SAVE} | grep -i 'Set:' | grep -i 'Update CHDs' | grep -i '${MAME_VERSION_TO_FIND}'"
  MAGNET_UPDATE_CHDS=$(cat ${FILE_TO_SAVE} | grep -i "Set:" | grep -i "Update CHDs" | grep -i "${MAME_VERSION_TO_FIND}" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"//')
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
    echo "MAGNET_UPDATE_CHDS does not contain 'magnet' / should not exists for this version"
  fi
fi
