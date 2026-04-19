## Why

The ggplot2 extended (companion) app is deployed and in production use, but a stakeholder review uncovered bugs, mislabeled data, broken dark/light mode, non-functional UI controls, and content that needs updating. These issues erode trust and usability — the app shows CRAN Title data labeled as "Description," the sort dropdown does nothing, colour mode breaks when navigating views, and the footer has an incorrect email address. Fixing these now prevents users from encountering a half-polished experience.

## What Changes

**Data pipeline corrections:**
- Split the CRAN `Title` and `Description` fields into separate columns (currently `Title` is stored as `description`)
- Add `has_vignettes` detection to conditionally hide the vignettes link
- Update JSON export to include both `title` and `description`

**Sidebar overhaul:**
- Remove the non-functional Sort by dropdown (sorting moves to reactable column headers)
- Add "Recently Added" and "Recently Updated" checkbox filters (replacing the two cards above the table)
- Display category `display_name` values instead of technical names
- Fix "Essential Extensions only" → "Essential Extensions Only" capitalization
- Reduce padding so all controls fit without scrolling

**Browse table changes:**
- Rename "Description" column to "Title"
- Show all category badges (not first + "+N") with 19 distinct category-specific colours
- Make Category and License columns sortable via column headers

**Detail view fixes:**
- Show Title as subtitle, Description as paragraph
- Change "GitHub/GitLab" → "Repo (GitHub, etc.)"
- Hide vignettes link when package has no vignettes
- Remove graph emoji from download value boxes
- Rename "All time (since 2015)" → "Since 2015"
- Red border + hover on back button

**Dark/light mode consistency:**
- Fix colour mode breaking between browse and detail views
- Fix search box always rendering dark
- Fix light mode background (should be white, not grey)

**Content updates:**
- Rename app to "ggplot2 extended (companion)"
- Convert header accordion to plain text with updated links
- Update footer: new email, book link, remove gallery line
- Remove Recently Added/Updated cards module

**Should-have enhancements:**
- Shareable package links via `?package={name}` query parameter
- Next/previous navigation arrows in detail view (alphabetical order)
- Prepend `install.packages()` / `library()` to code examples

## Capabilities

### New Capabilities
- `category-badges`: Category display name mapping, 19-colour badge palette, badge rendering for both table and detail views
- `recent-filters`: Recently Added / Recently Updated sidebar checkbox filters with OR logic
- `shareable-links`: URL query parameter routing for direct package detail links
- `detail-navigation`: Previous/next navigation arrows between packages in detail view

### Modified Capabilities

## Impact

**Files modified** (13 R files + 1 CSS):
- `R/fct_pipeline.R` — title/description split, has_vignettes extraction
- `R/fct_urls.R` — conditional vignettes URL
- `R/fct_data.R` — recently_added/recently_updated derived columns
- `R/fct_filters.R` — remove sort, add recent filter logic
- `R/mod_sidebar.R` — remove sort dropdown, add checkboxes, display names
- `R/mod_browse.R` — Title column, all category badges, sortable columns
- `R/mod_detail.R` — title/description layout, link labels, download cards, nav arrows
- `R/mod_header.R` — plain text, updated links
- `R/mod_footer.R` — email, book link, remove gallery line
- `R/app_ui.R` — app rename, remove mod_recent, meta tags
- `R/app_server.R` — remove sort, add recent filters, URL routing
- `_targets.R` — pass has_vignettes to construct_urls
- `inst/app/www/styles.css` — category badge colours, dark/light fixes, compact sidebar, back button

**Files created** (1): `R/fct_categories.R`
**Files deleted** (1): `R/mod_recent.R`

**No new package dependencies.** All changes work within the existing golem/bslib/reactable/arrow stack.
