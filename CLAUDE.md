# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Parquet Viewer is a Rust library and CLI tool for reading Parquet and Arrow files. It provides functionality to extract schema, metadata, and data from these file formats, with planned support for Swift bindings via C FFI.

## Core API Functions

The library exposes three main public functions (to be implemented in `src/lib.rs`):
- `read_schema` - Extract the schema/field list from Parquet/Arrow files
- `read_metadata` - Get file metadata including:
  - File size, total records, total fields, total row groups
  - File version, file creator
  - Metadata key-value pairs
- `read_data` - Read and return the actual data from the files

## Development Commands

### Build
```bash
cargo build           # Debug build
cargo build --release # Release build with optimizations
```

### Test
```bash
cargo test           # Run all tests
cargo test -- --nocapture  # Run tests with println! output visible
cargo test <test_name>     # Run a specific test
```

### Lint & Format
```bash
cargo fmt            # Format code
cargo fmt -- --check # Check formatting without changes
cargo clippy         # Run linter
cargo clippy -- -D warnings  # Treat warnings as errors
```

### Run CLI
```bash
cargo run -- <args>  # Run the CLI tool with arguments
```

## Architecture Guidelines

### Module Structure
- `src/lib.rs` - Library entry point with public API functions
- `src/main.rs` - CLI entry point using clap for argument parsing
- Internal modules should separate Parquet and Arrow implementations while presenting a unified public API

### Dependencies
- `arrow` & `arrow-schema` (v56) - Apache Arrow support
- `parquet` (v56) - Parquet file format support  
- `clap` (v4.1) - CLI argument parsing

### FFI/C Bindings for Swift
When implementing C exports:
1. Use `#[no_mangle]` and `extern "C"` for exported functions
2. Use C-compatible types (primitives, pointers, structs with `#[repr(C)]`)
3. Provide a header file (.h) for Swift to import
4. Handle memory management carefully (who allocates/frees)

### Error Handling
Use `thiserror` for error definitions. Public API functions should return `Result<T, Error>` types that can be converted to C error codes for FFI.