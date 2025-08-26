#!/bin/bash

# Script to verify the architecture of the built library
# This helps confirm that the universal binary was created correctly

set -e

echo "🔍 Verifying Library Architecture"
echo "=================================="

LIB_PATH="target/release/libparquet_viewer.dylib"

if [ ! -f "$LIB_PATH" ]; then
    echo "❌ Library not found at $LIB_PATH"
    echo "Please run ./build.sh first to build the library"
    exit 1
fi

echo ""
echo "📁 Library file information:"
file "$LIB_PATH"

echo ""
echo "🏗️  Architecture details:"
lipo -info "$LIB_PATH"

echo ""
echo "🔧 Detailed architecture breakdown:"
lipo -detailed_info "$LIB_PATH"

echo ""
echo "📊 File size:"
ls -lh "$LIB_PATH"

echo ""
echo "✅ Architecture verification complete!"
echo ""
echo "The library should show '2 architectures' if it's a proper universal binary:"
echo "  - arm64 (Apple Silicon)"
echo "  - x86_64 (Intel)"
