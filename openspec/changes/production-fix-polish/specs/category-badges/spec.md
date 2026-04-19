## ADDED Requirements

### Requirement: Category display names in sidebar and table
The sidebar category dropdown and the browse table category column SHALL display `display_name` values (e.g., "Arranging Plots") instead of technical category identifiers (e.g., "arranging_plots"). The mapping SHALL be read from `data-raw/categories.csv` which contains `category`, `display_name`, and `description` columns.

#### Scenario: Sidebar category dropdown shows display names
- **WHEN** the sidebar renders the category dropdown
- **THEN** the choices display "All", "Animation", "Annotations", "Arranging Plots", etc. (display_name values, sorted alphabetically)

#### Scenario: Table category badges show display names
- **WHEN** a package row renders in the browse table with categories "arranging_plots|geoms"
- **THEN** two badges appear showing "Arranging Plots" and "Geoms" (not "arranging_plots" and "geoms")

#### Scenario: Category filter still works with display names
- **WHEN** a user selects "Arranging Plots" from the category dropdown
- **THEN** the table filters to show only packages whose `categories` pipe-separated list contains "arranging_plots"

### Requirement: All categories shown as badges in browse table
The browse table category column SHALL display ALL categories for a package as separate badges. The previous behaviour of showing the first category plus "+N" for additional categories is removed.

#### Scenario: Package with multiple categories shows all badges
- **WHEN** a package has categories "animation|geoms|interactive_plots"
- **THEN** three separate badges appear in the cell: "Animation", "Geoms", "Interactive Plots"

#### Scenario: Badges wrap within the cell
- **WHEN** a package has 3+ categories and the column width cannot fit all badges on one line
- **THEN** badges wrap to additional lines within the cell (multi-line row height)

### Requirement: Category-specific badge colours
Each of the 19 categories SHALL have a distinct badge colour. The colour palette SHALL work in both dark and light modes using semi-transparent backgrounds with matching text colours.

#### Scenario: Dark mode badge rendering
- **WHEN** the app is in dark mode and a badge for category "animation" renders
- **THEN** the badge has background `rgba(139, 92, 246, 0.20)`, text colour `#8B5CF6`, and border `rgba(139, 92, 246, 0.40)`

#### Scenario: Light mode badge rendering
- **WHEN** the app is in light mode and a badge for category "animation" renders
- **THEN** the badge has background `rgba(139, 92, 246, 0.15)`, darkened text colour, and border `rgba(139, 92, 246, 0.30)`

#### Scenario: All 19 categories have distinct colours
- **WHEN** the category colour map is loaded
- **THEN** all 19 categories (animation, annotations, arranging_plots, coords, data, facets, finishing_touches, geoms, helpers, interactive_plots, interactive_tools, maps, networks, python, scales_and_guides, sports, stats, themes, na) have a unique hex colour assigned

### Requirement: Category and License columns are sortable
The Category and License columns in the browse table SHALL be sortable by clicking the column header. Category sorts alphabetically by the first category's display name. License sorts alphabetically. Ties in both columns SHALL preserve the existing row order (which is alphabetical by package_name).

#### Scenario: Sort by category column header
- **WHEN** a user clicks the "Category" column header in the browse table
- **THEN** the table sorts alphabetically by the first category's display name (e.g., packages with "Animation" first, "Themes" last)

#### Scenario: Sort by license column header
- **WHEN** a user clicks the "License" column header
- **THEN** the table sorts alphabetically by license string

#### Scenario: Reverse sort on second click
- **WHEN** a user clicks the same column header a second time
- **THEN** the sort order reverses (Z→A instead of A→Z)

### Requirement: Category badge helper module
A new file `R/fct_categories.R` SHALL provide helper functions for category display name mapping and badge colour rendering.

#### Scenario: get_category_display_names returns complete mapping
- **WHEN** `get_category_display_names()` is called
- **THEN** it returns a named character vector with 19 entries mapping category technical names to display names

#### Scenario: build_category_badge produces correct HTML
- **WHEN** `build_category_badge("arranging_plots", display_names, colours)` is called
- **THEN** it returns an `htmltools::span()` with text "Arranging Plots", pill-shaped badge styling, and the correct category colour
