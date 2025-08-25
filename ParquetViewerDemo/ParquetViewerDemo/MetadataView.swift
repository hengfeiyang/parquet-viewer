import SwiftUI

struct MetadataView: View {
    let metadata: FileMetadata?
    
    var body: some View {
        if let metadata = metadata {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic file information
                    metadataSection(
                        title: "File Information",
                        items: [
                            ("File Size", ByteCountFormatter.string(fromByteCount: Int64(metadata.fileSize), countStyle: .file)),
                            ("Total Records", "\(metadata.totalRecords)"),
                            ("Total Fields", "\(metadata.totalFields)"),
                            ("Total Row Groups", "\(metadata.totalRowGroups)"),
                            ("Version", "\(metadata.version)")
                        ]
                    )
                    
                    // Created by information
                    if let createdBy = metadata.createdBy {
                        metadataSection(
                            title: "Created By",
                            items: [
                                ("Application", createdBy)
                            ]
                        )
                    }
                    
                    // Key-value metadata
                    if !metadata.keyValueMetadata.isEmpty {
                        metadataSection(
                            title: "Key-Value Metadata",
                            items: metadata.keyValueMetadata.map { kv in
                                (kv.key, kv.value)
                            }
                        )
                    }
                }
                .padding()
            }
        } else {
            // No metadata available
            VStack(spacing: 16) {
                Image(systemName: "info.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Metadata Available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select a file to view its metadata information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func metadataSection(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { key, value in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)
                        
                        Text(value)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

#Preview {
    MetadataView(metadata: FileMetadata(
        fileSize: 1024,
        totalRecords: 1000,
        totalFields: 5,
        totalRowGroups: 1,
        version: 1,
        createdBy: "parquet-rs version 54.2.1",
        keyValueMetadata: [
            KeyValue(key: "min_ts", value: "1754315677492053"),
            KeyValue(key: "max_ts", value: "1754315791230690"),
            KeyValue(key: "records", value: "63")
        ]
    ))
}
