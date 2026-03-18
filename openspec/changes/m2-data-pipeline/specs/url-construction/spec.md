## ADDED Requirements

### Requirement: construct_urls builds CRAN-derived URLs
`construct_urls()` SHALL construct CRAN page, reference manual, and vignettes URLs based on package name and CRAN status.

#### Scenario: Package on CRAN
- **WHEN** a package is on CRAN
- **THEN** `cran_url` SHALL be `https://cran.r-project.org/package={name}`, `manual_url` SHALL be `https://cran.r-project.org/web/packages/{name}/{name}.pdf`, and `vignettes_url` SHALL be `https://cran.r-project.org/web/packages/{name}/vignettes/`

#### Scenario: Package not on CRAN
- **WHEN** a package is not on CRAN (`on_cran = FALSE`)
- **THEN** `cran_url`, `manual_url`, and `vignettes_url` SHALL all be NA
