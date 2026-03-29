# REQUIREMENTS.md
## ggplot2 extended (companion) — v1.1

### 1. Overview
- **Purpose**: Version 1.1 adds three planned features that were intentionally deferred from v1: a package submission flow via Google Form, an archived packages system to transparently surface packages that are no longer actively maintained, and data enrichment for non-CRAN packages by pulling metadata from GitHub repositories. These are not bug fixes — they are capabilities the stakeholder always intended to add.
- **Target Users**: R developers and data analysts who use ggplot2 and want to discover extension packages. No change from v1.
- **Success Criteria**: All three features are functional — the "Suggest a Package" button and footer link connect to a live Google Form, archived packages can be toggled on/off with clear visual indicators, and non-CRAN packages display richer metadata (Title, License, and ideally Maintainer and Description). Version labels are source-agnostic.

### 2. Functional Requirements

#### 2.1 Suggest a Package (Google Form)

##### 2.1.1 Google Form Creation
- Create a Google Form with the following fields:
  - **Package name** (required, short text)
  - **CRAN URL** (optional, short text)
  - **GitHub URL** (optional, short text)
  - **Suggested category/categories** (required, checklist of the 19 existing categories + "Other" option that reveals a free-text field). The 19 categories are: Animation, Annotations, Arranging Plots, Coords, Data, Facets, Finishing Touches, Geoms, Helpers, Interactive Plots, Interactive Tools, Maps, Networks, Python, Scales & Guides, Sports, Stats, Themes, NA
  - **Brief reason for suggesting** (required, long text)
  - **Submitter name** (required, short text)
  - **Submitter email** (required, short text with email validation)

##### 2.1.2 UI Integration
- **Sidebar**: The existing "Suggest a Package" button (currently disabled with `aria-disabled="true"` and tooltip "Package submission form coming soon" in `R/mod_sidebar.R`) must be activated and linked to the Google Form URL. It should open in a new browser tab.
- **Footer**: The existing "Submit it here" link (currently disabled with dotted underline styling and tooltip "Package submission form coming soon" in `R/mod_footer.R`) must be activated and linked to the same Google Form URL. It should open in a new browser tab.

##### 2.1.3 Review Workflow
- Manual process: the maintainer receives Google Forms email notifications, evaluates the submission, and either adds the package to `data-raw/packages_curated.csv` or declines it.
- The maintainer may optionally email the submitter to communicate the decision.
- No in-app automation, status tracking, or feedback loop is required.

#### 2.2 Archived Packages

##### 2.2.1 Data Model
- Add a new column `is_archived` to `data-raw/packages_curated.csv` (boolean, `TRUE`/`FALSE`).
- Default value: `FALSE`.
- Set manually by the maintainer — this is an editorial judgment, not an automated detection.
- "Archived" means the package is no longer viable for use. This is **independent of CRAN archive status** — a CRAN-archived package with a working GitHub version is NOT necessarily archived in this system. The `is_archived` flag reflects the maintainer's judgment that the package should no longer be recommended.
- The existing `notes` column is used to optionally provide context on why a package is archived (e.g., "Superseded by ggfoo", "Author has discontinued development").
- Approximately 10 packages will be marked as archived initially.

##### 2.2.2 Sidebar Filter
- Add a "Show Archived Packages" checkbox in the sidebar.
- **Position**: last checkbox in the filter list (after the existing "Recently Updated" checkbox).
- **Default state**: unchecked — archived packages are **hidden by default**.
- When checked, archived packages appear in browse results alongside all other packages.

##### 2.2.3 Browse View
- Archived packages display a 📁 (file folder) emoji next to the package name, mirroring the ⭐ (star) emoji used for essential packages.
- No other visual differentiation — no greying out, no muted styling.
- Archived packages sort and filter normally alongside other packages when visible (no special sort order).

##### 2.2.4 Detail View
- Display 📁 emoji and "Archived Package" label next to the package name (mirroring the essential package pattern).
- Display a warning banner: **"This package is no longer actively maintained."**
- If the `notes` column contains text for the package, display the notes text below the warning banner as additional per-package context.
- Download statistics are shown if available — no suppression needed.

#### 2.3 Non-CRAN Package Data Enrichment

