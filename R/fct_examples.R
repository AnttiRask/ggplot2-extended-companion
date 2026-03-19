# =============================================================================
# fct_examples.R
#
# Code example extraction and rendering functions. Extracts examples from
# package documentation, renders them in isolated subprocesses, and captures
# output as PNG images. Used by the weekly pipeline (GitHub Actions) and
# displayed in the detail view.
#
# Part of Milestone 6: Code Examples Pipeline & Display
# =============================================================================

#' Check if a license allows code example rendering
#'
#' Matches a package's license string against the allowlist patterns in
#' `data-raw/license_allowlist.csv`. Uses partial matching (grepl) so
#' "MIT + file LICENSE" matches the "MIT" pattern.
#'
#' @param license Character string of the package license.
#' @param allowlist Data frame with `license_pattern` and `allowed` columns.
#'
#' @return Logical. TRUE if the license matches any allowed pattern.
#'
#' @noRd
check_license_allowed <- function(license, allowlist) {
  if (is.na(license) || license == "") {
    return(FALSE)
  }

  # Only consider patterns where allowed == TRUE
  allowed_patterns <- allowlist$license_pattern[allowlist$allowed == TRUE]

  # Check if any allowed pattern matches the license string
  any(vapply(allowed_patterns, function(pattern) {
    grepl(pattern, license, fixed = TRUE)
  }, logical(1)))
}

#' Extract a code example from a package
#'
#' Attempts to extract the first example from the package's primary function
#' documentation using `tools::Rd_db()`. Falls back to NA if the package is
#' not installed or has no examples.
#'
#' @param package_name Name of the package.
#'
#' @return A character string of example code, or NA if none found.
#'
#' @noRd
extract_example <- function(package_name) {
  tryCatch(
    {
      # Get the Rd database for the package
      rd_db <- tools::Rd_db(package_name)

      if (length(rd_db) == 0) {
        return(NA_character_)
      }

      # Search through Rd entries for examples
      for (rd in rd_db) {
        # Extract \examples sections
        examples <- Filter(function(x) {
          identical(attr(x, "Rd_tag"), "\\examples")
        }, rd)

        if (length(examples) > 0) {
          # Flatten the example content to a string
          code <- paste(unlist(examples[[1]]), collapse = "")
          code <- trimws(code)

          if (nchar(code) > 0) {
            return(code)
          }
        }
      }

      NA_character_
    },
    error = function(e) {
      logger::log_warn("Failed to extract example for '{package_name}': {e$message}")
      NA_character_
    }
  )
}

#' Render a code example in an isolated subprocess
#'
#' Executes example code in a `callr::r()` subprocess with a timeout.
#' If the code produces a ggplot2 plot, captures it as a PNG image.
#' NOTE: The code is sourced from trusted package documentation only,
#' never from user input. The subprocess provides isolation.
#'
#' @param package_name Name of the package.
#' @param code Character string of R code to execute (from package \examples).
#' @param png_path Path where the PNG output should be saved.
#' @param timeout Timeout in seconds for the subprocess (default: 30).
#'
#' @return A list with `package_name`, `example_code`, `example_image`,
#'   `example_success`, and `example_rendered_at`.
#'
#' @noRd
render_example <- function(package_name, code, png_path, timeout = 30) {
  rendered_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  tryCatch(
    {
      # Run code in an isolated subprocess via callr
      # Code originates from trusted package documentation (\examples sections)
      callr::r(
        function(code_text, output_path) {
          # Parse and evaluate the example code from package documentation
          parsed <- parse(text = code_text)
          for (expr in parsed) {
            base::eval(expr, envir = globalenv())
          }

          # Capture the last plot if one exists
          last_plot <- tryCatch(
            ggplot2::last_plot(),
            error = function(e) NULL
          )

          if (!is.null(last_plot)) {
            ggplot2::ggsave(
              output_path,
              plot = last_plot,
              width = 800 / 150,   # 800px at 150 DPI
              height = 600 / 150,  # 600px at 150 DPI
              dpi = 150
            )
          }
        },
        args = list(code_text = code, output_path = png_path),
        timeout = timeout
      )

      # Check if PNG was created
      success <- file.exists(png_path)

      list(
        package_name       = package_name,
        example_code       = code,
        example_image      = if (success) basename(png_path) else NA_character_,
        example_success    = success,
        example_rendered_at = rendered_at
      )
    },
    error = function(e) {
      logger::log_warn("Render failed for '{package_name}': {e$message}")
      list(
        package_name       = package_name,
        example_code       = code,
        example_image      = NA_character_,
        example_success    = FALSE,
        example_rendered_at = rendered_at
      )
    }
  )
}

#' Render code examples for all packages
#'
#' Orchestrates the full example rendering pipeline: checks license,
#' extracts example code, renders in subprocess, captures PNG output.
#' Produces a tibble matching the Code Examples Entity (SPEC section 3.3).
#'
#' @param packages_combined Tibble with package data (needs `package_name`, `license`).
#' @param allowlist_path Path to the license allowlist CSV.
#' @param output_dir Directory for PNG output files.
#'
#' @return A tibble with one row per package and example metadata columns.
#'
#' @noRd
render_examples <- function(
  packages_combined,
  allowlist_path = "data-raw/license_allowlist.csv",
  output_dir = "inst/app/www/examples"
) {
  # Read allowlist
  allowlist <- read.csv(allowlist_path, stringsAsFactors = FALSE)

  # Ensure output directory exists
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  results <- lapply(seq_len(nrow(packages_combined)), function(i) {
    pkg_name <- packages_combined$package_name[i]
    pkg_license <- packages_combined$license[i]

    # Check license
    license_ok <- check_license_allowed(pkg_license, allowlist)

    if (!license_ok) {
      return(tibble::tibble(
        package_name        = pkg_name,
        example_code        = NA_character_,
        example_image       = NA_character_,
        example_success     = FALSE,
        example_rendered_at = NA_character_,
        license_allowed     = FALSE
      ))
    }

    # Extract example code
    code <- extract_example(pkg_name)

    if (is.na(code)) {
      return(tibble::tibble(
        package_name        = pkg_name,
        example_code        = NA_character_,
        example_image       = NA_character_,
        example_success     = FALSE,
        example_rendered_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        license_allowed     = TRUE
      ))
    }

    # Render the example
    png_path <- file.path(output_dir, paste0(pkg_name, ".png"))
    result <- render_example(pkg_name, code, png_path, timeout = 30)

    tibble::tibble(
      package_name        = result$package_name,
      example_code        = result$example_code,
      example_image       = result$example_image,
      example_success     = result$example_success,
      example_rendered_at = result$example_rendered_at,
      license_allowed     = TRUE
    )
  })

  dplyr::bind_rows(results)
}
