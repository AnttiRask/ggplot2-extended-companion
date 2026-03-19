## 1. License Checking (TDD)

- [x] 1.1 Write tests for check_license_allowed() — match against allowlist patterns
- [x] 1.2 Implement check_license_allowed() in R/fct_examples.R

## 2. Example Extraction and Rendering (TDD)

- [x] 2.1 Write tests for extract_example() — extracts code from package docs
- [x] 2.2 Implement extract_example()
- [x] 2.3 Write tests for render_example() — renders code in subprocess, captures PNG
- [x] 2.4 Implement render_example()
- [x] 2.5 Implement render_examples() — orchestrates rendering for all packages

## 3. Pipeline Integration

- [x] 3.1 Pipeline targets for examples deferred to CI (M10) — functions ready
- [x] 3.2 Add callr to DESCRIPTION

## 4. Detail View Code Example Card

- [x] 4.1 Create clipboard.js for copy-to-clipboard functionality
- [x] 4.2 Build code example card in mod_detail.R (success, failure, license cases)
- [x] 4.3 Write tests for build_example_card() — 4 test cases
- [x] 4.4 Update fct_data.R to load examples.parquet

## 5. Verification

- [x] 5.1 Run full test suite — 208 pass, 3 skip (ggplot2 not in renv)
- [x] 5.2 Detail view includes code example card
