# =============================================================================
# Dockerfile
#
# Multi-stage build for the ggplot2 Extended Companion Shiny app.
# Stage 1: Install system dependencies and R packages via renv
# Stage 2: Copy app files and Parquet data into a lean runtime image
#
# Build: docker build -t ggplot2-companion .
# Run:   docker run -p 3838:3838 ggplot2-companion
#
# Part of Milestone 10: Docker & Cloud Run Deployment
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build — install system deps and R packages
# ---------------------------------------------------------------------------
FROM rocker/r-ver:4.5.3 AS builder

# System dependencies for R packages (arrow, duckdb, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy renv infrastructure first (for caching)
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
COPY .Rprofile .Rprofile

# Restore R packages from lockfile
# Set MAKEFLAGS for parallel compilation (duckdb needs significant resources)
# NOT_CRAN allows duckdb to use its own build configuration
RUN MAKEFLAGS="-j$(nproc)" NOT_CRAN=true Rscript -e 'renv::restore(prompt = FALSE)'

# ---------------------------------------------------------------------------
# Stage 2: Runtime — lean image with app code and data
# ---------------------------------------------------------------------------
FROM rocker/r-ver:4.5.3

# Runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy renv library from builder
COPY --from=builder /app/renv /app/renv
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Copy renv infrastructure
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile

# Copy R package files
COPY DESCRIPTION DESCRIPTION
COPY NAMESPACE NAMESPACE
COPY R/ R/
COPY man/ man/
COPY inst/ inst/
COPY app.R app.R

# Copy Parquet data files (produced by pipeline)
COPY data/ data/

# Copy curated data files (needed by validation functions)
COPY data-raw/packages_curated.csv data-raw/packages_curated.csv
COPY data-raw/categories.csv data-raw/categories.csv
COPY data-raw/license_allowlist.csv data-raw/license_allowlist.csv

# Expose the Shiny port
ENV SHINY_PORT=3838
EXPOSE ${SHINY_PORT}

# Run the app
CMD ["Rscript", "-e", "pkgload::load_all(export_all = FALSE, helpers = FALSE, attach_testthat = FALSE); options(shiny.port = as.integer(Sys.getenv('PORT', Sys.getenv('SHINY_PORT', '3838'))), shiny.host = '0.0.0.0'); run_app()"]
