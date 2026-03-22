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
  is_essential = TRUE,
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
  downloads_all = 1500000L
) {
  data.frame(
    package_name = package_name,
    title = title,
    description = description,
    has_vignettes = has_vignettes,
    maintainer = maintainer,
    categories = categories,
    is_essential = is_essential,
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

test_that("build_header_card shows essential badge when is_essential is TRUE", {
  pkg <- make_test_pkg(is_essential = TRUE)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_true(grepl("Essential Extension", html))
})

test_that("build_header_card hides essential badge when is_essential is FALSE", {
  pkg <- make_test_pkg(is_essential = FALSE)

  result <- build_header_card(pkg)
  html <- as.character(result)

  expect_false(grepl("Essential Extension", html))
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

test_that("build_version_card shows CRAN version for CRAN packages", {
  pkg <- make_test_pkg(on_cran = TRUE, cran_version = "0.9.6")

  result <- build_version_card(pkg)
  html <- as.character(result)

  expect_true(grepl("0.9.6", html))
})

test_that("build_version_card shows not-on-CRAN message for non-CRAN packages", {
  pkg <- make_test_pkg(on_cran = FALSE, cran_version = NA)

  result <- build_version_card(pkg)
  html <- as.character(result)

  expect_true(grepl("Not available on CRAN", html))
})

test_that("build_version_card shows GitHub updated date", {
  pkg <- make_test_pkg(github_updated = as.Date("2024-12-01"))

  result <- build_version_card(pkg)
  html <- as.character(result)

  expect_true(grepl("2024-12-01", html))
})
