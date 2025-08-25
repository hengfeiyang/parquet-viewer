#!/bin/bash

# Parquet Viewer SwiftUI Demo Build Script
# This script builds the Rust library and prepares the Swift Package Manager project

set -e  # Exit on any error

echo "🚀 Building Parquet Viewer SwiftUI Demo"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    print_error "This script must be run from the XcodeProject directory"
    exit 1
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    print_error "Rust is not installed. Please install Rust first: https://rustup.rs/"
    exit 1
fi

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    print_error "Swift is not installed. Please install Xcode from the App Store."
    exit 1
fi

print_status "Checking prerequisites..."

# Get the path to the Rust library
RUST_LIB_DIR="../../target/release"
RUST_LIB_NAME="libparquet_viewer.dylib"

# Check if the Rust library exists
if [ ! -f "$RUST_LIB_DIR/$RUST_LIB_NAME" ]; then
    print_warning "Rust library not found. Building it now..."
    
    # Check if we can find the Rust project
    if [ -f "../../Cargo.toml" ]; then
        print_status "Building Rust library..."
        cd ../..
        cargo build --release --features ffi
        cd SwiftDemo/XcodeProject
        print_success "Rust library built successfully"
    else
        print_error "Could not find Rust project in parent directory"
        print_error "Please build the Rust library manually:"
        print_error "  cd ../.. && cargo build --release --features ffi"
        exit 1
    fi
else
    print_success "Rust library found"
fi

# Build the Swift package
print_status "Building Swift package..."
if swift build; then
    print_success "Swift package built successfully"
else
    print_error "Swift package build failed"
    exit 1
fi

echo ""
print_success "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode:"
echo "   open Package.swift"
echo ""
echo "2. In Xcode:"
echo "   - Select the 'ParquetViewerDemo' target"
echo "   - Choose your Mac as the destination"
echo "   - Click the Run button (▶️) or press Cmd+R"
echo ""
echo "3. The app will launch and you can:"
echo "   - Click 'Select File' to choose a Parquet or Arrow file"
echo "   - View the schema, metadata, and data in the tabs"
echo ""
echo "Alternative: Run from command line:"
echo "  swift run ParquetViewerDemo"
echo ""
echo "Note: Make sure the Rust library is accessible:"
echo "  Library location: $RUST_LIB_DIR/$RUST_LIB_NAME"
