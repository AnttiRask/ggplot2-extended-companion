# =============================================================================
# test-fct_json.R
#
# Tests for JSON export function matching SPEC §8 structure.
#
# Part of Milestone 8: AI Agent Compatibility & JSON Export
# =============================================================================

test_that("export_json produces valid JSON with correct top-level structure", {
  packages <- tibble::tibble(
    package_name = c("ggrepel", "patchwork"),
    description = c("Text labels", "Combine plots"),
    categories = c("annotations", "arranging_plots"),
    is_essential = c(TRUE, FALSE),
    on_cran = c(TRUE, TRUE),
    license = c("GPL-3", "MIT"),
    cran_version = c("0.9.6", "1.3.0"),
    cran_published = as.Date(c("2024-09-07", "2025-08-25")),
    github_updated = as.Date(c("2024-12-01", "2025-08-25")),
    cran_url = c("https://cran.r-project.org/package=ggrepel", "https://cran.r-project.org/package=patchwork"),
    website_url = c("https://ggrepel.slowkow.com/", "https://patchwork.data-imaginist.com/"),
    repo_url = c("https://github.com/slowkow/ggrepel", "https://github.com/thomasp85/patchwork")
  )

  downloads <- tibble::tibble(
    package_name = c("ggrepel", "patchwork"),
    downloads_30d = c(20000L, 15000L),
    downloads_all = c(1500000L, 900000L)
  )

  tmp_file <- withr::local_tempfile(fileext = ".json")
  export_json(packages, downloads, tmp_file)

  expect_true(file.exists(tmp_file))

  # Parse the JSON
  result <- jsonlite::fromJSON(tmp_file)

  # Top-level fields
  expect_true("generated_at" %in% names(result))
  expect_true("package_count" %in% names(result))
  expect_true("packages" %in% names(result))
  expect_equal(result$package_count, 2)
})

test_that("export_json packages have correct field names", {
  packages <- tibble::tibble(
    package_name = "ggrepel",
    description = "Text labels",
    categories = "annotations",
    is_essential = TRUE,
    on_cran = TRUE,
    license = "GPL-3",
    cran_version = "0.9.6",
    cran_published = as.Date("2024-09-07"),
    github_updated = as.Date("2024-12-01"),
    cran_url = "https://cran.r-project.org/package=ggrepel",
    website_url = "https://ggrepel.slowkow.com/",
    repo_url = "https://github.com/slowkow/ggrepel"
  )

  downloads <- tibble::tibble(
    package_name = "ggrepel",
    downloads_30d = 20000L,
    downloads_all = 1500000L
  )

  tmp_file <- withr::local_tempfile(fileext = ".json")
  export_json(packages, downloads, tmp_file)

  result <- jsonlite::fromJSON(tmp_file)
  pkg <- result$packages[1, ]

  # Spec §8 field names
  expect_equal(pkg$name, "ggrepel")
  expect_equal(pkg$description, "Text labels")
  expect_true(pkg$is_essential)
  expect_true(pkg$on_cran)
  expect_equal(pkg$downloads_30d, 20000)
  expect_equal(pkg$downloads_all, 1500000)
})

test_that("export_json converts pipe-separated categories to arrays", {
  packages <- tibble::tibble(
    package_name = "gganimate",
    description = "Animate",
    categories = "animation|interactive_plots",
    is_essential = FALSE,
    on_cran = TRUE,
    license = "MIT",
    cran_version = "1.0.9",
    cran_published = as.Date("2024-01-01"),
    github_updated = as.Date("2024-06-01"),
    cran_url = NA_character_,
    website_url = NA_character_,
    repo_url = "https://github.com/thomasp85/gganimate"
  )

  downloads <- tibble::tibble(
    package_name = "gganimate",
    downloads_30d = 5000L,
    downloads_all = 300000L
  )

  tmp_file <- withr::local_tempfile(fileext = ".json")
  export_json(packages, downloads, tmp_file)

  result <- jsonlite::fromJSON(tmp_file)
  cats <- result$packages$categories[[1]]

  expect_type(cats, "character")
  expect_equal(length(cats), 2)
  expect_true("animation" %in% cats)
  expect_true("interactive_plots" %in% cats)
})

test_that("export_json handles NA values correctly", {
  packages <- tibble::tibble(
    package_name = "bbplot",
    description = NA_character_,
    categories = "themes",
    is_essential = FALSE,
    on_cran = FALSE,
    license = NA_character_,
    cran_version = NA_character_,
    cran_published = as.Date(NA),
    github_updated = as.Date(NA),
    cran_url = NA_character_,
    website_url = NA_character_,
    repo_url = NA_character_
  )

  downloads <- tibble::tibble(
    package_name = "bbplot",
    downloads_30d = NA_integer_,
    downloads_all = NA_integer_
  )

  tmp_file <- withr::local_tempfile(fileext = ".json")
  export_json(packages, downloads, tmp_file)

  # Should not error — JSON should be valid
  result <- jsonlite::fromJSON(tmp_file)
  expect_equal(result$package_count, 1)
})
