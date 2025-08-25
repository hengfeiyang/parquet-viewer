import ParquetViewer

// Example usage of the ParquetViewer Swift package
func exampleUsage() {
    let filePath = "/path/to/your/file.parquet"
    
    do {
        // Read schema
        print("Reading schema...")
        let schema = try ParquetViewer.readSchema(filePath: filePath)
        print("Schema has \(schema.numFields) fields:")
        for field in schema.fields {
            print("- \(field.name): \(field.type)")
        }
        
        // Read metadata
        print("\nReading metadata...")
        let metadata = try ParquetViewer.readMetadata(filePath: filePath)
        print("File size: \(metadata.fileSize) bytes")
        print("Total records: \(metadata.totalRecords)")
        print("Total fields: \(metadata.totalFields)")
        print("Total row groups: \(metadata.totalRowGroups)")
        print("Version: \(metadata.version)")
        print("Created by: \(metadata.createdBy ?? "Unknown")")
        
        if !metadata.keyValueMetadata.isEmpty {
            print("Key-value metadata:")
            for kv in metadata.keyValueMetadata {
                print("- \(kv.key): \(kv.value)")
            }
        }
        
        // Read data
        print("\nReading data...")
        let batches = try ParquetViewer.readData(filePath: filePath, batchSize: 1000)
        print("Read \(batches.count) batches:")
        for (index, batch) in batches.enumerated() {
            print("Batch \(index): \(batch.numRows) rows, \(batch.numColumns) columns")
            // batch.json contains the JSON representation of the data
            // You can parse this JSON to access the actual data
        }
        
    } catch ParquetViewerError.invalidFilePath {
        print("Error: Invalid file path")
    } catch ParquetViewerError.operationFailed {
        print("Error: Operation failed - \(ParquetViewer.getLastError())")
    } catch {
        print("Unexpected error: \(error)")
    }
}

// Run the example
exampleUsage()
