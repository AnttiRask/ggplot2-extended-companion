## Why

The pipeline produces Parquet files but the app currently shows placeholder content. M3 wires the data into the Shiny app — loading Parquet files via DuckDB at startup and displaying all packages in a searchable, sortable reactable table.

## What Changes

- Create `R/fct_data.R` — data loading functions using DuckDB to read Parquet files
- Create `R/mod_browse.R` — browse module with reactable table (9 columns, pagination, search)
- Update `R/app_server.R` — load data at startup, call browse module
- Update `R/app_ui.R` — include browse module UI in main panel
- Create tests for data loading and browse module

## Capabilities

### New Capabilities
- `data-loading`: Functions to load packages and downloads from Parquet files via DuckDB
- `browse-table`: Shiny module displaying a searchable, sortable reactable table of all packages

### Modified Capabilities
<!-- None -->

## Impact

- **Modified files**: R/app_server.R, R/app_ui.R
- **New files**: R/fct_data.R, R/mod_browse.R, tests
- **Dependencies**: duckdb, dbplyr, reactable (already in DESCRIPTION)
- **Requires**: data/packages.parquet, data/downloads.parquet from pipeline
