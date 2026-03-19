# =============================================================================
# test-fct_filters.R
#
# Tests for package filtering logic used by the sidebar module.
# Verifies category, CRAN status, license, and essential filters.
#
# Part of Milestone 4: Sidebar Filters & Sorting
# =============================================================================

# Helper: create a minimal test dataset
make_test_data <- function() {
  tibble::tibble(
    package_name   = c("ggrepel", "patchwork", "bbplot", "gganimate", "ggthemes"),
    categories     = c("annotations", "arranging_plots", "themes", "animation|interactive_plots", "themes"),
    is_essential   = c(TRUE, TRUE, FALSE, FALSE, FALSE),
    on_cran        = c(TRUE, TRUE, FALSE, TRUE, TRUE),
    license        = c("GPL-3", "MIT", NA, "MIT", "GPL-2"),
    description    = c("Labels", "Combine plots", "BBC style", "Animate", "Themes"),
    maintainer     = c("Kamil", "Thomas", NA, "Thomas", "Jeffrey"),
    downloads_30d  = c(20000L, 15000L, NA_integer_, 5000L, 8000L),
    downloads_all  = c(1500000L, 900000L, NA_integer_, 300000L, 600000L)
  )
}

# --- filter by category -----------------------------------------------------

test_that("filter_packages filters by category", {
  data <- make_test_data()

  result <- filter_packages(data, category = "themes")

  expect_equal(nrow(result), 2)
  expect_true(all(c("bbplot", "ggthemes") %in% result$package_name))
})

test_that("filter_packages with category 'All' returns all packages", {
  data <- make_test_data()

  result <- filter_packages(data, category = "All")

  expect_equal(nrow(result), 5)
})

test_that("filter_packages finds packages with category in pipe-separated list", {
  data <- make_test_data()

  result <- filter_packages(data, category = "interactive_plots")

  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "gganimate")
})

# --- filter by CRAN status ---------------------------------------------------

test_that("filter_packages filters to On CRAN only", {
  data <- make_test_data()

  result <- filter_packages(data, cran_status = "On CRAN")

  expect_equal(nrow(result), 4)
  expect_false("bbplot" %in% result$package_name)
})

test_that("filter_packages filters to Not on CRAN only", {
  data <- make_test_data()

  result <- filter_packages(data, cran_status = "Not on CRAN")

  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "bbplot")
})

test_that("filter_packages with CRAN status 'All' returns all", {
  data <- make_test_data()

  result <- filter_packages(data, cran_status = "All")

  expect_equal(nrow(result), 5)
})

# --- filter by license -------------------------------------------------------

test_that("filter_packages filters by license", {
  data <- make_test_data()

  result <- filter_packages(data, license_filter = "MIT")

  expect_equal(nrow(result), 2)
  expect_true(all(c("patchwork", "gganimate") %in% result$package_name))
})

test_that("filter_packages with license 'All' returns all", {
  data <- make_test_data()

  result <- filter_packages(data, license_filter = "All")

  expect_equal(nrow(result), 5)
})

# --- filter by essential only ------------------------------------------------

test_that("filter_packages filters essential only", {
  data <- make_test_data()

  result <- filter_packages(data, essential_only = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("ggrepel", "patchwork") %in% result$package_name))
})

test_that("filter_packages with essential_only FALSE returns all", {
  data <- make_test_data()

  result <- filter_packages(data, essential_only = FALSE)

  expect_equal(nrow(result), 5)
})

# --- combined filters --------------------------------------------------------

test_that("filter_packages combines multiple filters", {
  data <- make_test_data()

  # On CRAN + MIT license
  result <- filter_packages(data, cran_status = "On CRAN", license_filter = "MIT")

  expect_equal(nrow(result), 2)
  expect_true(all(c("patchwork", "gganimate") %in% result$package_name))
})

test_that("filter_packages with all filters returns correct subset", {
  data <- make_test_data()

  # Essential + On CRAN + any category + any license
  result <- filter_packages(
    data,
    category = "All",
    cran_status = "On CRAN",
    license_filter = "All",
    essential_only = TRUE
  )

  expect_equal(nrow(result), 2)
})

# --- sort_packages() --------------------------------------------------------

test_that("sort_packages sorts by name ascending", {
  data <- make_test_data()

  result <- sort_packages(data, "Name (A\u2013Z)")

  expect_equal(result$package_name[1], "bbplot")
})

test_that("sort_packages sorts by name descending", {
  data <- make_test_data()

  result <- sort_packages(data, "Name (Z\u2013A)")

  expect_equal(result$package_name[1], "patchwork")
})

test_that("sort_packages sorts by downloads descending", {
  data <- make_test_data()

  result <- sort_packages(data, "Downloads (30d) \u2193")

  # ggrepel has 20000, should be first
  expect_equal(result$package_name[1], "ggrepel")
})

test_that("sort_packages sorts by CRAN published newest first", {
  data <- make_test_data()
  data$cran_published <- as.Date(c("2024-09-07", "2025-08-25", NA, "2025-09-04", "2024-01-01"))

  result <- sort_packages(data, "CRAN Published (newest)")

  expect_equal(result$package_name[1], "gganimate")
})
