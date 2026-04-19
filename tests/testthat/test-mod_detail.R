# =============================================================================
# test-mod_detail.R
#
# Tests for package detail view card builder functions in R/mod_detail.R.
# These are pure functions that take a data row and return HTML — fully
# testable without Shiny.
#
# Part of Milestone 5: Package Detail View
# =============================================================================

# Helper: create a one-row test package data frame
make_test_pkg <- function(
  package_name = "ggrepel",
  title = "Automatically Position Non-Overlapping Text Labels with ggplot2",
  description = "Provides geoms for ggplot2 to repel overlapping text labels.",
  maintainer = "Kamil Slowikowski",
  categories = "annotations",
  is_featured = TRUE,
  on_cran = TRUE,
  has_vignettes = TRUE,
  license = "GPL-3",
  cran_version = "0.9.6",
  cran_published = as.Date("2024-09-07"),
  github_updated = as.Date("2024-12-01"),
  website_url = "https://ggrepel.slowkow.com/",
  repo_url = "https://github.com/slowkow/ggrepel",
  cran_url = "https://cran.r-project.org/package=ggrepel",
  manual_url = "https://cran.r-project.org/web/packages/ggrepel/ggrepel.pdf",
  vignettes_url = "https://cran.r-project.org/web/packages/ggrepel/vignettes/",
  downloads_7d = 5000L,
  downloads_30d = 20000L,
  downloads_365d = 200000L,
  downloads_all = 1500000L,
  version = cran_version,
  github_title = NA_character_,
  github_description = NA_character_,
  github_maintainer = NA_character_,
  github_license = NA_character_
) {
  data.frame(
    package_name = package_name,
    title = title,
    description = description,
    has_vignettes = has_vignettes,
    maintainer = maintainer,
    categories = categories,
    is_featured = is_featured,
    on_cran = on_cran,
    license = license,
    cran_version = cran_version,
    cran_published = cran_published,
    github_updated = github_updated,
    website_url = website_url,
    repo_url = repo_url,
    cran_url = cran_url,
    manual_url = manual_url,
    vignettes_url = vignettes_url,
    downloads_7d = downloads_7d,
    downloads_30d = downloads_30d,
    downloads_365d = downloads_365d,
    downloads_all = downloads_all,
    version = version,
    github_title = github_title,
    github_description = github_description,
    github_maintainer = github_maintainer,
    github_license = github_license,
    stringsAsFactors = FALSE
  )
}

# --- build_header_card() ----------------------------------------------------

test_that("build_header_card includes package name and title", {
  pkg <- make_test_pkg()

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl("ggrepel", html))
  expect_true(grepl("Non-Overlapping Text Labels", html))
})

test_that("build_header_card shows featured badge when is_featured is TRUE", {
  pkg <- make_test_pkg(is_featured = TRUE)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl("Featured in the book", html))
})

test_that("build_header_card hides featured badge when is_featured is FALSE", {
  pkg <- make_test_pkg(is_featured = FALSE)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_false(grepl("Featured in the book", html))
})

test_that("build_header_card featured badge carries the book-disambiguating tooltip", {
  # v1.2 Designer Fix #6: the detail badge is wrapped in bslib::tooltip() so
  # the "featured in *what* book?" clarification is reachable on hover/focus.
  # The framing is singular ("Featured in the companion book…") for the
  # detail view, where the user is reading one package — contrast with the
  # sidebar's plural "Packages featured…" which fits a collection-filter
  # control. Both share the core "companion book 'ggplot2 extended'" phrase
  # so the answer to "which book?" is stable across surfaces. See the
  # FEATURED_TOOLTIP_BODY_* constants in R/fct_constants.R.
  #
  # Rendering note: bslib 0.10 renders `tooltip()` as a `<bslib-tooltip>`
  # Web Component whose `<template>` child holds the body text. The
  # runtime Bootstrap JS hydrates it into a `data-bs-title` attribute and
  # an `aria-describedby` link on activation — those attributes are not
  # present in the static HTML. The `grepl(..., fixed = TRUE)` below
  # locates the literal body string anywhere in the rendered HTML, which
  # is enough to verify the tooltip is wired up. The `fixed = TRUE` flag
  # sidesteps regex interpretation of the single-quote characters in the
  # body text.
  pkg <- make_test_pkg(is_featured = TRUE)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl(
    FEATURED_TOOLTIP_BODY_DETAIL,
    html,
    fixed = TRUE
  ))
})

test_that("build_header_card shows all category badges for multi-category package", {
  pkg <- make_test_pkg(categories = "geoms|stats|themes")

  result <- build_header_card(pkg)
  html <- as.character(result)

  # Category badges use display names (capitalized)
  expect_true(grepl("Geoms", html))
  expect_true(grepl("Stats", html))
  expect_true(grepl("Themes", html))
})

test_that("build_header_card handles NA title and description", {
  pkg <- make_test_pkg(title = NA, description = NA)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl("No title available", html))
})

test_that("build_header_card shows title as lead and description as body", {
  pkg <- make_test_pkg(
    title = "My Package Title",
    description = "A longer description of the package."
  )

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl("My Package Title", html))
  expect_true(grepl("A longer description", html))
})

