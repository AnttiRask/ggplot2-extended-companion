## ADDED Requirements

### Requirement: merge_package_data combines all data sources
`merge_package_data()` SHALL join curated data, CRAN metadata, download stats, GitHub metadata, and constructed URLs into a single tibble.

#### Scenario: Successful merge
- **WHEN** all data sources are provided
- **THEN** the result SHALL contain all columns from §3.1 (Package Entity) with one row per package

### Requirement: write_parquet_output writes Parquet files
`write_parquet_output()` SHALL write a data frame to a Parquet file at the specified path.

#### Scenario: Successful write
- **WHEN** `write_parquet_output(df, "data/packages.parquet")` is called
- **THEN** the file SHALL be created and readable with `arrow::read_parquet()`

### Requirement: write_metadata records pipeline run info
`write_metadata()` SHALL write pipeline run metadata to `data/metadata.parquet`.

#### Scenario: Metadata written
- **WHEN** `write_metadata()` is called after a pipeline run
- **THEN** `data/metadata.parquet` SHALL contain columns `source`, `last_run`, `status`
