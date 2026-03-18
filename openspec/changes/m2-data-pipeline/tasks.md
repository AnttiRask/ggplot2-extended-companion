## 1. URL Construction (TDD)

- [x] 1.1 Write tests for construct_urls() — CRAN and non-CRAN packages
- [x] 1.2 Implement construct_urls() in R/fct_urls.R

## 2. Pipeline Functions (TDD)

- [x] 2.1 Create test fixtures for mock API responses (CRAN, cranlogs, GitHub)
- [x] 2.2 Write tests for read_curated_csv()
- [x] 2.3 Implement read_curated_csv() in R/fct_pipeline.R
- [x] 2.4 Write tests for fetch_cran_metadata() with mocked responses
- [x] 2.5 Implement fetch_cran_metadata()
- [x] 2.6 Write tests for fetch_download_stats() with mocked responses
- [x] 2.7 Implement fetch_download_stats()
- [x] 2.8 Write tests for fetch_github_metadata() with mocked responses
- [x] 2.9 Implement fetch_github_metadata()
- [x] 2.10 Write tests for merge_package_data()
- [x] 2.11 Implement merge_package_data()
- [x] 2.12 Write tests for write_parquet_output()
- [x] 2.13 Implement write_parquet_output()
- [x] 2.14 Implement write_metadata()

## 3. Pipeline Orchestration

- [x] 3.1 Create _targets.R with pipeline DAG definition
- [x] 3.2 Update DESCRIPTION with new dependencies (targets, pkgsearch, cranlogs, gh)

## 4. Verification

- [x] 4.1 Run full test suite — all tests pass (109 total)
- [ ] 4.2 Run targets::tar_make() — produces valid Parquet files
- [ ] 4.3 Verify packages.parquet has ~455 rows with expected columns
