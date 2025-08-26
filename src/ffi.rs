use crate::{read_data, read_metadata, read_schema};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;
use std::ptr;

#[repr(C)]
pub struct CKeyValue {
    pub key: *mut c_char,
    pub value: *mut c_char,
}

#[repr(C)]
pub struct CFileMetadata {
    pub file_size: usize,
    pub total_records: i64,
    pub total_fields: usize,
    pub total_row_groups: usize,
    pub version: i32,
    pub created_by: *mut c_char,
    pub key_value_metadata: *mut CKeyValue,
    pub key_value_count: usize,
}

#[repr(C)]
pub struct CField {
    pub name: *mut c_char,
    pub data_type: *mut c_char,
    pub nullable: bool,
}

#[repr(C)]
pub struct CSchema {
    pub fields: *mut CField,
    pub num_fields: usize,
}

#[repr(C)]
pub struct CRecordBatch {
    pub json: *mut c_char,
    pub num_rows: usize,
    pub num_columns: usize,
}

#[repr(C)]
pub struct CRecordBatchArray {
    pub batches: *mut CRecordBatch,
    pub count: usize,
}

/// Read schema from a Parquet or Arrow file
/// Returns NULL on error, caller must free the returned CSchema with parquet_viewer_free_schema
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_read_schema(file_path: *const c_char) -> *mut CSchema {
    if file_path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(file_path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let path = Path::new(path_str);
    match read_schema(path) {
        Ok(schema) => {
            let mut c_fields: Vec<CField> = Vec::new();

            for field in schema.fields() {
                let name = match CString::new(field.name().as_str()) {
                    Ok(s) => s.into_raw(),
                    Err(_) => ptr::null_mut(),
                };

                let data_type = match CString::new(format!("{:?}", field.data_type())) {
                    Ok(s) => s.into_raw(),
                    Err(_) => ptr::null_mut(),
                };

                c_fields.push(CField {
                    name,
                    data_type,
                    nullable: field.is_nullable(),
                });
            }

            let count = c_fields.len();
            let fields_ptr = if count > 0 {
                let mut boxed_slice = c_fields.into_boxed_slice();
                let ptr = boxed_slice.as_mut_ptr();
                std::mem::forget(boxed_slice);
                ptr
            } else {
                ptr::null_mut()
            };

            let c_schema = Box::new(CSchema {
                fields: fields_ptr,
                num_fields: count,
            });

            Box::into_raw(c_schema)
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Read metadata from a Parquet or Arrow file
/// Returns NULL on error, caller must free the returned CFileMetadata with parquet_viewer_free_metadata
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_read_metadata(file_path: *const c_char) -> *mut CFileMetadata {
    if file_path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(file_path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let path = Path::new(path_str);
    match read_metadata(path) {
        Ok(metadata) => {
            let created_by = metadata
                .created_by
                .and_then(|s| CString::new(s).ok())
                .map(|s| s.into_raw())
                .unwrap_or(ptr::null_mut());

            // Convert key-value metadata
            let (key_value_metadata, key_value_count) = if let Some(kv_pairs) = metadata.key_value_metadata {
                let mut c_kv_pairs: Vec<CKeyValue> = Vec::new();
                
                for (key, value) in kv_pairs {
                    let c_key = CString::new(key).ok().map(|s| s.into_raw()).unwrap_or(ptr::null_mut());
                    let c_value = CString::new(value).ok().map(|s| s.into_raw()).unwrap_or(ptr::null_mut());
                    
                    c_kv_pairs.push(CKeyValue {
                        key: c_key,
                        value: c_value,
                    });
                }
                
                let count = c_kv_pairs.len();
                let ptr = if count > 0 {
                    let mut boxed_slice = c_kv_pairs.into_boxed_slice();
                    let ptr = boxed_slice.as_mut_ptr();
                    std::mem::forget(boxed_slice);
                    ptr
                } else {
                    ptr::null_mut()
                };
                
                (ptr, count)
            } else {
                (ptr::null_mut(), 0)
            };

            let c_metadata = Box::new(CFileMetadata {
                file_size: metadata.file_size,
                total_records: metadata.total_records,
                total_fields: metadata.total_fields,
                total_row_groups: metadata.total_row_groups,
                version: metadata.version,
                created_by,
                key_value_metadata,
                key_value_count,
            });

            Box::into_raw(c_metadata)
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Read data from a Parquet or Arrow file
/// Returns NULL on error, caller must free the returned CRecordBatchArray with parquet_viewer_free_data
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_read_data(
    file_path: *const c_char,
    batch_size: usize,
) -> *mut CRecordBatchArray {
    if file_path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(file_path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let path = Path::new(path_str);
    let batch_size_opt = if batch_size > 0 {
        Some(batch_size)
    } else {
        None
    };

    match read_data(path, batch_size_opt) {
        Ok(batches) => {
            let mut c_batches: Vec<CRecordBatch> = Vec::new();

            for batch in batches {
                let json_str = batch_to_json(&batch);
                let c_json = match CString::new(json_str) {
                    Ok(s) => s,
                    Err(_) => CString::new("{}").unwrap(),
                };

                c_batches.push(CRecordBatch {
                    json: c_json.into_raw(),
                    num_rows: batch.num_rows(),
                    num_columns: batch.num_columns(),
                });
            }

            let count = c_batches.len();
            let batches_ptr = if count > 0 {
                let mut boxed_slice = c_batches.into_boxed_slice();
                let ptr = boxed_slice.as_mut_ptr();
                std::mem::forget(boxed_slice);
                ptr
            } else {
                ptr::null_mut()
            };

            let result = Box::new(CRecordBatchArray {
                batches: batches_ptr,
                count,
            });

            Box::into_raw(result)
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Free a CSchema returned by parquet_viewer_read_schema
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_free_schema(schema: *mut CSchema) {
    if schema.is_null() {
        return;
    }

    unsafe {
        let schema = Box::from_raw(schema);
        if !schema.fields.is_null() && schema.num_fields > 0 {
            let fields = Vec::from_raw_parts(schema.fields, schema.num_fields, schema.num_fields);
            for field in fields {
                if !field.name.is_null() {
                    let _ = CString::from_raw(field.name);
                }
                if !field.data_type.is_null() {
                    let _ = CString::from_raw(field.data_type);
                }
            }
        }
    }
}

/// Free a CFileMetadata returned by parquet_viewer_read_metadata
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_free_metadata(metadata: *mut CFileMetadata) {
    if metadata.is_null() {
        return;
    }

    unsafe {
        let metadata = Box::from_raw(metadata);
        
        // Free created_by string
        if !metadata.created_by.is_null() {
            let _ = CString::from_raw(metadata.created_by);
        }
        
        // Free key-value metadata
        if !metadata.key_value_metadata.is_null() && metadata.key_value_count > 0 {
            let kv_pairs = Vec::from_raw_parts(
                metadata.key_value_metadata,
                metadata.key_value_count,
                metadata.key_value_count,
            );
            
            for kv in kv_pairs {
                if !kv.key.is_null() {
                    let _ = CString::from_raw(kv.key);
                }
                if !kv.value.is_null() {
                    let _ = CString::from_raw(kv.value);
                }
            }
        }
    }
}

/// Free a CRecordBatchArray returned by parquet_viewer_read_data
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_free_data(data: *mut CRecordBatchArray) {
    if data.is_null() {
        return;
    }

    unsafe {
        let data = Box::from_raw(data);
        if !data.batches.is_null() && data.count > 0 {
            let batches = Vec::from_raw_parts(data.batches, data.count, data.count);
            for batch in batches {
                if !batch.json.is_null() {
                    let _ = CString::from_raw(batch.json);
                }
            }
        }
    }
}

/// Get the last error message
/// Returns NULL if no error, caller should not free the returned string
#[unsafe(no_mangle)]
pub extern "C" fn parquet_viewer_get_last_error() -> *const c_char {
    // This is a simplified error handling - in production you'd want thread-local storage
    static ERROR_MSG: &str = "Operation failed\0";
    ERROR_MSG.as_ptr() as *const c_char
}

fn batch_to_json(batch: &arrow::array::RecordBatch) -> String {
    use serde_json::Value;
    
    let mut rows = Vec::new();
    for row_idx in 0..batch.num_rows() {
        let mut row_obj = serde_json::Map::new();
        for col_idx in 0..batch.num_columns() {
            let column = batch.column(col_idx);
            let schema = batch.schema();
            let field = schema.field(col_idx);
            let value_str = arrow::util::display::array_value_to_string(column, row_idx).unwrap_or_else(|_| "null".to_string());
            
            // Convert the value string to appropriate JSON value
            let json_value = if value_str == "null" {
                Value::Null
            } else if value_str.is_empty() {
                Value::String("".to_string())
            } else {
                // Try to parse as number if possible
                if let Ok(num) = value_str.parse::<i64>() {
                    Value::Number(serde_json::Number::from(num))
                } else if let Ok(num) = value_str.parse::<f64>() {
                    if let Some(n) = serde_json::Number::from_f64(num) {
                        Value::Number(n)
                    } else {
                        Value::String(value_str)
                    }
                } else if value_str == "true" {
                    Value::Bool(true)
                } else if value_str == "false" {
                    Value::Bool(false)
                } else {
                    Value::String(value_str)
                }
            };
            
            row_obj.insert(field.name().to_string(), json_value);
        }
        rows.push(Value::Object(row_obj));
    }
    
    serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_string())
}
