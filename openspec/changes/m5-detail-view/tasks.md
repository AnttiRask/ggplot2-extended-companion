## 1. Detail Module

- [x] 1.1 Create mod_detail_ui() with conditional display placeholder
- [x] 1.2 Implement mod_detail_server() — renders package detail cards from selected package data
- [x] 1.3 Build package header card (name, essential badge, description, maintainer, categories, license)
- [x] 1.4 Build links card (website, GitHub, CRAN, manual, vignettes — hide NA links)
- [x] 1.5 Build download statistics card (4 value boxes: 7d, 30d, 365d, all-time)
- [x] 1.6 Build version info card (CRAN version + published, GitHub updated)
- [x] 1.7 Add back button ("← Back to all packages")

## 2. Browse/Detail Toggle

- [x] 2.1 Update app_ui.R — add conditionalPanel for browse vs detail view
- [x] 2.2 Update app_server.R — toggle between browse and detail based on selected_package
- [x] 2.3 Wire back button to clear selected_package and return to browse view

## 3. Verification

- [x] 3.1 Run full test suite — all 150 tests pass
- [x] 3.2 App launches with browse/detail toggle working