##### 2.3.1 Data Gap
- Non-CRAN packages currently only have data from `packages_curated.csv`: `package_name`, `categories`, `is_essential`, `website_url`, `repo_url`, `date_added`, `notes`.
- They are missing: Title, License, Maintainer, Description/Summary, and Version information that CRAN packages get automatically from the CRAN API.

##### 2.3.2 Automated Enrichment (Preferred Approach)
- For packages with a `repo_url` pointing to GitHub, attempt to fetch the DESCRIPTION file from the repository via the GitHub API.
- Extract the following fields from DESCRIPTION:
  - `Title` (must-have)
  - `License` (must-have)
  - `Maintainer` or `Authors@R` (should-have)
  - `Description` (should-have)
  - `Version` (must-have, for version field renaming — see §2.3.4)
- This enrichment should run as part of the **weekly pipeline run only** (not daily) to conserve GitHub API calls.
- Use the existing `GITHUB_PAT` for authentication.

##### 2.3.3 Fallback Strategy
- If the automated approach yields too many missing values (excessive NAs or empty strings), consider adding manual columns to `packages_curated.csv` as a fallback.
- **Stakeholder preference**: avoid manual CSV columns if possible — automated is strongly preferred.
- The Solution Architect should investigate the feasibility and data coverage of the automated approach before deciding on the fallback.

##### 2.3.4 Version Field Renaming
- Rename "CRAN Version" → **"Version"** and "Latest CRAN Version" → **"Latest Version"** throughout the app UI (browse table and detail view).
- Logic: use CRAN version data when available; fall back to GitHub version (from DESCRIPTION) for non-CRAN packages.

#### 2.4 README Update
- After all v1.1 features are implemented, update `README.md` to reflect the new capabilities.
- This is the **final step** of the release.

### 3. Data Model

#### 3.1 Changes to Package Entity

| Field | Source | Change Type | Notes |
|---|---|---|---|
| `is_archived` | `packages_curated.csv` | New column | Boolean, manually curated, default `FALSE` |
| `notes` | `packages_curated.csv` | Existing (new usage) | Now surfaced in detail view for archived packages |
| `title` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Extended source | New for non-CRAN packages |
| `license` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Extended source | New for non-CRAN packages |
| `maintainer` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Extended source | New for non-CRAN packages |
| `description` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Extended source | New for non-CRAN packages |
| `version` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Renamed + extended | Formerly "CRAN Version" |
| `latest_version` | CRAN API (existing) / GitHub DESCRIPTION (new fallback) | Renamed + extended | Formerly "Latest CRAN Version" |

#### 3.2 Data Sources
- No new data sources. The GitHub API (already used via `gh` package) is extended to fetch DESCRIPTION files for non-CRAN packages.

#### 3.3 Storage
- No changes — Parquet files via the existing targets pipeline.

#### 3.4 Refresh Pipeline
- GitHub DESCRIPTION enrichment for non-CRAN packages added to the **weekly run only** (not the daily run).
- All other pipeline behaviour unchanged.

### 4. Non-Functional Requirements
- **Performance**: No significant change expected. ~10 archived packages and a limited number of non-CRAN packages add negligible overhead.
- **Hosting**: No change (Docker on Google Cloud Run).
- **Authentication**: No change (fully public, no login).
- **Responsiveness**: No change (existing responsive behaviour).
- **Accessibility**: The "Show Archived Packages" checkbox and warning banner should follow existing accessibility patterns in the app.
- **Analytics**: No new tracking required.
- **API rate limits**: Non-CRAN GitHub DESCRIPTION fetching runs weekly only to conserve the 5,000 req/hr GitHub API budget.

### 5. User Experience
- **Archived packages design**: Mirrors the essential packages pattern but in reverse — subtle emoji markers (📁 vs ⭐), hidden by default rather than highlighted. No greying out or muted styling.
- **Warning banner**: Appears only in the detail view for archived packages. Informative but not alarming.
- **Per-package notes**: Displayed below the warning banner only when the `notes` column has content.
- **"Show Archived Packages" checkbox**: Last in the sidebar filter list, unchecked by default.
- **Version labels**: "CRAN Version" → "Version", "Latest CRAN Version" → "Latest Version" — making the UI source-agnostic.
- **Google Form**: Opens in a new tab from both sidebar button and footer link.

