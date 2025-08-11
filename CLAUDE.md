# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parquet Viewer is a Rust library and CLI tool for reading Parquet and Arrow files. It provides functionality to extract schema, metadata, and data from these file formats, with implemented C FFI bindings for Swift integration.

## Core API Functions

The library exposes the following public functions in `src/lib.rs`:
- `read_schema(file_path: &Path) -> Result<SchemaRef>` - Extract the schema/field list from Parquet/Arrow files
- `read_metadata(file_path: &Path) -> Result<FileMetadata>` - Get file metadata including:
  - File size, total records, total fields, total row groups
  - File version, file creator
  - Metadata key-value pairs
- `read_data(file_path: &Path, batch_size: Option<usize>) -> Result<Vec<RecordBatch>>` - Read and return the actual data from the files
- `read_data_with_projection(file_path: &Path, column_indices: Vec<usize>, batch_size: Option<usize>) -> Result<Vec<RecordBatch>>` - Read specific columns only

## Development Commands

### Build
```bash
cargo build           # Debug build
cargo build --release # Release build with optimizations
cargo build --release --features ffi  # Build with FFI support for Swift integration
```

### Test
```bash
cargo test           # Run all tests
cargo test -- --nocapture  # Run tests with println! output visible
cargo test test_read_arrow  # Run specific test by pattern
cargo test --lib     # Run library tests only
```

### Lint & Format
```bash
cargo fmt            # Format code
cargo fmt -- --check # Check formatting without changes
cargo clippy         # Run linter
cargo clippy -- -D warnings  # Treat warnings as errors
cargo clippy --fix   # Auto-fix clippy warnings
```

### Run CLI
```bash
cargo run -- schema <file.parquet>     # Read schema
cargo run -- metadata <file.parquet>   # Read metadata
cargo run -- data <file.parquet> --batch-size 1024 --limit 100  # Read data
```

## Architecture Guidelines

### Module Structure
- `src/lib.rs` - Library entry point with public API functions and file format detection
  - Auto-detects format via extension (.parquet, .arrow, .ipc, .feather) or magic bytes
  - All functions use pattern matching on `FileFormat` enum
- `src/main.rs` - CLI entry point using clap for argument parsing with three subcommands
- `src/ffi.rs` - C FFI bindings (enabled with `ffi` feature flag)
  - Exports C-compatible functions with `#[no_mangle]` and `extern "C"`
  - JSON serialization used for complex data transfer across FFI boundary
  - Proper memory management with allocation/deallocation pairs

### Dependencies
- `arrow` & `arrow-schema` (v56) - Apache Arrow support
- `parquet` (v56) - Parquet file format support  
- `clap` (v4.1) - CLI argument parsing
- `thiserror` (v1.0) - Error handling
- `serde_json` (v1.0) - JSON serialization for FFI

### FFI/C Bindings for Swift

Key structures in `src/ffi.rs`:
- `CFileMetadata` - Includes key-value metadata support via `CKeyValue` struct
- `CSchema` - Returns JSON representation of schema
- `CRecordBatch` & `CRecordBatchArray` - For data transfer

Memory management pattern:
- Allocation functions: `parquet_viewer_read_*` return pointers
- Deallocation functions: `parquet_viewer_free_*` clean up memory
- Key-value pairs properly freed in `parquet_viewer_free_metadata`

Header file `parquet_viewer.h` provides C declarations for Swift bridging.

### Error Handling
- `ParquetViewerError` enum defined with `thiserror`
- FFI functions return NULL on error
- `parquet_viewer_get_last_error()` for error messages (simplified implementation)