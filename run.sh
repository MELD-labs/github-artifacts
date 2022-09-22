#!/usr/bin/env bash
# Copied and modified https://github.com/ndmitchell/neil/blob/6c5a2d5d5f5a5d8fde2de63794ab5da216aa4364/misc/run.sh

set -e # exit on errors

ORG=$1
PACKAGE=$2
VERSION=$3
SUFFIX=$4

if [[ -z "$ORG" || -z "$PACKAGE" || -z "$VERSION" || -z "$SUFFIX" ]]; then
  echo No arguments provided, please pass the org, repo, version and hosted file suffix as the arguments.
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
  export OS=osx
  ;;
MINGW64_NT-* | MSYS_NT-*)
  export OS=windows
  ;;
*)
  export OS=linux
  ;;
esac

if [ "$OS" = "windows" ]; then
  export EXT=.zip
else
  export EXT=.tar.gz
fi

echo "Downloading $ORG/$PACKAGE @ $VERSION..."

EXPANDED_SUFFIX=$(envsubst <<< $SUFFIX)

URL="https://github.com/$ORG/$PACKAGE/releases/download/v$VERSION/$PACKAGE-$VERSION$EXPANDED_SUFFIX"

TEMP=$(mktemp -d .$PACKAGE-XXXXXX)

trap "rm -rf $TEMP" EXIT

retry() {
  ($@) && return
  sleep 15
  ($@) && return
  sleep 15
  $@
}

EXECUTABLE_DIR="$TEMP/$PACKAGE-$VERSION"

if [[ $EXPANDED_SUFFIX == *$EXT ]]; then
  retry curl --progress-bar --location -o$TEMP/$PACKAGE$EXT $URL
  if [ "$OS" = "windows" ]; then
    7z x -y $TEMP/$PACKAGE$EXT -o$TEMP -r >/dev/null
  else
    tar -xzf $TEMP/$PACKAGE$EXT -C$TEMP
  fi
else
  mkdir $EXECUTABLE_DIR
  retry curl --progress-bar --location -o$EXECUTABLE_DIR/$PACKAGE $URL
  chmod +x $EXECUTABLE_DIR/$PACKAGE
fi

$EXECUTABLE_DIR/$PACKAGE $*
