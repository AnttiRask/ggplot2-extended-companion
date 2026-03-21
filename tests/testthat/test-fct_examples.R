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

# --- prioritize_rd_files() ---------------------------------------------------

test_that("prioritize_rd_files puts primary Rd first", {
  rd_files <- c("pkg/man/aes.Rd", "pkg/man/pkg.Rd", "pkg/man/geom_point.Rd")
  result <- prioritize_rd_files(rd_files, "pkg")

  expect_equal(result[1], "pkg/man/pkg.Rd")
})

test_that("prioritize_rd_files puts package-name-containing files before generic ones", {
  rd_files <- c(
    "animint2/man/lims.Rd",
    "animint2/man/geom_point.Rd",
    "animint2/man/animint2dir.Rd",
    "animint2/man/theme_animint.Rd",
    "animint2/man/aes.Rd"
  )
  result <- prioritize_rd_files(rd_files, "animint2")

  # Files containing "animint" in the basename should come first
  basenames <- basename(result)
  animint_positions <- which(grepl("animint", basenames, ignore.case = TRUE))
  other_positions <- which(!grepl("animint", basenames, ignore.case = TRUE))

  # All animint-named files should appear before all generic files
  if (length(animint_positions) > 0 && length(other_positions) > 0) {
    expect_true(max(animint_positions) < min(other_positions))
  }
})

test_that("prioritize_rd_files deprioritizes common ggplot2 re-export names", {

  rd_files <- c(
    "mypkg/man/geom_point.Rd",
    "mypkg/man/aes.Rd",
    "mypkg/man/mypkg_special.Rd",
    "mypkg/man/scale_colour_continuous.Rd",
    "mypkg/man/some_unique_function.Rd"
  )
  result <- prioritize_rd_files(rd_files, "mypkg")

  basenames <- basename(result)
  # mypkg_special should be near the top (contains package name)
  pkg_pos <- which(basenames == "mypkg_special.Rd")
  # Common ggplot2 names should be near the bottom
  geom_pos <- which(basenames == "geom_point.Rd")

  expect_true(pkg_pos < geom_pos)
})

test_that("prioritize_rd_files handles empty input", {
  result <- prioritize_rd_files(character(0), "pkg")
  expect_length(result, 0)
})

test_that("prioritize_rd_files handles single file", {
  rd_files <- c("pkg/man/foo.Rd")
  result <- prioritize_rd_files(rd_files, "pkg")
  expect_equal(result, rd_files)
})

# --- clean_rd2ex_output() ----------------------------------------------------

test_that("clean_rd2ex_output strips header lines", {
  lines <- c("### Name: test", "### Title: Test", "", "### ** Examples",
             "", "  x <- 1 + 1", "  print(x)")
  result <- clean_rd2ex_output(lines)
  expect_false(any(grepl("^###", result)))
  expect_true(any(grepl("x <- 1", result)))
})

test_that("clean_rd2ex_output removes dontrun blocks", {
  lines <- c("  x <- 1", "  ## Not run: ", "##D   slow_fn()",
             "## End(Not run)", "  print(x)")
  result <- clean_rd2ex_output(lines)
  code <- trimws(paste(result, collapse = "\n"))
  expect_false(grepl("slow_fn", code))
  expect_true(grepl("print\\(x\\)", code))
})

test_that("clean_rd2ex_output removes dontshow blocks", {
  lines <- c("  x <- 1", "  ## Don't show: ", "    stopifnot(TRUE)",
             "  ", "## End(Don't show)", "  print(x)")
  result <- clean_rd2ex_output(lines)
  code <- trimws(paste(result, collapse = "\n"))
  expect_false(grepl("stopifnot", code))
  expect_true(grepl("print\\(x\\)", code))
})

test_that("clean_rd2ex_output preserves normal code and donttest code", {
  lines <- c("### Name: test", "### ** Examples", "",
             "  library(ggplot2)", "  ## No test: ",
             "    ggplot(mtcars) + geom_point()", "  ",
             "## End(No test)", "  print('done')")
  result <- clean_rd2ex_output(lines)
  code <- trimws(paste(result, collapse = "\n"))
  # donttest code should be kept (it's runnable, just slow)
  expect_true(grepl("geom_point", code))
  expect_true(grepl("print", code))
})

test_that("clean_rd2ex_output handles empty input", {
  result <- clean_rd2ex_output(character(0))
  expect_length(result, 0)
})

# --- extract_example_from_cran() ---------------------------------------------

test_that("extract_example_from_cran downloads tarball and extracts example code", {
  tmp_dir <- withr::local_tempdir()

  # fortunes is small and has examples in its Rd files
  result <- extract_example_from_cran("fortunes", download_dir = tmp_dir)

  expect_type(result, "character")
  expect_false(is.na(result))
  expect_true(nchar(result) > 0)
})

test_that("extract_example_from_cran returns NA for non-existent package", {
  tmp_dir <- withr::local_tempdir()

  result <- extract_example_from_cran("definitely_not_a_real_package_xyz_999",
                                       download_dir = tmp_dir)

  expect_true(is.na(result))
})

test_that("extract_example_from_cran returns NA for NA package name", {
  tmp_dir <- withr::local_tempdir()

  result <- extract_example_from_cran(NA_character_, download_dir = tmp_dir)

  expect_true(is.na(result))
})

test_that("extract_example_from_cran returns NA for empty string", {
  tmp_dir <- withr::local_tempdir()

  result <- extract_example_from_cran("", download_dir = tmp_dir)

  expect_true(is.na(result))
})

# --- render_examples() with tarball extraction --------------------------------

test_that("render_examples extracts examples from CRAN tarballs", {
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
  # Key assertion: example_code should not be NA — the tarball should have
  # been downloaded and Rd examples extracted
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
