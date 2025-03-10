#!/bin/bash
# script to launch mame romset update
# example of call of this script for manual validation: ./launch_mame_romset_update.sh
# example using for recurrent running: (time ./launch_mame_romset_update.sh) > report_$(date +%Y-%m-%d_%H-%M-%S).txt 2>&1

helpFunction()
{
   echo "Usage: $0 -v mame_version"
   echo "-v mame_version to force update version (optional)"
   exit 1 # Exit script after printing help
}

while getopts ":v:?" opt; do
   case "$opt" in
      v ) mame_version="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Define variables (replace with your details)
GITHUB_TAG_NAME=mame${mame_version}
SAVE_PATH=/home/bozo/ROMSETS/MAME # CHANGE WITH YOUR LOCAL DOWNLOAD/SAVE PATH !
UPDATES_LIST_URL=https://pleasuredome.github.io/pleasuredome/mame/index.html # CHANGE WITH REPO/SITE URL WITH UPDATES MAGNET URLS

#clean files in all cases before to get info (in case of any previous stop of the script on issue)
rm -f version.txt
rm -f commit.txt
rm -f date.txt
rm -f release_notes.md
rm -f release_id.txt

if [ -z "$mame_version" ] ; then
	bash ./get_mame_repo_info.sh -u mamedev -r mame
else
	bash ./get_mame_repo_info.sh -u mamedev -r mame -n ${GITHUB_TAG_NAME}
fi
# Print success or error message
if [ $? -eq 0 ]; then
  echo "get mame repo informations successful!"
else
  echo "get mame repo informations failed!"
  exit 1
fi

# check if a version if available in file (coming from a previous script executed that get version from original repo/alternbative repo)
if test -f "${PWD}/version.txt" ; then
  VERSION=$(cat ${PWD}/version.txt) #format of version in .txt file should follow the standard format as vX.Y.Z
  # remove everything to have numeric version only for thiks mk file
  UPDATE_VERSION=${VERSION//v/}
else  
  echo "version.txt not found!"
  exit 1
fi

bash ./update_romset_by_version.sh -v ${UPDATE_VERSION} -s ${SAVE_PATH} -u ${UPDATES_LIST_URL}

# Clean up if no issue only
rm -f version.txt
rm -f commit.txt
rm -f date.txt
rm -f release_notes.md
rm -f release_id.txt