test_that("build_header_card falls back to GitHub fields when CRAN fields are NA", {
  pkg <- make_test_pkg(
    title = NA,
    description = NA,
    maintainer = NA,
    license = NA,
    on_cran = FALSE,
    github_title = "GitHub Package Title",
    github_description = "A description from GitHub DESCRIPTION file.",
    github_maintainer = "Jane Doe",
    github_license = "MIT + file LICENSE"
  )

  result <- build_header_card(pkg)
  html <- as.character(result)

  # GitHub values should appear in rendered HTML
  expect_true(grepl("GitHub Package Title", html))
  expect_true(grepl("A description from GitHub", html))
  expect_true(grepl("Jane Doe", html))
  expect_true(grepl("MIT \\+ file LICENSE", html))
})

test_that("build_header_card prefers CRAN data over GitHub when both exist", {
  pkg <- make_test_pkg(
    title = "CRAN Title",
    description = "CRAN description.",
    maintainer = "CRAN Maintainer",
    license = "GPL-3",
    on_cran = TRUE,
    github_title = "GitHub Title",
    github_description = "GitHub description.",
    github_maintainer = "GitHub Maintainer",
    github_license = "MIT"
  )

  result <- build_header_card(pkg)
  html <- as.character(result)

  # CRAN values should appear (not GitHub)
  expect_true(grepl("CRAN Title", html))
  expect_true(grepl("CRAN description", html))
  expect_true(grepl("CRAN Maintainer", html))
  expect_true(grepl("GPL-3", html))
  expect_false(grepl("GitHub Title", html))
  expect_false(grepl("GitHub Maintainer", html))
})

# --- build_links_card() -----------------------------------------------------

test_that("build_links_card shows all links when present", {
  pkg <- make_test_pkg()

  result <- build_links_card(pkg)
  html <- as.character(result)

  expect_true(grepl("Website", html))
  expect_true(grepl("GitHub", html))
  expect_true(grepl("CRAN", html))
  expect_true(grepl("Manual", html))
  expect_true(grepl("Vignettes", html))
})

test_that("build_links_card hides NA links", {
  pkg <- make_test_pkg(website_url = NA, manual_url = NA, vignettes_url = NA)

  result <- build_links_card(pkg)
  html <- as.character(result)

  # Should still show GitHub and CRAN
  expect_true(grepl("GitHub", html))
  expect_true(grepl("CRAN", html))

  # Should not show Website, Manual, Vignettes
  expect_false(grepl("Website", html))
  expect_false(grepl("Manual", html))
  expect_false(grepl("Vignettes", html))
})

test_that("build_links_card returns NULL when all links are NA", {
  pkg <- make_test_pkg(
    website_url = NA, repo_url = NA, cran_url = NA,
    manual_url = NA, vignettes_url = NA
  )

  result <- build_links_card(pkg)

  expect_null(result)
})

test_that("build_links_card opens links in new tab", {
  pkg <- make_test_pkg()

  result <- build_links_card(pkg)
  html <- as.character(result)

  expect_true(grepl('target="_blank"', html))
  expect_true(grepl('noopener noreferrer', html))
})

# --- build_downloads_card() -------------------------------------------------

test_that("build_downloads_card shows formatted download counts", {
  pkg <- make_test_pkg(
    downloads_7d = 5000L,
    downloads_30d = 20000L,
    downloads_365d = 200000L,
    downloads_all = 1500000L
  )

  result <- build_downloads_card(pkg)
  html <- as.character(result)

  expect_true(grepl("5,000", html))
  expect_true(grepl("20,000", html))
  expect_true(grepl("200,000", html))
  expect_true(grepl("1,500,000", html))
})

test_that("build_downloads_card shows em-dash for NA downloads", {
  pkg <- make_test_pkg(
    downloads_7d = NA_integer_,
    downloads_30d = NA_integer_,
    downloads_365d = NA_integer_,
    downloads_all = NA_integer_
  )

  result <- build_downloads_card(pkg)
  html <- as.character(result)

  # Should contain em-dash (—) for NA values
  expect_true(grepl("\u2014", html))
})

# --- build_version_card() ---------------------------------------------------

test_that("build_version_card shows Latest Version for CRAN packages", {
  pkg <- make_test_pkg(on_cran = TRUE, cran_version = "0.9.6", version = "0.9.6")

  result <- build_version_card(pkg)
  html <- as.character(result)

  expect_true(grepl("Latest Version", html))
  expect_true(grepl("0.9.6", html))
})

test_that("build_version_card shows em dash for non-CRAN packages without version", {
  pkg <- make_test_pkg(on_cran = FALSE, cran_version = NA, version = NA)

  result <- build_version_card(pkg)
  html <- as.character(result)

  # v1.1: "Not available on CRAN." removed, shows "Latest Version: —" instead
  expect_true(grepl("Latest Version", html))
  expect_true(grepl("\u2014", html))
  expect_false(grepl("Not available on CRAN", html))
})

test_that("build_version_card shows GitHub updated date", {
  pkg <- make_test_pkg(github_updated = as.Date("2024-12-01"))

  result <- build_version_card(pkg)
  html <- as.character(result)

  expect_true(grepl("2024-12-01", html))
})
