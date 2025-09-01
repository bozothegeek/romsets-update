#!/bin/bash

#First, ensure that aria2 is installed on your system. Most Linux distributions have it in their default repositories.
#Debian/Ubuntu: sudo apt-get install aria2
#Fedora/RHEL: sudo dnf install aria2
# Magnet link to process
MAGNET_LINK="magnet:?xt=urn:btih:2fb700439ced9401e5032f908acdb6fb508b5666&dn=MAME%200.280%20ROMs%20(non-merged)&xl=156301797287&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fexodus.desync.com%3A6969%2Fannounce"

# Run aria2c to fetch the .torrent file
echo "Fetching .torrent file from magnet link..."
aria2c "$MAGNET_LINK" --bt-metadata-only=true --bt-save-metadata

# Check if the command was successful
if [ $? -eq 0 ]; then
    echo "Successfully downloaded the .torrent file."
else
    echo "Failed to download the .torrent file."
fi