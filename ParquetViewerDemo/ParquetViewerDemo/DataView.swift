import SwiftUI

struct DataView: View {
    let recordBatches: [RecordBatch]
    
    var body: some View {
        if !recordBatches.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Data summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label("\(recordBatches.count) batches", systemImage: "tablecells")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let totalRows = recordBatches.reduce(0) { $0 + $1.numRows }
                        Label("\(totalRows) total rows", systemImage: "number")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Batches list
                VStack(alignment: .leading, spacing: 0) {
                    Text("Record Batches")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    List {
                        ForEach(Array(recordBatches.enumerated()), id: \.offset) { index, batch in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Batch \(index + 1)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(batch.numRows) rows")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(batch.numColumns) columns")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Data preview
                                if let dataPreview = parseDataPreview(batch.json) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Data Preview:")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        
                                        Text(dataPreview)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        } else {
            // No data available
            VStack(spacing: 16) {
                Image(systemName: "tablecells")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Data Available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select a file to view its data information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func parseDataPreview(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        // The new format is an array of row objects
        if !jsonArray.isEmpty {
            let firstRow = jsonArray[0]
            let columnNames = Array(firstRow.keys)
            let preview = "Columns: " + columnNames.joined(separator: ", ")
            let rowCount = jsonArray.count
            return "\(rowCount) rows with \(columnNames.count) columns - \(preview)"
        }
        
        // Fallback to showing the JSON structure
        return "JSON structure available"
    }
}

//#Preview {
//    DataView(recordBatches: [
//        RecordBatch(
//            json: "{\"columns\":[{\"name\":\"id\",\"type\":\"Int32\"},{\"name\":\"name\",\"type\":\"Utf8\"}]}",
//            numRows: 100,
//            numColumns: 2
//        ),
//        RecordBatch(
//            json: "{\"columns\":[{\"name\":\"value\",\"type\":\"Float64\"}]}",
//            numRows: 50,
//            numColumns: 1
//        )
//    ])
//}
