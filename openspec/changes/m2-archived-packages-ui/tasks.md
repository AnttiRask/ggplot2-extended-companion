## 1. Filter Logic

- [x] 1.1 Update `make_test_data()` in test-fct_filters.R to include `is_archived` column (default FALSE, one TRUE row)
- [x] 1.2 Write failing tests for `show_archived` parameter: default hides archived, TRUE shows archived, composes with other filters
- [x] 1.3 Add `show_archived` parameter to `filter_packages()` with archived filter as first filter
- [x] 1.4 Run tests to confirm they pass

## 2. Sidebar Checkbox

- [x] 2.1 Add "Show Archived Packages" checkbox to `mod_sidebar_ui()` after "Recently Updated"
- [x] 2.2 Add `show_archived` to `mod_sidebar_server()` return list

## 3. App Server Integration

- [x] 3.1 Add `show_archived` to `filtered_data` reactive in `app_server.R`, pass to `filter_packages()`

## 4. Browse Table Display

- [x] 4.1 Add 📁 archived badge in `build_package_table()` Name column cell renderer
- [x] 4.2 Add `is_archived` to hidden columns list in `build_package_table()`

## 5. Detail View Display

- [x] 5.1 Add archived badge in `build_header_card()` alongside essential badge
- [x] 5.2 Add archived warning banner with notes in detail view (above header card)

## 6. CSS

- [x] 6.1 Add `.badge-archived` CSS class to styles.css

## 7. Final Verification

- [x] 7.1 Run full test suite to confirm no regressions
