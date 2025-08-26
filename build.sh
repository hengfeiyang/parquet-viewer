#!/bin/bash

# Build script for ParquetViewer Swift Package
# This script builds the Rust library for both arm64 and x86_64 architectures
# and creates a universal binary that works on both Apple Silicon and Intel Macs

set -e

echo "Building Rust library for universal binary (arm64 + x86_64)..."

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Rust is not installed. Please install Rust first: https://rustup.rs/"
    exit 1
fi

# Check if required targets are installed
echo "Checking Rust targets..."
if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
    echo "Installing aarch64-apple-darwin target..."
    rustup target add aarch64-apple-darwin
fi

if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
    echo "Installing x86_64-apple-darwin target..."
    rustup target add x86_64-apple-darwin
fi

# Build for arm64 (Apple Silicon)
echo "Building for arm64 (Apple Silicon)..."
cargo build --release --features ffi --target aarch64-apple-darwin

# Build for x86_64 (Intel)
echo "Building for x86_64 (Intel)..."
cargo build --release --features ffi --target x86_64-apple-darwin

# Create universal binary using lipo
echo "Creating universal binary..."
lipo -create \
    target/aarch64-apple-darwin/release/libparquet_viewer.dylib \
    target/x86_64-apple-darwin/release/libparquet_viewer.dylib \
    -output target/release/libparquet_viewer.dylib

# Verify the universal binary
echo "Verifying universal binary..."
file target/release/libparquet_viewer.dylib
lipo -info target/release/libparquet_viewer.dylib

echo "Copying universal dynamic library to Swift package sources..."
cp target/release/libparquet_viewer.dylib Frameworks/

echo "Build complete! The universal dynamic library now supports both arm64 and x86_64 architectures."
echo "You can now build the Swift package or distribute it to other projects."
