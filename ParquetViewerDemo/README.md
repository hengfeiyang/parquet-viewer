# Parquet Viewer SwiftUI Demo

This Swift Package Manager project contains a SwiftUI application that demonstrates how to use the `parquet-viewer` Rust library from Swift with a beautiful, native macOS interface.

## Features

- **📁 File Picker**: Select Parquet or Arrow files using the native file picker
- **📋 Schema Tab**: View file schema with field names and types
- **📊 Metadata Tab**: Display file metadata, statistics, and custom key-value pairs
- **📄 Data Tab**: Show record batch information and data preview
- **🎨 Native UI**: Beautiful SwiftUI interface with proper macOS design patterns
- **⚡ Real-time Analysis**: Instant file analysis with progress indicators

## Screenshots

The app provides a clean, tabbed interface:

1. **Welcome Screen**: When no file is selected
2. **Schema View**: Lists all fields with their data types
3. **Metadata View**: Shows file statistics and metadata
4. **Data View**: Displays record batch information

## Prerequisites

1. **Xcode 15.0+** (for SwiftUI and latest macOS features)
2. **macOS 13.0+** (minimum deployment target)
3. **Rust Library**: The Rust library must be built first

## Setup Instructions

### 1. Build the Rust Library

First, build the Rust library that this app depends on:

```bash
# From the parquet-viewer root directory
cargo build --release --features ffi
```

### 2. Set up the Swift Package

```bash
# Navigate to the XcodeProject directory
cd SwiftDemo/XcodeProject

# Run the build script to set everything up
./build.sh
```

### 3. Open in Xcode

```bash
# Open the Package.swift file in Xcode
open Package.swift
```

### 4. Build and Run

1. In Xcode, select the "ParquetViewerDemo" target
2. Choose your Mac as the destination
3. Click the "Run" button (▶️) or press `Cmd+R`

## Project Structure

```
XcodeProject/
├── Package.swift                    # Swift Package Manager manifest
├── build.sh                        # Automated build script
├── README.md                       # This file
└── Sources/
    └── ParquetViewerDemo/          # Main app source code
        ├── ParquetViewerDemoApp.swift   # Main app entry point
        ├── ContentView.swift            # Main content view with tabs
        ├── SchemaView.swift             # Schema display
        ├── MetadataView.swift           # Metadata display
        ├── DataView.swift               # Data display
        ├── ParquetViewerFFI.swift       # FFI wrapper
        ├── BasicExample.swift           # Basic usage example
        └── IntegrationExample.swift     # Advanced integration example
```

## How to Use

1. **Launch the App**: Run the app from Xcode or use `swift run ParquetViewerDemo`
2. **Select a File**: Click "Select File" to choose a Parquet or Arrow file
3. **View Analysis**: The app will automatically analyze the file and display results in three tabs:
   - **Schema**: Field names and data types
   - **Metadata**: File statistics and metadata
   - **Data**: Record batch information

## Command Line Usage

You can also run the app directly from the command line:

```bash
cd SwiftDemo/XcodeProject
swift run ParquetViewerDemo
```

## Technical Details

### Library Integration

The app integrates the Rust library through:

- **FFI Wrapper**: `ParquetViewerFFI.swift` provides safe Swift interfaces
- **Library Linking**: The Rust library is linked via Swift Package Manager
- **Runtime Path**: Library path is set up in the app initialization

### SwiftUI Architecture

- **ContentView**: Main container with file picker and tab view
- **SchemaView**: Displays file schema in a clean list format
- **MetadataView**: Shows metadata in organized sections
- **DataView**: Lists record batches with preview information

### Error Handling

- **File Access**: Proper security-scoped resource handling
- **Async Processing**: Background file analysis with UI updates
- **Error Display**: User-friendly error messages

## Customization

### Adding New Features

1. **New Views**: Add SwiftUI views to the `Sources/ParquetViewerDemo/` directory
2. **FFI Functions**: Extend `ParquetViewerFFI.swift` with new functions
3. **UI Components**: Create reusable SwiftUI components

### Styling

The app uses native macOS design patterns:
- System colors and fonts
- Proper spacing and layout
- Accessibility support
- Dark mode compatibility

## Troubleshooting

### Common Issues

1. **Library Not Found**: Ensure the Rust library is built and accessible
2. **Build Errors**: Check that all Swift files are included in the package
3. **Runtime Errors**: Verify file permissions and access

### Debug Tips

- Use Xcode's console to see error messages
- Check the library path in the app initialization
- Verify file format support

## Performance

The app is designed for performance:
- **Async Processing**: File analysis runs in background
- **Memory Efficient**: Processes files in batches
- **UI Responsive**: Non-blocking user interface

## Contributing

To contribute to this demo:

1. Fork the repository
2. Make your changes
3. Test with various file types
4. Submit a pull request

## License

This demo is provided under the same license as the main `parquet-viewer` library.

---

**Enjoy exploring your Parquet and Arrow files with this beautiful SwiftUI interface!** 🎉
