## 1. Dependencies

- [x] 1.1 Add `desc` to DESCRIPTION Imports and install via renv

## 2. fetch_github_descriptions()

- [x] 2.1 Create test fixture: mock GitHub DESCRIPTION API response (base64-encoded)
- [x] 2.2 Write failing tests for `fetch_github_descriptions()`: CRAN package returns NA, non-CRAN parses fields, error handling returns NA row, cache write
- [x] 2.3 Implement `fetch_github_descriptions()` in `R/fct_pipeline.R`
- [x] 2.4 Run tests to confirm they pass

## 3. merge_package_data() update

- [x] 3.1 Write failing tests for updated `merge_package_data()`: github_desc parameter, version derivation, cache loading
- [x] 3.2 Update `merge_package_data()` signature and implementation
- [x] 3.3 Run tests to confirm they pass

## 4. export_json() update

- [x] 4.1 Write failing tests for `is_archived` and `version` in JSON export
- [x] 4.2 Update `export_json()` to include `is_archived` and `version`
- [x] 4.3 Run tests to confirm they pass

## 5. _targets.R update

- [x] 5.1 Add step 4.5 target (github_descriptions) gated by should_render_examples()
- [x] 5.2 Update step 6 (packages_combined) to pass github_desc parameter
- [x] 5.3 Write/update pipeline DAG tests to verify new target and edges

## 6. Final Verification

- [x] 6.1 Run full test suite to confirm no regressions
