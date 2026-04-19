## Context

The pipeline currently fetches metadata from CRAN (pkgsearch), cranlogs, and GitHub repo API. Non-CRAN packages get NA for title, description, license, maintainer, and version. By fetching the DESCRIPTION file from GitHub, we can fill these gaps.

## Goals / Non-Goals

**Goals:**
- Fetch DESCRIPTION from GitHub for non-CRAN packages with GitHub repos
- Cache results for daily pipeline reuse
- Derive unified `version` field (CRAN or GitHub)
- Add `is_archived` and `version` to JSON export

**Non-Goals:**
- UI display of enriched data (M4)
- Fetching from non-GitHub repos (GitLab, etc.)

## Decisions

**1. Fetch for ALL packages, store NA for CRAN/non-GitHub**
- Per spec §4.3: build tibble for all packages, only make API calls for eligible ones
- Simplifies join logic — every package has a row

**2. Use `desc` package for DESCRIPTION parsing**
- Handles both `Maintainer` field and `Authors@R` parsing
- Well-maintained, stable dependency

**3. Cache to RDS, committed alongside parquet files**
- `data/github_descriptions.rds` persists via git commit in pipeline workflows
- Daily runs load from cache without API calls

**4. Defensive per-package tryCatch following fetch_github_metadata pattern**
- 404, rate limit, network errors all produce NA row + log warning
- Partial results are acceptable

## Risks / Trade-offs

- [Risk] desc package parse failure for malformed DESCRIPTION → Mitigated by per-package tryCatch
- [Risk] base64 decoding issues → GitHub API always returns base64 for file contents
