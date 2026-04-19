## Why

With `is_archived` now in the data model (M1), users need a way to see archived packages when desired and understand their archived status. By default archived packages should be hidden to keep the directory focused on active packages, with an opt-in toggle and clear visual indicators.

## What Changes

- Add `show_archived` parameter to `filter_packages()` — hidden by default, shown when TRUE
- Add "Show Archived Packages" checkbox to sidebar (last position)
- Pass `show_archived` reactive through `app_server.R` to `filter_packages()`
- Add 📁 archived badge in browse table Name column
- Add archived badge, warning banner with notes in detail view
- Add `.badge-archived` CSS class
- Add `is_archived` to hidden columns in browse table

## Capabilities

### New Capabilities
- `archived-packages-filter`: Sidebar checkbox and filter logic for showing/hiding archived packages
- `archived-packages-display`: Visual indicators (emojis, badges, banners) for archived packages in browse and detail views

### Modified Capabilities

## Impact

- **Code**: `R/fct_filters.R`, `R/mod_sidebar.R`, `R/mod_browse.R`, `R/mod_detail.R`, `R/app_server.R`
- **CSS**: `inst/app/www/styles.css`
- **Tests**: `tests/testthat/test-fct_filters.R`
- **Dependencies**: None new
