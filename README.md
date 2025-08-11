# Parquet Viewer

Parquet Viewer is a Rust library and CLI tool that allows you to read Parquet and Arrow files. It provides both a native Rust API and C FFI bindings for integration with other languages like Swift.

## Features

- Read both Parquet and Arrow (IPC/Feather) files
- Extract schema and field information
- Read file metadata including:
  - File size, total records, total fields, total row groups
  - File version, creator information
  - Key-value metadata pairs
- Read actual data with optional batch processing
- Column projection support for selective reading
- C FFI bindings for Swift/Objective-C integration

## Installation

### As a Rust Library

Add to your `Cargo.toml`:

```toml
[dependencies]
parquet-viewer = { path = "path/to/parquet-viewer" }
```

### For Swift Integration

Build the dynamic library with FFI support:

```bash
# Build release version with FFI support
cargo build --release --features ffi

# The dynamic library will be created at:
# macOS: target/release/libparquet_viewer.dylib
# Linux: target/release/libparquet_viewer.so
# Windows: target/release/parquet_viewer.dll
```

## Rust API

### Public Functions

```rust
use parquet_viewer::{read_schema, read_metadata, read_data};
use std::path::Path;

// Read schema
let schema = read_schema(Path::new("data.parquet"))?;

// Read metadata
let metadata = read_metadata(Path::new("data.parquet"))?;
println!("Total records: {}", metadata.total_records);

// Read data
let batches = read_data(Path::new("data.parquet"), Some(1024))?;
```

## CLI Usage

```bash
# Read schema
parquet-viewer schema data.parquet

# Read metadata
parquet-viewer metadata data.parquet

# Read data with options
parquet-viewer data data.parquet --batch-size 1024 --limit 100
```

## Swift Integration Guide

### 1. Build the Library

First, build the Rust library with FFI support:

```bash
cargo build --release --features ffi
```

### 2. Add to Xcode Project

1. Copy the generated library and header file to your Xcode project:
   - `target/release/libparquet_viewer.dylib` (for macOS)
   - `parquet_viewer.h`

2. In Xcode:
   - Add `libparquet_viewer.dylib` to your project (drag and drop)
   - Add to "Frameworks, Libraries, and Embedded Content"
   - Set "Embed & Sign" for the library
   - Add `parquet_viewer.h` to your project

3. Create a bridging header (if not exists):
   - File → New → File → Header File
   - Name it `YourProject-Bridging-Header.h`
   - Add: `#import "parquet_viewer.h"`

4. Configure build settings:
   - Go to Build Settings
   - Search for "Objective-C Bridging Header"
   - Set it to `YourProject/YourProject-Bridging-Header.h`

### 3. Swift Wrapper Implementation

Create a Swift wrapper for easier use:

```swift
import Foundation

class ParquetViewer {
    
    // MARK: - Schema Reading
    
    static func readSchema(from filePath: String) throws -> Schema {
        guard let cSchema = filePath.withCString({ parquet_viewer_read_schema($0) }) else {
            throw ParquetError.failedToReadSchema
        }
        defer { parquet_viewer_free_schema(cSchema) }
        
        guard let jsonPtr = cSchema.pointee.json,
              let jsonData = String(cString: jsonPtr).data(using: .utf8) else {
            throw ParquetError.invalidSchemaFormat
        }
        
        let schema = try JSONDecoder().decode(Schema.self, from: jsonData)
        return schema
    }
    
    // MARK: - Metadata Reading
    
    static func readMetadata(from filePath: String) throws -> FileMetadata {
        guard let cMetadata = filePath.withCString({ parquet_viewer_read_metadata($0) }) else {
            throw ParquetError.failedToReadMetadata
        }
        defer { parquet_viewer_free_metadata(cMetadata) }
        
        let metadata = cMetadata.pointee
        
        // Extract key-value metadata
        var keyValuePairs: [String: String] = [:]
        if metadata.key_value_count > 0, let kvArray = metadata.key_value_metadata {
            for i in 0..<metadata.key_value_count {
                let kv = kvArray[i]
                if let keyPtr = kv.key, let valuePtr = kv.value {
                    let key = String(cString: keyPtr)
                    let value = String(cString: valuePtr)
                    keyValuePairs[key] = value
                }
            }
        }
        
        return FileMetadata(
            fileSize: metadata.file_size,
            totalRecords: Int(metadata.total_records),
            totalFields: metadata.total_fields,
            totalRowGroups: metadata.total_row_groups,
            version: Int(metadata.version),
            createdBy: metadata.created_by.map { String(cString: $0) },
            keyValueMetadata: keyValuePairs.isEmpty ? nil : keyValuePairs
        )
    }
    
    // MARK: - Data Reading
    
    static func readData(from filePath: String, batchSize: Int = 0) throws -> [RecordBatch] {
        guard let cBatchArray = filePath.withCString({ 
            parquet_viewer_read_data($0, batchSize) 
        }) else {
            throw ParquetError.failedToReadData
        }
        defer { parquet_viewer_free_data(cBatchArray) }
        
        var batches: [RecordBatch] = []
        let batchArray = cBatchArray.pointee
        
        if batchArray.count > 0, let batchesPtr = batchArray.batches {
            for i in 0..<batchArray.count {
                let cBatch = batchesPtr[i]
                if let jsonPtr = cBatch.json,
                   let jsonData = String(cString: jsonPtr).data(using: .utf8) {
                    let batch = try JSONDecoder().decode(RecordBatch.self, from: jsonData)
                    batches.append(batch)
                }
            }
        }
        
        return batches
    }
}

// MARK: - Data Models

struct Schema: Codable {
    let fields: [Field]
    
    struct Field: Codable {
        let name: String
        let type: String
    }
}

struct FileMetadata {
    let fileSize: Int
    let totalRecords: Int
    let totalFields: Int
    let totalRowGroups: Int
    let version: Int
    let createdBy: String?
    let keyValueMetadata: [String: String]?
}

struct RecordBatch: Codable {
    let columns: [Column]
    let num_rows: Int
    let num_columns: Int
    
    struct Column: Codable {
        let name: String
        let type: String
    }
}

enum ParquetError: Error {
    case failedToReadSchema
    case failedToReadMetadata
    case failedToReadData
    case invalidSchemaFormat
    case invalidDataFormat
}
```

