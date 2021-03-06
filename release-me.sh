#!/bin/bash
# Release branch management!

# Variables
RELEASER_VERSION="1.0"
RELEASER_PATH=$(pwd)
BUILD_PATH="${RELEASER_PATH}/build"
DEV_PATH="${BUILD_PATH}/dev"
RELEASE_PATH="${BUILD_PATH}/release"
# Writable
GITHUB_ORG="" # Default `Automattic`
PLUGIN_SLUG="" # Default `vaultpress`
BUILD_COMMAND="" # Default `yarn build-production`

# We'll need to do this later
FULL_COMMAND="./release-me.sh"
add_to_full_command() {
    FULL_COMMAND="$FULL_COMMAND $1"
}

# Functions

# Color codes:
# 0 - black
# 1 - red
# 2 - green
# 3 - yellow
# 4 - blue
# 5 - magenta
# 6 - cian
# 7 - white
output() {
  echo "$(tput setaf "$1")$2$(tput sgr0)"
}

# Output colorized list
output_list() {
  echo "$(tput setaf "$1") • $2:$(tput sgr0) \"$3\""
}

cleanup() {
    cd "$RELEASER_PATH"
    rm -rf "$BUILD_PATH"
    exit 1
}

usage() {
    echo "Usage: ./release-me.sh [options]"
    echo
    output 2 "RELEASE ME"
    echo "Assistant to the Release Branch Manager"
    echo
    echo "Examples:"
    echo "./release-me.sh -n -p=\"jetpack\"  # Create a new release branch on the Jetpack repo"
    echo "./release-me.sh -u -p=\"jetpack\"  # update a release branch on the Jetpack repo"
    echo
    echo "Available options:"
    echo "  -h [--help]              Shows help message"
    echo "  -v [--version]           Shows script version"
    echo "  -r [--release]           The release number you are branching"
    echo "  -c [--clean]             Clean build directory"
    echo "  -p [--plugin-slug]       Plugin's slug"
    echo "  -o [--github-org]        GitHub organization (defaults to \"automattic\")"
    echo "  -b [--branch]            Branch to base the release from. Defaults to \"master\""
    echo "  -n [--new]               Start a new release branch"
    echo "  -u [--update]            Update existing release branch"
    exit 1
}

output 5 "-------------------------------------------"
output 5 "          RELEASE BRANCH MANAGER           "
output 5 "-------------------------------------------"

# Source custom variables if a .custom file exists
if [[ -f "./custom" ]]; then
    output 3 "Fetching your custom configuration from the .custom file..."
	source ./.custom
fi

# Set the arguments
for ARG in "$@"
do
  KEY=$(echo "$ARG" | cut -f1 -d=)
  VALUE=$(echo "$ARG" | cut -f2 -d=)

  case "$KEY" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      echo "Version ${RELEASER_VERSION}"
      exit 0
      ;;
    -c|--clean)
      rm -rf "$BUILD_PATH"
      output 2 "Build directory cleaned!"
      exit 0
      ;;
    -r|--release)
      shift
      VERSION=${VALUE}
      ;;
    -p|--plugin-slug)
      shift
      PLUGIN_SLUG=${VALUE}
      ;;
    -o|--github-org)
      shift
      GITHUB_ORG=${VALUE}
      ;;
    -b|--branch)
      shift
      SRC_BRANCH=${VALUE}
      ;;
    -n|--new)
      shift
      PROCESS="create"
      ;;
    -u|--update)
      shift
      PROCESS="update"
      ;;
    *)
      output 1 "Not valid - see \"./release-me.sh --help\"."
      usage
      ;;
  esac
  shift
done

output 3 "Checking for system requirements..."

# Check for system requirements
hash composer 2>/dev/null || {
    output 1 "This script requires you to have composer package manager installed."
    output 3 "Please install it following the instructions on https://getcomposer.org/. Aborting.";
    cleanup
}

hash yarn 2>/dev/null || {
	output 1 "This script requires you to have yarn package manager installed."
	output 3 "Please install it following the instructions on https://yarnpkg.com. Aborting.";
	cleanup
}

output 2 "Requirements there!"

# Ask for variable requirements
if [[ -z "$PROCESS" ]]; then
    output 3 "Are you here to create a new release branch or update existing? Enter one: create | update"
    read -r PROCESS
    PROCESS=${PROCESS}
    if [[ "create" != "$PROCESS" ]] && [[ "update" != "$PROCESS" ]]; then
        output 1 "Try again with the -n (new) or -u (update) parameter."
        usage
    fi
fi
if [[ 'create' == "$PROCESS" ]]; then
    add_to_full_command "-n"
elif [[ 'update' == "$PROCESS" ]]; then
    add_to_full_command "-u"
fi

if [[ -z "$PLUGIN_SLUG" ]]; then
    output 3 "Please enter the plugin slug: (Press enter for 'vaultpress')"
    read -r PLUGIN_SLUG
    PLUGIN_SLUG=${PLUGIN_SLUG:-vaultpress}
fi
add_to_full_command "-p=\"$PLUGIN_SLUG\""

if [[ -z "$GITHUB_ORG" ]]; then
    output 3 "Please enter the repo org: (Press enter for 'Automattic')"
    read -r GITHUB_ORG
    GITHUB_ORG=${GITHUB_ORG:-Automattic}
fi
add_to_full_command "-o=\"$GITHUB_ORG\""

# Set deploy variables
GIT_REPO="git@github.com:${GITHUB_ORG}/${PLUGIN_SLUG}.git"
GIT_PATH="${DEV_PATH}/${PLUGIN_SLUG}"
GIT_PATH_RELEASE="${RELEASE_PATH}/${PLUGIN_SLUG}"

