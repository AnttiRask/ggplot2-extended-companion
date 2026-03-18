# =============================================================================
# migrate_notion.R
#
# One-time migration script that reads the Notion CSV export and produces
# data-raw/packages_curated.csv — the source of truth for all curated package
# metadata. Transforms column names, converts category display names to
# pipe-separated snake_case identifiers, and adds missing fields.
#
# Usage: source("data-raw/migrate_notion.R")
#
# Input:  data-raw/notion_export_part_1.csv (455 packages from Notion)
# Output: data-raw/packages_curated.csv
#
# Part of Milestone 1: Notion Migration & Curated Data
# =============================================================================

library(dplyr, warn.conflicts = FALSE)

# Load the package's validation functions (export_all = TRUE so we can access
# internal validation functions that are @noRd)
pkgload::load_all(export_all = TRUE, helpers = FALSE, attach_testthat = FALSE)

# -----------------------------------------------------------------------------
# 1. Read source data
# -----------------------------------------------------------------------------

cat("Reading Notion export...\n")
notion <- read.csv(
  "data-raw/notion_export_part_1.csv",
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8"
)
cat(sprintf("  Found %d packages\n", nrow(notion)))

# -----------------------------------------------------------------------------
# 2. Build category lookup table
# -----------------------------------------------------------------------------

# Read the canonical category list
cats_ref <- read.csv("data-raw/categories.csv", stringsAsFactors = FALSE)

# Build lookup: lowercase display name → snake_case category identifier
# The Notion export uses lowercase display names (e.g., "scales and guides")
# while categories.csv uses title case (e.g., "Scales & Guides")
cat_lookup <- stats::setNames(cats_ref$category, tolower(cats_ref$display_name))

# Handle known mismatches between Notion and categories.csv display names
# Notion uses "scales and guides" but categories.csv display name is "Scales & Guides"
cat_lookup["scales and guides"] <- "scales_and_guides"

cat(sprintf("  Category lookup table: %d entries\n", length(cat_lookup)))

# -----------------------------------------------------------------------------
# 3. Convert categories from display names to snake_case pipe-separated
# -----------------------------------------------------------------------------

#' Convert a single Notion category string to pipe-separated snake_case
#'
#' @param cat_string Comma-separated display name categories from Notion
#'   (e.g., "animation, interactive plots")
#' @param lookup Named character vector mapping lowercase display names to
#'   snake_case identifiers
#'
#' @return Pipe-separated snake_case string (e.g., "animation|interactive_plots"),
#'   or "na" if the input is empty/NA
convert_categories <- function(cat_string, lookup) {
  # Handle empty or NA
  if (is.na(cat_string) || trimws(cat_string) == "") {
    return("na")
  }

  # Split on comma, trim whitespace, lowercase
  display_names <- trimws(strsplit(cat_string, ",")[[1]])
  display_names <- tolower(display_names)

  # Look up each display name → snake_case
  snake_cats <- vapply(display_names, function(dn) {
    matched <- lookup[dn]
    if (is.na(matched)) {
      warning(sprintf("Unknown category display name: '%s'", dn))
      return(dn)
    }
    return(matched)
  }, character(1), USE.NAMES = FALSE)

  # Join with pipe separator
  paste(snake_cats, collapse = "|")
}

cat("Converting categories...\n")
converted_categories <- vapply(
  notion$Category,
  convert_categories,
  character(1),
  lookup = cat_lookup,
  USE.NAMES = FALSE
)

# Report any warnings (unknown categories)
unknown <- converted_categories[grepl(" ", converted_categories)]
if (length(unknown) > 0) {
  cat(sprintf("  WARNING: %d packages had unknown categories\n", length(unknown)))
}

# -----------------------------------------------------------------------------
# 4. Build the curated CSV
# -----------------------------------------------------------------------------

cat("Building packages_curated.csv...\n")

curated <- data.frame(
  package_name = notion$Name,
  categories   = converted_categories,
  is_essential = FALSE,
  website_url  = ifelse(
    is.na(notion$Website) | notion$Website == "" | notion$Website == "NA",
    NA_character_,
    notion$Website
  ),
  repo_url     = ifelse(
    is.na(notion$GitHub.GitLab) | notion$GitHub.GitLab == "" | notion$GitHub.GitLab == "NA",
    NA_character_,
    notion$GitHub.GitLab
  ),
  date_added   = as.character(Sys.Date()),
  notes        = "",
  stringsAsFactors = FALSE
)

# Mark packages that had no category in Notion
no_cat_rows <- which(is.na(notion$Category) | trimws(notion$Category) == "")
if (length(no_cat_rows) > 0) {
  curated$notes[no_cat_rows] <- "No category in Notion export"
  cat(sprintf("  %d packages had no category (mapped to 'na')\n", length(no_cat_rows)))
}

# Sort by package name for consistency
curated <- curated |>
  arrange(package_name)

cat(sprintf("  Curated CSV: %d rows, %d columns\n", nrow(curated), ncol(curated)))

# -----------------------------------------------------------------------------
# 5. Validate before writing
# -----------------------------------------------------------------------------

cat("Validating...\n")
valid_categories <- cats_ref$category
result <- validate_curated_csv(curated, valid_categories)

if (!result$valid) {
  cat("\n  VALIDATION FAILED:\n")
  for (err in result$errors) {
    cat(sprintf("    - %s\n", err))
  }
  stop("Migration produced invalid data. Fix errors above before proceeding.")
}

cat("  All validation checks passed!\n")

# -----------------------------------------------------------------------------
# 6. Write output
# -----------------------------------------------------------------------------

write.csv(curated, "data-raw/packages_curated.csv", row.names = FALSE)
cat(sprintf("\nWrote data-raw/packages_curated.csv (%d packages)\n", nrow(curated)))
