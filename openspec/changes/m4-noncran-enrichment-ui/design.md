## Context

M3 added `version`, `github_title`, `github_description`, `github_license`, `github_maintainer`, `github_version` to the data. The UI needs to display these appropriately.

## Goals / Non-Goals

**Goals:**
- Source-agnostic version labels throughout UI
- GitHub metadata fallbacks for non-CRAN packages in detail view
- Hide enrichment columns from browse table

**Non-Goals:**
- Pipeline changes (done in M3)
- New test infrastructure (UI changes verified by existing tests)

## Decisions

**1. Use the "simpler approach" from spec for version column**
- Add `version` as a visible column, hide `cran_version`
- Cleaner than overriding the cell renderer to read from a different column

**2. Fallback chain: CRAN → GitHub → NULL**
- Per spec §5.4.4: CRAN data takes priority, GitHub fills in only for non-CRAN packages
- Use simple if/else chains, not complex conditional expressions

## Risks / Trade-offs

- [Risk] Data may not have `version` or `github_*` columns yet (before pipeline runs) → Mitigated by defensive column-existence checks
