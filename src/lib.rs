use arrow::array::RecordBatch;
use arrow::ipc::reader::FileReader as ArrowFileReader;
use arrow_schema::SchemaRef;
use parquet::arrow::arrow_reader::ParquetRecordBatchReaderBuilder;
use parquet::arrow::{ProjectionMask, parquet_to_arrow_schema};
use parquet::file::reader::{FileReader, SerializedFileReader};
use std::fs::File;
use std::path::Path;
use std::sync::Arc;
use thiserror::Error;

#[cfg(feature = "ffi")]
pub mod ffi;

#[derive(Error, Debug)]
pub enum ParquetViewerError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Parquet error: {0}")]
    Parquet(#[from] parquet::errors::ParquetError),
    #[error("Arrow error: {0}")]
    Arrow(#[from] arrow::error::ArrowError),
    #[error("File not found: {0}")]
    FileNotFound(String),
}

pub type Result<T> = std::result::Result<T, ParquetViewerError>;

#[derive(Debug, Clone)]
pub struct FileMetadata {
    pub file_size: usize,
    pub total_records: i64,
    pub total_fields: usize,
    pub total_row_groups: usize,
    pub version: i32,
    pub created_by: Option<String>,
    pub key_value_metadata: Option<Vec<(String, String)>>,
}

#[derive(Debug, Clone, Copy)]
pub enum FileFormat {
    Parquet,
    Arrow,
}

fn detect_file_format(file_path: &Path) -> Result<FileFormat> {
    let extension = file_path
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|s| s.to_lowercase());

    match extension.as_deref() {
        Some("parquet") => Ok(FileFormat::Parquet),
        Some("arrow") | Some("arrows") | Some("ipc") | Some("feather") => Ok(FileFormat::Arrow),
        _ => {
            // Try to detect by reading file magic bytes
            let file = File::open(file_path)?;
            let mut reader = std::io::BufReader::new(file);
            let mut magic = [0u8; 4];
            use std::io::Read;
            reader.read_exact(&mut magic)?;

            if &magic == b"PAR1" {
                Ok(FileFormat::Parquet)
            } else if &magic == b"ARRO" {
                Ok(FileFormat::Arrow)
            } else {
                // Default to Parquet for backward compatibility
                Ok(FileFormat::Parquet)
            }
        }
    }
}

pub fn read_schema(file_path: &Path) -> Result<SchemaRef> {
    if !file_path.exists() {
        return Err(ParquetViewerError::FileNotFound(
            file_path.display().to_string(),
        ));
    }

    let format = detect_file_format(file_path)?;

    match format {
        FileFormat::Parquet => {
            let file = File::open(file_path)?;
            let reader = SerializedFileReader::new(file)?;
            let parquet_metadata = reader.metadata();
            let file_metadata = parquet_metadata.file_metadata();

            let arrow_schema = parquet_to_arrow_schema(
                file_metadata.schema_descr(),
                file_metadata.key_value_metadata(),
            )?;

            Ok(Arc::new(arrow_schema))
        }
        FileFormat::Arrow => {
            let file = File::open(file_path)?;
            let reader = ArrowFileReader::try_new(file, None)?;
            Ok(reader.schema())
        }
    }
}

pub fn read_metadata(file_path: &Path) -> Result<FileMetadata> {
    if !file_path.exists() {
        return Err(ParquetViewerError::FileNotFound(
            file_path.display().to_string(),
        ));
    }

    let file_size = std::fs::metadata(file_path)?.len() as usize;
    let format = detect_file_format(file_path)?;

    match format {
        FileFormat::Parquet => {
            let file = File::open(file_path)?;
            let reader = SerializedFileReader::new(file)?;
            let parquet_metadata = reader.metadata();
            let file_metadata = parquet_metadata.file_metadata();

            let total_records = parquet_metadata
                .row_groups()
                .iter()
                .map(|rg| rg.num_rows())
                .sum();

            let total_fields = file_metadata.schema().get_fields().len();
            let total_row_groups = parquet_metadata.num_row_groups();
            let version = file_metadata.version();
            let created_by = file_metadata.created_by().map(|s| s.to_string());

            let key_value_metadata = file_metadata.key_value_metadata().map(|kv_pairs| {
                kv_pairs
                    .iter()
                    .map(|kv| (kv.key.clone(), kv.value.clone().unwrap_or_default()))
                    .collect()
            });

            Ok(FileMetadata {
                file_size,
                total_records,
                total_fields,
                total_row_groups,
                version,
                created_by,
                key_value_metadata,
            })
        }
        FileFormat::Arrow => {
            let file = File::open(file_path)?;
            let reader = ArrowFileReader::try_new(file, None)?;
            let schema = reader.schema();

            // Count total records by iterating through batches
            let mut total_records = 0i64;
            let mut batch_count = 0;
            for batch in reader {
                let batch = batch?;
                total_records += batch.num_rows() as i64;
                batch_count += 1;
            }

            Ok(FileMetadata {
                file_size,
                total_records,
                total_fields: schema.fields().len(),
                total_row_groups: batch_count, // Arrow doesn't have row groups, using batch count
                version: 0,                    // Arrow IPC doesn't have version like Parquet
                created_by: Some("Arrow IPC".to_string()),
                key_value_metadata: if schema.metadata().is_empty() {
                    None
                } else {
                    Some(
                        schema
                            .metadata()
                            .iter()
                            .map(|(k, v)| (k.clone(), v.clone()))
                            .collect(),
                    )
                },
            })
        }
    }
}

