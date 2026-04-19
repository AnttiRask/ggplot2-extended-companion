## Context

M1 added `is_archived` to the CSV and validation. M2 builds the UI layer: filter logic, sidebar checkbox, browse table badges, and detail view banner/badges. The spec (SPEC-v1.1 §5.1–5.5) defines exact HTML, CSS, and filter logic.

## Goals / Non-Goals

**Goals:**
- Archived packages hidden by default, visible via checkbox
- 📁 emoji in browse table for archived packages
- Archived badge + warning banner + notes in detail view
- Filter composes with all existing filters via AND logic

**Non-Goals:**
- Version column rename (M4)
- Non-CRAN metadata fallbacks (M4)
- Google Form link activation (M0)

## Decisions

**1. Filter position: first, before category**
- Per spec §5.5.1: archived filter is applied as the first filter, before category
- Rationale: Remove archived packages early to avoid counting them in category results

**2. Archived warning banner position: after nav bar, before header card**
- Per spec §5.4.2: "first thing the user sees after navigating to the package"

**3. CSS mirrors `.badge-essential` pattern**
- Gray (#6b7280) to signal "inactive" without being alarming

## Risks / Trade-offs

- [Risk] Data doesn't have `is_archived` column yet in parquet → Mitigated: column flows through `merge_package_data()` from curated CSV automatically (confirmed in M1 review)
- [Risk] `isTRUE(.data$is_archived)` won't work with dplyr filter → Use `!isTRUE(is_archived)` pattern per spec, which handles NA gracefully
