# =============================================================================
# test-fct_urls.R
#
# Tests for URL construction functions in R/fct_urls.R.
# Verifies CRAN page, reference manual, and vignette URL patterns
# from SPEC Appendix B.
#
# Part of Milestone 2: Data Pipeline (Core)
# =============================================================================

test_that("construct_urls builds correct URLs for CRAN packages", {
  df <- data.frame(
    package_name = c("ggrepel", "patchwork"),
    on_cran = c(TRUE, TRUE),
    stringsAsFactors = FALSE
  )

  result <- construct_urls(df)

  expect_equal(result$cran_url[1], "https://cran.r-project.org/package=ggrepel")
  expect_equal(result$cran_url[2], "https://cran.r-project.org/package=patchwork")

  expect_equal(
    result$manual_url[1],
    "https://cran.r-project.org/web/packages/ggrepel/ggrepel.pdf"
  )

  expect_equal(
    result$vignettes_url[1],
    "https://cran.r-project.org/web/packages/ggrepel/vignettes/"
  )
})

test_that("construct_urls returns NA URLs for non-CRAN packages", {
  df <- data.frame(
    package_name = c("gg3D", "bbplot"),
    on_cran = c(FALSE, FALSE),
    stringsAsFactors = FALSE
  )

  result <- construct_urls(df)

  expect_true(all(is.na(result$cran_url)))
  expect_true(all(is.na(result$manual_url)))
  expect_true(all(is.na(result$vignettes_url)))
})

test_that("construct_urls handles mixed CRAN and non-CRAN packages", {
  df <- data.frame(
    package_name = c("ggrepel", "bbplot", "patchwork"),
    on_cran = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  result <- construct_urls(df)

  expect_false(is.na(result$cran_url[1]))
  expect_true(is.na(result$cran_url[2]))
  expect_false(is.na(result$cran_url[3]))
})

test_that("construct_urls returns tibble with expected columns", {
  df <- data.frame(
    package_name = c("ggrepel"),
    on_cran = c(TRUE),
    stringsAsFactors = FALSE
  )

  result <- construct_urls(df)

  expect_true(tibble::is_tibble(result))
  expect_true(all(c("package_name", "cran_url", "manual_url", "vignettes_url") %in% names(result)))
})
