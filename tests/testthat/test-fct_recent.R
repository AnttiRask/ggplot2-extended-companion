# =============================================================================
# test-fct_recent.R
#
# Tests for recently added/updated package list functions.
#
# Part of Milestone 7: Recently Added / Updated & Header
# =============================================================================

# Helper: create test data with varied dates
make_recent_data <- function() {
  tibble::tibble(
    package_name   = paste0("pkg", 1:15),
    date_added     = as.Date("2026-03-01") + seq(1, 15),
    cran_published = as.Date("2025-01-01") + seq(1, 15) * 30,
    github_updated = as.Date("2025-06-01") + seq(1, 15) * 10
  )
}

# --- get_recently_added() ---------------------------------------------------

test_that("get_recently_added returns 10 packages sorted by date_added desc", {
  data <- make_recent_data()

  result <- get_recently_added(data, n = 10)

  expect_equal(nrow(result), 10)
  # First entry should be the most recently added
  expect_equal(result$package_name[1], "pkg15")
  # Dates should be descending
  expect_true(all(diff(result$date_added) <= 0))
})

test_that("get_recently_added handles fewer than n packages", {
  data <- make_recent_data()[1:5, ]

  result <- get_recently_added(data, n = 10)

  expect_equal(nrow(result), 5)
})

test_that("get_recently_added handles NA date_added", {
  data <- make_recent_data()
  data$date_added[1:3] <- NA

  result <- get_recently_added(data, n = 10)

  # NA dates should be sorted to the end (excluded from top 10 if enough non-NA)
  expect_equal(nrow(result), 10)
})

# --- get_recently_updated() -------------------------------------------------

test_that("get_recently_updated returns 10 packages by most recent update", {
  data <- make_recent_data()

  result <- get_recently_updated(data, n = 10)

  expect_equal(nrow(result), 10)
  # Should have an update_date column and source label
  expect_true("update_date" %in% names(result))
  expect_true("update_source" %in% names(result))
})

test_that("get_recently_updated picks max of cran_published and github_updated", {
  data <- tibble::tibble(
    package_name   = c("pkg_cran", "pkg_github"),
    cran_published = as.Date(c("2026-01-15", "2025-01-01")),
    github_updated = as.Date(c("2025-01-01", "2026-02-20"))
  )

  result <- get_recently_updated(data, n = 10)

  # pkg_github should be first (2026-02-20 > 2026-01-15)
  expect_equal(result$package_name[1], "pkg_github")
  expect_equal(result$update_source[1], "GitHub")

  expect_equal(result$package_name[2], "pkg_cran")
  expect_equal(result$update_source[2], "CRAN")
})

test_that("get_recently_updated handles all-NA dates", {
  data <- tibble::tibble(
    package_name   = c("pkg1", "pkg2"),
    cran_published = as.Date(c(NA, NA)),
    github_updated = as.Date(c(NA, NA))
  )

  result <- get_recently_updated(data, n = 10)

  # Should return rows but with NA dates
  expect_equal(nrow(result), 2)
})
