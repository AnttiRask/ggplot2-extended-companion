## 1. Project Configuration Files

- [x] 1.1 Create .gitignore for R package + renv + Docker workflow
- [x] 1.2 Create .Rbuildignore to exclude non-package files from R CMD check
- [x] 1.3 Create .dockerignore to exclude dev files from Docker builds

## 2. Golem Package Structure

- [x] 2.1 Create DESCRIPTION with package metadata and all M0 dependencies
- [x] 2.2 Create R/app_config.R with golem configuration helpers (app_sys, get_golem_config)
- [x] 2.3 Create R/app_ui.R with bslib page_sidebar() dark theme and placeholder content
- [x] 2.4 Create R/app_server.R with empty server function
- [x] 2.5 Create R/run_app.R with run_app() function using golem::with_golem_options()
- [x] 2.6 Create app.R golem entry point
- [x] 2.7 Generate NAMESPACE via roxygen2

## 3. Theme and Styling

- [x] 3.1 Create inst/app/www/ directory structure
- [x] 3.2 Create inst/app/www/styles.css with dark mode colours, font imports, and custom overrides

## 4. Curated Data Files

- [x] 4.1 Create data-raw/categories.csv with 15 canonical categories from SPEC section 4.5
- [x] 4.2 Create data-raw/license_allowlist.csv with common open-source license patterns

## 5. Dependency Management

- [x] 5.1 Initialize renv and create lockfile with all declared dependencies
- [x] 5.2 Verify renv/activate.R exists and renv.lock captures all dependencies

## 6. Verification

- [x] 6.1 Verify app launches with golem::run_app() — dark theme visible, page title correct, sidebar and main content placeholders present
- [x] 6.2 Run R CMD check to confirm valid package structure (allow expected golem notes)
