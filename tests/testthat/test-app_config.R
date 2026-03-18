# =============================================================================
# test-app_config.R
#
# Tests for golem configuration helpers in R/app_config.R.
# Verifies that app_sys() returns valid paths within the package.
#
# Part of Milestone 0: Project Scaffold
# =============================================================================

test_that("app_sys returns a character string", {
  # app_sys() should always return a character path, even if the package

  # is loaded via pkgload rather than formally installed
  result <- app_sys()

  expect_type(result, "character")
  expect_length(result, 1)
})

test_that("app_sys returns path to golem-config.yml", {
  # The golem config file should be findable via app_sys()
  config_path <- app_sys("golem-config.yml")

  expect_type(config_path, "character")

  # When the package is properly loaded, the file should exist
  if (nzchar(config_path)) {
    expect_true(file.exists(config_path))
  }
})
