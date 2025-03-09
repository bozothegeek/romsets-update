#!/bin/bash
# example to call this script: ./qbt_inject_magnet.sh -m magnet:?xt=urn:btih:2fff... -s /home/user/ROMSETS/MAME
# script to inject any magnet URL in QBittorent via WEB UI API (need to activate WEB UI in Qbittorent )
# and if available we inject it in qbittorent to be downloaded immediately

# Check if required tool is installed
if ! [ $(command -v curl) ] ; then
  echo "Error: Please install curl before running this script."
  exit 1
fi

# Check if required tool is installed
if ! [ $(command -v qbt) ] ; then
  echo "Error: Please install qbittorent-cli (and not only qbittorent) before running this script."
  exit 1
fi

#to manage mandatory parameters
helpFunction()
{
   echo "Usage: $0 -m magnet_url -s save_path"
   echo "-m magnet_url to inject in qbittorent (mandatory)"
   echo "-s save_path to save updates (mandatory to store data to download)"
   exit 1 # Exit script after printing help
}

while getopts ":m:s:?" opt; do
   case "$opt" in
      # Define type of update: could be pre-release/release
      m ) magnet_url="$OPTARG" ;;
      s ) save_path="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$magnet_url" ] || [ -z "$save_path" ]
then
   echo "Some or all of the parameters are empty"
   helpFunction
fi

# based on: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)#api-v20
MAGNET_LINK="${magnet_url}"
SAVE_PATH="${save_path}"

if pgrep -x "qbittorrent" > /dev/null; then
  echo "qBittorrent is running."
else
  echo "qBittorrent is not running - need to launch it yourself first !"
  exit 1
fi

#QBT parameters to change if needed 
QBT_HOST="localhost"
QBT_PORT="8080"
QBT_USER="admin"
QBT_PASS="adminadmin" #Change this!

# 1. Login to get a cookie
COOKIE=$(curl -s -X POST \
  -d "username=$QBT_USER&password=$QBT_PASS" \
  "http://$QBT_HOST:$QBT_PORT/api/v2/auth/login" \
  -c cookies.txt | grep -o 'SID=.*;' )

# 2. Add the magnet link
curl -s -X POST \
  -b cookies.txt \
  -d "urls=$MAGNET_LINK&savepath=$SAVE_PATH" \
  "http://$QBT_HOST:$QBT_PORT/api/v2/torrents/add"

#optional, remove cookie file.
rm cookies.txt