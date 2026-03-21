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

#' Prioritize Rd files to find package-specific examples
#'
#' Reorders a vector of Rd file paths so that files most likely to contain
#' package-specific examples come first. This avoids extracting re-exported
#' examples (e.g., ggplot2's `xlim.Rd` from animint2) when a package wraps
#' or re-exports functions from its dependencies.
#'
#' Priority tiers (highest to lowest):
#' 1. `{package_name}.Rd` — the package-level documentation file
#' 2. Rd files whose basename contains the package name (e.g., `animint2dir.Rd`)
#' 3. Rd files with unique-sounding names (not matching common ggplot2/tidyverse
#'    patterns like `geom_*.Rd`, `scale_*.Rd`, `aes*.Rd`, etc.)
#' 4. Everything else (likely re-exports)
#'
#' @param rd_files Character vector of Rd file paths (e.g., "pkg/man/foo.Rd").
#' @param package_name Name of the package being processed.
#'
#' @return Character vector of the same Rd file paths, reordered by priority.
#'
#' @noRd
prioritize_rd_files <- function(rd_files, package_name) {
  if (length(rd_files) == 0) return(character(0))

  basenames <- basename(rd_files)

  # Strip the package name prefix (e.g., "animint2" from "animint2") to get
  # a root for matching — handle packages with digits/dots in names
  pkg_pattern <- gsub("([.+*?^${}()|\\[\\]])", "\\\\\\1", package_name)

  # Tier 1: exact primary Rd file ({package_name}.Rd)
  is_primary <- basenames == paste0(package_name, ".Rd")

  # Tier 2: basename contains the package name (case-insensitive)
  # e.g., "animint2dir.Rd", "theme_animint.Rd", "scale_size_animint.Rd"
  # Also match without trailing digits: "animint" matches "animint2dir.Rd"
  pkg_root <- gsub("[0-9]+$", "", package_name)
  pkg_root_pattern <- gsub("([.+*?^${}()|\\[\\]])", "\\\\\\1", pkg_root)
  is_pkg_named <- grepl(pkg_root_pattern, basenames, ignore.case = TRUE) & !is_primary

  # Tier 3: NOT a common ggplot2/tidyverse re-export pattern
  # These patterns match functions commonly re-exported by ggplot2 wrapper packages
  reexport_patterns <- paste0(
    "^(geom_|stat_|scale_|coord_|facet_|position_|theme_|guide_|",
    "annotation_|element_|aes|labs|lims|borders|qplot|ggplot|",
    "fortify|autoplot|margin|waiver|resolution|last_plot|",
    "draw_key|sec_axis|dup_axis|expansion|after_stat|after_scale|",
    "stage|cut_interval|cut_number|cut_width)\\.Rd$"
  )
  is_reexport <- grepl(reexport_patterns, basenames)
  is_unique <- !is_primary & !is_pkg_named & !is_reexport

  # Tier 4: everything else (likely re-exports)
  is_other <- !is_primary & !is_pkg_named & !is_unique

  # Combine tiers in priority order
  c(
    rd_files[is_primary],
    rd_files[is_pkg_named],
    rd_files[is_unique],
    rd_files[is_other]
  )
}

