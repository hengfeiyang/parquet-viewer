import SwiftUI
import ParquetViewer

struct SchemaView: View {
    let schema: Schema?
    
    var body: some View {
        if let schema = schema {
            VStack(alignment: .leading, spacing: 16) {
                // Schema summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schema Summary")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label("\(schema.numFields) fields", systemImage: "list.bullet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Fields table
                VStack(alignment: .leading, spacing: 0) {
                    Text("Fields")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    
                    List {
                        ForEach(Array(schema.fields.enumerated()), id: \.offset) { index, field in
                            HStack {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    Text(field.type)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        } else {
            // No schema available
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No Schema Available")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select a file to view its schema information.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

//#Preview {
//    SchemaView(schema: Schema(
//        fields: [
//            SchemaField(name: "id", type: "Int32"),
//            SchemaField(name: "name", type: "Utf8"),
//            SchemaField(name: "value", type: "Float64")
//        ],
//        numFields: 3
//    ))
//}
