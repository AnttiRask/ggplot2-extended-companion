# =============================================================================
# test-fct_data.R
#
# Tests for data loading functions in R/fct_data.R.
# Verifies Parquet file reading and data preparation for the Shiny app.
#
# Part of Milestone 3: Data Loading & Browse Table
# =============================================================================

# --- load_packages() ---------------------------------------------------------

test_that("load_packages returns a tibble with expected columns", {
  parquet_path <- file.path(test_path(), "..", "..", "data", "packages.parquet")
  skip_if_not(file.exists(parquet_path), "packages.parquet not found")

  result <- load_packages(parquet_path)

  expect_true(tibble::is_tibble(result))
  expect_gte(nrow(result), 400)

  expected_cols <- c(
    "package_name", "description", "maintainer", "categories", "is_featured",
    "on_cran", "license", "cran_version", "cran_published", "github_updated"
  )
  expect_true(all(expected_cols %in% names(result)))
})

# --- load_downloads() --------------------------------------------------------

test_that("load_downloads returns a tibble with download columns", {
  parquet_path <- file.path(test_path(), "..", "..", "data", "downloads.parquet")
  skip_if_not(file.exists(parquet_path), "downloads.parquet not found")

  result <- load_downloads(parquet_path)

  expect_true(tibble::is_tibble(result))
  expect_gte(nrow(result), 400)

  expected_cols <- c(
    "package_name", "downloads_7d", "downloads_30d",
    "downloads_365d", "downloads_all"
  )
  expect_true(all(expected_cols %in% names(result)))
})

# --- load_app_data() ---------------------------------------------------------

test_that("load_app_data combines packages and downloads", {
  pkg_path <- file.path(test_path(), "..", "..", "data", "packages.parquet")
  dl_path <- file.path(test_path(), "..", "..", "data", "downloads.parquet")
  skip_if_not(
    file.exists(pkg_path) && file.exists(dl_path),
    "Parquet files not found"
  )

  result <- load_app_data(pkg_path, dl_path)

  expect_true(tibble::is_tibble(result))
  expect_gte(nrow(result), 400)

  # Should have both package and download columns
  expect_true("package_name" %in% names(result))
  expect_true("description" %in% names(result))
  expect_true("downloads_30d" %in% names(result))
  expect_true("downloads_all" %in% names(result))
})

test_that("load_app_data returns NULL with message when files missing", {
  result <- load_app_data(
    "nonexistent/packages.parquet",
    "nonexistent/downloads.parquet"
  )

  expect_null(result)
})
