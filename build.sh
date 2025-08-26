#!/bin/bash

# Build script for ParquetViewer Swift Package
# This script builds the Rust library and copies the dynamic library to the Swift package

set -e

echo "Building Rust library..."
cargo build --release --features ffi

echo "Copying dynamic library to Swift package sources..."
cp target/release/libparquet_viewer.dylib Frameworks/

echo "Build complete! The dynamic library is now embedded in the Swift package."
echo "You can now build the Swift package or distribute it to other projects."
