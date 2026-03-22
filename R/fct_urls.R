# =============================================================================
# fct_urls.R
#
# URL construction functions for CRAN-derived URLs. Builds CRAN page,
# reference manual, and vignettes directory URLs based on package name
# and CRAN status. Patterns from SPEC Appendix B.
#
# Part of Milestone 2: Data Pipeline (Core)
# =============================================================================

#' Construct CRAN-derived URLs for packages
#'
#' Builds CRAN page, reference manual, and vignettes directory URLs using
#' the patterns defined in SPEC Appendix B. Only generates URLs for packages
#' that are on CRAN (`on_cran == TRUE`); others get NA. Vignettes URL is
#' also set to NA when `has_vignettes == FALSE` (package has no vignettes).
#'
#' @param df A data frame with `package_name` (character), `on_cran`
#'   (logical), and `has_vignettes` (logical) columns.
#'
#' @return A tibble with columns: `package_name`, `cran_url`, `manual_url`,
#'   `vignettes_url`.
#'
#' @noRd
construct_urls <- function(df) {
  # has_vignettes may not be present in older data — default to TRUE
  has_vignettes <- if ("has_vignettes" %in% names(df)) {
    df$has_vignettes
  } else {
    rep(TRUE, nrow(df))
  }

  tibble::tibble(
    package_name = df$package_name,

    # CRAN page: https://cran.r-project.org/package={name}
    cran_url = ifelse(
      df$on_cran,
      paste0("https://cran.r-project.org/package=", df$package_name),
      NA_character_
    ),

    # Reference manual: https://cran.r-project.org/web/packages/{name}/{name}.pdf
    manual_url = ifelse(
      df$on_cran,
      paste0(
        "https://cran.r-project.org/web/packages/",
        df$package_name, "/", df$package_name, ".pdf"
      ),
      NA_character_
    ),

    # Vignettes directory: only if on CRAN AND has vignettes
    vignettes_url = ifelse(
      df$on_cran & has_vignettes,
      paste0(
        "https://cran.r-project.org/web/packages/",
        df$package_name, "/vignettes/"
      ),
      NA_character_
    )
  )
}