### 4. Usage Example

```swift
import Foundation

// Example usage in your Swift app
class ParquetReader {
    
    func readParquetFile(at path: String) {
        do {
            // Read schema
            let schema = try ParquetViewer.readSchema(from: path)
            print("Schema has \(schema.fields.count) fields:")
            for field in schema.fields {
                print("  - \(field.name): \(field.type)")
            }
            
            // Read metadata
            let metadata = try ParquetViewer.readMetadata(from: path)
            print("\nFile Metadata:")
            print("  File size: \(metadata.fileSize) bytes")
            print("  Total records: \(metadata.totalRecords)")
            print("  Total fields: \(metadata.totalFields)")
            print("  Row groups: \(metadata.totalRowGroups)")
            print("  Version: \(metadata.version)")
            
            if let createdBy = metadata.createdBy {
                print("  Created by: \(createdBy)")
            }
            
            if let kvMetadata = metadata.keyValueMetadata {
                print("  Key-Value Metadata:")
                for (key, value) in kvMetadata {
                    print("    \(key): \(value)")
                }
            }
            
            // Read data
            let batches = try ParquetViewer.readData(from: path, batchSize: 1024)
            print("\nData: \(batches.count) batches")
            for (index, batch) in batches.enumerated() {
                print("  Batch \(index): \(batch.num_rows) rows x \(batch.num_columns) columns")
            }
            
        } catch {
            print("Error reading Parquet file: \(error)")
        }
    }
}
```

### 5. SwiftUI Example

```swift
import SwiftUI

struct ParquetFileView: View {
    @State private var metadata: FileMetadata?
    @State private var errorMessage: String?
    let filePath: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let metadata = metadata {
                Text("File: \(filePath)")
                    .font(.headline)
                
                Group {
                    Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(metadata.fileSize), countStyle: .file))")
                    Text("Records: \(metadata.totalRecords)")
                    Text("Fields: \(metadata.totalFields)")
                    Text("Row Groups: \(metadata.totalRowGroups)")
                    
                    if let createdBy = metadata.createdBy {
                        Text("Created by: \(createdBy)")
                    }
                }
                .padding(.leading)
                
                if let kvMetadata = metadata.keyValueMetadata {
                    Text("Metadata:")
                        .font(.subheadline)
                        .padding(.top)
                    
                    ForEach(Array(kvMetadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .fontWeight(.medium)
                            Spacer()
                            Text(kvMetadata[key] ?? "")
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading)
                    }
                }
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                ProgressView("Loading...")
            }
        }
        .padding()
        .onAppear {
            loadMetadata()
        }
    }
    
    private func loadMetadata() {
        do {
            metadata = try ParquetViewer.readMetadata(from: filePath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## Supported File Formats

- **Parquet** (`.parquet`)
- **Arrow IPC** (`.arrow`, `.arrows`, `.ipc`)
- **Feather** (`.feather`)

The library automatically detects the file format based on file extension or magic bytes.

## Error Handling

All functions return proper error types that can be handled in Swift:

```swift
do {
    let metadata = try ParquetViewer.readMetadata(from: "data.parquet")
    // Use metadata
} catch ParquetError.failedToReadMetadata {
    print("Failed to read metadata")
} catch ParquetError.invalidDataFormat {
    print("Invalid data format")
} catch {
    print("Unexpected error: \(error)")
}
```

## Memory Management

The FFI interface properly manages memory:
- All allocated memory is freed by the corresponding `free` functions
- Swift wrapper handles memory cleanup automatically using `defer` blocks
- No manual memory management required in Swift code

## Thread Safety

The library functions are thread-safe for reading operations. Multiple threads can safely read from different files simultaneously.

## License

AGPL-3.0-only
