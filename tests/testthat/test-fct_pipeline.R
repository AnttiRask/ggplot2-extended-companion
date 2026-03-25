# =============================================================================
# test-fct_pipeline.R
#
# Tests for data pipeline functions in R/fct_pipeline.R.
# Uses mock API responses from fixtures/ to test CRAN, cranlogs, and GitHub
# data fetching without making real API calls.
#
# Part of Milestone 2: Data Pipeline (Core)
# =============================================================================

# --- read_curated_csv() ------------------------------------------------------

test_that("read_curated_csv returns a tibble with expected columns", {
  csv_path <- file.path(test_path(), "..", "..", "data-raw", "packages_curated.csv")
  skip_if_not(file.exists(csv_path), "packages_curated.csv not found")

  result <- read_curated_csv(csv_path)

  expect_true(tibble::is_tibble(result))
  expect_true(all(
    c("package_name", "categories", "is_essential", "website_url", "repo_url", "date_added")
    %in% names(result)
  ))
  # Use lower bound instead of exact count — exact count validated by M1 integration test
  expect_gte(nrow(result), 400)
})

# --- fetch_cran_metadata_single() -------------------------------------------

test_that("fetch_cran_metadata_single returns correct fields for CRAN package", {
  # Mock pkgsearch::cran_package by loading fixture
  mock_response <- readRDS(test_path("fixtures", "cran_response_ggrepel.rds"))

  # Use mockr or manual injection — here we test the parser directly
  result <- parse_cran_response("ggrepel", mock_response)

  expect_equal(result$package_name, "ggrepel")
  expect_equal(result$on_cran, TRUE)
  expect_equal(result$cran_version, "0.9.6")
  expect_equal(result$license, "GPL-3 | file LICENSE")
  expect_true(!is.na(result$description))
  expect_true(!is.na(result$maintainer))
  expect_true(!is.na(result$cran_published))
})

test_that("parse_cran_response splits Title and Description into separate fields", {
  mock_response <- readRDS(test_path("fixtures", "cran_response_ggrepel.rds"))

  result <- parse_cran_response("ggrepel", mock_response)

  # title comes from response$Title, description from response$Description
  expect_true("title" %in% names(result))
  expect_true("description" %in% names(result))
  expect_equal(result$title, mock_response$Title)
  expect_equal(result$description, mock_response$Description)
})

test_that("parse_cran_response detects has_vignettes from response", {
  mock_response <- readRDS(test_path("fixtures", "cran_response_ggrepel.rds"))

  result <- parse_cran_response("ggrepel", mock_response)

  expect_true("has_vignettes" %in% names(result))
  expect_type(result$has_vignettes, "logical")
})

test_that("parse_cran_response returns NA fields for NULL response", {
  result <- parse_cran_response("fake_package", NULL)

  expect_equal(result$package_name, "fake_package")
  expect_equal(result$on_cran, FALSE)
  expect_true(is.na(result$cran_version))
  expect_true(is.na(result$license))
  expect_true(is.na(result$title))
  expect_true(is.na(result$description))
  expect_equal(result$has_vignettes, FALSE)
})

# --- parse_github_response() ------------------------------------------------

test_that("parse_github_response extracts update date", {
  mock_response <- readRDS(test_path("fixtures", "github_response_ggrepel.rds"))

  result <- parse_github_response("ggrepel", mock_response)

  expect_equal(result$package_name, "ggrepel")
  expect_true(!is.na(result$github_updated))
  expect_s3_class(result$github_updated, "Date")
})

test_that("parse_github_response returns NA for NULL response", {
  result <- parse_github_response("fake_package", NULL)

  expect_equal(result$package_name, "fake_package")
  expect_true(is.na(result$github_updated))
})

# --- parse_github_url() -----------------------------------------------------

test_that("parse_github_url extracts owner and repo from GitHub URLs", {
  result <- parse_github_url("https://github.com/slowkow/ggrepel")
  expect_equal(result$owner, "slowkow")
  expect_equal(result$repo, "ggrepel")
})

test_that("parse_github_url handles trailing slash", {
  result <- parse_github_url("https://github.com/slowkow/ggrepel/")
  expect_equal(result$owner, "slowkow")
  expect_equal(result$repo, "ggrepel")
})

test_that("parse_github_url returns NULL for non-GitHub URLs", {
  result <- parse_github_url("https://gitlab.com/some/repo")
  expect_null(result)
})

test_that("parse_github_url returns NULL for NA", {
  result <- parse_github_url(NA_character_)
  expect_null(result)
})

# --- aggregate_downloads() --------------------------------------------------

