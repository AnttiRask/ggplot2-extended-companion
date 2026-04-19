# =============================================================================
# test-fct_validation.R
#
# Tests for CSV validation functions in R/fct_validation.R.
# Validates packages_curated.csv integrity: no duplicates, valid categories,
# required fields, boolean is_featured, well-formed pipe-separated categories.
#
# v1.2 (M0): the "featured in the book" column replaces the v1.1 legacy name.
# validate_is_featured() now also detects a missing is_featured column
# (parallel to validate_is_archived).
#
# Part of Milestone 1: Notion Migration & Curated Data
# =============================================================================

# --- validate_no_duplicates() ------------------------------------------------

test_that("validate_no_duplicates returns no errors for unique names", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork", "gganimate"),
    stringsAsFactors = FALSE
  )

  result <- validate_no_duplicates(df)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_no_duplicates returns errors for duplicate names", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork", "ggrepel"),
    stringsAsFactors = FALSE
  )

  result <- validate_no_duplicates(df)

  expect_false(result$valid)
  expect_length(result$errors, 1)
  expect_true(grepl("ggrepel", result$errors[[1]]))
})

test_that("validate_no_duplicates detects multiple duplicates", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork", "ggrepel", "patchwork"),
    stringsAsFactors = FALSE
  )

  result <- validate_no_duplicates(df)

  expect_false(result$valid)
  # Should mention both duplicated names
  errors_text <- paste(result$errors, collapse = " ")
  expect_true(grepl("ggrepel", errors_text))
  expect_true(grepl("patchwork", errors_text))
})

# --- validate_required_fields() ----------------------------------------------

test_that("validate_required_fields returns no errors when all required fields present", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    categories = c("annotations", "arranging_plots"),
    date_added = c("2026-03-17", "2026-03-17"),
    stringsAsFactors = FALSE
  )

  result <- validate_required_fields(df)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_required_fields detects empty package_name", {
  df <- data.frame(
    package_name = c("ggrepel", ""),
    categories = c("annotations", "geoms"),
    date_added = c("2026-03-17", "2026-03-17"),
    stringsAsFactors = FALSE
  )

  result <- validate_required_fields(df)

  expect_false(result$valid)
  expect_true(any(grepl("package_name", result$errors)))
})

test_that("validate_required_fields detects NA categories", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    categories = c("annotations", NA_character_),
    date_added = c("2026-03-17", "2026-03-17"),
    stringsAsFactors = FALSE
  )

  result <- validate_required_fields(df)

  expect_false(result$valid)
  expect_true(any(grepl("categories", result$errors)))
})

test_that("validate_required_fields detects empty date_added", {
  df <- data.frame(
    package_name = c("ggrepel"),
    categories = c("annotations"),
    date_added = c(""),
    stringsAsFactors = FALSE
  )

  result <- validate_required_fields(df)

  expect_false(result$valid)
  expect_true(any(grepl("date_added", result$errors)))
})

# --- validate_is_featured() --------------------------------------------------

test_that("validate_is_featured returns no errors for valid booleans", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_featured = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )

  result <- validate_is_featured(df)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_is_featured detects missing column", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    stringsAsFactors = FALSE
  )

  result <- validate_is_featured(df)

  expect_false(result$valid)
  expect_length(result$errors, 1)
  expect_true(grepl("Missing required column: is_featured", result$errors[[1]]))
})

test_that("validate_is_featured detects invalid values", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_featured = c("TRUE", "yes"),
    stringsAsFactors = FALSE
  )

  result <- validate_is_featured(df)

  expect_false(result$valid)
  expect_true(any(grepl("patchwork", result$errors)))
})

test_that("validate_is_featured detects NA values", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_featured = c(TRUE, NA),
    stringsAsFactors = FALSE
  )

  result <- validate_is_featured(df)

  expect_false(result$valid)
})

# --- validate_category_format() ----------------------------------------------

test_that("validate_category_format returns no errors for well-formed categories", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork", "gganimate"),
    categories = c("annotations", "arranging_plots", "animation|interactive_plots"),
    stringsAsFactors = FALSE
  )

  result <- validate_category_format(df)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_category_format detects trailing pipe", {
  df <- data.frame(
    package_name = c("ggrepel"),
    categories = c("geoms|stats|"),
    stringsAsFactors = FALSE
  )

  result <- validate_category_format(df)

  expect_false(result$valid)
  expect_true(any(grepl("ggrepel", result$errors)))
})

