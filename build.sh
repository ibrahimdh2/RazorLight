#!/bin/bash
# Cross-platform build script for Linux and macOS
# Usage: ./build.sh [debug|release|size]

set -e

TARGET="${1:-debug}"

case "$TARGET" in
    debug)
        echo "Building project (debug)..."
        odin run . -o:none -debug
        ;;
    release)
        echo "Building project (release)..."
        odin run . -o:speed
        ;;
    size)
        echo "Building project (size optimized)..."
        odin run . -o:size
        ;;
    *)
        echo "Unknown build target: $TARGET"
        echo "Valid targets: debug, release, size"
        exit 1
        ;;
esac

echo "Build completed successfully!"
