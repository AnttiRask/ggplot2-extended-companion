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
    is_archived    = c(FALSE, FALSE, FALSE, FALSE, TRUE),
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

  # show_archived = TRUE so ggthemes (archived, themes) is included
  result <- filter_packages(data, category = "themes", show_archived = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("bbplot", "ggthemes") %in% result$package_name))
})

test_that("filter_packages with category 'All' returns all non-archived packages", {
  data <- make_test_data()

  result <- filter_packages(data, category = "All")

  # ggthemes is archived, so 4 of 5 returned by default
  expect_equal(nrow(result), 4)
  expect_false("ggthemes" %in% result$package_name)
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

  # show_archived = TRUE so ggthemes (archived, on CRAN) is included
  result <- filter_packages(data, cran_status = "On CRAN", show_archived = TRUE)

  expect_equal(nrow(result), 4)
  expect_false("bbplot" %in% result$package_name)
})

test_that("filter_packages filters to Not on CRAN only", {
  data <- make_test_data()

  result <- filter_packages(data, cran_status = "Not on CRAN")

  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "bbplot")
})

test_that("filter_packages with CRAN status 'All' returns all non-archived", {
  data <- make_test_data()

  result <- filter_packages(data, cran_status = "All")

  expect_equal(nrow(result), 4)
})

# --- filter by license -------------------------------------------------------

test_that("filter_packages filters by license", {
  data <- make_test_data()

  result <- filter_packages(data, license_filter = "MIT")

  expect_equal(nrow(result), 2)
  expect_true(all(c("patchwork", "gganimate") %in% result$package_name))
})

test_that("filter_packages with license 'All' returns all non-archived", {
  data <- make_test_data()

  result <- filter_packages(data, license_filter = "All")

  expect_equal(nrow(result), 4)
})

# --- filter by essential only ------------------------------------------------

test_that("filter_packages filters essential only", {
  data <- make_test_data()

  result <- filter_packages(data, essential_only = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("ggrepel", "patchwork") %in% result$package_name))
})

test_that("filter_packages with essential_only FALSE returns all non-archived", {
  data <- make_test_data()

  result <- filter_packages(data, essential_only = FALSE)

  expect_equal(nrow(result), 4)
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

# --- recently_added / recently_updated filters --------------------------------

test_that("filter_packages filters by recently_added", {
  data <- make_test_data()
  data$recently_added <- c(TRUE, FALSE, FALSE, TRUE, FALSE)
  data$recently_updated <- c(FALSE, FALSE, FALSE, FALSE, FALSE)

  result <- filter_packages(data, recently_added = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("ggrepel", "gganimate") %in% result$package_name))
})

test_that("filter_packages filters by recently_updated", {
  data <- make_test_data()
  data$recently_added <- c(FALSE, FALSE, FALSE, FALSE, FALSE)
  data$recently_updated <- c(FALSE, TRUE, FALSE, FALSE, TRUE)

  # show_archived = TRUE so ggthemes (archived, recently updated) is included
  result <- filter_packages(data, recently_updated = TRUE, show_archived = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("patchwork", "ggthemes") %in% result$package_name))
})

test_that("filter_packages uses OR logic between recently_added and recently_updated", {
  data <- make_test_data()
  # ggrepel: recently added only
  # patchwork: recently updated only
  # gganimate: both
  data$recently_added <- c(TRUE, FALSE, FALSE, TRUE, FALSE)
  data$recently_updated <- c(FALSE, TRUE, FALSE, TRUE, FALSE)

  result <- filter_packages(data, recently_added = TRUE, recently_updated = TRUE)

  # Should return union: ggrepel, patchwork, gganimate (3 packages)
  expect_equal(nrow(result), 3)
  expect_true(all(c("ggrepel", "patchwork", "gganimate") %in% result$package_name))
})

test_that("filter_packages recent filters compose with other filters via AND", {
  data <- make_test_data()
  data$recently_added <- c(TRUE, TRUE, TRUE, TRUE, TRUE)
  data$recently_updated <- c(FALSE, FALSE, FALSE, FALSE, FALSE)

  # Recently added AND on CRAN — bbplot is not on CRAN, ggthemes is archived
  result <- filter_packages(data, cran_status = "On CRAN", recently_added = TRUE)

  expect_equal(nrow(result), 3)
  expect_false("bbplot" %in% result$package_name)
  expect_false("ggthemes" %in% result$package_name)
})

test_that("filter_packages with recently_added FALSE has no effect", {
  data <- make_test_data()
  data$recently_added <- c(TRUE, FALSE, FALSE, TRUE, FALSE)
  data$recently_updated <- c(FALSE, FALSE, FALSE, FALSE, FALSE)

  # show_archived = TRUE to test that recently_added FALSE is neutral
  result <- filter_packages(data, recently_added = FALSE, recently_updated = FALSE, show_archived = TRUE)

  expect_equal(nrow(result), 5)
})

# --- show_archived filter -----------------------------------------------------

test_that("filter_packages hides archived packages by default", {
  data <- make_test_data()
  # ggthemes is archived in make_test_data()

  result <- filter_packages(data)

  expect_equal(nrow(result), 4)
  expect_false("ggthemes" %in% result$package_name)
})

test_that("filter_packages shows archived packages when show_archived is TRUE", {
  data <- make_test_data()

  result <- filter_packages(data, show_archived = TRUE)

  expect_equal(nrow(result), 5)
  expect_true("ggthemes" %in% result$package_name)
})

test_that("filter_packages show_archived composes with other filters via AND", {
  data <- make_test_data()
  # ggthemes is archived and has category "themes"
  # bbplot is not archived and has category "themes"

  result <- filter_packages(data, category = "themes", show_archived = TRUE)

  expect_equal(nrow(result), 2)
  expect_true(all(c("bbplot", "ggthemes") %in% result$package_name))
})

test_that("filter_packages show_archived FALSE with category still excludes archived", {
  data <- make_test_data()

  result <- filter_packages(data, category = "themes", show_archived = FALSE)

  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "bbplot")
})
