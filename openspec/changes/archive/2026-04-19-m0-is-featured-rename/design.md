## Context

SPEC-v1.2 introduces a rename: the v1.1 "essential extension" terminology is retired in favour of "featured in the book." The flag's semantics are unchanged — it still marks packages that are covered in the companion book *ggplot2 extended* — but the name overpromised in v1.1. "Featured" more honestly describes what the flag represents: a curation anchored in the book, not a global value judgement.

This change is the first milestone of v1.2 (see SPEC-v1.2 §9 dependency graph). It is intentionally scoped to a pure mechanical rename so that the grep sweeps performed in M1 (layout restructure), M2 (connection stability), and M3 (empty-state button + URL filter sync) start from a clean base with zero residual `is_essential` tokens. Landing M0 before the other v1.2 milestones diverge is critical — rebasing later milestones onto a renamed base is avoidable work.

The rename affects every layer: CSV header, Parquet column, JSON export key, validation function, filter parameter, sidebar input ID, sidebar filter label, detail badge text, browse tooltip/aria-label, CSS class, and R variable names. SPEC-v1.2 §3.2 provides the canonical mapping table — this change folder is the implementation of that table.

## Goals / Non-Goals

**Goals:**

- Rename every occurrence of the tokens `is_essential`, `essential_only`, `Essential Extension`, and `badge-essential` across `R/`, `inst/`, `tests/`, and `data-raw/` to their v1.2 counterparts
- Match every surface-area entry in SPEC-v1.2 §3.2 exactly — no partial renames, no dual-key transitional period
- Add a missing-column early-return branch to `validate_is_featured()`, parallel to the v1.1 `validate_is_archived()` pattern (SPEC-v1.2 §8.3)
- Add `title` and `aria-label` attributes on the browse-table star glyph per SPEC-v1.2 §5.9, replacing the v1.1 un-annotated star with a proper accessibility affordance
- Satisfy the four M0 definition-of-done checks from SPEC-v1.2 §9 (grep sweep, test suite, UI smoke, real-CSV validation)

**Non-Goals:**

- Layout changes (M1 handles `bslib::page_sidebar()` / `page_fillable()` per-view)
- New sidebar or detail copy beyond the rename (the Designer's POLISH tooltip items are addressed in the review-fix pass but are still polish, not new feature copy)
- Parquet regeneration in the real pipeline (happens automatically on the next `targets::tar_make()` run; this change edits only the local dev parquet for test purposes)
- JSON-consumer back-compat (release notes will call out the hard break per SPEC-v1.2 §3.2)
- Milestones M1–M7 (separately scoped)

## Decisions

**1. Hard rename over dual-key transitional period**

- **Rationale**: The JSON export is the only external-facing surface. v1.2 is young enough that an unknown external consumer is a low-likelihood / low-impact risk (SPEC-v1.2 §12 risk table). A dual-key period would double the code-path surface for no real benefit — the next pipeline run already regenerates the JSON with the new key, and release notes carry the callout. A clean break now avoids carrying two keys into M1–M7.
- **Alternative**: Emit both `is_essential` and `is_featured` in the JSON for one version, then drop `is_essential` in v1.3. Rejected: adds complexity, delays the cleanup, and assumes an externaI consumer that has not materialised.

**2. TDD ordering: RED before GREEN, at the layer granularity**

- **Rationale**: Every layer is a single concern (validation, filters, pipeline/JSON, modules, app server, CSS, data). Committing the RED test first per layer produces a branch-history narrative where each GREEN commit is demonstrably caused by the matching RED. This makes the Reviewer's job easier (every `feat:` commit's tests were already red) and gives the Developer a built-in safety net — if the source change fails to flip the test, the problem is in the source not the test.
- **Alternative considered**: One big RED commit covering all test files, then one big GREEN covering all source. Rejected: the narrative is flatter but the commits are bigger and harder to bisect if something regresses.

**3. Data-file rename (CSV header) goes last among the GREEN commits**

- **Rationale**: The CSV is read by both `read_curated_csv()` (used by the pipeline) and by the two integration tests in `test-fct_validation.R` that load the real file. Flipping the CSV header early would make those integration tests pass while the source code still used the legacy name — a false-green. Flipping last means the final commit is the one that makes everything converge.
- **Alternative**: Flip the CSV first. Rejected for the false-green reason above.

**4. Migration-note comments use "v1.1 legacy name" phrasing (not the literal legacy token)**

- **Rationale**: The DoD grep is `grep -rn "is_essential|essential_only|Essential Extension|badge-essential"` across `R/ inst/ tests/ data-raw/`. If migration-note comments contain the literal token, the grep returns non-zero, and DoD 9.1 fails. Rephrasing to "the v1.1 legacy name" (or "the legacy validator", etc.) lets the comments document the migration without tripping the DoD grep.
- **Alternative**: Carve out comment lines from the grep. Rejected: fragile — `grep` can't easily distinguish comments in R vs CSS vs R Markdown, and a future `rename()` refactor might move a comment to code unchecked.

**5. The new `title` + `aria-label` on the browse-table star (SPEC-v1.2 §5.9) is in scope for M0**

- **Rationale**: SPEC-v1.2 §5.9 lists this as part of the rename's accessibility surface, not as a separate a11y milestone. M6 (Accessibility floor) will *verify* it with axe-core and the keyboard-nav walkthrough, but the affordance itself ships with M0 because it directly accompanies the cell-rendering change. Splitting it off would fragment the commit narrative.
- **Alternative**: Defer to M6. Rejected: the star-cell renderer only gets edited once in v1.2; adding the attributes now is free.

## Risks / Trade-offs

- **[Risk] Local stale parquet breaks `test-fct_data.R:12` after CSV rename** — Mitigated by a one-off in-place column rename on `data/packages.parquet` (renames only, no pipeline re-run). CI and fresh clones skip the test via `skip_if_not(file.exists(parquet_path))`, so this is a local-environment issue only.
- **[Risk] JSON export hard break surprises an external consumer** — Mitigated by a callout in SPEC-v1.2 §3.2, future v1.2 release notes, and README. Likelihood low per SPEC-v1.2 §12 risk table.
- **[Trade-off] Adding the SPEC §5.9 a11y affordance inside M0 rather than M6** — M0 becomes slightly more than a pure rename, but the commit narrative stays clean and the M6 audit has one less remediation item. Net win.
- **[Trade-off] Migration-note comments use indirect phrasing** — Slightly awkward prose ("the v1.1 legacy name") instead of the literal token, but the DoD grep stays reliable and future grep sweeps in M1–M3 benefit from the same zero-hit cleanliness.

## See Also

- `SPEC-v1.2.md` §3.2 — canonical rename mapping table (the authoritative source for what changes)
- `SPEC-v1.2.md` §5.7 — sidebar "Featured in the Book" filter
- `SPEC-v1.2.md` §5.9 — detail badge and browse tooltip/aria-label
- `SPEC-v1.2.md` §8.3 — test updates including the new missing-column case
- `SPEC-v1.2.md` §M0 — milestone goal, file list, and definition of done
- `openspec/changes/m1-archived-data-validation/` — sibling change whose `validate_is_archived()` pattern was mirrored here
