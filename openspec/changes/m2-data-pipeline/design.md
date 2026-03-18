## Context

M1 delivered `packages_curated.csv` with 455 packages. M2 builds the pipeline that enriches this data with live API data and produces Parquet files. The pipeline runs daily on GitHub Actions (M10) but must also work locally for development.

Three external APIs are involved:
- **pkgsearch** (CRAN metadata): ~455 calls, ~1 req/sec, no auth
- **cranlogs** (download counts): batch-friendly, no auth
- **gh** (GitHub metadata): ~441 calls (packages with repo_url), needs GITHUB_PAT

## Goals / Non-Goals

**Goals:**
- Pipeline functions that fetch, merge, and write data for all 455 packages
- Per-package error handling (log warning, continue with NA/cached values)
- Testable with mocked API responses (no real API calls in tests)
- Parquet output files matching the data model (§3.1, §3.2, §3.4)

**Non-Goals:**
- Code example rendering (M6)
- JSON export (M8)
- GitHub Actions workflow files (M10)
- Running the full pipeline in CI tests (too slow, needs API access)

## Decisions

### 1. Per-package tryCatch wrapping for API calls

**Decision**: Wrap each individual API call in tryCatch. On failure, log a warning and return NA values for that package. The pipeline continues with remaining packages.

**Rationale**: SPEC §4.2 requires per-package error handling. A single package failure shouldn't block the other 454.

### 2. cranlogs batching for download stats

**Decision**: Use `cranlogs::cran_downloads()` with batches of packages rather than individual calls. cranlogs supports multiple packages per request.

**Rationale**: Much faster than 455 individual calls. Compute 7d, 30d, 365d, all-time aggregates in R from the daily data.

### 3. Mock API responses with static fixture files

**Decision**: Store representative API responses in `tests/testthat/fixtures/` as JSON/RDS files. Tests load these fixtures instead of calling real APIs.

**Rationale**: Tests must be fast, offline, and deterministic. httptest2 or webmockr would work but static fixtures are simpler for this use case.

### 4. GitHub URL parsing for owner/repo extraction

**Decision**: Parse `repo_url` from curated CSV using regex to extract `owner` and `repo` for the GitHub API call. Handle both `github.com` and `gitlab.com` URLs, skip non-GitHub/GitLab URLs.

**Rationale**: SPEC Appendix A notes: "Parse repo_url from curated CSV to extract owner and repo."

## Risks / Trade-offs

- **[Risk] API rate limits during development** → Use targets caching — only re-fetch when inputs change. For GitHub, GITHUB_PAT provides 5,000 req/hr which is ample.
- **[Risk] pkgsearch may not have data for non-CRAN packages** → ~126 packages are not on CRAN. Set `on_cran = FALSE` and fill metadata fields with NA.
- **[Risk] cranlogs data is 2 days behind** → Documented in spec, acceptable for this use case.
