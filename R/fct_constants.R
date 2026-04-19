# =============================================================================
# fct_constants.R
#
# Package-internal constants for user-visible UI strings that appear in more
# than one place. Centralising them here means a copy change (e.g., the
# companion book's title) is a single-file edit rather than a grep-and-hope
# sweep across modules.
#
# Conventions:
# - SCREAMING_SNAKE_CASE per the tidyverse style guide for constants.
# - `@noRd` on every constant — these are package-internal.
# - One constant per UI string. Do not collapse variants (e.g., singular vs
#   plural wording) into a shared base — the contextual framing is the whole
#   reason the two strings exist.
#
# v1.2 (M0): introduced for the Featured-in-the-book tooltip bodies per
# Reviewer §7 (magic-string DRY) and Designer round-02 finding #1 (the
# sidebar context calls for plural framing, the detail context for singular).
# =============================================================================

#' Sidebar tooltip body for the "Featured in the Book" checkbox
#'
#' Plural framing ("Packages featured…") because the sidebar filter
#' operates on the whole package collection, not any single package.
#' Used by `R/mod_sidebar.R`.
#'
#' @noRd
FEATURED_TOOLTIP_BODY_SIDEBAR <-
  "Packages featured in the companion book 'ggplot2 extended'"

#' Detail-view tooltip body for the "Featured in the book" badge
#'
#' Singular/neutral framing (no subject) because the detail view is
#' about one package at a time — plural framing would create a mild
#' cognitive stutter. The core disambiguating phrase
#' ("companion book 'ggplot2 extended'") is kept identical to the
#' sidebar body so the user's mental model of "which book?" stays
#' stable across surfaces. Used by `R/mod_detail.R`.
#'
#' @noRd
FEATURED_TOOLTIP_BODY_DETAIL <-
  "Featured in the companion book 'ggplot2 extended'"