if [[ -z "$VERSION" ]]; then
    output 3 "What version are you releasing?"
    read -r VERSION
    if [[ -z "$VERSION" ]]; then
        output 1 "We need a version number!"
        usage
    fi
fi
add_to_full_command "-r=\"$VERSION\""

DEST_BRANCH="release/${VERSION}"
DEV_BRANCH="release/${VERSION}-dev"
if [[ -z "$SRC_BRANCH" ]]; then
    if [[ "update" == "$PROCESS" ]]; then
        SRC_BRANCH="release/${VERSION}-dev"
    else
        SRC_BRANCH="master"
    fi
fi
add_to_full_command "-b=\"$SRC_BRANCH\""
echo
echo "-------------------------------------------"
echo
echo "Review all data before proceed:"
echo
output_list 3 "Action" "${PROCESS} release branch"
output_list 3 "Plugin slug" "${PLUGIN_SLUG}"
output_list 3 "Version to ${PROCESS}" "${VERSION}"
output_list 3 "Release branch source" "${SRC_BRANCH}"
if [[ "create" == "$PROCESS" ]]; then
    output_list 3 "Release branch (dev) to create" "${DEV_BRANCH}"
fi
output_list 3 "Release branch to ${PROCESS}" "${DEST_BRANCH}"
output_list 3 "GIT repository" "${GIT_REPO}"
echo
output_list 5 "Full command: " "$FULL_COMMAND"
echo
printf "Are you sure? [y/N]: "
read -r PROCEED
echo
if [[ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "y" ]]; then
  output 1 "Release cancelled!"
  cleanup
fi

output 2 "Confirmed! Starting process..."

# Make sure that "new" is not trying to create something that already exists
if [[ "create" == "$PROCESS" ]]; then
    output 5 "@todo check if branch exists"
fi

# Create build directory if does not exists
if [[ ! -d "$BUILD_PATH" ]]; then
  mkdir -p "$BUILD_PATH"
  mkdir -p "$RELEASE_PATH"
else
  printf "Existing release found. Would you like to delete it and start fresh? [y/N]: "
  read -r PROCEED
  if [[ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "n" ]]; then
    rm -rf "$BUILD_PATH" "$RELEASE_PATH"
    mkdir -p "$BUILD_PATH"
    mkdir -p "$RELEASE_PATH"
  fi
fi

# Clone GIT repository
output 2 "Cloning GIT repository..."
git clone "$GIT_REPO" "$GIT_PATH" --branch "$SRC_BRANCH" --single-branch --depth=1 || exit "$?"
cd "$GIT_PATH"

# Get main file and readme.txt versions
# @todo use them somewhere?
PLUGIN_VERSION_HEADER=$(grep -i "Version:" "$GIT_PATH/vaultpress.php" | awk '{print $3}' | sed "s/[',\"]//g")
PLUGIN_VERSION_CONSTANT=$(grep -i "VAULTPRESS__VERSION" "$GIT_PATH/vaultpress.php" | awk '{print $3}' | sed "s/[',\"]//g")
PLUGIN_VERSION_PACKAGE=$(grep -i "version" "$GIT_PATH/package.json" | awk '{print $2}' | sed "s/[',\"]//g")
README_VERSION=$(grep -i "Stable tag:" "$GIT_PATH/readme.txt" | awk '{print $3}' | sed "s/[',\"]//g")

# Create release/X.X-dev branch
if [[ "create" == "$PROCESS" ]]; then
    git checkout -b "$DEV_BRANCH"
    git push -u origin "$DEV_BRANCH"
fi

# Run build commands
# @todo this should be over-writable by custom command defined in .custom file
if [[ ! -z "$BUILD_COMMAND" ]]; then
    eval "$BUILD_COMMAND" || exit
else
    yarn build-production || exit
fi

# Purge dev files from release branch.
# Will purge any files found in:
# - .releaseignore in this directory's root
# - .releaseignore in the plugin directory's root
# - .svnignore in the plugin directory's root (legacy/deprecated)
output 3 "Purging file paths found in ./releaseignore..."
RELEASEIGNORE=$(cat "$RELEASER_PATH"/.releaseignore "$GIT_PATH"/.releaseignore "$GIT_PATH"/.svnignore 2>/dev/null)
while read -r line; do
    if [[ "$line" != "#"* ]] && [[ ! -z "$line" ]] && [[ "$line" != "!"* ]]; then
        rm -rf "$line"
        output 1 "$line"
    fi
done <<< "$RELEASEIGNORE"

output 2 "Done purging files!"

# Create or clone release/X.X branch
if [[ "update" == "$PROCESS" ]]; then
    git clone "$GIT_REPO" "$GIT_PATH_RELEASE" --branch "$DEST_BRANCH" --single-branch --depth=1 || exit "$?"
fi

# Bring changes to release build
rsync -r --delete --exclude="*.git*" "$GIT_PATH"/* "$GIT_PATH_RELEASE"

if [[ "update" == "$PROCESS" ]]; then
    cd "$GIT_PATH_RELEASE"
elif [[ "create" == "$PROCESS" ]]; then
    git checkout -b "$DEST_BRANCH"
fi
git add .
git commit -am "New Build!"

# Push to remote?
printf "Release branch ${PROCESS}d locally! Would you like to push to the repo? [y/N]: "
read -r PROCEED
if [[ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "n" ]]; then
    if [[ "create" == "$PROCESS" ]]; then
        git push -u origin "$DEST_BRANCH"
    else
        git push
    fi
fi

echo "Done!"
