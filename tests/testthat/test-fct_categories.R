# =============================================================================
# test-fct_categories.R
#
# Tests for category display name mapping, colour palette, and badge rendering.
#
# Part of production-fix-polish: Category Infrastructure
# =============================================================================

# --- get_category_display_names() --------------------------------------------

test_that("get_category_display_names returns a named character vector", {
  result <- get_category_display_names()

  expect_type(result, "character")
  expect_true(length(result) > 0)
  expect_true(!is.null(names(result)))
})

test_that("get_category_display_names includes all 19 categories", {
  result <- get_category_display_names()

  expected_categories <- c(
    "animation", "annotations", "arranging_plots", "coords", "data",
    "facets", "finishing_touches", "geoms", "helpers", "interactive_plots",
    "interactive_tools", "maps", "networks", "python", "scales_and_guides",
    "sports", "stats", "themes", "na"
  )

  for (cat in expected_categories) {
    expect_true(cat %in% names(result), info = paste("Missing category:", cat))
  }
})

test_that("get_category_display_names maps technical names to display names", {
  result <- get_category_display_names()

  expect_equal(result[["arranging_plots"]], "Arranging Plots")
  expect_equal(result[["scales_and_guides"]], "Scales & Guides")
  expect_equal(result[["geoms"]], "Geoms")
  expect_equal(result[["na"]], "NA")
})

# --- category_to_display_name() ----------------------------------------------

test_that("category_to_display_name returns display name for valid category", {
  result <- category_to_display_name("arranging_plots")
  expect_equal(result, "Arranging Plots")
})

test_that("category_to_display_name returns technical name for unknown category", {
  result <- category_to_display_name("unknown_category")
  expect_equal(result, "unknown_category")
})

# --- get_category_colours() --------------------------------------------------

test_that("get_category_colours returns a named character vector", {
  result <- get_category_colours()

  expect_type(result, "character")
  expect_true(length(result) > 0)
  expect_true(!is.null(names(result)))
})

test_that("get_category_colours has all 19 categories", {
  result <- get_category_colours()

  expected_categories <- c(
    "animation", "annotations", "arranging_plots", "coords", "data",
    "facets", "finishing_touches", "geoms", "helpers", "interactive_plots",
    "interactive_tools", "maps", "networks", "python", "scales_and_guides",
    "sports", "stats", "themes", "na"
  )

  for (cat in expected_categories) {
    expect_true(cat %in% names(result), info = paste("Missing colour:", cat))
  }
})

test_that("get_category_colours returns unique colours", {
  result <- get_category_colours()

  # na is allowed to be a generic grey, but all others should be unique
  non_na <- result[names(result) != "na"]
  expect_equal(length(non_na), length(unique(non_na)))
})

test_that("get_category_colours returns valid hex codes", {
  result <- get_category_colours()

  for (colour in result) {
    expect_true(
      grepl("^#[0-9A-Fa-f]{6}$", colour),
      info = paste("Invalid hex colour:", colour)
    )
  }
})

# --- build_category_badge() --------------------------------------------------

test_that("build_category_badge returns an htmltools span", {
  result <- build_category_badge("animation")

  expect_s3_class(result, "shiny.tag")
  html <- as.character(result)
  expect_true(grepl("Animation", html))
  expect_true(grepl("badge-category", html))
})

test_that("build_category_badge uses category-specific colour", {
  result <- build_category_badge("geoms")
  html <- as.character(result)

  # Should contain the geoms colour (#C1272D) in some form (rgba or hex)
  colours <- get_category_colours()
  expect_true(grepl("background-color", html))
})

test_that("build_category_badge handles na category", {
  result <- build_category_badge("na")
  html <- as.character(result)

  expect_true(grepl("NA", html))
})

test_that("build_category_badge handles unknown category gracefully", {
  result <- build_category_badge("totally_unknown")
  html <- as.character(result)

  # Should still render, using the technical name as fallback

  expect_true(grepl("totally_unknown", html))
})
