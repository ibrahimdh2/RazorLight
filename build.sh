#!/bin/bash
# Cross-platform build script for Linux and macOS
# Usage: ./build.sh [debug|release|size]

set -e

TARGET="${1:-debug}"

case "$TARGET" in
    debug)
        echo "Building project (debug)..."
        odin build . -o:none -debug -out:RazorLight.bin
        ;;
    release)
        echo "Building project (release)..."
        odin build . -o:speed -out:RazorLight.bin
        ;;
    size)
        echo "Building project (size optimized)..."
        odin build . -o:size -out:RazorLight.bin
        ;;
    *)
        echo "Unknown build target: $TARGET"
        echo "Valid targets: debug, release, size"
        exit 1
        ;;
esac

echo "Build completed successfully: ./RazorLight.bin"
