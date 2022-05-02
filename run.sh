#!/usr/bin/env bash
# Copied and modified https://github.com/ndmitchell/neil/blob/6c5a2d5d5f5a5d8fde2de63794ab5da216aa4364/misc/run.sh

set -e # exit on errors

ORG=$1
PACKAGE=$2
EXECUTABLE=$3
VERSION=$4

if [[ -z "$ORG" || -z "$PACKAGE" || -z "$EXECUTABLE" || -z "$VERSION" ]]; then
  echo No arguments provided, please pass the org, repo, executable name and version as the first, second, third and fourth arguments
  exit 1
fi

shift 4

if command -v $EXECUTABLE &>/dev/null; then
  if $EXECUTABLE --version | grep -q "\bv\?${VERSION//\./\\.}"; then
    $EXECUTABLE $*
    exit
  else
    echo "$EXECUTABLE has mismatched version, needs $VERSION"
  fi
else
  echo "$EXECUTABLE is not available"
fi

case "$(uname)" in
"Darwin")
  OS=osx
  ;;
MINGW64_NT-* | MSYS_NT-*)
  OS=windows
  ;;
*)
  OS=linux
  ;;
esac

if [ "$OS" = "windows" ]; then
  EXT=.zip
  ESCEXT=\.zip
else
  EXT=.tar.gz
  ESCEXT=\.tar\.gz
fi

echo "Downloading $ORG/$PACKAGE @ $VERSION..."

# Don't go for the API since it hits the Appveyor GitHub API limit and fails
ALL_RELEASES=$(curl --silent --show-error https://github.com/$ORG/$PACKAGE/releases)
RELEASE=$(echo $ALL_RELEASES | grep -o '\"[^\"]*-'$VERSION'-x86_64-'$OS$ESCEXT'\"' | sed s/\"//g | head -n1)
if [ -z "$RELEASE" ]; then
  echo "Release $VERSION not found in $ORG/$PACKAGE"
  exit 1
fi
URL="https://github.com/$RELEASE"

TEMP=$(mktemp -d .$PACKAGE-XXXXXX)

trap "rm -rf $TEMP" EXIT

retry() {
  ($@) && return
  sleep 15
  ($@) && return
  sleep 15
  $@
}

retry curl --progress-bar --location -o$TEMP/$PACKAGE$EXT $URL
if [ "$OS" = "windows" ]; then
  7z x -y $TEMP/$PACKAGE$EXT -o$TEMP -r >/dev/null
else
  tar -xzf $TEMP/$PACKAGE$EXT -C$TEMP
fi

EXECUTABLE_DIR=$TEMP/$PACKAGE-$(echo $RELEASE | sed -n 's@.*-\(.*\)-x86_64-'$OS$ESCEXT'@\1@p')
$EXECUTABLE_DIR/$EXECUTABLE $*
