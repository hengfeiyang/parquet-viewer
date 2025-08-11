use clap::{command, Arg, ArgAction, Command};
use parquet_viewer::{read_data, read_metadata, read_schema};
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
    println!("{:#?}", schema);

    Ok(())
}

fn handle_metadata(file_path: &str) -> parquet_viewer::Result<()> {
    let path = Path::new(file_path);
    let metadata = read_metadata(path)?;

    println!("Metadata for: {}", file_path);
    println!("File size: {} bytes", metadata.file_size);
    println!("Total records: {}", metadata.total_records);
    println!("Total fields: {}", metadata.total_fields);
    println!("Total row groups: {}", metadata.total_row_groups);
    println!("Parquet version: {}", metadata.version);

    if let Some(created_by) = metadata.created_by {
        println!("Created by: {}", created_by);
    }

    if let Some(kv_metadata) = metadata.key_value_metadata {
        println!("\nKey-Value Metadata:");
        for (key, value) in kv_metadata {
            println!("  {}: {}", key, value);
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

        for col_idx in 0..batch.num_columns() {
            let column = batch.column(col_idx);
            let schema = batch.schema();
            let field = schema.field(col_idx);
            println!("\nColumn '{}' ({}): ", field.name(), field.data_type());

            for row_idx in 0..rows_to_print {
                let value = arrow::util::display::array_value_to_string(column, row_idx)?;
                println!("  [{}]: {}", row_idx, value);
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
