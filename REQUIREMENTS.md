# REQUIREMENTS.md
## ggplot2 Extended Companion App

### 1. Overview
- **Purpose**: An R Shiny web application that serves as the most comprehensive, searchable directory of ggplot2 extension packages. It is a companion to the [ggplot2 extended book](https://ggplot2-extended-book.com/), replacing a manually maintained [Notion database](https://youcanbeapirate.notion.site/7d7e8ac88bfb4f1b88118c01b82850eb?v=15a163223ec843dfb0040f6a234754ee&pvs=74) with an automated, polished web app. The app helps ggplot2 users discover extension packages from a curated database of ~455 packages, with daily-refreshed metadata and download statistics.
- **Target Users**:
  - **Primary**: Intermediate-to-advanced ggplot2 users looking to discover and evaluate extension packages
  - **Secondary**: Beginners (guided by curated "Essential Extensions" filtering), package authors seeking visibility, educators looking for a resource to point students to, and AI agents consuming structured data
- **Success Criteria**:
  - Users discover new ggplot2 extension packages through the app
  - Maintainer spends minimal time on weekly maintenance (target: under 30 minutes/week)
  - The app is recognised as the most complete directory of ggplot2 extensions

### 2. Functional Requirements

#### 2.1 Package Discovery & Browsing
- **Search bar** (must-have): Search by package name. Searching by description, author, and tags is a stretch goal.
- **Filtering** (must-have):
  - By category (single category at a time; multi-category filtering is a stretch goal)
  - By CRAN status (on CRAN or not)
  - By license
  - By "Essential Extensions" tag (curated subset for beginners)
- **Sorting** (must-have):
  - Alphabetical by package name
  - Alphabetical by creator/maintainer name
  - By download count
  - By CRAN latest version published date
  - By GitHub last update date
- **Sorting** (nice-to-have):
  - By "recently added to the app" date
- **Main browsing view**: A searchable, filterable, sortable table
- **Design reference**: [r-packages.io](https://r-packages.io/packages) for general functionality inspiration

#### 2.2 Package Detail View
Accessed by clicking a package in the table. Displays all available metadata:

| Field | Source | Also in Table? |
|---|---|---|
| Name | CRAN / GitHub | Yes |
| Short Description | CRAN (preferred), GitHub/similar (fallback) | Yes (excerpt) |
| Creator/Maintainer Name | CRAN / GitHub (to be added) | No |
| Website URL | Automated where predictable; manual otherwise | No |
| GitHub/GitLab Repo URL | Manual / automated | No |
| CRAN URL | Automated | No |
| Reference Manual(s) URL | Automated where predictable | No |
| Vignette(s) URL | Automated where predictable (single or directory) | No |
| CRAN Downloads (7 days) | cranlogs API | No |
| CRAN Downloads (30 days) | cranlogs API | Yes |
| CRAN Downloads (365 days) | cranlogs API | No |
| CRAN Downloads (all time, 2015–present) | cranlogs API | Yes |
| Latest Version (CRAN) | CRAN metadata | Yes |
| Category | Manual with auto-suggestion | Yes |
| License | CRAN metadata | Yes |
| Latest Version Published (CRAN) | CRAN metadata | Yes |
| Last Update (GitHub) | GitHub API | Yes |
| Runnable code example | Pulled from package documentation | No |

- **Future additions (not in v1)**:
  - Short editorial description or "Note from the package author"
  - Related packages ("if you like this, you might also like...") — feasibility to be evaluated by Solution Architect

#### 2.3 Download Statistics
- **Time windows** (all sliding): Past 7 days, past 30 days, past 365 days, all time (2015–present)
- **Table columns**: Past 30 days and all time
- **Detail page**: All four time windows
- **Trend visualisation** (nice-to-have): Line chart of downloads over time on the detail page
- **No ranking display** — users sort the table by download count instead

#### 2.4 Package Submission
- **Mechanism**: Link from the app to a Google Form (more robust in-app solution is a future consideration if volume demands it)
- **Submission fields**: Package name, link (CRAN/GitHub/pkgdown/etc.), optional category suggestion
- **Review process**: Maintainer personally reviews and adds packages. Email notification via Google Forms. No public "pending" status in v1.

#### 2.5 Data Refresh
- **Frequency**: Daily scheduled job
- **Trigger**: Automated schedule (stakeholder preference: GitHub Actions), plus a manual trigger for when new packages are added
- **Automated data sources**:
  - CRAN metadata (versions, descriptions, license, published date)
  - cranlogs API (download counts)
  - GitHub/GitLab API (last update, repo info)
  - Predictable URL patterns (reference manuals, vignettes, some website URLs)
- **Semi-automated**:
  - Category assignment: Auto-suggestion based on package description, with maintainer's manual approval
  - Audit of all existing categorisations for missed or incorrect tags (one-time task during build)
- **Manual (deferred to v2)**: Non-predictable website URLs, vignette links that don't follow standard patterns
- **Pipeline**: Unified new pipeline. Borrow needed functionality from existing repos ([CRAN-package-info](https://github.com/AnttiRask/CRAN-package-info) and [CRAN-package-downloads](https://github.com/AnttiRask/CRAN-package-downloads)) but do not merge or deprecate them.

#### 2.6 Recently Added / Recently Updated
- A simple list (last 10 each) for both recently added packages and recently updated packages (on CRAN or GitHub)
- Must-have for v1

#### 2.7 Introductory / Onboarding Content
- Brief introductory text explaining what ggplot2 extensions are
- May be drawn from the book — natural cross-over opportunity
- Links to the book and other resources (details deferred to after v1 is functional)

#### 2.8 Disclaimer
- The app must include a disclaimer text stating that if anyone has concerns about information presented on the site (licensing, metadata accuracy, etc.), they can reach out via email to have it corrected or removed.

### 3. Data Model

- **Package attributes**: See full field list in Section 2.2
- **Creator/maintainer name**: To be added (not currently in Notion database). Automatable from CRAN or GitHub metadata.
- **"Last Checked" field**: Internal/maintenance only, not user-facing
- **"Essential Extensions" tag**: Manually curated boolean flag for beginner-friendly packages

- **Data sources**:
  - CRAN metadata API (descriptions, versions, license, published date, maintainer)
  - cranlogs API (download counts across time windows)
  - GitHub/GitLab API (last update, repo info)
  - Manual curation (categories, essential extensions tag, non-standard URLs)
  - Package documentation (code examples for runnable snippets)

- **Storage**: Stakeholder preference is Turso (existing experience). Solution Architect to evaluate fit or recommend alternatives.

- **Refresh pipeline**: Daily GitHub Actions job fetches from all automated sources, updates the database, and checks for changes. Manual trigger available for adding new packages.

- **Backup**: Not needed for data that can be re-fetched from CRAN/GitHub. Backup strategy required for manually curated data (categories, editorial tags, essential extensions flag, non-standard URLs).

### 4. Non-Functional Requirements
- **Performance**: ~455 packages, modest growth. No strict load time targets — just reasonable for the data size. Not a performance-intensive dataset.
- **Hosting**: Docker on Google Cloud Run (stakeholder preference, existing infrastructure). Solution Architect to flag if there is a strong reason against it.
- **Repository**: Private (at least for now).
- **Authentication**: Fully public app, no login required.
- **Responsiveness**: Desktop-first. Nice if it also works on phones, but not a must-have.
- **Accessibility**: No specific requirements stated beyond general usability.
- **Analytics**: Basic usage tracking for v1 (e.g., page views, popular packages). Details to be determined by Solution Architect.
- **SEO**: Nice-to-have, not a must. Primary discovery will be through the maintainer's own links from apps/websites.
- **Language**: English only.
- **AI agent compatibility** (must-have): App should be well-structured and parseable by AI agents browsing the web. JSON API or downloadable dataset is a stretch goal — feasibility to be evaluated by Solution Architect.

### 5. User Experience
- **Design direction**: Professional yet approachable. Functional and user-focused — content-first, not heavy decoration. Consistent with existing youcanbeapirate.com apps.
- **Design references**:
  - [r-packages.io](https://r-packages.io/packages) for table/browsing functionality
  - [BiblioStatus app](https://bibliostatus.youcanbeapirate.com) for tone, feel, and navigation patterns
  - [BiblioStatus pkgdown](https://youcanbeapirate.com/BiblioStatus) for branding style
  - [ggplot2 extended book](https://ggplot2-extended-book.com/) for content style
- **Branding**: Blend of "ggplot2 extended" (book) and "youcanbeapirate" identity. The ggplot2 extended logo is a work-in-progress; youcanbeapirate branding is more established.
- **Colour palette**: Deep red (#C1272D) as primary accent (consistent with existing apps), neutral grays/blacks/whites for foundation.
- **Typography**: Modern fonts (Gotham and Inter used across existing apps).
- **Dark mode**: Default. Light/dark mode toggle is a nice-to-have if easy to implement.
- **Key UX principle**: **Speed to finding a useful package** is the #1 priority.
- **Layout**: Sidebar navigation pattern (familiar from existing apps). Two main views: browsable table and package detail page.

### 6. Content
- **"Essential Extensions" tag**: Manually curated filter/tag for beginner-friendly packages. Must-have in v1. A featured section on the landing page is a future consideration (v2).
- **Introductory text**: Brief explanation of what ggplot2 extensions are. Potential cross-over content from the book.
- **Recently added / recently updated**: Simple lists (last 10 each). Must-have.
- **External links**: Links to the book, maintainer's other resources, and general ggplot2 materials. Details deferred to after v1 is functional.
- **No community features in v1**: No ratings, reviews, or comments.

### 7. Maintenance & Operations
- **Maintainer(s)**: Solo maintainer (Antti Rask).
- **Update workflow**: Add a row to config/database → trigger pipeline → pipeline fetches all automatable fields → maintainer confirms/assigns category → package goes live.
- **Submission handling**: Google Form submission → email notification → maintainer reviews and adds package via the update workflow.
- **Monitoring**: GitHub Actions notifications for failures (data refresh failures, pipeline errors).
- **Backup**: Backup strategy for manually curated data only. Auto-fetchable data does not need backup.
- **App versioning / release cadence**: Not specified. "When it's ready" approach.

### 8. Constraints
- **Budget**: Comfortable with reasonable hosting costs (Google Cloud Run, Turso, etc.). No hard ceiling specified.
- **Timeline**: No hard deadline. No external dependencies (not tied to book launch or events).
- **Technical constraints**:
  - Primary technology: R Shiny. Open to other technologies (JavaScript, HTML, CSS) where needed (e.g., webR integration), but maintainer cannot validate non-R code as easily. Solution Architect should be aware.
  - Stakeholder preferences (not hard requirements): Turso for database, Docker on Google Cloud Run for hosting, GitHub Actions for scheduled jobs.
  - Tidyverse syntax and style conventions for all R code.
- **Legal/licensing**:
  - No package logos used (to avoid potential licensing issues).
  - Code examples pulled from package documentation — must respect each package's license.
  - The app should have a mechanism to check what each package's license permits regarding use of metadata and examples. Do not use anything not clearly allowed.
  - Disclaimer text required (see Section 2.8).
- **Existing assets**:
  - [Notion database](https://youcanbeapirate.notion.site/7d7e8ac88bfb4f1b88118c01b82850eb?v=15a163223ec843dfb0040f6a234754ee&pvs=74) — current source of truth (~455 packages)
  - [CRAN-package-info repo](https://github.com/AnttiRask/CRAN-package-info) — existing automation for CRAN metadata
  - [CRAN-package-downloads repo](https://github.com/AnttiRask/CRAN-package-downloads) — existing automation for download stats
  - Other youcanbeapirate.com apps — can be used for inspiration, but Solution Architect should be critical of the code (not always best practices)

### 9. Prioritisation

| Requirement | Priority |
|---|---|
| Searchable/filterable/sortable package table | Must-have |
| Search by package name | Must-have |
| Filter by category (single), CRAN status, license | Must-have |
| "Essential Extensions" tag/filter | Must-have |
| Package detail page with full metadata and links | Must-have |
| Runnable code examples (static snippet + "Run" button) | Must-have |
| Download stats (7d, 30d, 365d, all-time) | Must-have |
| Daily automated data refresh pipeline (GitHub Actions) | Must-have |
| Manual trigger for adding new packages | Must-have |
| Category auto-suggestion with manual approval | Must-have |
| Audit of existing categorisations | Must-have |
| Recently added / recently updated lists (last 10) | Must-have |
| Google Form link for package submissions | Must-have |
| Introductory/onboarding text | Must-have |
| Disclaimer text | Must-have |
| Dark mode as default | Must-have |
| Well-structured HTML for AI agent parsing | Must-have |
| Creator/maintainer name field | Must-have |
| Backup strategy for manually curated data | Must-have |
| Docker on Google Cloud Run deployment | Must-have |
| Download trend chart (line chart on detail page) | Nice-to-have |
| Sort by "recently added to the app" | Nice-to-have |
| Light/dark mode toggle | Nice-to-have |
| SEO optimisation | Nice-to-have |
| Mobile responsiveness | Nice-to-have |
| Search by description, author, tags | Stretch goal |
| Multi-category filtering | Stretch goal |
| JSON API or downloadable dataset for AI agents | Stretch goal |
| Interactive code editor (beyond static "Run") | Stretch goal |
| Related packages suggestions | Stretch goal (feasibility TBD) |
| In-app package submission form (replacing Google Form) | Stretch goal |

### 10. Parking Lot (Future Considerations)
- **Featured/curated section on landing page** (v2) — e.g., "Staff Picks" or highlighted essential extensions beyond just a filter
- **Editorial descriptions or "Note from the package author"** per package
- **Non-predictable URL resolution** — website URLs, vignette links that don't follow standard patterns
- **More customised code examples** beyond what's in package documentation
- **Community features** — ratings, reviews, comments
- **Tighter book integration** — linking to specific book chapters from package detail pages
- **Package comparison** — side-by-side comparison of packages
- **Multilingual support**

### 11. Open Questions
1. **Turso suitability**: Is Turso the right database choice for this use case, or is there a better alternative? (Solution Architect to evaluate)
2. **webR integration feasibility**: What is the best approach for runnable code examples in a Shiny app? webR, shinylive, or another approach? What are the limitations?
3. **License checking mechanism**: How should the app determine what each package's license permits regarding displaying metadata and running examples? Can this be automated?
4. **Category auto-suggestion approach**: What method should be used for suggesting categories based on package descriptions? (NLP, keyword matching, LLM-based, etc.)
5. **GitHub Actions + Google Cloud Run**: What is the best architecture for a daily GitHub Actions pipeline that updates a database consumed by a Dockerised Shiny app on Cloud Run?
6. **AI agent compatibility**: What structural choices (semantic HTML, meta tags, structured data, etc.) best support AI agent parsing without building a full API?
7. **Notion data migration**: What is the best approach for the initial migration of ~455 packages from Notion to the new database?
8. **Backup strategy for curated data**: What is the simplest reliable approach? (e.g., periodic database export to a GitHub repo, cloud storage, etc.)
9. **Basic analytics implementation**: What is the lightest-weight approach for tracking usage in a Shiny app on Cloud Run?
10. **Existing repo code reuse**: Which specific functionalities from CRAN-package-info and CRAN-package-downloads are worth incorporating into the unified pipeline?
