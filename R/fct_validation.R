# =============================================================================
# fct_validation.R
#
# CSV validation functions for packages_curated.csv. Enforces data integrity
# rules defined in SPEC section 4.4: no duplicates, valid categories, required
# fields, boolean is_essential, well-formed pipe-separated categories.
#
# These functions are used by the migration script (data-raw/migrate_notion.R)
# and can be called in CI (e.g., GitHub Actions check.yml) to validate the
# curated CSV on every push/PR.
#
# Part of Milestone 1: Notion Migration & Curated Data
# =============================================================================

#' Create a validation result
#'
#' Helper to construct a consistent validation result object.
#'
#' @param valid Logical. TRUE if validation passed.
#' @param errors Character vector of error messages (empty if valid).
#'
#' @return A list with `valid` (logical) and `errors` (character vector).
#'
#' @noRd
validation_result <- function(valid, errors = character(0)) {
  list(valid = valid, errors = errors)
}

#' Validate no duplicate package names
#'
#' Checks that every `package_name` in the data frame is unique.
#' SPEC section 4.4: "No duplicate package_name values in packages_curated.csv."
#'
#' @param df A data frame with a `package_name` column.
#'
#' @return A validation result list with `valid` and `errors`.
#'
#' @noRd
validate_no_duplicates <- function(df) {
  dupes <- df$package_name[duplicated(df$package_name)]

  if (length(dupes) == 0) {
    return(validation_result(valid = TRUE))
  }

  unique_dupes <- unique(dupes)
  errors <- paste0("Duplicate package_name: '", unique_dupes, "'")

  validation_result(valid = FALSE, errors = errors)
}

#' Validate required fields are non-empty
#'
#' Checks that `package_name`, `categories`, and `date_added` are present and
#' non-empty for every row.
#' SPEC section 4.4: "Required fields (package_name, categories, date_added)
#' are non-empty."
#'
#' @param df A data frame with the required columns.
#'
#' @return A validation result list with `valid` and `errors`.
#'
#' @noRd
validate_required_fields <- function(df) {
  required <- c("package_name", "categories", "date_added")
  errors <- character(0)

  for (field in required) {
    # Check for NA or empty string values
    empty_rows <- which(is.na(df[[field]]) | df[[field]] == "")

    if (length(empty_rows) > 0) {
      errors <- c(
        errors,
        paste0("Empty '", field, "' at row(s): ", paste(empty_rows, collapse = ", "))
      )
    }
  }

  validation_result(valid = length(errors) == 0, errors = errors)
}

#' Validate is_essential contains only TRUE/FALSE
#'
#' Checks that the `is_essential` column contains only logical TRUE or FALSE
#' values (not strings, not NA).
#' SPEC section 4.4: "is_essential is TRUE or FALSE."
#'
#' @param df A data frame with an `is_essential` column.
#'
#' @return A validation result list with `valid` and `errors`.
#'
#' @noRd
validate_is_essential <- function(df) {
  errors <- character(0)

  # Must be logical type with no NAs
  invalid_rows <- which(is.na(df$is_essential) | !is.logical(df$is_essential))

  if (length(invalid_rows) > 0) {
    bad_pkgs <- df$package_name[invalid_rows]
    errors <- paste0(
      "Invalid is_essential value for package '", bad_pkgs,
      "' (must be TRUE or FALSE)"
    )
  }

  validation_result(valid = length(errors) == 0, errors = errors)
}

#' Validate pipe-separated category format
#'
#' Checks that `categories` values are well-formed pipe-separated strings:
#' no trailing pipes, no leading pipes, no spaces around pipes, no empty
#' segments between pipes.
#' SPEC section 4.4: "Pipe-separated categories are well-formed (no trailing
#' pipes, no spaces around pipes)."
#'
#' @param df A data frame with `package_name` and `categories` columns.
#'
#' @return A validation result list with `valid` and `errors`.
#'
#' @noRd
validate_category_format <- function(df) {
  errors <- character(0)

  for (i in seq_len(nrow(df))) {
    cats <- df$categories[i]
    pkg <- df$package_name[i]

    # Skip NA (caught by validate_required_fields)
    if (is.na(cats)) next

    # Check for leading or trailing pipe
    if (grepl("^\\|", cats) || grepl("\\|$", cats)) {
      errors <- c(errors, paste0("Leading/trailing pipe in categories for '", pkg, "': '", cats, "'"))
      next
    }

    # Check for spaces around pipes
    if (grepl("\\s\\|", cats) || grepl("\\|\\s", cats)) {
      errors <- c(errors, paste0("Spaces around pipe in categories for '", pkg, "': '", cats, "'"))
      next
    }

    # Check for empty segments (consecutive pipes)
    if (grepl("\\|\\|", cats)) {
      errors <- c(errors, paste0("Empty segment in categories for '", pkg, "': '", cats, "'"))
    }
  }

  validation_result(valid = length(errors) == 0, errors = errors)
}

#' Validate categories against canonical list
#'
#' Checks that every individual category in every row's pipe-separated
#' `categories` field exists in the canonical category list.
#' SPEC section 4.4: "All categories values match the known category set
#' (defined in data-raw/categories.csv)."
#'
#' @param df A data frame with `package_name` and `categories` columns.
#' @param valid_categories Character vector of valid category identifiers.
#'
#' @return A validation result list with `valid` and `errors`.
#'
#' @noRd
validate_categories <- function(df, valid_categories) {
  errors <- character(0)

  for (i in seq_len(nrow(df))) {
    cats <- df$categories[i]
    pkg <- df$package_name[i]

    # Skip NA (caught by validate_required_fields)
    if (is.na(cats)) next

    # Split on pipe and check each category
    individual_cats <- strsplit(cats, "\\|")[[1]]
    invalid <- individual_cats[!individual_cats %in% valid_categories]

    if (length(invalid) > 0) {
      errors <- c(
        errors,
        paste0(
          "Invalid category '", invalid, "' for package '", pkg, "'"
        )
      )
    }
  }

  validation_result(valid = length(errors) == 0, errors = errors)
}

#' Validate a curated CSV data frame (all checks)
#'
#' Runs all individual validation checks on a packages_curated.csv data frame
#' and returns a combined result. Does NOT stop at the first failure -- collects
#' all errors from all checks so they can be fixed in one pass.
#'
#' @param df A data frame representing the curated CSV.
#' @param valid_categories Character vector of valid category identifiers
#'   (from `data-raw/categories.csv`).
#'
#' @return A validation result list with `valid` (TRUE if all checks pass)
#'   and `errors` (combined character vector of all error messages).
#'
#' @noRd
validate_curated_csv <- function(df, valid_categories) {
  # Run all checks, collecting errors from each
  checks <- list(
    validate_no_duplicates(df),
    validate_required_fields(df),
    validate_is_essential(df),
    validate_category_format(df),
    validate_categories(df, valid_categories)
  )

  # Combine all errors
  all_errors <- unlist(lapply(checks, function(x) x$errors))

  validation_result(
    valid = length(all_errors) == 0,
    errors = all_errors
  )
}
