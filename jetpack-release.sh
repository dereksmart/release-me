#!/bin/bash
# Release branch management!

# Variables
RELEASER_PATH=$(pwd)
BUILD_PATH="${RELEASER_PATH}/build"
DEV_PATH="${BUILD_PATH}/dev"
RELEASE_PATH="${BUILD_PATH}/release"
BUILD_COMMAND="yarn build-production" # Default `yarn build-production`

# Writable
GITHUB_ORG="" # Default `Automattic`
PLUGIN_SLUG="" # Default `jetpack`

# We'll need to do this later
FULL_COMMAND="./jetpack-release.sh"
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
    output 2 "Jetpack Release Branch"
    echo "Jetpack release branching"
    echo
    echo "Examples:"
    echo "./release-me.sh -n"  # Create a new release branch on the Jetpack repo
    echo "./release-me.sh -u"  # update a release branch on the Jetpack repo"
    echo
    echo "Available options:"
    echo "  -h [--help]              Shows help message."
    echo "  -v [--version]           The version you are branching for."
    echo "  -n [--new]               Start a new release branch."
    echo "  -u [--update]            Update existing release branch."
    echo "  -p [--plugin-slug]       Plugin's slug (defaults to 'jetpack')"
    echo "  -o [--github-org]        GitHub organization (defaults to 'Automattic')"
    echo "  -b [--branch]            Branch to base the release from. Defaults to 'master'."
    echo "  -c [--clean]             Clean build directory."
    exit 1
}

output 5 "-------------------------------------------"
output 5 "          RELEASE BRANCH MANAGER           "
output 5 "-------------------------------------------"

# Set the arguments
for ARG in "$@"
do
  KEY=$(printf -- "$ARG" | cut -f1 -d=)
  VALUE=$(printf -- "$ARG" | cut -f2 -d=)

  case "$KEY" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      shift
      VERSION=${VALUE}
      ;;
    -n|--new)
      shift
      PROCESS="create"
      ;;
    -u|--update)
      shift
      PROCESS="update"
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
    -c|--clean)
      rm -rf "$BUILD_PATH"
      output 2 "Build directory cleaned!"
      exit 0
      ;;
    *)
      output 1 "Not valid - see \"./jetpack-release.sh --help\"."
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
    PLUGIN_SLUG=${PLUGIN_SLUG:-jetpack}
fi
add_to_full_command "-p=\"$PLUGIN_SLUG\""

if [[ -z "$GITHUB_ORG" ]]; then
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
add_to_full_command "-v=\"$VERSION\""

DEST_BRANCH="branch-${VERSION}-built"
DEV_BRANCH="branch-${VERSION}"
if [[ -z "$SRC_BRANCH" ]]; then
    if [[ "update" == "$PROCESS" ]]; then
        SRC_BRANCH="branch-${VERSION}"
    else
        SRC_BRANCH="master"
    fi
fi
add_to_full_command "-b=\"$SRC_BRANCH\""

# Ask if they want to update the file versions.
read -p "Do you want to update the version in files? [y/N]" reply
if [[ 'y' == $reply || 'Y' == $reply ]]; then
    UPDATE_VERSION_NUMBER="yes"
else
    UPDATE_VERSION_NUMBER="no"
fi

echo
echo "-------------------------------------------"
echo
echo "Review all data before proceed:"
echo
output_list 3 "Action" "${PROCESS} release branch"
output_list 3 "Version to ${PROCESS}" "${VERSION}"
output_list 3 "Update version numbers in files?" "${UPDATE_VERSION_NUMBER}"
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
    if [[ -n $( git branch -r | grep "$DEV_BRANCH" ) ]]; then
        output 1 "$DEV_BRANCH already exists.  Exiting..."
        exit 1
    fi
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
output 2 "Cloning fresh from Git repository..."
git clone "$GIT_REPO" "$GIT_PATH" --branch "$SRC_BRANCH" --single-branch --depth=1 || exit "$?"
cd "$GIT_PATH"

# Update Versions?
if [[ $UPDATE_VERSION_NUMBER == 'yes' ]]; then
    "$GIT_PATH/tools/version-update.sh"
fi

# Create branch-X.X branch
if [[ "create" == "$PROCESS" ]]; then
    output 3 "Creating and pushing $DEV_BRANCH to the repo..."

    git checkout -b "$DEV_BRANCH"
    git push -u origin "$DEV_BRANCH"

    output 2 "Done!"
fi

# Run build commands
output 3 "Running the build command..."
$BUILD_COMMAND || exit
output 2 "Done!"

# Purge dev files from release branch.
output 3 "Purging file paths found in ./svnignore..."
# We'll be making some exceptions.
for file in $( cat "$GIT_PATH/.svnignore" 2>/dev/null ); do
    # We want to keep testing instructions.
    if [[ $file == "to-test.md" ]]; then
        continue;
    fi

    # Let's keep .git for now, since we'll be committing into that branch later on.
    if [[ $file == ".git" ]]; then
        continue;
    fi

    # Let's keep tools. We use them within the release branches.
    if [[ $file == "tools" ]]; then
        continue;
    fi

    rm -rf $file
done
output 2 "Done purging files!"

# Create or clone branch-X.X branch
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
