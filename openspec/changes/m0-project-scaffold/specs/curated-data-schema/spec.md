## ADDED Requirements

### Requirement: Categories CSV exists with canonical list
The file `data-raw/categories.csv` SHALL contain all 15 canonical categories from SPEC section 4.5.

#### Scenario: Categories file structure
- **WHEN** `data-raw/categories.csv` is read
- **THEN** it SHALL have columns: `category`, `display_name`, `description`

#### Scenario: All categories present
- **WHEN** the categories are counted
- **THEN** there SHALL be exactly 15 categories matching the list in SPEC section 4.5 (animation, annotations, arranging_plots, colours, geoms, helpers, interactive_plots, maps, networks, rendering, scales_and_guides, sports, stats, themes, transformations)

### Requirement: License allowlist CSV exists
The file `data-raw/license_allowlist.csv` SHALL define which licenses permit code example rendering.

#### Scenario: License allowlist structure
- **WHEN** `data-raw/license_allowlist.csv` is read
- **THEN** it SHALL have columns: `license_pattern`, `allowed`

#### Scenario: Common open-source licenses included
- **WHEN** the allowlist is checked
- **THEN** it SHALL include patterns for MIT, GPL-2, GPL-3, Apache-2.0, and BSD licenses with `allowed = TRUE`
