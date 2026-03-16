## ADDED Requirements

### Requirement: bslib dark theme as default
The app SHALL use bslib with Bootstrap 5 and dark mode as the default colour mode.

#### Scenario: App launches in dark mode
- **WHEN** the app is launched via `golem::run_app()`
- **THEN** the page background SHALL be `#191414` and text SHALL be `#FFFFFF`

#### Scenario: Dark/light toggle exists
- **WHEN** the app UI is rendered
- **THEN** an `input_dark_mode()` toggle SHALL be present with `mode = "dark"` as default

### Requirement: Colour palette matches spec
The bslib theme SHALL use the colour palette defined in SPEC section 7.

#### Scenario: Primary accent colour
- **WHEN** the theme is applied
- **THEN** primary accent colour SHALL be `#C1272D`

#### Scenario: Dark mode colours
- **WHEN** dark mode is active
- **THEN** background SHALL be `#191414`, foreground SHALL be `#FFFFFF`

### Requirement: page_sidebar layout
The app SHALL use `bslib::page_sidebar()` as the primary layout with a sidebar and main content area.

#### Scenario: Layout structure
- **WHEN** the app UI is rendered
- **THEN** it SHALL contain a sidebar (placeholder content) and a main content area (placeholder content)

#### Scenario: Page title
- **WHEN** the app is loaded in a browser
- **THEN** the page title SHALL be "ggplot2 Extended Companion"

### Requirement: Typography configuration
The theme SHALL configure fonts as specified in SPEC section 7.

#### Scenario: Font families
- **WHEN** the theme is applied
- **THEN** headings SHALL use Gotham (with Inter as fallback), body text SHALL use Inter, and code blocks SHALL use Fira Code / Source Code Pro / monospace
