## ADDED Requirements

### Requirement: _targets.R defines the pipeline DAG
The `_targets.R` file SHALL define a {targets} pipeline that orchestrates all data fetching, merging, and output steps.

#### Scenario: Pipeline runs successfully
- **WHEN** `targets::tar_make()` is executed
- **THEN** it SHALL produce `data/packages.parquet`, `data/downloads.parquet`, and `data/metadata.parquet`

#### Scenario: Pipeline handles partial failures
- **WHEN** some API calls fail during the pipeline run
- **THEN** the pipeline SHALL continue and produce output files with NA values for failed packages
