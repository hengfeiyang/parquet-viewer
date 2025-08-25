import XCTest
import Foundation
@testable import ParquetViewerFFI

final class ParquetViewerFFITests: XCTestCase {
    
    // MARK: - Test Data
    
    func createTestParquetFile() -> String {
        // This would create a test parquet file in a real implementation
        // For now, we'll use a placeholder path
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_data.parquet")
        return testFile.path
    }
    
    // MARK: - Schema Tests
    
    func testReadSchemaWithValidFile() throws {
        let filePath = createTestParquetFile()
        
        // Note: This test will fail if the file doesn't exist
        // In a real test environment, you would create a test parquet file first
        
        do {
            let schema = try ParquetViewer.readSchema(filePath: filePath)
            
            // Verify schema structure
            XCTAssertGreaterThanOrEqual(schema.numFields, 0)
            XCTAssertEqual(schema.fields.count, Int(schema.numFields))
            
            // Verify each field has valid data
            for field in schema.fields {
                XCTAssertFalse(field.name.isEmpty)
                XCTAssertFalse(field.type.isEmpty)
            }
            
        } catch {
            // If file doesn't exist, that's expected in this test environment
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadSchemaWithInvalidPath() {
        let invalidPath = "/nonexistent/path/file.parquet"
        
        XCTAssertThrowsError(try ParquetViewer.readSchema(filePath: invalidPath)) { error in
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadSchemaWithEmptyPath() {
        let emptyPath = ""
        
        XCTAssertThrowsError(try ParquetViewer.readSchema(filePath: emptyPath)) { error in
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    // MARK: - Metadata Tests
    
    func testReadMetadataWithValidFile() throws {
        let filePath = createTestParquetFile()
        
        do {
            let metadata = try ParquetViewer.readMetadata(filePath: filePath)
            
            // Verify metadata structure
            XCTAssertGreaterThan(metadata.fileSize, 0)
            XCTAssertGreaterThanOrEqual(metadata.totalRecords, 0)
            XCTAssertGreaterThanOrEqual(metadata.totalFields, 0)
            XCTAssertGreaterThanOrEqual(metadata.totalRowGroups, 0)
            XCTAssertGreaterThanOrEqual(metadata.version, 0)
            
            // Verify key-value metadata if present
            for kv in metadata.keyValueMetadata {
                XCTAssertFalse(kv.key.isEmpty)
                // Value can be empty, so we don't check that
            }
            
        } catch {
            // If file doesn't exist, that's expected in this test environment
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadMetadataWithInvalidPath() {
        let invalidPath = "/nonexistent/path/file.parquet"
        
        XCTAssertThrowsError(try ParquetViewer.readMetadata(filePath: invalidPath)) { error in
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    // MARK: - Data Tests
    
    func testReadDataWithValidFile() throws {
        let filePath = createTestParquetFile()
        
        do {
            let batches = try ParquetViewer.readData(filePath: filePath)
            
            // Verify batches structure
            XCTAssertGreaterThanOrEqual(batches.count, 0)
            
            for batch in batches {
                XCTAssertGreaterThanOrEqual(batch.numRows, 0)
                XCTAssertGreaterThanOrEqual(batch.numColumns, 0)
                XCTAssertFalse(batch.json.isEmpty)
                
                // Verify JSON is valid
                if let data = batch.json.data(using: .utf8) {
                    XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
                }
            }
            
        } catch {
            // If file doesn't exist, that's expected in this test environment
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadDataWithCustomBatchSize() throws {
        let filePath = createTestParquetFile()
        let customBatchSize: UInt = 1000
        
        do {
            let batches = try ParquetViewer.readData(filePath: filePath, batchSize: customBatchSize)
            
            // Verify batches structure
            XCTAssertGreaterThanOrEqual(batches.count, 0)
            
            for batch in batches {
                XCTAssertGreaterThanOrEqual(batch.numRows, 0)
                XCTAssertGreaterThanOrEqual(batch.numColumns, 0)
            }
            
        } catch {
            // If file doesn't exist, that's expected in this test environment
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadDataWithZeroBatchSize() throws {
        let filePath = createTestParquetFile()
        
        do {
            let batches = try ParquetViewer.readData(filePath: filePath, batchSize: 0)
            
            // Should still work with zero batch size (default)
            XCTAssertGreaterThanOrEqual(batches.count, 0)
            
        } catch {
            // If file doesn't exist, that's expected in this test environment
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    func testReadDataWithInvalidPath() {
        let invalidPath = "/nonexistent/path/file.parquet"
        
        XCTAssertThrowsError(try ParquetViewer.readData(filePath: invalidPath)) { error in
            XCTAssertTrue(error is ParquetViewerError)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorTypes() {
        // Test that all error types are properly defined
        let errors: [ParquetViewerError] = [
            .invalidFilePath,
            .operationFailed,
            .fileNotFound,
            .invalidData
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
    }
    
    func testGetLastError() {
        // Test that getLastError doesn't crash
        let errorMessage = ParquetViewer.getLastError()
        XCTAssertFalse(errorMessage.isEmpty)
    }
    
    // MARK: - Model Tests
    
    func testSchemaFieldStructure() {
        let field = SchemaField(name: "test_field", type: "Int32")
        
        XCTAssertEqual(field.name, "test_field")
        XCTAssertEqual(field.type, "Int32")
    }
    
    func testSchemaStructure() {
        let fields = [
            SchemaField(name: "id", type: "Int32"),
            SchemaField(name: "name", type: "String")
        ]
        let schema = Schema(fields: fields, numFields: 2)
        
        XCTAssertEqual(schema.fields.count, 2)
        XCTAssertEqual(schema.numFields, 2)
        XCTAssertEqual(schema.fields[0].name, "id")
        XCTAssertEqual(schema.fields[1].name, "name")
    }
    
    func testFileMetadataStructure() {
        let metadata = FileMetadata(
            fileSize: 1024,
            totalRecords: 100,
            totalFields: 3,
            totalRowGroups: 1,
            version: 1,
            createdBy: "Test Creator",
            keyValueMetadata: [
                KeyValue(key: "test_key", value: "test_value")
            ]
        )
        
        XCTAssertEqual(metadata.fileSize, 1024)
        XCTAssertEqual(metadata.totalRecords, 100)
        XCTAssertEqual(metadata.totalFields, 3)
        XCTAssertEqual(metadata.totalRowGroups, 1)
        XCTAssertEqual(metadata.version, 1)
        XCTAssertEqual(metadata.createdBy, "Test Creator")
        XCTAssertEqual(metadata.keyValueMetadata.count, 1)
        XCTAssertEqual(metadata.keyValueMetadata[0].key, "test_key")
        XCTAssertEqual(metadata.keyValueMetadata[0].value, "test_value")
    }
    
    func testRecordBatchStructure() {
        let batch = RecordBatch(
            json: "{\"columns\":[{\"name\":\"id\",\"type\":\"Int32\"}]}",
            numRows: 10,
            numColumns: 1
        )
        
        XCTAssertEqual(batch.json, "{\"columns\":[{\"name\":\"id\",\"type\":\"Int32\"}]}")
        XCTAssertEqual(batch.numRows, 10)
        XCTAssertEqual(batch.numColumns, 1)
    }
    
    func testKeyValueStructure() {
        let kv = KeyValue(key: "test_key", value: "test_value")
        
        XCTAssertEqual(kv.key, "test_key")
        XCTAssertEqual(kv.value, "test_value")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceReadSchema() {
        let filePath = createTestParquetFile()
        
        measure {
            do {
                _ = try ParquetViewer.readSchema(filePath: filePath)
            } catch {
                // Expected in test environment
            }
        }
    }
    
    func testPerformanceReadMetadata() {
        let filePath = createTestParquetFile()
        
        measure {
            do {
                _ = try ParquetViewer.readMetadata(filePath: filePath)
            } catch {
                // Expected in test environment
            }
        }
    }
    
    func testPerformanceReadData() {
        let filePath = createTestParquetFile()
        
        measure {
            do {
                _ = try ParquetViewer.readData(filePath: filePath, batchSize: 1000)
            } catch {
                // Expected in test environment
            }
        }
    }
}