test_that("validate_category_format detects leading pipe", {
  df <- data.frame(
    package_name = c("ggrepel"),
    categories = c("|geoms|stats"),
    stringsAsFactors = FALSE
  )

  result <- validate_category_format(df)

  expect_false(result$valid)
})

test_that("validate_category_format detects spaces around pipes", {
  df <- data.frame(
    package_name = c("ggrepel"),
    categories = c("geoms | stats"),
    stringsAsFactors = FALSE
  )

  result <- validate_category_format(df)

  expect_false(result$valid)
  expect_true(any(grepl("ggrepel", result$errors)))
})

test_that("validate_category_format detects empty segments", {
  df <- data.frame(
    package_name = c("ggrepel"),
    categories = c("geoms||stats"),
    stringsAsFactors = FALSE
  )

  result <- validate_category_format(df)

  expect_false(result$valid)
})

# --- validate_categories() ---------------------------------------------------

test_that("validate_categories returns no errors for valid categories", {
  valid_cats <- c("animation", "annotations", "geoms", "themes", "stats", "na")

  df <- data.frame(
    package_name = c("pkg1", "pkg2", "pkg3"),
    categories = c("animation", "geoms|stats", "na"),
    stringsAsFactors = FALSE
  )

  result <- validate_categories(df, valid_cats)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_categories detects invalid category", {
  valid_cats <- c("animation", "annotations", "geoms")

  df <- data.frame(
    package_name = c("pkg1", "pkg2"),
    categories = c("animation", "not_a_category"),
    stringsAsFactors = FALSE
  )

  result <- validate_categories(df, valid_cats)

  expect_false(result$valid)
  expect_true(any(grepl("not_a_category", result$errors)))
  expect_true(any(grepl("pkg2", result$errors)))
})

test_that("validate_categories detects invalid category in pipe-separated list", {
  valid_cats <- c("animation", "geoms", "stats")

  df <- data.frame(
    package_name = c("pkg1"),
    categories = c("geoms|fake_cat|stats"),
    stringsAsFactors = FALSE
  )

  result <- validate_categories(df, valid_cats)

  expect_false(result$valid)
  expect_true(any(grepl("fake_cat", result$errors)))
})

# --- validate_is_archived() --------------------------------------------------

test_that("validate_is_archived returns no errors for valid booleans", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork", "gganimate"),
    is_archived = c(TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  result <- validate_is_archived(df)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_is_archived detects missing column", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    stringsAsFactors = FALSE
  )

  result <- validate_is_archived(df)

  expect_false(result$valid)
  expect_length(result$errors, 1)
  expect_true(grepl("Missing required column: is_archived", result$errors[[1]]))
})

test_that("validate_is_archived detects NA values", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_archived = c(FALSE, NA),
    stringsAsFactors = FALSE
  )

  result <- validate_is_archived(df)

  expect_false(result$valid)
  expect_true(any(grepl("patchwork", result$errors)))
})

test_that("validate_is_archived detects non-logical string values", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_archived = c("TRUE", "no"),
    stringsAsFactors = FALSE
  )

  result <- validate_is_archived(df)

  expect_false(result$valid)
  # Both rows should be flagged — character column is never logical
  expect_length(result$errors, 2)
  expect_true(any(grepl("ggrepel", result$errors)))
  expect_true(any(grepl("patchwork", result$errors)))
})

test_that("validate_is_archived detects numeric values", {
  # Numeric 0/1 can appear if CSV is misread or manually edited
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    is_archived = c(0, 1),
    stringsAsFactors = FALSE
  )

  result <- validate_is_archived(df)

  expect_false(result$valid)
  expect_length(result$errors, 2)
})

# --- validate_curated_csv() --------------------------------------------------