pub fn read_data(file_path: &Path, batch_size: Option<usize>) -> Result<Vec<RecordBatch>> {
    if !file_path.exists() {
        return Err(ParquetViewerError::FileNotFound(
            file_path.display().to_string(),
        ));
    }

    let format = detect_file_format(file_path)?;

    match format {
        FileFormat::Parquet => {
            let file = File::open(file_path)?;
            let builder = ParquetRecordBatchReaderBuilder::try_new(file)?;

            let reader = if let Some(batch_size) = batch_size {
                builder.with_batch_size(batch_size).build()?
            } else {
                builder.build()?
            };

            let mut batches = Vec::new();
            for batch in reader {
                batches.push(batch?);
            }

            Ok(batches)
        }
        FileFormat::Arrow => {
            let file = File::open(file_path)?;
            let reader = ArrowFileReader::try_new(file, None)?;

            let mut batches = Vec::new();
            for batch in reader {
                batches.push(batch?);
            }

            Ok(batches)
        }
    }
}

pub fn read_data_with_projection(
    file_path: &Path,
    column_indices: Vec<usize>,
    batch_size: Option<usize>,
) -> Result<Vec<RecordBatch>> {
    if !file_path.exists() {
        return Err(ParquetViewerError::FileNotFound(
            file_path.display().to_string(),
        ));
    }

    let format = detect_file_format(file_path)?;

    match format {
        FileFormat::Parquet => {
            let file = File::open(file_path)?;
            let builder = ParquetRecordBatchReaderBuilder::try_new(file)?;

            let mask = ProjectionMask::roots(builder.parquet_schema(), column_indices.clone());

            let reader = if let Some(batch_size) = batch_size {
                builder
                    .with_projection(mask)
                    .with_batch_size(batch_size)
                    .build()?
            } else {
                builder.with_projection(mask).build()?
            };

            let mut batches = Vec::new();
            for batch in reader {
                batches.push(batch?);
            }

            Ok(batches)
        }
        FileFormat::Arrow => {
            let file = File::open(file_path)?;
            let reader = ArrowFileReader::try_new(file, None)?;
            let schema = reader.schema();

            // Create projected schema
            let projected_fields: Vec<_> = column_indices
                .iter()
                .map(|&i| schema.field(i).clone())
                .collect();
            let projected_schema = Arc::new(arrow::datatypes::Schema::new(projected_fields));

            let mut batches = Vec::new();
            for batch in reader {
                let batch = batch?;
                // Project columns
                let projected_columns: Vec<_> = column_indices
                    .iter()
                    .map(|&i| batch.column(i).clone())
                    .collect();
                let projected_batch =
                    RecordBatch::try_new(projected_schema.clone(), projected_columns)?;
                batches.push(projected_batch);
            }

            Ok(batches)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use arrow::array::{Int32Array, StringArray};
    use arrow::datatypes::{DataType, Field, Schema};
    use arrow::ipc::writer::FileWriter as ArrowFileWriter;
    use arrow::record_batch::RecordBatch;
    use parquet::arrow::ArrowWriter;
    use std::sync::Arc;
    use tempfile::NamedTempFile;

    fn create_test_parquet_file() -> NamedTempFile {
        let temp_file = NamedTempFile::new().unwrap();

        let schema = Arc::new(Schema::new(vec![
            Field::new("id", DataType::Int32, false),
            Field::new("name", DataType::Utf8, false),
        ]));

        let id_array = Int32Array::from(vec![1, 2, 3, 4, 5]);
        let name_array = StringArray::from(vec!["Alice", "Bob", "Charlie", "David", "Eve"]);

        let batch = RecordBatch::try_new(
            schema.clone(),
            vec![Arc::new(id_array), Arc::new(name_array)],
        )
        .unwrap();

        let file = temp_file.reopen().unwrap();
        let mut writer = ArrowWriter::try_new(file, schema, None).unwrap();
        writer.write(&batch).unwrap();
        writer.close().unwrap();

        temp_file
    }

    #[test]
    fn test_read_schema() {
        let temp_file = create_test_parquet_file();
        let schema = read_schema(temp_file.path()).unwrap();

        assert_eq!(schema.fields().len(), 2);
        assert_eq!(schema.field(0).name(), "id");
        assert_eq!(schema.field(1).name(), "name");
        assert_eq!(schema.field(0).data_type(), &DataType::Int32);
        assert_eq!(schema.field(1).data_type(), &DataType::Utf8);
    }

    #[test]
    fn test_read_metadata() {
        let temp_file = create_test_parquet_file();
        let metadata = read_metadata(temp_file.path()).unwrap();

        assert_eq!(metadata.total_records, 5);
        assert_eq!(metadata.total_fields, 2);
        assert_eq!(metadata.total_row_groups, 1);
        assert!(metadata.file_size > 0);
    }

    #[test]
    fn test_read_data() {
        let temp_file = create_test_parquet_file();
        let batches = read_data(temp_file.path(), None).unwrap();

        assert_eq!(batches.len(), 1);
        let batch = &batches[0];
        assert_eq!(batch.num_rows(), 5);
        assert_eq!(batch.num_columns(), 2);
    }

    #[test]
    fn test_read_data_with_projection() {
        let temp_file = create_test_parquet_file();
        let batches = read_data_with_projection(temp_file.path(), vec![1], None).unwrap();

        assert_eq!(batches.len(), 1);
        let batch = &batches[0];
        assert_eq!(batch.num_rows(), 5);
        assert_eq!(batch.num_columns(), 1);
        assert_eq!(batch.schema().field(0).name(), "name");
    }

    #[test]
    fn test_file_not_found() {
        let result = read_schema(Path::new("/nonexistent/file.parquet"));
        assert!(matches!(result, Err(ParquetViewerError::FileNotFound(_))));
    }

    fn create_test_arrow_file() -> NamedTempFile {
        let temp_file = NamedTempFile::new().unwrap();

        let schema = Arc::new(Schema::new(vec![
            Field::new("id", DataType::Int32, false),
            Field::new("name", DataType::Utf8, false),
        ]));

        let id_array = Int32Array::from(vec![1, 2, 3, 4, 5]);
        let name_array = StringArray::from(vec!["Alice", "Bob", "Charlie", "David", "Eve"]);

        let batch = RecordBatch::try_new(
            schema.clone(),
            vec![Arc::new(id_array), Arc::new(name_array)],
        )
        .unwrap();

        {
            let file = temp_file.reopen().unwrap();
            let mut writer = ArrowFileWriter::try_new(file, &schema).unwrap();
            writer.write(&batch).unwrap();
            writer.finish().unwrap();
        }

        // Rename to .arrow extension
        let arrow_path = temp_file.path().with_extension("arrow");
        std::fs::copy(temp_file.path(), &arrow_path).unwrap();
        let arrow_file = NamedTempFile::new().unwrap();
        std::fs::copy(&arrow_path, arrow_file.path()).unwrap();
        std::fs::remove_file(&arrow_path).unwrap();

        arrow_file
    }

    #[test]
    fn test_read_arrow_schema() {
        let temp_file = create_test_arrow_file();
        let schema = read_schema(temp_file.path()).unwrap();

        assert_eq!(schema.fields().len(), 2);
        assert_eq!(schema.field(0).name(), "id");
        assert_eq!(schema.field(1).name(), "name");
        assert_eq!(schema.field(0).data_type(), &DataType::Int32);
        assert_eq!(schema.field(1).data_type(), &DataType::Utf8);
    }

    #[test]
    fn test_read_arrow_metadata() {
        let temp_file = create_test_arrow_file();
        let metadata = read_metadata(temp_file.path()).unwrap();

        assert_eq!(metadata.total_records, 5);
        assert_eq!(metadata.total_fields, 2);
        assert!(metadata.file_size > 0);
        assert_eq!(metadata.created_by, Some("Arrow IPC".to_string()));
    }

    #[test]
    fn test_read_arrow_data() {
        let temp_file = create_test_arrow_file();
        let batches = read_data(temp_file.path(), None).unwrap();

        assert!(!batches.is_empty());
        let total_rows: usize = batches.iter().map(|b| b.num_rows()).sum();
        assert_eq!(total_rows, 5);
        assert_eq!(batches[0].num_columns(), 2);
    }

    #[test]
    fn test_read_arrow_data_with_projection() {
        let temp_file = create_test_arrow_file();
        let batches = read_data_with_projection(temp_file.path(), vec![1], None).unwrap();

        assert!(!batches.is_empty());
        let batch = &batches[0];
        assert_eq!(batch.num_columns(), 1);
        assert_eq!(batch.schema().field(0).name(), "name");
    }
}
