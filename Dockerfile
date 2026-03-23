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
# Stage 1: Build -- install system deps and R packages
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
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy renv infrastructure first (for caching)
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
COPY .Rprofile .Rprofile

# Restore R packages from lockfile into a known library path
# Set MAKEFLAGS for parallel compilation (duckdb needs significant resources)
# NOT_CRAN allows duckdb to use its own build configuration
ENV RENV_PATHS_LIBRARY=/build/renv_lib
RUN mkdir -p /build/renv_lib && \
    MAKEFLAGS="-j$(nproc)" NOT_CRAN=true Rscript -e ' \
      renv::restore(prompt = FALSE, library = "/build/renv_lib") \
    '

# ---------------------------------------------------------------------------
# Stage 2: Runtime -- lean image with app code and data
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

# Copy the renv library from builder into the system library
COPY --from=builder /build/renv_lib /usr/local/lib/R/site-library

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

# Install the app package itself
RUN Rscript -e 'install.packages(".", repos = NULL, type = "source")'

# Create non-root user for security (don't run Shiny as root)
RUN useradd -m -u 1000 shinyuser && \
    chown -R shinyuser:shinyuser /app
USER shinyuser

# Expose the Shiny port
ENV SHINY_PORT=3838
EXPOSE ${SHINY_PORT}

# Run the app using the installed package
CMD ["Rscript", "-e", "options(shiny.port = as.integer(Sys.getenv('PORT', Sys.getenv('SHINY_PORT', '3838'))), shiny.host = '0.0.0.0'); ggplot2.extended.companion::run_app()"]
