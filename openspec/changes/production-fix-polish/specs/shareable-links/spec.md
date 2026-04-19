## ADDED Requirements

### Requirement: URL updates when viewing a package
When a user navigates to a package detail view, the browser URL SHALL update to include the package name as a query parameter in the format `?package={package_name}`.

#### Scenario: Clicking package updates URL
- **WHEN** a user clicks on "ggrepel" in the browse table
- **THEN** the browser URL updates to include `?package=ggrepel` without a page reload

#### Scenario: Back button clears URL parameter
- **WHEN** a user clicks "← Back to all packages" from the detail view
- **THEN** the `?package=` parameter is removed from the URL

### Requirement: Direct navigation via URL parameter
When the app loads with a `?package={name}` query parameter, it SHALL navigate directly to that package's detail view without showing the browse table first.

#### Scenario: Load app with package parameter
- **WHEN** a user opens the URL `{app_url}?package=ggrepel`
- **THEN** the app loads directly into the ggrepel detail view

#### Scenario: Invalid package parameter
- **WHEN** a user opens the URL `{app_url}?package=nonexistent_package`
- **THEN** the app shows the browse table (falls back to browse view)

#### Scenario: Shareable link round-trip
- **WHEN** a user copies the URL while viewing a package and pastes it into a new browser tab
- **THEN** the new tab opens directly to the same package's detail view

### Requirement: URL routing uses standard Shiny mechanisms
The URL routing SHALL use `shiny::updateQueryString()` to update the URL and `shiny::parseQueryString(session$clientData$url_search)` to read the URL on app load. No additional routing libraries SHALL be added.

#### Scenario: URL updates use updateQueryString
- **WHEN** a package is selected
- **THEN** `shiny::updateQueryString()` is called with the query string `?package={name}`

#### Scenario: URL parsed on startup
- **WHEN** the app initializes
- **THEN** `session$clientData$url_search` is parsed for a `package` parameter and if present, `selected_package()` is set to that value
