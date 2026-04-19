## 1. Validation layer

- [x] 1.1 RED: Update `tests/testthat/test-fct_validation.R` — rename `validate_is_essential` → `validate_is_featured`, update fixture columns, add missing-column case parallel to `validate_is_archived`
- [x] 1.2 GREEN: Rename `validate_is_essential()` → `validate_is_featured()` in `R/fct_validation.R`; update roxygen, file-header comment, and `validate_curated_csv()` dispatch
- [x] 1.3 REFACTOR: Confirm the new function matches the `validate_is_archived` pattern (missing-column → NA-values → non-logical branches)

## 2. Filter layer

- [x] 2.1 RED: Update `tests/testthat/test-fct_filters.R` — `essential_only` → `featured_only` argument, fixture column `is_essential` → `is_featured`
- [x] 2.2 GREEN: Rename `essential_only` → `featured_only` parameter in `filter_packages()` in `R/fct_filters.R`; update `.data$is_essential` → `.data$is_featured`, roxygen `@param`

## 3. Pipeline & JSON export

- [x] 3.1 RED: Update `tests/testthat/test-fct_pipeline.R` — rename field assertions in `merge_package_data()` and `export_json()` tests
- [x] 3.2 RED: Update `tests/testthat/test-fct_json.R` — rename JSON export key assertions
- [x] 3.3 GREEN: Rename `is_essential` → `is_featured` in `R/fct_pipeline.R` — `export_json()` per-package JSON object key, `merge_package_data()` references, file-header doc
- [x] 3.4 Check `_targets.R` for any `is_essential` references (confirmed none — the pipeline passes rows through unchanged)

## 4. Shiny modules

- [x] 4.1 RED: Update `tests/testthat/test-mod_detail.R` — badge label assertion "Featured in the book"
- [x] 4.2 GREEN: Rename in `R/mod_sidebar.R` — `ns("essential_only")` → `ns("featured_only")`, label "Featured in the Book", return-list key, roxygen
- [x] 4.3 GREEN: Rename in `R/mod_browse.R` — `is_essential <- data$is_essential[index]` → `is_featured`; `essential_badge` var → `featured_badge`; tooltip and aria-label "Featured in the book"; `is_essential = reactable::colDef(show = FALSE)` → `is_featured`
- [x] 4.4 GREEN: Rename in `R/mod_detail.R` — `essential_badge` var → `featured_badge`, badge text "⭐ Featured in the book", isTRUE check on `pkg$is_featured`

## 5. App server

- [x] 5.1 GREEN: Rename in `R/app_server.R` — `sidebar_values$essential_only()` → `sidebar_values$featured_only()`, pass `featured_only = ...` to `filter_packages()`

## 6. Styling

- [x] 6.1 Rename `.badge-essential` → `.badge-featured` in `inst/app/www/styles.css` (rule body unchanged)

## 7. Data source

- [x] 7.1 Rename header row `is_essential` → `is_featured` in `data-raw/packages_curated.csv` (values unchanged, 455 rows)
- [x] 7.2 Update `data-raw/migrate_notion.R` literal references

## 8. Test fixtures & integration

- [x] 8.1 Update `tests/testthat/test-fct_data.R` fixture references to `is_featured`
- [x] 8.2 Search `tests/testthat/fixtures/` for any `is_essential` literal values — zero found (grep clean)

## 9. Definition of done

- [x] 9.1 `grep -rn "is_essential\|essential_only\|Essential Extension\|badge-essential" R/ inst/ tests/ data-raw/` returns zero matches
- [x] 9.2 `devtools::test()` runs clean (466 PASS, 0 FAIL, 3 SKIP)
- [x] 9.3 Smoke-check: `mod_sidebar_ui()` body contains the label `"Featured in the Book"`; `build_header_card()` body contains the badge text `"Featured in the book"`
- [x] 9.4 `validate_curated_csv(curated, cats$category)` succeeds with renamed column (valid=TRUE, 0 errors)

## 10. Review hand-off

- [x] 10.1 Push branch `feature/m0-is-featured-rename`
- [x] 10.2 Request review (Reviewer for code; UX/UI Designer for label and badge text changes)

## 11. Address review feedback — round 01

From `comments/COMMENTS-m0-is-featured-rename-01.md` (Reviewer, APPROVED)
and `DESIGN_FIXES.md` (Designer, READY TO SHIP). Per the stakeholder's
working rule, every actionable item — SHOULD FIX, SUGGESTION, POLISH —
is addressed on the same branch before re-review.

