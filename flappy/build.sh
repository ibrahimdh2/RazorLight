#!/bin/bash
# Build script for hot-reload project

set -e

TARGET=${1:-debug}

case "$TARGET" in
    debug)
        OPT="-o:none -debug"
        ;;
    release)
        OPT="-o:speed"
        ;;
    *)
        echo "Usage: ./build.sh [debug|release]"
        exit 1
        ;;
esac

echo "Building game library..."
odin build game -build-mode:shared -out:game.so $OPT
echo "Game library built."

echo "Building host..."
odin build host -out:flappy $OPT
echo "Host built."

echo "Done! Run with: ./flappy"
