# REQUIREMENTS.md
## ggplot2 extended (companion) — Production Fix & Polish Round

### 1. Overview
- **Purpose**: This document captures the bugs, spec corrections, and feature additions needed to bring the ggplot2 extended (companion) Shiny app from its current state to a polished, correct release. The app is a searchable, filterable directory of ~455 ggplot2 extension packages with daily-refreshed metadata, download statistics, and pre-rendered code examples. These requirements address issues discovered during production use and stakeholder review.
- **Target Users**: R developers and data analysts who use ggplot2 and want to discover extension packages that enhance their plots.
- **Success Criteria**: All must-have items resolved. Dark/light mode works consistently across all views. Data displays correctly (Title vs. Description). Filters (including sort) are fully functional. The app looks and feels correct in both color modes.
- **Context**: The app is already built and deployed. This is a bug-fix and polish round, not a greenfield build. The existing SPEC.md remains the source of truth for overall architecture — this document captures **corrections to the spec** and **new requirements** discovered during production review.

### 2. Functional Requirements

#### 2.1 App Title
- **Requirement**: Rename the app from "ggplot2 Extended Companion" to **"ggplot2 extended (companion)"** everywhere it appears — header, meta tags, page title, any internal references.
- **Priority**: Must-have

#### 2.2 Recently Added / Recently Updated → Filter Checkboxes
- **Current behavior**: Two separate cards above the main table showing lists of recently added and recently updated packages.
- **Required behavior**:
  - Remove the Recently Added and Recently Updated cards entirely.
  - Add two **checkbox filters** to the sidebar: "Recently Added" and "Recently Updated".
  - A package is flagged as `recently_added` if its `date_added` is within the past 7 days.
  - A package is flagged as `recently_updated` if `max(cran_published, github_updated)` is within the past 7 days.
  - These checkboxes are **stackable** with all other sidebar filters (category, CRAN status, license, essential).
  - When checked, the table shows only packages matching the flag. Both can be checked simultaneously. **Open question for developer**: Confirm whether AND or OR logic is more useful when both are checked. Stakeholder preference: whichever is more practical.
- **Layout impact**: The main table moves up to occupy the space previously held by the Recently Added/Updated cards.
- **Priority**: Must-have

#### 2.3 "What are ggplot2 extensions?" Section
- **Current behavior**: Collapsible `bslib::accordion()` panel, collapsed by default.
- **Required behavior**:
  - Convert to **plain text** — always visible, no accordion, no collapsible behavior.
  - Update the links within the section:
    - "ggplot2 extensions gallery" → **"ggplot2 extended (the book)"** with a link to https://ggplot2-extended-book.com/.
    - Keep the **"ggplot2 documentation"** link.
  - The section should remain understated — informative for newcomers, unobtrusive for regulars.
- **Priority**: Must-have

#### 2.4 Sidebar Fixes
- **Category dropdown**: Display **`display_name`** values (e.g., "Arranging Plots") instead of technical names (e.g., "arranging_plots").
- **Essential checkbox label**: Change "Essential Extensions only" to **"Essential Extensions Only"** (capitalize the O).
- **Sort by dropdown**: Currently non-functional. **Must be investigated** — determine whether this is a wiring bug or an unbuilt feature, then fix/build it so it works as specified in SPEC.md §5.3.
- **Padding/margins**: Reduce sidebar padding/margins so the "Suggest a Package" button is visible without scrolling on a typical desktop viewport.
- **Suggest a Package button**: Keep visible but **disabled** with a **"Coming soon" tooltip**. The Google Form has not been created yet.
- **Priority**: All must-have except padding reduction (should-have)

#### 2.5 Main Table Changes

##### 2.5.1 Title vs. Description (Data Correction)
- **Current behavior**: The "Description" column shows the CRAN **Title** field (a short one-liner like "Animated Interactive Grammar of Graphics"), mislabeled as "Description".
- **Required behavior**:
  - Rename the table column from "Description" to **"Title"**.
  - The data source for this column should be the CRAN **Title** field (which is what is currently being displayed — the label is wrong, not the data).
  - In the **Package Detail view**, show:
    - **Title** as a subtitle directly under the package name.
    - **Description** (the longer CRAN Description field) as a paragraph below the Title.
  - This may require fetching the CRAN Description field in the pipeline if it is not already being captured.
- **Priority**: Must-have