- [x] 11.1 Reviewer §6 [SHOULD FIX]: add v1.2 (M0) header notes to `R/fct_pipeline.R`, `R/app_server.R`, `R/mod_browse.R`, `R/mod_detail.R`
- [x] 11.2 Reviewer §7 [SHOULD FIX]: create `openspec/changes/m0-is-featured-rename/design.md` matching sibling folders' format
- [x] 11.3 Reviewer §8 [SUGGESTION]: document the deliberate visual split between the detail pill and the browse star glyph (inline comments in `mod_detail.R` and `mod_browse.R`)
- [x] 11.4 Reviewer §9 [SUGGESTION]: drop the pre-existing double blank line in `R/fct_filters.R:84-85`
- [x] 11.5 Designer Fix #1 [SHOULD FIX]: add inline comments in `mod_sidebar.R` and `mod_detail.R` documenting the intentional Title Case vs sentence case split
- [x] 11.6 Designer Fix #2 [POLISH]: wrap the sidebar "Featured in the Book" checkbox in `bslib::tooltip()` with body `"Packages featured in the companion book 'ggplot2 extended'"`
- [x] 11.7 Designer Fix #6 [POLISH]: wrap the detail-view featured badge in `bslib::tooltip()` with the same body; add regression test asserting the tooltip body renders into the HTML
- [x] 11.8 Re-run DoD: grep sweep still zero matches; `devtools::test()` = 467 PASS / 0 FAIL / 3 SKIP; `validate_curated_csv()` on real CSV = valid/0 errors

## 12. Re-review hand-off

- [x] 12.1 Push round-01 fixes to `feature/m0-is-featured-rename`
- [x] 12.2 Request re-review (received `comments/COMMENTS-m0-is-featured-rename-02.md` — APPROVED with two follow-ups — and `comments/DESIGN_FIXES-m0-is-featured-rename-02.md` — READY TO SHIP with one SHOULD FIX)

## 13. Address review feedback — round 02

From `comments/COMMENTS-m0-is-featured-rename-02.md` (Reviewer, APPROVED) and
`comments/DESIGN_FIXES-m0-is-featured-rename-02.md` (Designer, READY TO SHIP).
Per the stakeholder's working rule, every actionable item is addressed on the
same branch before merge.

- [x] 13.1 Designer round-02 finding #1 [SHOULD FIX] + Reviewer §7 [SUGGESTION]: extract tooltip bodies to constants in `R/fct_constants.R`, differentiate sidebar (plural framing) from detail (singular framing). Preserves the shared "companion book 'ggplot2 extended'" phrase so "which book?" stays stable across surfaces.
- [x] 13.2 Reviewer §5 [SHOULD FIX]: fix comment rot in `tests/testthat/test-mod_detail.R:102-106` — bslib 0.10 renders tooltip as a `<bslib-tooltip>` Web Component with a `<template>` child, not a `data-bs-title` attribute (that's hydrated at runtime). Rewrote the block to match reality.
- [x] 13.3 Reviewer §8 [SUGGESTION]: create `tests/testthat/test-mod_sidebar.R` with five assertions — smoke test, Title Case label, sidebar tooltip body present, detail tooltip body NOT leaking into sidebar, namespaced input ID. Closes the coverage asymmetry between the two tooltip surfaces.
- [x] 13.4 Reviewer §6 [QUESTION] answered: two-surface scope (long body on sidebar + detail only) was deliberate per Designer round-01 LEAVE-IT #3 and round-02 finding #1. Added an inline comment in `R/mod_browse.R` documenting this so a future maintainer does not re-litigate.
- [ ] 13.5 Designer round-02 finding #2 [POLISH]: keyboard reachability of the detail-badge tooltip — **deferred to M6** (accessibility floor) per Designer's own scoping note: "an M6 question, not an M0 question."
- [x] 13.6 Re-run DoD: grep sweep still zero matches; `devtools::test()` = 473 PASS / 0 FAIL / 3 SKIP; `validate_curated_csv()` on real CSV = valid/0 errors; `openspec validate m0-is-featured-rename` = valid.

## 14. Re-review hand-off — round 03

- [x] 14.1 Push round-02 fixes to `feature/m0-is-featured-rename`
- [x] 14.2 Request round-03 review (received `comments/COMMENTS-m0-is-featured-rename-03.md` — APPROVED, 0 MUST FIX / 0 SHOULD FIX — and `comments/DESIGN_FIXES-m0-is-featured-rename-03.md` — READY TO SHIP, "nothing more from the Designer seat"). Both reviewers explicitly closed their loops; no round-04 needed.

## 15. Merge and close out

- [ ] 15.1 Merge `feature/m0-is-featured-rename` into `main` with a milestone-closing merge commit
- [ ] 15.2 Archive this openspec change to `openspec/changes/archive/m0-is-featured-rename/` cross-referencing the merge commit
- [ ] 15.3 Delete the local feature branch (keep the remote ref for history)
