#!/bin/bash

# example of call of this script to target last version (no need token finally to get info in this case): ./get_mame_repo_info.sh -u mamedev -r mame
# example of call of this script to target a specific version using tag (no need token finally to get info in this case): ./get_mame_repo_info.sh -u mamedev -r mame -n mame0273

# Check if required tool is installed
if ! command -v git &> /dev/null; then
  echo "Error: Please install git before running this script."
  exit 1
fi
# Check if required tool is installed
if ! command -v curl &> /dev/null; then
  echo "Error: Please install curl before running this script."
  exit 1
fi
# Check if required ool is installed
if ! command -v wget &> /dev/null; then
  echo "Error: Please install wget before running this script."
  exit 1
fi

#to manage mandatory parameters
helpFunction()
{
   echo "Usage: $0 -u github_user -r github_repo -g github_token -n github_tag_name"
   echo "-u github user"
   echo "-r github repo"
   echo "-g github token (optional depending usage)"
   echo "-n github tag name (optional depending usage)"
   exit 1 # Exit script after printing help
}

while getopts ":u:r:g:n:?" opt; do
   case "$opt" in
      # Define type of update: could be pre-release/release
      u ) github_user="$OPTARG" ;;
      r ) github_repo="$OPTARG" ;;
      g ) github_token="$OPTARG" ;;
      n ) github_tag_name="$OPTARG" ;;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$github_user" ] || [ -z "$github_repo" ]
then
   echo "Some or all of the parameters are empty"
   helpFunction
fi

# Define variables (replace with your details)
GITHUB_API_URL="https://api.github.com/repos"
GITHUB_USER=${github_user}  
GITHUB_REPO=${github_repo}
GITHUB_TOKEN=${github_token}  # Personal access token with repo:releases permission - not used in this script
GITHUB_TAG_NAME=${github_tag_name}

# Authenticate with GitHub using personal access token (not used finally !!!)
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

# get last version of release/tag
# specific to libretro mame
REPO_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO.git"

# Get tags information from remote repository using tag name or using last version released
if [ -z "$github_tag_name" ] ; then
	TAGS_INFO=$(git ls-remote --tags "$REPO_URL" | grep -i "mame" | tail -1 |  awk -F'mame' '{print $2}' | sed 's/[^0-9]//g') 
	TAGS_HASH=$(git ls-remote --tags "$REPO_URL" | grep -i "mame" | tail -1 |  awk -F' ' '{print $1}')
else
	TAGS_INFO=$(git ls-remote --tags "$REPO_URL" | grep -i "${github_tag_name}" | tail -1 |  awk -F'mame' '{print $2}' | sed 's/[^0-9]//g') 
	TAGS_HASH=$(git ls-remote --tags "$REPO_URL" | grep -i "${github_tag_name}" | tail -1 |  awk -F' ' '{print $1}')
fi
echo "TAGS_INFO: $TAGS_INFO"
echo "TAGS_HASH: $TAGS_HASH"
commit_sha="${TAGS_HASH}"
echo  "$commit_sha"> commit.txt

# Make additional API call to get commit details (including date and more)
#commit_details=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "$GITHUB_API_URL/$GITHUB_USER/$GITHUB_REPO/commits/$commit_sha")
#echo "commit_details: $commit_details"

TAGS_DATE=$(curl -sSL -H "Accept: application/vnd.github.v3+json" "$GITHUB_API_URL/$GITHUB_USER/$GITHUB_REPO/commits/$commit_sha" | grep -i -m 1 '"date":' | awk -F'"' '{print $4}')
echo "TAGS_DATE: $TAGS_DATE"
echo  "$TAGS_DATE"> date.txt

# remove evrything to have no risk of bad format
NUMERIC_VERSION=${TAGS_INFO//v/}
NUMERIC_VERSION=${NUMERIC_VERSION//./}
echo "NUMERIC_VERSION: $NUMERIC_VERSION"

#recreate PIXL_VERSION from NUMERIC one
PIXL_VERSION=$(echo "v$NUMERIC_VERSION" | sed -e "s/v0/v0./g")
echo "PIXL_VERSION: $PIXL_VERSION"
echo  "$PIXL_VERSION"> version.txt

# download release note from mame repo using "numeric" version
#echo "release_notes.md: https://github.com/mamedev/mame/releases/download/mame${NUMERIC_VERSION}/whatsnew_${NUMERIC_VERSION}.txt"
wget -O release_notes.md https://github.com/mamedev/mame/releases/download/mame${NUMERIC_VERSION}/whatsnew_${NUMERIC_VERSION}.txt
# Print success or error message
if [ $? -eq 0 ]; then
  echo "version ${NUMERIC_VERSION} available (whatsnew file downloaded) !"
else
  echo "version ${NUMERIC_VERSION} not available !"
  exit 1
fi