##### 2.5.2 Category Display
- **Current behavior**: Shows the first category plus "+N" for packages with multiple categories (e.g., "animation +1").
- **Required behavior**: Show **all categories** as separate badges. Since Title and other fields already allow multi-line rows, multiple category badges can wrap to additional lines within the cell.
- **Category names**: Use **`display_name`** values, not technical names (consistent with sidebar fix in §2.4).
- **Category-specific colors**: Each of the 19 categories should have a **distinct badge color**. The color palette should:
  - Work well in both dark and light modes.
  - Be proposed by the designer/developer (no specific palette mandated by stakeholder).
- **Priority**: Must-have (display all categories + display names). Category-specific colors: must-have.

##### 2.5.3 Table Position
- The main table should occupy the space previously held by the Recently Added/Updated cards (i.e., higher up in the layout). See §2.2.
- **Priority**: Must-have

#### 2.6 Package Detail View Fixes

##### 2.6.1 Link Labels
- **Current**: "GitHub/GitLab" label for the repository link.
- **Required**: Change to **"Repo (GitHub, etc.)"**.
- **Priority**: Must-have

##### 2.6.2 Vignettes Link
- **Current behavior**: May show even when no vignettes exist.
- **Required behavior**: **Hide the vignettes link entirely** when the package has no vignettes. This is consistent with the existing pattern where unavailable links are hidden (not greyed out), as specified in SPEC.md §5.4.
- **Implementation note**: This requires a way to check whether vignettes actually exist for a given package. The developer should investigate the best approach (e.g., checking the CRAN page, using the `tools` package, or checking the constructed vignettes URL for a 404).
- **Priority**: Must-have

##### 2.6.3 Download Statistics Cards
- Remove the **graph emoji** from the download statistics value boxes.
- Rename **"All time (since 2015)"** to **"Since 2015"**.
- **Priority**: Must-have