test_that("aggregate_downloads computes correct windows", {
  mock_data <- readRDS(test_path("fixtures", "cranlogs_response_ggrepel.rds"))

  result <- aggregate_downloads("ggrepel", mock_data)

  expect_equal(result$package_name, "ggrepel")
  expect_true(is.integer(result$downloads_7d) || is.numeric(result$downloads_7d))
  expect_true(is.integer(result$downloads_30d) || is.numeric(result$downloads_30d))
  expect_true(is.integer(result$downloads_365d) || is.numeric(result$downloads_365d))
  expect_true(is.integer(result$downloads_all) || is.numeric(result$downloads_all))
  # All-time should be >= 365d >= 30d >= 7d
  expect_true(result$downloads_all >= result$downloads_365d)
  expect_true(result$downloads_365d >= result$downloads_30d)
  expect_true(result$downloads_30d >= result$downloads_7d)
})

test_that("aggregate_downloads returns NA for empty data", {
  empty_data <- data.frame(
    date = as.Date(character(0)),
    count = integer(0),
    package = character(0),
    stringsAsFactors = FALSE
  )

  result <- aggregate_downloads("fake_package", empty_data)

  expect_equal(result$package_name, "fake_package")
  expect_true(is.na(result$downloads_7d))
  expect_true(is.na(result$downloads_all))
})

# --- parse_github_description_response() ------------------------------------

test_that("parse_github_description_response extracts fields from mock API response", {
  mock_response <- readRDS(test_path("fixtures", "github_description_response.rds"))

  result <- parse_github_description_response("fakepkg", mock_response)

  expect_equal(result$package_name, "fakepkg")
  expect_equal(result$github_title, "A Fake Package for Testing")
  expect_equal(result$github_version, "0.2.1")
  expect_equal(result$github_license, "MIT + file LICENSE")
  expect_true(!is.na(result$github_description))
  expect_true(!is.na(result$github_maintainer))
})

test_that("parse_github_description_response returns NA row for NULL response", {
  result <- parse_github_description_response("missing_pkg", NULL)

  expect_equal(result$package_name, "missing_pkg")
  expect_true(is.na(result$github_title))
  expect_true(is.na(result$github_version))
  expect_true(is.na(result$github_license))
  expect_true(is.na(result$github_description))
  expect_true(is.na(result$github_maintainer))
})

# --- fetch_github_descriptions() (unit-level) --------------------------------

test_that("fetch_github_descriptions returns NA for CRAN packages", {
  tmp_cache <- withr::local_tempfile(fileext = ".rds")

  # Mock: 2 packages, first is on CRAN, second is not but has no GitHub URL
  result <- fetch_github_descriptions(
    package_names = c("ggrepel", "cran_only"),
    repo_urls = c("https://github.com/slowkow/ggrepel", NA),
    on_cran = c(TRUE, TRUE),
    cache_path = tmp_cache,
    .fetch_fn = function(owner, repo) stop("Should not be called")
  )

  expect_equal(nrow(result), 2)
  expect_true(all(is.na(result$github_title)))
  expect_true(all(is.na(result$github_version)))
  # Cache should be written
  expect_true(file.exists(tmp_cache))
})

test_that("fetch_github_descriptions fetches for non-CRAN GitHub packages", {
  mock_response <- readRDS(test_path("fixtures", "github_description_response.rds"))
  tmp_cache <- withr::local_tempfile(fileext = ".rds")

  # Mock fetch function returns our fixture
  mock_fetch <- function(owner, repo) mock_response

  result <- fetch_github_descriptions(
    package_names = c("ggrepel", "fakepkg"),
    repo_urls = c("https://github.com/slowkow/ggrepel", "https://github.com/user/fakepkg"),
    on_cran = c(TRUE, FALSE),
    cache_path = tmp_cache,
    .fetch_fn = mock_fetch
  )

  expect_equal(nrow(result), 2)
  # CRAN package: all NA
  expect_true(is.na(result$github_title[result$package_name == "ggrepel"]))
  # Non-CRAN package: parsed from mock
  expect_equal(result$github_title[result$package_name == "fakepkg"], "A Fake Package for Testing")
  expect_equal(result$github_version[result$package_name == "fakepkg"], "0.2.1")
})

test_that("fetch_github_descriptions handles API errors gracefully", {
  tmp_cache <- withr::local_tempfile(fileext = ".rds")

  # Mock fetch function that always errors
  mock_fetch <- function(owner, repo) stop("404 Not Found")

  result <- fetch_github_descriptions(
    package_names = c("broken_pkg"),
    repo_urls = c("https://github.com/user/broken_pkg"),
    on_cran = c(FALSE),
    cache_path = tmp_cache,
    .fetch_fn = mock_fetch
  )

  expect_equal(nrow(result), 1)
  expect_true(is.na(result$github_title))
  expect_true(is.na(result$github_version))
})

# --- merge_package_data() ---------------------------------------------------

