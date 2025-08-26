import SwiftUI

struct TableView: View {
    let recordBatches: [RecordBatch]
    @State private var selectedBatchIndex = 0
    @State private var sortColumn: String?
    @State private var sortAscending = true
    @State private var searchText = ""
    
    var body: some View {
        if !recordBatches.isEmpty {
            VStack(spacing: 0) {
                // Header controls
                headerControls
                
                // Table content
                tableContent
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
                
                Text("Select a file to view its data in table format.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private var headerControls: some View {
        VStack(spacing: 12) {
            // Batch selector
            HStack {
                Text("Batch:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Select Batch", selection: $selectedBatchIndex) {
                    ForEach(0..<recordBatches.count, id: \.self) { index in
                        Text("\(index + 1) (\(recordBatches[index].numRows) rows)")
                            .tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
            }
            
            // Batch info
            if selectedBatchIndex < recordBatches.count {
                let batch = recordBatches[selectedBatchIndex]
                HStack {
                    Label("\(batch.numRows) rows", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("\(batch.numColumns) columns", systemImage: "tablecells")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    private var tableContent: some View {
        Group {
            if selectedBatchIndex < recordBatches.count {
                let batch = recordBatches[selectedBatchIndex]
                if let tableData = parseTableData(from: batch.json) {
                    DataTable(
                        data: tableData,
                        searchText: searchText,
                        sortColumn: $sortColumn,
                        sortAscending: $sortAscending
                    )
                } else {
                    // Fallback view if parsing fails
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Parse Data")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("The data format could not be parsed for table display.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func parseTableData(from jsonString: String) -> TableData? {
        guard let data = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }
        
        guard !jsonArray.isEmpty else { return nil }
        
        // Extract column headers from the first row
        let firstRow = jsonArray[0]
        let columns = Array(firstRow.keys).sorted()
        
        // Convert data to rows
        let rows = jsonArray.map { row in
            columns.map { column in
                if let value = row[column] {
                    return String(describing: value)
                } else {
                    return ""
                }
            }
        }
        
        return TableData(columns: columns, rows: rows)
    }
}

struct TableData {
    let columns: [String]
    let rows: [[String]]
}

struct DataTable: View {
    let data: TableData
    let searchText: String
    @Binding var sortColumn: String?
    @Binding var sortAscending: Bool
    
    private var filteredAndSortedData: (columns: [String], rows: [[String]]) {
        var filteredRows = data.rows
        
        // Apply search filter
        if !searchText.isEmpty {
            filteredRows = data.rows.filter { row in
                row.contains { cell in
                    cell.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
        
        // Apply sorting
        if let sortCol = sortColumn,
           let columnIndex = data.columns.firstIndex(of: sortCol) {
            filteredRows.sort { row1, row2 in
                let value1 = row1[columnIndex]
                let value2 = row2[columnIndex]
                
                // Try to sort as numbers first, then as strings
                if let num1 = Double(value1), let num2 = Double(value2) {
                    return sortAscending ? num1 < num2 : num1 > num2
                } else {
                    return sortAscending ? value1 < value2 : value1 > value2
                }
            }
        }
        
        return (data.columns, filteredRows)
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // Header row
                headerRow
                
                // Data rows
                dataRows
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(filteredAndSortedData.columns, id: \.self) { column in
                VStack(spacing: 0) {
                    HStack {
                        Text(column)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Sort indicator
                        if sortColumn == column {
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .onTapGesture {
                        if sortColumn == column {
                            sortAscending.toggle()
                        } else {
                            sortColumn = column
                            sortAscending = true
                        }
                    }
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor))
                }
                .frame(width: 150)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var dataRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredAndSortedData.rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        VStack(spacing: 0) {
                            Text(cell)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(width: 150, alignment: .leading)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(NSColor.separatorColor).opacity(0.5))
                        }
                        .background(index % 2 == 0 ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.8))
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

#Preview {
    TableView(recordBatches: [
        RecordBatch(
            json: """
            [
                {"id": "1", "name": "Alice", "age": "25", "city": "New York"},
                {"id": "2", "name": "Bob", "age": "30", "city": "Los Angeles"},
                {"id": "3", "name": "Charlie", "age": "35", "city": "Chicago"}
            ]
            """,
            numRows: 3,
            numColumns: 4
        )
    ])
}