##### 2.6.4 Back Button Styling
- The "← Back to all packages" button should have a **red border** and turn **red on hover/active** state (using the app's primary accent color `#C1272D`).
- **Priority**: Should-have

##### 2.6.5 Title and Description Layout
- Show the CRAN **Title** as a subtitle directly under the package name (h2 heading).
- Show the CRAN **Description** as a full paragraph below the Title.
- See §2.5.1 for data source details.
- **Priority**: Must-have

#### 2.7 Dark/Light Mode Consistency
- **Current behavior**: Color mode breaks when navigating between browse view and detail view. Light mode shows dark-styled boxes in the detail view. Dark mode shows white boxes in the detail view.
- **Required behavior**: The selected color mode (dark or light) must **persist consistently** across all views — browse, detail, sidebar, header, footer. No elements should render in the wrong mode.
- **Additional light mode issues**:
  - Search box renders in dark mode styling regardless of the active mode. Must respect the current color mode.
  - Background color should be **white (`#FFFFFF`)**, not gray. Text color adjusted accordingly (per SPEC.md §7: foreground light is `#1a1a1a`).
- **Priority**: Must-have

#### 2.8 Footer Updates
- **Current footer content** needs the following changes:
  - **Email address**: Change from `antti@youcanbeapirate.com` to **`anttilennartrask@gmail.com`** (as a clickable mailto link).
  - **Remove**: "ggplot2 extensions gallery | youcanbeapirate.com" line.
  - **Add**: "Check out the book (in progress): **ggplot2 extended**" — link to https://ggplot2-extended-book.com/.
  - **Keep** (with proper links):
    - "Package data last updated: {timestamp}"
    - Disclaimer with updated email
    - "Know a ggplot2 extension we're missing? Submit it here." — already disabled with tooltip, no change needed.
    - "Machine-readable data: packages.json" [LINK]
    - "Created by Antti Rask | youcanbeapirate.com" [LINK]
- **Priority**: Must-have

#### 2.9 Shareable Package Links
- **Requirement**: When a user is viewing a package detail page, the browser URL should update to include the package name (e.g., `?package=ggrepel` or a hash-based route like `#package/ggrepel`), so the URL can be shared and will open directly to that package's detail view.
- **Note**: The current SPEC.md (§5.1) says "no URL routing in v1". This is a change from the spec.
- **Priority**: Should-have

#### 2.10 Navigation Arrows Between Packages
- **Requirement**: In the package detail view, provide **next/previous navigation arrows** to move between packages. Navigation order should follow the current sort order of the table (e.g., if sorted alphabetically, arrows move to the next/previous package alphabetically).
- **Priority**: Should-have

#### 2.11 Code Example Enhancements
- **Requirement**: Prepend the necessary `install.packages()` and `library()` calls at the beginning of each code example, so users can copy the full snippet and run it without manually installing dependencies.
- **Feasibility check needed**: The developer should assess whether this is straightforward (the package name is known; `install.packages()` is simple) or whether dependency detection adds complexity.
- **Priority**: Should-have (if feasible)

### 3. Data Model

#### 3.1 Changes to Package Entity
- **Add field**: `title` (character) — sourced from the CRAN **Title** field. This is the short one-liner. Currently this data may already be captured but mislabeled as `description`.
- **Clarify field**: `description` (character) — should contain the CRAN **Description** field (the longer paragraph). If this is not currently being fetched, it needs to be added to the pipeline.
- **Add flags**: `recently_added` (logical) and `recently_updated` (logical) — derived fields, computed as:
  - `recently_added`: `date_added` is within the past 7 days.
  - `recently_updated`: `max(cran_published, github_updated)` is within the past 7 days.
- **Add field (if not present)**: `has_vignettes` (logical) — to support conditional display of the vignettes link in the detail view.

#### 3.2 Investigation Needed
- **`github_updated` field**: The stakeholder asked which GitHub API field is being used. The developer should verify and document which field from the GitHub API populates `github_updated` (e.g., `pushed_at`, `updated_at`, or something else) and confirm it represents the most meaningful "last update" date.
- **CRAN Title vs. Description**: Confirm which CRAN API field is currently being stored as `description` in the pipeline. Map the correct fields.

### 4. Non-Functional Requirements
- No changes from the existing SPEC.md. The app remains:
  - **Public** (no authentication)
  - **Desktop-first** (basic mobile responsiveness via bslib)
  - **Deployed** on Google Cloud Run via Docker
  - **Dark mode default** with light mode toggle

### 5. User Experience

#### 5.1 Color Mode Consistency
- This is the single most impactful UX issue. The app must feel like one cohesive experience regardless of which color mode is active. See §2.7 for details.

#### 5.2 Category Badge Colors
- 19 distinct colors is a significant design challenge. The palette should:
  - Be visually distinguishable (not just slight hue shifts).
  - Work on both dark and light backgrounds.
  - Not be so saturated that they overwhelm the table layout.
- **Stakeholder preference**: Left to designer/developer discretion. No specific colors mandated.

#### 5.3 Sidebar Compactness
- The sidebar should be compact enough that all controls and the "Suggest a Package" button are visible without scrolling on a standard desktop viewport (~900px height). Reducing padding/margins is the preferred approach.

### 6. Content

#### 6.1 Header Section
- "What are ggplot2 extensions?" becomes plain text (always visible).
- Links updated: "ggplot2 extended (the book)" + "ggplot2 documentation".

#### 6.2 Footer Section
- See §2.8 for full updated footer content.
- New addition: Link to the book (in progress).

#### 6.3 Code Examples
- If feasible, prepend `install.packages()` and `library()` calls to code snippets. See §2.11.

### 7. Maintenance & Operations
- No changes from existing SPEC.md for this round.
- **Google Form**: Not yet created. Parked for a future iteration. The "Suggest a Package" button shows as disabled with "Coming soon" tooltip in the interim.

### 8. Constraints
- **Budget**: No change.
- **Timeline**: These are production fixes — should be addressed promptly but no hard deadline specified.
- **Technical constraints**: All changes should work within the existing golem/bslib/reactable architecture. No new framework dependencies expected.
- **Scope**: This is a fix/polish round. The existing SPEC.md architecture remains intact. Changes are to the UI layer, data labels, and filter behavior.

### 9. Prioritisation

| Requirement | Priority |
|---|---|
| App title rename to "ggplot2 extended (companion)" | Must-have |
| Dark/light mode consistency across all views | Must-have |
| Light mode: white background, search box styling | Must-have |
| Sort by dropdown functional | Must-have |
| Category display names in sidebar and table | Must-have |
| Title vs. Description data correction | Must-have |
| Show all categories in table (not "+N") | Must-have |
| Category-specific badge colors (19 categories) | Must-have |
| Recently Added/Updated → sidebar checkbox filters | Must-have |
| Main table moved up (cards removed) | Must-have |
| "What are ggplot2 extensions?" as plain text with updated links | Must-have |
| Footer content updates (email, book link, removed gallery line) | Must-have |
| Hide vignettes link when unavailable | Must-have |
| Detail view: "Repo (GitHub, etc.)" link label | Must-have |
| Detail view: remove graph emoji from download cards | Must-have |
| Detail view: "Since 2015" label | Must-have |
| Detail view: Title as subtitle, Description as paragraph | Must-have |
| "Essential Extensions Only" capitalization | Must-have |
| Suggest a Package button: disabled with "Coming soon" tooltip | Must-have |
| Shareable links to package pages | Should-have |
| Navigation arrows between packages in detail view | Should-have |
| `install.packages()` / `library()` in code examples | Should-have (if feasible) |
| Back button: red border and red on hover | Should-have |
| Sidebar padding/margin reduction | Should-have |

### 10. Parking Lot (Future Considerations)
- **Google Form creation** and connection to "Suggest a Package" button/footer link.
- **More information about non-CRAN packages** — automated or manual process for enriching metadata for packages not on CRAN.
- **Download trend chart** (already noted as v1.1 in SPEC.md §5.4) — `plotly` or `echarts4r` line chart of monthly downloads.

### 11. Open Questions

| # | Question | Context | Who Resolves |
|---|---|---|---|
| 1 | Which GitHub API field populates `github_updated`? | Stakeholder flagged this as a data accuracy concern. Is it `pushed_at`, `updated_at`, or another field? | Developer |
| 2 | Is the CRAN Description field currently fetched by the pipeline? | The table shows the CRAN Title. The longer Description may not be in the data model yet. | Developer |
| 3 | Is the Sort by dropdown a bug or an unbuilt feature? | Dropdown exists in the UI but does nothing. | Developer |
| 4 | How to check if a package has vignettes? | Needed to conditionally hide the vignettes link. Options: check CRAN page, use `tools` package, check URL for 404. | Developer |
| 5 | Recently Added + Recently Updated checkboxes: AND or OR logic when both checked? | If both are checked, should the table show packages matching BOTH flags or EITHER flag? | Developer (stakeholder defers to practicality) |
| 6 | Is prepending `install.packages()` / `library()` to examples straightforward? | Package name is known, but dependency detection may add complexity. | Developer |
| ~~7~~ | ~~What is the book URL for "ggplot2 extended (the book)"?~~ | **Resolved**: https://ggplot2-extended-book.com/ | Stakeholder |
| ~~8~~ | ~~What is the submission link URL for "Submit it here" in the footer?~~ | **Resolved**: Footer submission link is already disabled with tooltip. No change needed. | Stakeholder |

### 12. SPEC.md Corrections Needed

The following items in the existing SPEC.md should be updated to reflect these requirements:

| Section | Current | Should Be |
|---|---|---|
| §1 App name | "ggplot2 Extended Companion" | "ggplot2 extended (companion)" |
| §3.1 `description` field | "Short description" from CRAN API | Split into `title` (CRAN Title) and `description` (CRAN Description) |
| §5.1 Navigation | "no URL routing in v1" | URL updates with package name for shareable links (if implemented) |
| §5.2 Description column | Column labeled "Description" | Column labeled "Title", showing CRAN Title |
| §5.2 Category column | "First category shown, '+N' if multiple" | All categories shown as separate badges with category-specific colors |
| §5.3 Category dropdown | Implied technical names | Must use `display_name` values |
| §5.3 Essential checkbox | "Essential Extensions only" | "Essential Extensions Only" |
| §5.4 Links card | "GitHub/GitLab" | "Repo (GitHub, etc.)" |
| §5.4 Vignettes link | Hidden when NA | Hidden when NA **and** when package has no vignettes |
| §5.4 Download stats | "All time (since 2015)" with emoji | "Since 2015", no emoji |
| §5.5 Recent lists | Separate cards above table | Removed — replaced by sidebar checkbox filters |
| §5.6 Header/Intro | Collapsible accordion, collapsed by default | Plain text, always visible |
| §5.6 Header links | "ggplot2 extensions gallery" | "ggplot2 extended (the book)" |
| §5.7 Footer | See §2.8 of this document | Updated email, book link, removed gallery line |
| §7 Light mode background | `#FFFFFF` (specified but not rendering correctly) | Confirm implementation matches spec |
