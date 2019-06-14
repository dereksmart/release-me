#!/bin/sh

# Variables
RELEASER_VERSION="1.0"
RELEASER_PATH=$(pwd)
BUILD_PATH="${RELEASER_PATH}/build"
GITHUB_ORG="Automattic"

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

output 5 "-------------------------------------------"
output 5 "          RELEASE BRANCH MANAGER           "
output 5 "-------------------------------------------"

# Set the arguments
for ARG in "$@"
do
  KEY=$(echo $ARG | cut -f1 -d=)
  VALUE=$(echo $ARG | cut -f2 -d=)

  case "$KEY" in
    -h|--help)
      echo "Usage: ./release-branch.sh [options]"
      echo
      echo "Assistant to the Release Branch Manager"
      echo
      echo "Examples:"
      echo "./release-branch.sh -n -p=\"jetpack\"  # Create a new release branch on the Jetpack repo"
      echo "./release-branch.sh -u -p=\"jetpack\"  # update a release branch on the Jetpack repo"
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
      exit 0
      ;;
    -v|--version)
      echo "Version ${RELEASER_VERSION}"
      exit 0
      ;;
    -c|--clean)
      rm -rf "$BUILD_PATH"
      output 2 "Build directory cleaned!"
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
      SRC_BRANCH="master"
      ;;
    -u|--update)
      shift
      PROCESS="update"
      ;;
    *)
      output 1 "Not valid - see \"./release-branch.sh --help\"."
      exit 1;
      ;;
  esac
  shift
done

# Check for system requirements
hash composer 2>/dev/null || {
    output 3 "This script requires you to have composer package manager installed."
    output 3 "Please install it following the instructions on https://getcomposer.org/. Aborting.";
    cleanup
}

hash yarn 2>/dev/null || {
	output 3 "This script requires you to have yarn package manager installed."
	output 3 "Please install it following the instructions on https://yarnpkg.com. Aborting.";
	cleanup
}

# Check for variable requirements
if [ -z "$PROCESS" ]; then
    output 1 "Tell me what to do: --new or --update?"
    cleanup
fi

if [ -z "$PLUGIN_SLUG" ]; then
    printf "Please enter the plugin slug: "
    read -r PLUGIN_SLUG
fi

# Set deploy variables
GIT_REPO="git@github.com:${GITHUB_ORG}/${PLUGIN_SLUG}.git"
GIT_PATH="${BUILD_PATH}/${PLUGIN_SLUG}"

# Ask info
output 2 "Let's begin..."
if [ -z "$VERSION" ]; then
    echo
    printf "VERSION: "
    read -r VERSION
fi
DEST_BRANCH="release/${VERSION}"
DEV_BRANCH="release-dev/${VERSION}"
if [ "update" == "$PROCESS" ]; then
    SRC_BRANCH="release-dev/${VERSION}"
fi
echo
echo "-------------------------------------------"
echo
echo "Review all data before proceed:"
echo
output_list 3 "Action" "${PROCESS} release branch"
output_list 3 "Plugin slug" "${PLUGIN_SLUG}"
output_list 3 "Version to ${PROCESS}" "${VERSION}"
output_list 3 "Release branch source" "${SRC_BRANCH}"
if [ "create" == "$PROCESS" ]; then
    output_list 3 "Release branch (dev) to create" "${DEV_BRANCH}"
fi
output_list 3 "Release branch to ${PROCESS}" "${DEST_BRANCH}"
output_list 3 "GIT repository" "${GIT_REPO}"
echo
printf "Are you sure? [y/N]: "
read -r PROCEED
echo
if [ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "y" ]; then
  output 1 "Release cancelled!"
  cleanup
fi

output 2 "Confirmed! Starting process..."

# Create build directory if does not exists
if [ ! -d "$BUILD_PATH" ]; then
  mkdir -p "$BUILD_PATH"
else
  printf "Existing release found. Would you like to delete it and start fresh? [y/N]: "
  read -r PROCEED
  if [ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "n" ]; then
    rm -rf "$BUILD_PATH"
    mkdir -p "$BUILD_PATH"
  fi
fi

# Clone GIT repository
output 2 "Cloning GIT repository..."
git clone "$GIT_REPO" "$GIT_PATH" --branch "$SRC_BRANCH" --depth=1 || exit "$?"
cd "$GIT_PATH"

# Create release-dev/X.X branch
if [ "create" == "$PROCESS" ]; then
    git checkout -b "$DEV_BRANCH"
    git push -u origin "$DEV_BRANCH"
fi

# Create release/X.X branch

# Run build commands
yarn build-production || exit

# Purge excluded
# @todo The idea is that we can defer to the script's directory's ".custom" file if we want to override this.
while read -r line; do
    if [[ "$line" != "#"* ]]; then
        rm -rf "$line"
    fi
done < "$GIT_PATH/.svnignore"

git checkout -b "$DEST_BRANCH"
git pull origin "$DEST_BRANCH"
git add .
git commit -m "New build!"

# Push to remote?
printf "Release branch ${PROCESS}d locally! Would you like to push to the repo?"
read -r PROCEED
if [ "$(echo "${PROCEED:-n}" | tr "[:upper:]" "[:lower:]")" != "n" ]; then
    git push -u origin "$DEST_BRANCH"
fi

echo "Done!"


