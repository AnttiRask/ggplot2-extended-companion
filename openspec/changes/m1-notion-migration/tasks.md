## 1. CSV Validation Functions (TDD)

- [x] 1.1 Write tests for validate_no_duplicates() — valid and duplicate cases
- [x] 1.2 Implement validate_no_duplicates() in R/fct_validation.R
- [x] 1.3 Write tests for validate_required_fields() — valid and missing field cases
- [x] 1.4 Implement validate_required_fields()
- [x] 1.5 Write tests for validate_is_essential() — valid booleans and invalid values
- [x] 1.6 Implement validate_is_essential()
- [x] 1.7 Write tests for validate_category_format() — well-formed, trailing pipe, spaces
- [x] 1.8 Implement validate_category_format()
- [x] 1.9 Write tests for validate_categories() — valid and invalid categories against canonical list
- [x] 1.10 Implement validate_categories()
- [x] 1.11 Write tests for validate_curated_csv() — combined validation, all-pass and multi-error cases
- [x] 1.12 Implement validate_curated_csv()

## 2. Migration Script

- [x] 2.1 Create data-raw/migrate_notion.R — read Notion export, build category lookup table from categories.csv
- [x] 2.2 Implement column mapping and category conversion (display name → snake_case, comma → pipe)
- [x] 2.3 Add default values for missing fields (is_essential = FALSE, date_added, notes)
- [x] 2.4 Write packages_curated.csv and run validate_curated_csv() as final check

## 3. Verification

- [x] 3.1 Run full test suite — all validation tests pass
- [x] 3.2 Run migration script — produces valid packages_curated.csv with 455 rows
- [x] 3.3 Verify all categories in output match canonical list (zero validation errors)