test_that("validate_curated_csv passes for a valid data frame", {
  valid_cats <- c("animation", "annotations", "geoms", "stats", "themes", "na")

  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    categories = c("annotations", "geoms|stats"),
    is_featured = c(TRUE, FALSE),
    is_archived = c(FALSE, FALSE),
    website_url = c("https://example.com", NA),
    repo_url = c("https://github.com/a/b", "https://github.com/c/d"),
    date_added = c("2026-03-17", "2026-03-17"),
    notes = c("", ""),
    stringsAsFactors = FALSE
  )

  result <- validate_curated_csv(df, valid_cats)

  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_curated_csv collects errors from all checks", {
  valid_cats <- c("animation", "geoms")

  # Multiple problems: duplicate name, invalid category, bad format
  df <- data.frame(
    package_name = c("ggrepel", "ggrepel", "pkg3"),
    categories = c("animation", "geoms", "bad_cat|"),
    is_featured = c(TRUE, FALSE, FALSE),
    is_archived = c(FALSE, FALSE, FALSE),
    website_url = c(NA, NA, NA),
    repo_url = c(NA, NA, NA),
    date_added = c("2026-03-17", "2026-03-17", "2026-03-17"),
    notes = c("", "", ""),
    stringsAsFactors = FALSE
  )

  result <- validate_curated_csv(df, valid_cats)

  expect_false(result$valid)
  # Should have errors from multiple checks (duplicate + trailing pipe + invalid cat)
  expect_true(length(result$errors) >= 2)
})

test_that("validate_curated_csv catches missing is_archived column", {
  valid_cats <- c("animation", "geoms")

  # Valid data but missing is_archived column entirely
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    categories = c("animation", "geoms"),
    is_featured = c(TRUE, FALSE),
    website_url = c(NA, NA),
    repo_url = c(NA, NA),
    date_added = c("2026-03-17", "2026-03-17"),
    notes = c("", ""),
    stringsAsFactors = FALSE
  )

  result <- validate_curated_csv(df, valid_cats)

  expect_false(result$valid)
  expect_true(any(grepl("is_archived", result$errors)))
})

test_that("validate_curated_csv catches missing is_featured column", {
  valid_cats <- c("animation", "geoms")

  # Valid data but missing is_featured column entirely
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    categories = c("animation", "geoms"),
    is_archived = c(FALSE, FALSE),
    website_url = c(NA, NA),
    repo_url = c(NA, NA),
    date_added = c("2026-03-17", "2026-03-17"),
    notes = c("", ""),
    stringsAsFactors = FALSE
  )

  result <- validate_curated_csv(df, valid_cats)

  expect_false(result$valid)
  expect_true(any(grepl("is_featured", result$errors)))
})

# --- Integration test: real packages_curated.csv ----------------------------

test_that("packages_curated.csv has valid is_archived column", {
  csv_path <- file.path(testthat::test_path(), "..", "..", "data-raw", "packages_curated.csv")
  skip_if_not(file.exists(csv_path), "packages_curated.csv not found")

  df <- read.csv(csv_path, stringsAsFactors = FALSE)
  result <- validate_is_archived(df)

  expect_true(result$valid, info = paste(result$errors, collapse = "\n"))
  # Verify column is logical type

  expect_true(is.logical(df$is_archived))
  # Verify no NAs
  expect_false(any(is.na(df$is_archived)))
})

test_that("packages_curated.csv has valid is_featured column", {
  csv_path <- file.path(testthat::test_path(), "..", "..", "data-raw", "packages_curated.csv")
  skip_if_not(file.exists(csv_path), "packages_curated.csv not found")

  df <- read.csv(csv_path, stringsAsFactors = FALSE)
  result <- validate_is_featured(df)

  expect_true(result$valid, info = paste(result$errors, collapse = "\n"))
  # Verify column is logical type
  expect_true(is.logical(df$is_featured))
  # Verify no NAs
  expect_false(any(is.na(df$is_featured)))
})

test_that("packages_curated.csv passes all validation checks", {
  # Skip if the CSV doesn't exist (e.g., in CI before migration runs)
  csv_path <- file.path(testthat::test_path(), "..", "..", "data-raw", "packages_curated.csv")
  skip_if_not(file.exists(csv_path), "packages_curated.csv not found")

  cats_path <- file.path(testthat::test_path(), "..", "..", "data-raw", "categories.csv")
  skip_if_not(file.exists(cats_path), "categories.csv not found")

  df <- read.csv(csv_path, stringsAsFactors = FALSE)
  cats <- read.csv(cats_path, stringsAsFactors = FALSE)

  result <- validate_curated_csv(df, cats$category)

  expect_true(result$valid, info = paste(result$errors, collapse = "\n"))
})
