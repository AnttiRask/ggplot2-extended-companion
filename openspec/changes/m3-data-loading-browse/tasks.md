## 1. Data Loading Functions (TDD)

- [x] 1.1 Write tests for load_packages() — returns tibble with expected columns
- [x] 1.2 Implement load_packages() in R/fct_data.R
- [x] 1.3 Write tests for load_downloads() — returns tibble with download columns
- [x] 1.4 Implement load_downloads()
- [x] 1.5 Write test for load_app_data() — combines packages + downloads
- [x] 1.6 Implement load_app_data()

## 2. Browse Module

- [x] 2.1 Create mod_browse_ui() with reactable output placeholder
- [x] 2.2 Implement mod_browse_server() with reactable table (9 columns, formatting, pagination, search)
- [x] 2.3 Add package name click handler (Shiny.setInputValue infrastructure)

## 3. App Integration

- [x] 3.1 Update app_server.R — load data at startup, call browse module
- [x] 3.2 Update app_ui.R — replace placeholder with browse module UI
- [x] 3.3 Add dbplyr to DESCRIPTION imports

## 4. Verification

- [x] 4.1 Run full test suite — all 127 tests pass
- [x] 4.2 Verify app launches with populated table (455 rows, 22 columns)
