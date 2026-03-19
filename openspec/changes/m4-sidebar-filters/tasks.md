## 1. Sidebar Module

- [x] 1.1 Create mod_sidebar_ui() with all filter controls (category, CRAN status, license, essential, sort)
- [x] 1.2 Create mod_sidebar_server() returning filter/sort reactive values

## 2. Filtering Logic

- [x] 2.1 Write tests for filter_packages() — category, CRAN status, license, essential filters
- [x] 2.2 Implement filter_packages() in R/fct_filters.R
- [x] 2.3 Write tests for sort_packages() — all 10 sort options

## 3. App Integration

- [x] 3.1 Update app_ui.R — replace sidebar placeholder with dynamic uiOutput for mod_sidebar_ui
- [x] 3.2 Update app_server.R — wire sidebar filters to browse table via filtered_data reactive
- [x] 3.3 Sidebar populated with data-driven category and license choices

## 4. Verification

- [x] 4.1 Run full test suite — all 150 tests pass
- [x] 4.2 App launches with sidebar controls and filtered browse table
