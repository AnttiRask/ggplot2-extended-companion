# =============================================================================
# test-fct_examples.R
#
# Tests for code example extraction and rendering functions.
#
# Part of Milestone 6: Code Examples Pipeline & Display
# =============================================================================

# --- check_license_allowed() ------------------------------------------------

test_that("check_license_allowed returns TRUE for MIT license", {
  allowlist <- data.frame(
    license_pattern = c("MIT", "GPL-3"),
    allowed = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  expect_true(check_license_allowed("MIT + file LICENSE", allowlist))
})

test_that("check_license_allowed returns TRUE for GPL-3 license", {
  allowlist <- data.frame(
    license_pattern = c("MIT", "GPL-3"),
    allowed = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  expect_true(check_license_allowed("GPL-3", allowlist))
})

test_that("check_license_allowed returns TRUE for GPL (>= 2)", {
  allowlist <- data.frame(
    license_pattern = c("MIT", "GPL (>= 2)"),
    allowed = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  expect_true(check_license_allowed("GPL (>= 2)", allowlist))
})

test_that("check_license_allowed returns FALSE for unknown license", {
  allowlist <- data.frame(
    license_pattern = c("MIT", "GPL-3"),
    allowed = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  expect_false(check_license_allowed("Proprietary", allowlist))
})

test_that("check_license_allowed returns FALSE for NA license", {
  allowlist <- data.frame(
    license_pattern = c("MIT"),
    allowed = c(TRUE),
    stringsAsFactors = FALSE
  )

  expect_false(check_license_allowed(NA_character_, allowlist))
})

test_that("check_license_allowed returns FALSE when pattern matches but allowed is FALSE", {
  allowlist <- data.frame(
    license_pattern = c("GPL-3", "MIT"),
    allowed = c(FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  # GPL-3 matches but is not allowed
  expect_false(check_license_allowed("GPL-3", allowlist))
  # MIT matches and is allowed
  expect_true(check_license_allowed("MIT + file LICENSE", allowlist))
})

# --- extract_example() ------------------------------------------------------

test_that("extract_example returns code string for installed package", {
  # ggplot2 should be available and have examples
  skip_if_not_installed("ggplot2")

  result <- extract_example("ggplot2")

  expect_type(result, "character")
  expect_true(nchar(result) > 0)
})

test_that("extract_example returns NA for non-existent package", {
  result <- extract_example("definitely_not_a_real_package_xyz")

  expect_true(is.na(result))
})

# --- render_example() -------------------------------------------------------

test_that("render_example returns a result list with expected fields", {
  # Use a simple ggplot2 example we know works
  skip_if_not_installed("ggplot2")

  code <- "library(ggplot2); ggplot(mtcars, aes(wt, mpg)) + geom_point()"
  tmp_dir <- withr::local_tempdir()
  png_path <- file.path(tmp_dir, "test_pkg.png")

  result <- render_example("test_pkg", code, png_path, timeout = 30)

  expect_type(result, "list")
  expect_true("package_name" %in% names(result))
  expect_true("example_code" %in% names(result))
  expect_true("example_success" %in% names(result))
  expect_true("example_image" %in% names(result))
})

test_that("render_example succeeds for valid ggplot2 code", {
  skip_if_not_installed("ggplot2")

  code <- "library(ggplot2); ggplot(mtcars, aes(wt, mpg)) + geom_point()"
  tmp_dir <- withr::local_tempdir()
  png_path <- file.path(tmp_dir, "test_pkg.png")

  result <- render_example("test_pkg", code, png_path, timeout = 30)

  expect_true(result$example_success)
  expect_true(file.exists(png_path))
})

test_that("render_example handles failing code gracefully", {
  code <- "stop('this will fail')"
  tmp_dir <- withr::local_tempdir()
  png_path <- file.path(tmp_dir, "fail_pkg.png")

  result <- render_example("fail_pkg", code, png_path, timeout = 10)

  expect_false(result$example_success)
  expect_equal(result$example_code, code)
})

# --- install_package_temp() --------------------------------------------------

test_that("install_package_temp installs a small CRAN package into temp lib", {
  # Use a small, dependency-light CRAN package for fast install
  tmp_lib <- withr::local_tempdir()

  result <- install_package_temp("fortunes", lib_path = tmp_lib)

  expect_true(result)
  expect_true("fortunes" %in% list.files(tmp_lib))
})

test_that("install_package_temp returns FALSE for non-existent package", {
  tmp_lib <- withr::local_tempdir()

  result <- install_package_temp("definitely_not_a_real_package_xyz_999", lib_path = tmp_lib)

  expect_false(result)
})

test_that("install_package_temp returns FALSE for NA package name", {
  tmp_lib <- withr::local_tempdir()

  result <- install_package_temp(NA_character_, lib_path = tmp_lib)

  expect_false(result)
})

test_that("install_package_temp returns FALSE for empty string", {
  tmp_lib <- withr::local_tempdir()

  result <- install_package_temp("", lib_path = tmp_lib)

  expect_false(result)
})

# --- render_examples() with package installation -----------------------------

test_that("render_examples installs packages into temp lib before extraction", {
  # Create minimal test data with a small, real CRAN package
  packages <- tibble::tibble(
    package_name = "fortunes",
    license = "GPL-2 | GPL-3"
  )

  # Create a temp allowlist that allows GPL
  tmp_dir <- withr::local_tempdir()
  allowlist_path <- file.path(tmp_dir, "allowlist.csv")
  write.csv(
    data.frame(license_pattern = "GPL", allowed = TRUE, stringsAsFactors = FALSE),
    allowlist_path,
    row.names = FALSE
  )

  output_dir <- file.path(tmp_dir, "examples")

  result <- render_examples(
    packages,
    allowlist_path = allowlist_path,
    output_dir = output_dir
  )

  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "fortunes")
  expect_true(result$license_allowed)
  # Key assertion: example_code should not be NA — the package should have
  # been installed and its examples extracted (fortunes has examples)
  expect_false(is.na(result$example_code))
  # fortunes examples don't produce ggplot2 plots, so render should fail gracefully
  expect_false(result$example_success)
})

# --- build_example_card() ---------------------------------------------------

test_that("build_example_card shows code and image for successful example", {
  example <- data.frame(
    package_name = "ggrepel",
    example_code = "library(ggrepel)\nggplot(mtcars) + geom_point()",
    example_image = "ggrepel.png",
    example_success = TRUE,
    example_rendered_at = "2026-03-17T06:00:00Z",
    license_allowed = TRUE,
    stringsAsFactors = FALSE
  )

  result <- build_example_card(example)
  html <- as.character(result)

  expect_true(grepl("ggrepel", html))
  expect_true(grepl("geom_point", html))
  expect_true(grepl("ggrepel.png", html))
})

test_that("build_example_card shows fallback for failed render", {
  example <- data.frame(
    package_name = "test_pkg",
    example_code = "some_code()",
    example_image = NA_character_,
    example_success = FALSE,
    example_rendered_at = "2026-03-17T06:00:00Z",
    license_allowed = TRUE,
    stringsAsFactors = FALSE
  )

  result <- build_example_card(example)
  html <- as.character(result)

  expect_true(grepl("some_code", html))
  expect_true(grepl("Output preview not available", html))
})

test_that("build_example_card shows license message when not allowed", {
  example <- data.frame(
    package_name = "test_pkg",
    example_code = NA_character_,
    example_image = NA_character_,
    example_success = FALSE,
    example_rendered_at = NA_character_,
    license_allowed = FALSE,
    stringsAsFactors = FALSE
  )

  result <- build_example_card(example)
  html <- as.character(result)

  expect_true(grepl("license could not be verified", html))
  expect_false(grepl("<code", html))
})

test_that("build_example_card returns NULL when no example data", {
  result <- build_example_card(NULL)

  expect_null(result)
})