#' Extract a code example by downloading a CRAN source tarball
#'
#' Downloads the source tarball from CRAN, extracts the `man/*.Rd` files,
#' and parses them with `tools::parse_Rd()` to find `\examples{}` sections.
#' This avoids installing the package entirely — no compilation, no
#' dependencies needed — making it fast and reliable for all CRAN packages
#' regardless of system library availability.
#'
#' Used by the weekly pipeline (`render_examples()`) as the primary method
#' to extract example code. Replaces the previous approach of installing
#' packages which failed for ~50% of packages due to missing compiled
#' dependencies.
#'
#' @param package_name Name of the CRAN package.
#' @param download_dir Directory to download the tarball into.
#'
#' @return A character string of example code, or `NA_character_` if no
#'   example was found or the package is not on CRAN.
#'
#' @noRd
extract_example_from_cran <- function(package_name, download_dir) {
  # Guard against NA or empty package names
  if (is.na(package_name) || package_name == "") {
    return(NA_character_)
  }

  # Download the source tarball from CRAN — tryCatch with warning handler
  # scoped to the download step only, so parse_Rd() warnings don't bail out
  tarball_path <- tryCatch(
    {
      result <- utils::download.packages(
        package_name,
        destdir = download_dir,
        repos = "https://cloud.r-project.org",
        type = "source",
        quiet = TRUE
      )

      if (is.null(result) || nrow(result) == 0) {
        logger::log_warn("Could not download tarball for '{package_name}'")
        return(NA_character_)
      }

      result[1, 2]
    },
    warning = function(w) {
      # download.packages() warns when a package is not available on CRAN
      logger::log_warn("Download warning for '{package_name}': {w$message}")
      NULL
    },
    error = function(e) {
      logger::log_warn("Download failed for '{package_name}': {e$message}")
      NULL
    }
  )

  if (is.null(tarball_path)) {
    return(NA_character_)
  }

  # List files in the tarball and find Rd documentation files
  tryCatch(
    {
      all_files <- utils::untar(tarball_path, list = TRUE)
      rd_files <- all_files[grepl("/man/.*\\.Rd$", all_files)]

      if (length(rd_files) == 0) {
        return(NA_character_)
      }

      # Reorder Rd files so package-specific examples come first,
      # avoiding re-exported function docs (e.g., ggplot2's xlim from animint2)
      rd_files <- prioritize_rd_files(rd_files, package_name)

      # Extract the Rd files to a temporary directory
      extract_dir <- file.path(download_dir, "extract", package_name)
      dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)
      utils::untar(tarball_path, files = rd_files, exdir = extract_dir)

      # Parse each Rd file and look for \examples sections.
      # parse_Rd() warnings (minor formatting issues) are suppressed so we
      # don't skip valid packages — only errors cause a file to be skipped.
      for (rd_file in rd_files) {
        rd_path <- file.path(extract_dir, rd_file)
        if (!file.exists(rd_path)) next

        rd <- tryCatch(
          suppressWarnings(tools::parse_Rd(rd_path)),
          error = function(e) NULL
        )
        if (is.null(rd)) next

        # Extract \examples sections from the parsed Rd
        examples <- Filter(function(x) {
          identical(attr(x, "Rd_tag"), "\\examples")
        }, rd)

        if (length(examples) > 0) {
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
      logger::log_warn("Failed to extract example from tarball for '{package_name}': {e$message}")
      NA_character_
    }
  )
}

#' Extract a code example from a locally-installed package
#'
#' Fallback method that extracts examples from an installed package using
#' `tools::Rd_db()`. Used when the package is already available locally
#' (e.g. in the development environment). The pipeline uses
#' `extract_example_from_cran()` instead, which works without installation.
#'
#' @param package_name Name of the package.
#'
#' @return A character string of example code, or NA if none found.
#'
#' @noRd
extract_example <- function(package_name) {
  tryCatch(
    {
      # Get the Rd database for the package from installed libraries
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

  # Create a shared temporary directory for downloading source tarballs.
  # Tarballs are downloaded here, Rd files extracted and parsed — no
  # package installation or compilation is needed.
  download_dir <- tempfile("examples_dl_")
  dir.create(download_dir, recursive = TRUE)
  on.exit(unlink(download_dir, recursive = TRUE), add = TRUE)

  logger::log_info("Example rendering: download dir at {download_dir}")
  logger::log_info("Processing {nrow(packages_combined)} packages for examples")

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

    # Extract example code by downloading the CRAN source tarball and
    # parsing the Rd files directly — no installation or compilation needed
    code <- extract_example_from_cran(pkg_name, download_dir = download_dir)

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

    # Render the example in a subprocess
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
