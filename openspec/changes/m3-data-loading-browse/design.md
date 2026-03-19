## Context

The pipeline (M2) produces `data/packages.parquet` and `data/downloads.parquet`. The spec requires loading this data into DuckDB at app startup and displaying it in a reactable table. The data is static for the app's lifetime (refreshed only by container redeployment).

## Goals / Non-Goals

**Goals:**
- Load Parquet data once at app startup via DuckDB
- Display all packages in a reactable table with 9 columns matching SPEC §5.2
- Client-side search and column sorting via reactable built-in features
- Pagination at 25 rows per page

**Non-Goals:**
- Sidebar filters (M4)
- Detail view / row click handling (M5)
- Recently added/updated lists (M7)
- Loading examples data (M6)

## Decisions

### 1. DuckDB for Parquet reading, tibble for app data

**Decision**: Use DuckDB + dbplyr to read Parquet files, then collect into a tibble held in memory. The app works with the in-memory tibble, not live DuckDB queries.

**Rationale**: With ~455 rows, in-memory is trivially fast. DuckDB provides efficient Parquet reading but there's no need for query-time database access for this data volume. The spec says "loaded once at app startup."

### 2. Browse module receives data as reactive

**Decision**: `mod_browse_server()` receives the full dataset as a reactive value from the parent server. Filtering (M4) will update this reactive, and the table will re-render.

**Rationale**: Clean reactive data flow. The browse module doesn't need to know about data sources — it just renders whatever it receives.

### 3. Package name click handled via Shiny.setInputValue

**Decision**: Use reactable's `onClick` callback with `Shiny.setInputValue()` to communicate the selected package back to the server. For M3, we'll set up the click infrastructure but the detail view (M5) isn't built yet.

**Rationale**: reactable doesn't have built-in row selection that plays well with Shiny modules. JavaScript `onClick` is the standard pattern.

## Risks / Trade-offs

- **[Risk] Parquet files might not exist at startup** → Add graceful error handling in data loading. Show a user-friendly message if data is missing.
- **[Risk] DuckDB connection management** → Open once at startup, close on session end. Use `onStop()` to clean up.
