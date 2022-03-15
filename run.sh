#!/bin/sh
# Copied and modified https://github.com/ndmitchell/neil/blob/6c5a2d5d5f5a5d8fde2de63794ab5da216aa4364/misc/run.sh

set -e # exit on errors

ORG=$1
PACKAGE=$2
EXECUTABLE=$3
if [[ -z "$ORG" || -z "$PACKAGE" || -z "$EXECUTABLE" ]]; then
    echo No arguments provided, please pass the org, repo and executable name as the first, second and third arguments
    exit 1
fi

shift 3

if command -v $EXECUTABLE &> /dev/null; then
    command -v $EXECUTABLE
    $EXECUTABLE $*
    exit
fi
command -v $EXECUTABLE

case "$(uname)" in
    "Darwin")
        OS=osx;;
    MINGW64_NT-*|MSYS_NT-*)
        OS=windows;;
    *)
        OS=linux
esac

if [ "$OS" = "windows" ]; then
    EXT=.zip
    ESCEXT=\.zip
else
    EXT=.tar.gz
    ESCEXT=\.tar\.gz
fi

echo Downloading and running $ORG/$PACKAGE...
# Don't go for the API since it hits the Appveyor GitHub API limit and fails
RELEASES=$(curl --silent --show-error https://github.com/$ORG/$PACKAGE/releases)
URL=https://github.com/$(echo $RELEASES | grep -o '\"[^\"]*-x86_64-'$OS$ESCEXT'\"' | sed s/\"//g | head -n1)
VERSION=$(echo $URL | sed -n 's@.*-\(.*\)-x86_64-'$OS$ESCEXT'@\1@p')
TEMP=$(mktemp -d .$PACKAGE-XXXXXX)

cleanup(){
    rm -r $TEMP
}
trap cleanup EXIT

retry(){
    ($@) && return
    sleep 15
    ($@) && return
    sleep 15
    $@
}

retry curl --progress-bar --location -o$TEMP/$PACKAGE$EXT $URL
if [ "$OS" = "windows" ]; then
    7z x -y $TEMP/$PACKAGE$EXT -o$TEMP -r > /dev/null
else
    tar -xzf $TEMP/$PACKAGE$EXT -C$TEMP
fi
$TEMP/$PACKAGE-$VERSION/$EXECUTABLE $*