test_that("merge_package_data joins all data sources", {
  curated <- tibble::tibble(
    package_name = c("ggrepel", "bbplot"),
    categories = c("annotations", "themes"),
    is_essential = c(TRUE, FALSE),
    website_url = c("https://ggrepel.slowkow.com/", NA),
    repo_url = c("https://github.com/slowkow/ggrepel", NA),
    date_added = c("2026-03-17", "2026-03-17")
  )

  cran_meta <- tibble::tibble(
    package_name = c("ggrepel", "bbplot"),
    title = c("Text labels", "BBC style"),
    description = c("Repel overlapping text", "BBC plot theme"),
    maintainer = c("Kamil", NA),
    license = c("GPL-3", NA),
    cran_version = c("0.9.6", NA),
    cran_published = as.Date(c("2024-09-07", NA)),
    on_cran = c(TRUE, FALSE),
    has_vignettes = c(TRUE, FALSE)
  )

  github_meta <- tibble::tibble(
    package_name = c("ggrepel", "bbplot"),
    github_updated = as.Date(c("2024-12-01", NA))
  )

  urls <- tibble::tibble(
    package_name = c("ggrepel", "bbplot"),
    cran_url = c("https://cran.r-project.org/package=ggrepel", NA),
    manual_url = c("https://cran.r-project.org/web/packages/ggrepel/ggrepel.pdf", NA),
    vignettes_url = c("https://cran.r-project.org/web/packages/ggrepel/vignettes/", NA)
  )

  # merge_package_data no longer takes downloads (SPEC §3.6 separation)
  result <- merge_package_data(curated, cran_meta, github_meta, urls)

  expect_true(tibble::is_tibble(result))
  expect_equal(nrow(result), 2)

  # Check all expected columns are present (no download columns)
  expected_cols <- c(
    "package_name", "title", "description", "maintainer", "categories",
    "is_essential", "on_cran", "has_vignettes", "license", "cran_version",
    "cran_published", "github_updated", "cran_url", "website_url", "repo_url",
    "manual_url", "vignettes_url", "date_added", "last_checked"
  )
  expect_true(all(expected_cols %in% names(result)))

  # Download columns should NOT be in the merged result
  expect_false("downloads_30d" %in% names(result))

  # Check ggrepel has full data
  ggrepel <- result[result$package_name == "ggrepel", ]
  expect_equal(ggrepel$on_cran, TRUE)
  expect_equal(ggrepel$cran_version, "0.9.6")

  # Check bbplot has NAs for missing data
  bbplot <- result[result$package_name == "bbplot", ]
  expect_equal(bbplot$on_cran, FALSE)
  expect_true(is.na(bbplot$cran_version))
})

# --- fix_non_cran_downloads() -----------------------------------------------

test_that("fix_non_cran_downloads sets NA for non-CRAN packages", {
  downloads <- tibble::tibble(
    package_name = c("ggrepel", "bbplot", "patchwork"),
    downloads_7d = c(5000L, 0L, 3000L),
    downloads_30d = c(20000L, 0L, 12000L),
    downloads_365d = c(200000L, 0L, 100000L),
    downloads_all = c(1500000L, 0L, 800000L)
  )

  cran_meta <- tibble::tibble(
    package_name = c("ggrepel", "bbplot", "patchwork"),
    on_cran = c(TRUE, FALSE, TRUE)
  )

  result <- fix_non_cran_downloads(downloads, cran_meta)

  # CRAN packages keep their counts
  expect_equal(result$downloads_all[result$package_name == "ggrepel"], 1500000L)
  expect_equal(result$downloads_all[result$package_name == "patchwork"], 800000L)

  # Non-CRAN packages get NA
  expect_true(is.na(result$downloads_all[result$package_name == "bbplot"]))
  expect_true(is.na(result$downloads_7d[result$package_name == "bbplot"]))

  # on_cran column should not be in the result
  expect_false("on_cran" %in% names(result))
})

# --- write_parquet_output() --------------------------------------------------

test_that("write_parquet_output writes readable Parquet file", {
  df <- tibble::tibble(
    package_name = c("test_pkg"),
    value = c(42L)
  )

  tmp_file <- withr::local_tempfile(fileext = ".parquet")
  write_parquet_output(df, tmp_file)

  expect_true(file.exists(tmp_file))

  # Read it back
  result <- arrow::read_parquet(tmp_file)
  expect_equal(nrow(result), 1)
  expect_equal(result$package_name, "test_pkg")
  expect_equal(result$value, 42L)
})

# --- write_metadata() -------------------------------------------------------

test_that("write_metadata produces valid Parquet with expected columns", {
  tmp_file <- withr::local_tempfile(fileext = ".parquet")

  write_metadata(
    output_path = tmp_file,
    cran_status = "success",
    downloads_status = "success",
    github_status = "success"
  )

  expect_true(file.exists(tmp_file))

  result <- arrow::read_parquet(tmp_file)
  expect_true(all(c("source", "last_run", "status") %in% names(result)))
  expect_true(nrow(result) >= 3)
})

