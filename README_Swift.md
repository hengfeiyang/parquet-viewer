# ParquetViewer Swift Package

A Swift package that provides a high-level interface to read Parquet and Arrow files using a Rust backend.

## Package Structure

This package consists of:
- **Rust Library**: Core functionality written in Rust with FFI bindings
- **Swift FFI Wrapper**: High-level Swift API that wraps the Rust FFI functions
- **Swift Package**: Proper Swift Package Manager configuration for easy integration

The package automatically links to the built Rust library and provides a clean Swift API for reading Parquet and Arrow files.

## Features

- Read schema information from Parquet/Arrow files
- Read file metadata (size, record count, version, etc.)
- Read data in batches with configurable batch sizes
- Full Swift API with proper error handling
- Support for macOS 13+ and iOS 16+

## Installation

### Prerequisites

1. **Build the Rust library first:**
   ```bash
   cargo build --release --features ffi
   ```

2. **Add the package to your Swift project:**
   
   In your `Package.swift`:
   ```swift
   dependencies: [
       .package(path: "/path/to/parquet-viewer")
   ]
   ```
   
   Or add it directly in Xcode:
   - File → Add Package Dependencies
   - Enter the local path to this package

## Usage

### Basic Example

```swift
import ParquetViewer

do {
    // Read schema
    let schema = try ParquetViewer.readSchema(filePath: "/path/to/file.parquet")
    print("Schema has \(schema.numFields) fields:")
    for field in schema.fields {
        print("- \(field.name): \(field.type)")
    }
    
    // Read metadata
    let metadata = try ParquetViewer.readMetadata(filePath: "/path/to/file.parquet")
    print("File size: \(metadata.fileSize) bytes")
    print("Total records: \(metadata.totalRecords)")
    print("Created by: \(metadata.createdBy ?? "Unknown")")
    
    // Read data
    let batches = try ParquetViewer.readData(filePath: "/path/to/file.parquet", batchSize: 1000)
    print("Read \(batches.count) batches:")
    for (index, batch) in batches.enumerated() {
        print("Batch \(index): \(batch.numRows) rows, \(batch.numColumns) columns")
        // batch.json contains the JSON representation of the data
    }
    
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Error Handling

The package provides detailed error information:

```swift
do {
    let schema = try ParquetViewer.readSchema(filePath: "/path/to/file.parquet")
} catch ParquetViewerError.invalidFilePath {
    print("Invalid file path provided")
} catch ParquetViewerError.operationFailed {
    print("Operation failed: \(ParquetViewer.getLastError())")
} catch {
    print("Unexpected error: \(error)")
}
```

## API Reference

### ParquetViewer

Main class providing static methods for file operations.

#### Methods

- `readSchema(filePath: String) throws -> Schema`
  - Reads and returns the schema information from a Parquet/Arrow file
  
- `readMetadata(filePath: String) throws -> FileMetadata`
  - Reads and returns file metadata (size, record count, version, etc.)
  
- `readData(filePath: String, batchSize: UInt = 0) throws -> [RecordBatch]`
  - Reads data from the file in batches
  - `batchSize`: Number of rows per batch (0 for default)
  
- `getLastError() -> String`
  - Returns the last error message from the underlying library

### Data Models

#### Schema
```swift
public struct Schema {
    public let fields: [SchemaField]
    public let numFields: UInt
}

public struct SchemaField {
    public let name: String
    public let type: String
}
```

#### FileMetadata
```swift
public struct FileMetadata {
    public let fileSize: UInt
    public let totalRecords: Int64
    public let totalFields: UInt
    public let totalRowGroups: UInt
    public let version: Int32
    public let createdBy: String?
    public let keyValueMetadata: [KeyValue]
}
```

#### RecordBatch
```swift
public struct RecordBatch {
    public let json: String  // JSON representation of the data
    public let numRows: UInt
    public let numColumns: UInt
}
```

#### KeyValue
```swift
public struct KeyValue {
    public let key: String
    public let value: String
}
```

### Error Types

```swift
public enum ParquetViewerError: Error, LocalizedError {
    case invalidFilePath
    case operationFailed
    case fileNotFound
    case invalidData
}
```

## Building from Source

1. Clone the repository
2. Build the Rust library with FFI support:
   ```bash
   cargo build --release --features ffi
   ```
3. The Swift package will automatically link to the built library

## License

AGPL-3.0-only - see LICENSE file for details.
