import SwiftUI
import UniformTypeIdentifiers
import ParquetViewer

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var isFilePickerPresented = false
    @State private var schema: Schema?
    @State private var metadata: FileMetadata?
    @State private var recordBatches: [RecordBatch] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with file picker
                headerView
                
                if selectedFile != nil {
                    // Tab view for file analysis
                    TabView(selection: $selectedTab) {
                        SchemaView(schema: schema)
                            .tabItem {
                                Label("Schema", systemImage: "list.bullet")
                            }
                            .tag(0)
                        
                        MetadataView(metadata: metadata)
                            .tabItem {
                                Label("Metadata", systemImage: "info.circle")
                            }
                            .tag(1)
                        
                        DataView(recordBatches: recordBatches)
                            .tabItem {
                                Label("Data", systemImage: "tablecells")
                            }
                            .tag(2)
                    }
                    .padding(.top, 1)
                } else {
                    // Welcome view when no file is selected
                    welcomeView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Parquet Viewer")
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: [UTType(filenameExtension: "parquet")!, UTType(filenameExtension: "arrow")!],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    isFilePickerPresented = true
                }) {
                    Label("Select File", systemImage: "doc.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                if let selectedFile = selectedFile {
                    VStack(alignment: .trailing) {
                        Text("Selected File:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedFile.lastPathComponent)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView("Analyzing file...")
                    .padding(.horizontal)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
    
    private var welcomeView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to Parquet Viewer")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select a Parquet or Arrow file to analyze its schema, metadata, and data.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                isFilePickerPresented = true
            }) {
                Label("Choose File", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .padding()
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFile = url
            analyzeFile(url)
        case .failure(let error):
            errorMessage = "Failed to select file: \(error.localizedDescription)"
        }
    }
    
    private func analyzeFile(_ url: URL) {
        isLoading = true
        errorMessage = nil
        
        // Start file access
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Failed to access file"
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let filePath = url.path
                
                // Read schema
                let schema = try ParquetViewer.readSchema(filePath: filePath)
                
                // Read metadata
                let metadata = try ParquetViewer.readMetadata(filePath: filePath)
                
                // Read data
                let batches = try ParquetViewer.readData(filePath: filePath)
                
                DispatchQueue.main.async {
                    self.schema = schema
                    self.metadata = metadata
                    self.recordBatches = batches
                    self.isLoading = false
                    url.stopAccessingSecurityScopedResource()
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error analyzing file: \(error.localizedDescription)"
                    self.isLoading = false
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