# --- targets pipeline integration ---------------------------------------------

test_that("weekly pipeline includes code_examples -> pipeline_metadata dependency", {
  # Temporarily set RENDER_EXAMPLES to simulate weekly mode
  withr::local_envvar(RENDER_EXAMPLES = "true")

  # tar_network() needs to find _targets.R — run from project root
  project_root <- file.path(test_path(), "..", "..")
  skip_if_not(file.exists(file.path(project_root, "_targets.R")), "_targets.R not found")
  withr::local_dir(project_root)

  # Use tar_network to inspect the DAG edges in weekly mode
  net <- targets::tar_network()
  edges <- net$edges

  # code_examples should feed into both examples_parquet and pipeline_metadata
  expect_true(
    any(edges$from == "code_examples" & edges$to == "examples_parquet"),
    info = "code_examples -> examples_parquet edge missing"
  )
  expect_true(
    any(edges$from == "code_examples" & edges$to == "pipeline_metadata"),
    info = "code_examples -> pipeline_metadata edge missing"
  )
})

test_that("daily pipeline excludes code_examples and examples_parquet targets", {
  withr::local_envvar(RENDER_EXAMPLES = NA)

  project_root <- file.path(test_path(), "..", "..")
  skip_if_not(file.exists(file.path(project_root, "_targets.R")), "_targets.R not found")
  withr::local_dir(project_root)

  m <- targets::tar_manifest()

  expect_false("code_examples" %in% m$name)
  expect_false("examples_parquet" %in% m$name)
})

# --- should_render_examples() ------------------------------------------------

test_that("should_render_examples returns TRUE when RENDER_EXAMPLES is 'true'", {
  withr::local_envvar(RENDER_EXAMPLES = "true")

  expect_true(should_render_examples())
})

test_that("should_render_examples returns TRUE when RENDER_EXAMPLES is 'TRUE'", {
  withr::local_envvar(RENDER_EXAMPLES = "TRUE")

  expect_true(should_render_examples())
})

test_that("should_render_examples returns FALSE when RENDER_EXAMPLES is unset", {
  withr::local_envvar(RENDER_EXAMPLES = NA)

  expect_false(should_render_examples())
})

test_that("should_render_examples returns FALSE when RENDER_EXAMPLES is empty", {
  withr::local_envvar(RENDER_EXAMPLES = "")

  expect_false(should_render_examples())
})

test_that("should_render_examples returns FALSE when RENDER_EXAMPLES is 'false'", {
  withr::local_envvar(RENDER_EXAMPLES = "false")

  expect_false(should_render_examples())
})

test_that("should_render_examples returns FALSE for 'yes' (strict contract)", {
  # Only "true" (case-insensitive) is accepted, not "yes", "1", etc.
  withr::local_envvar(RENDER_EXAMPLES = "yes")

  expect_false(should_render_examples())
})

test_that("should_render_examples returns FALSE for '1' (strict contract)", {
  withr::local_envvar(RENDER_EXAMPLES = "1")

  expect_false(should_render_examples())
})

# --- write_metadata with examples_status -------------------------------------

test_that("write_metadata includes examples row with correct status value", {
  tmp_file <- withr::local_tempfile(fileext = ".parquet")

  write_metadata(
    output_path = tmp_file,
    cran_status = "success",
    downloads_status = "success",
    github_status = "success",
    examples_status = "success"
  )

  result <- arrow::read_parquet(tmp_file)
  expect_equal(nrow(result), 4)
  expect_true("examples" %in% result$source)

  # Assert actual status values, not just row count
  examples_row <- result[result$source == "examples", ]
  expect_equal(examples_row$status, "success")
  expect_equal(result$status[result$source == "cran"], "success")
})

test_that("write_metadata records failed examples status correctly", {
  tmp_file <- withr::local_tempfile(fileext = ".parquet")

  write_metadata(
    output_path = tmp_file,
    cran_status = "success",
    downloads_status = "failed",
    github_status = "success",
    examples_status = "failed"
  )

  result <- arrow::read_parquet(tmp_file)
  expect_equal(nrow(result), 4)
  expect_equal(result$status[result$source == "examples"], "failed")
  expect_equal(result$status[result$source == "cranlogs"], "failed")
})

test_that("write_metadata omits examples row when examples_status is NULL", {
  tmp_file <- withr::local_tempfile(fileext = ".parquet")

  write_metadata(
    output_path = tmp_file,
    cran_status = "success",
    downloads_status = "success",
    github_status = "success",
    examples_status = NULL
  )

  result <- arrow::read_parquet(tmp_file)
  expect_equal(nrow(result), 3)
  expect_false("examples" %in% result$source)
})
