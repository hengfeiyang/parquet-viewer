use clap::{command, Arg, ArgAction, Command};
use parquet_viewer::{read_data, read_metadata, read_schema};
use prettytable::{Table, Row, Cell};
use std::path::Path;

fn main() {
    env_logger::init();

    let matches = command!()
        .subcommand(
            Command::new("schema")
                .about("Read and display the schema of a Parquet file")
                .arg(
                    Arg::new("file")
                        .help("Path to the Parquet file")
                        .required(true)
                        .index(1),
                ),
        )
        .subcommand(
            Command::new("metadata")
                .about("Read and display metadata of a Parquet file")
                .arg(
                    Arg::new("file")
                        .help("Path to the Parquet file")
                        .required(true)
                        .index(1),
                ),
        )
        .subcommand(
            Command::new("data")
                .about("Read and display data from a Parquet file")
                .arg(
                    Arg::new("file")
                        .help("Path to the Parquet file")
                        .required(true)
                        .index(1),
                )
                .arg(
                    Arg::new("batch-size")
                        .short('b')
                        .long("batch-size")
                        .help("Number of rows per batch")
                        .value_parser(clap::value_parser!(usize))
                        .action(ArgAction::Set),
                )
                .arg(
                    Arg::new("limit")
                        .short('l')
                        .long("limit")
                        .help("Maximum number of rows to display")
                        .value_parser(clap::value_parser!(usize))
                        .action(ArgAction::Set),
                ),
        )
        .subcommand_required(true)
        .get_matches();

    let result = match matches.subcommand() {
        Some(("schema", sub_matches)) => {
            let file_path = sub_matches.get_one::<String>("file").unwrap();
            handle_schema(file_path)
        }
        Some(("metadata", sub_matches)) => {
            let file_path = sub_matches.get_one::<String>("file").unwrap();
            handle_metadata(file_path)
        }
        Some(("data", sub_matches)) => {
            let file_path = sub_matches.get_one::<String>("file").unwrap();
            let batch_size = sub_matches.get_one::<usize>("batch-size").copied();
            let limit = sub_matches.get_one::<usize>("limit").copied();
            handle_data(file_path, batch_size, limit)
        }
        _ => unreachable!(),
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}

fn handle_schema(file_path: &str) -> parquet_viewer::Result<()> {
    let path = Path::new(file_path);
    let schema = read_schema(path)?;

    println!("Schema for: {}", file_path);
    
    let mut table = Table::new();
    table.add_row(Row::new(vec![
        Cell::new("Field Name"),
        Cell::new("Data Type"),
        Cell::new("Nullable"),
    ]));

    for field in schema.fields() {
        table.add_row(Row::new(vec![
            Cell::new(field.name()),
            Cell::new(&format!("{:?}", field.data_type())),
            Cell::new(if field.is_nullable() { "Yes" } else { "No" }),
        ]));
    }

    table.printstd();

    Ok(())
}

fn handle_metadata(file_path: &str) -> parquet_viewer::Result<()> {
    let path = Path::new(file_path);
    let metadata = read_metadata(path)?;

    println!("Metadata for: {}", file_path);
    
    let mut table = Table::new();
    table.add_row(Row::new(vec![
        Cell::new("Property"),
        Cell::new("Value"),
    ]));

    table.add_row(Row::new(vec![
        Cell::new("File size"),
        Cell::new(&format!("{} bytes", metadata.file_size)),
    ]));
    table.add_row(Row::new(vec![
        Cell::new("Total records"),
        Cell::new(&metadata.total_records.to_string()),
    ]));
    table.add_row(Row::new(vec![
        Cell::new("Total fields"),
        Cell::new(&metadata.total_fields.to_string()),
    ]));
    table.add_row(Row::new(vec![
        Cell::new("Total row groups"),
        Cell::new(&metadata.total_row_groups.to_string()),
    ]));
    table.add_row(Row::new(vec![
        Cell::new("Parquet version"),
        Cell::new(&metadata.version.to_string()),
    ]));

    if let Some(created_by) = metadata.created_by {
        table.add_row(Row::new(vec![
            Cell::new("Created by"),
            Cell::new(&created_by),
        ]));
    }

    table.printstd();

    if let Some(kv_metadata) = metadata.key_value_metadata {
        if !kv_metadata.is_empty() {
            println!("\nKey-Value Metadata:");
            let mut kv_table = Table::new();
            kv_table.add_row(Row::new(vec![
                Cell::new("Key"),
                Cell::new("Value"),
            ]));

            for (key, value) in kv_metadata {
                // Truncate long values for better display
                let display_value = if value.len() > 100 {
                    format!("{}...", &value[..100])
                } else {
                    value.clone()
                };
                
                kv_table.add_row(Row::new(vec![
                    Cell::new(&key),
                    Cell::new(&display_value),
                ]));
            }

            kv_table.printstd();
        }
    }

    Ok(())
}

fn handle_data(
    file_path: &str,
    batch_size: Option<usize>,
    limit: Option<usize>,
) -> parquet_viewer::Result<()> {
    let path = Path::new(file_path);
    let batches = read_data(path, batch_size)?;

    println!("Data from: {}", file_path);

    let mut total_rows = 0;
    for (batch_idx, batch) in batches.iter().enumerate() {
        if let Some(limit) = limit {
            if total_rows >= limit {
                break;
            }
        }

        println!(
            "\nBatch {}: {} rows x {} columns",
            batch_idx,
            batch.num_rows(),
            batch.num_columns()
        );

        let rows_to_print = if let Some(limit) = limit {
            std::cmp::min(batch.num_rows(), limit - total_rows)
        } else {
            std::cmp::min(batch.num_rows(), 10)
        };

        if rows_to_print > 0 {
            // For wide tables, show data in a more compact format
            if batch.num_columns() > 8 {
                println!("Showing data in compact format ({} columns):", batch.num_columns());
                
                for row_idx in 0..rows_to_print {
                    println!("Row {}:", row_idx);
                    for col_idx in 0..batch.num_columns() {
                        let column = batch.column(col_idx);
                        let schema = batch.schema();
                        let field = schema.field(col_idx);
                        let value = arrow::util::display::array_value_to_string(column, row_idx)?;
                        
                        // Truncate long values
                        let display_value = if value.len() > 100 {
                            format!("{}...", &value[..100])
                        } else {
                            value
                        };
                        
                        println!("  {}: {}", field.name(), display_value);
                    }
                    println!();
                }
            } else {
                // Create table for narrower datasets
                let mut table = Table::new();
                
                // Add header row
                let mut header_cells = Vec::new();
                for col_idx in 0..batch.num_columns() {
                    let schema = batch.schema();
                    let field = schema.field(col_idx);
                    header_cells.push(Cell::new(&format!("{} ({:?})", field.name(), field.data_type())));
                }
                table.add_row(Row::new(header_cells));

                // Add data rows
                for row_idx in 0..rows_to_print {
                    let mut row_cells = Vec::new();
                    for col_idx in 0..batch.num_columns() {
                        let column = batch.column(col_idx);
                        let value = arrow::util::display::array_value_to_string(column, row_idx)?;
                        
                        // Truncate long values for better display
                        let display_value = if value.len() > 30 {
                            format!("{}...", &value[..30])
                        } else {
                            value
                        };
                        
                        row_cells.push(Cell::new(&display_value));
                    }
                    table.add_row(Row::new(row_cells));
                }

                table.set_format(*prettytable::format::consts::FORMAT_BOX_CHARS);
                table.printstd();
            }
        }

        total_rows += batch.num_rows();

        if rows_to_print < batch.num_rows() {
            println!(
                "\n... {} more rows in this batch",
                batch.num_rows() - rows_to_print
            );
        }
    }

    println!("\nTotal rows displayed: {}", total_rows);

    Ok(())
}