### 6. Content
- **Warning banner text**: "This package is no longer actively maintained."
- **Per-package notes**: Sourced from the `notes` column in `packages_curated.csv`. Displayed below the warning banner in the detail view when populated; omitted when empty.
- **Google Form**: Self-contained content within the form (field labels, descriptions, validation messages). Created as part of this project scope.
- **README.md**: Updated as the final step of v1.1 to reflect all new features.

### 7. Maintenance & Operations
- **Maintainer**: Solo (Antti) — no change.
- **Package submission handling**: Manual. Google Forms email notification → evaluate → add to `packages_curated.csv` or decline → optionally email submitter.
- **Archiving workflow**: Manual. Edit `is_archived` in `packages_curated.csv` → re-run pipeline.
- **Non-CRAN data**: Automated weekly via pipeline. No manual intervention unless fallback CSV approach is needed.
- **Monitoring**: No change from v1.

### 8. Constraints
- **Budget**: No additional costs expected. Google Forms is free. GitHub API calls are within existing rate limits.
- **Timeline**: No deadline — "when it's ready."
- **Technical constraints**: Non-CRAN enrichment must run weekly only (not daily) to conserve API calls.
- **Legal/licensing**: No new concerns.

### 9. Prioritisation

| Requirement | Priority |
|---|---|
| Google Form creation with all specified fields | Must-have |
| Activate sidebar "Suggest a Package" button → Google Form | Must-have |
| Activate footer "Submit it here" link → Google Form | Must-have |
| `is_archived` column in `packages_curated.csv` | Must-have |
| "Show Archived Packages" sidebar checkbox (hidden by default, last position) | Must-have |
| 📁 emoji in browse view for archived packages | Must-have |
| 📁 emoji + "Archived Package" label in detail view | Must-have |
| Warning banner in detail view for archived packages | Must-have |
| `notes` displayed below warning banner when populated | Must-have |
| Non-CRAN: fetch Title from GitHub DESCRIPTION | Must-have |
| Non-CRAN: fetch License from GitHub DESCRIPTION | Must-have |
| Non-CRAN: fetch Version from GitHub DESCRIPTION | Must-have |
| Version field renaming ("CRAN Version" → "Version", etc.) | Must-have |
| Weekly-only schedule for non-CRAN enrichment | Must-have |
| Non-CRAN: fetch Maintainer from GitHub DESCRIPTION | Should-have |
| Non-CRAN: fetch Description from GitHub DESCRIPTION | Should-have |
| Fallback CSV columns for non-CRAN data (if automated approach fails) | Nice-to-have (contingency) |
| README.md update | Must-have (final step) |

### 10. Parking Lot (Future Considerations)
- Automated detection of CRAN-archived or GitHub-archived packages (currently manual editorial judgment only)
- Automated GitHub issue creation from Google Form submissions
- Feedback loop to submitters (in-app status tracking of their suggestion)
- Spam protection on the Google Form (if submission volume increases)
- Download trend chart (already noted as future in SPEC.md §5.4)

### 11. Open Questions

| # | Question | Context | Who Resolves |
|---|---|---|---|
| 1 | What data coverage does the automated GitHub DESCRIPTION approach yield for non-CRAN packages? | Need to assess how many non-CRAN packages have parseable DESCRIPTION files and what percentage of Title, License, Maintainer, Description, Version fields are populated. This determines whether the fallback CSV approach is needed. | Solution Architect / Developer |
| 2 | What is the best approach for parsing DESCRIPTION files fetched via the GitHub API? | Options include the `desc` package, raw text parsing, or `gh` content API. Need to handle encoding, `Authors@R` parsing, etc. | Solution Architect / Developer |
| 3 | How should version comparison or "outdated" indicators work for GitHub-only packages? | When renaming version fields to be source-agnostic, the existing logic for comparing CRAN version vs. latest CRAN version may not apply to GitHub-only packages. | Solution Architect / Developer |
| 4 | Which ~10 packages should be marked as `is_archived = TRUE` initially? | The maintainer needs to identify these and populate the CSV before launch. | Maintainer (Antti) |
