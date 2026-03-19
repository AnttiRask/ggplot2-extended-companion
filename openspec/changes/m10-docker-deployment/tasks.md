## 1. Dockerfile

- [x] 1.1 Create Dockerfile — multi-stage build (builder + runtime), renv restore, app files, Parquet data

## 2. GitHub Actions Workflows

- [x] 2.1 Create .github/workflows/check.yml — R CMD check, tests, CSV validation on PRs
- [x] 2.2 Create .github/workflows/pipeline.yml — daily pipeline (06:00 UTC) + Docker build/deploy
- [x] 2.3 Create .github/workflows/examples.yml — weekly examples (Sunday 04:00 UTC) + deploy

## 3. Verification

- [x] 3.1 Dockerfile syntax valid, multi-stage build pattern correct
- [x] 3.2 Run full test suite — 226 pass, 3 skip
