# ==============================================================================
# iNaturalist Bioblitz Data Dive Analysis
# ==============================================================================

cat("=== DATA DIVE SCRIPT STARTING ===\n\n")

# ==============================================================================
# ==============================================================================
# ENHANCED CONFIGURATION SECTION FOR DATA DIVE V4
# ==============================================================================
# This enhanced configuration adds:
# - Advanced heatmap analysis with grid-based and interpolated visualizations
# - Rarefaction curve analysis for species accumulation patterns
# - Effort-corrected richness metrics
# ==============================================================================

# ==============================================================================
# CONFIGURATION - EDIT THESE SETTINGS
# ==============================================================================
# 
# To use this script for a different bioblitz, update the following:
# 1. project_slug - your iNaturalist project URL slug
# 2. bioblitz_name - the name that will appear on slides
# 3. bioblitz_year - the year of your bioblitz
# 4. date_min and date_max - your bioblitz dates
# 5. hq_lon, hq_lat - coordinates for your bioblitz headquarters
# 6. bioblitz_logo - your logo filename (optional)
# ==============================================================================

# --- Project Settings ---
project_slug <- "walpole-wilderness-bioblitz-2025"
bioblitz_name <- "Walpole Wilderness"               # Name of your bioblitz (used in slides)
bioblitz_year <- 2025                               # Year of the bioblitz

# Logo file for title slide - if file exists, creates graphic title slide
# If file doesn't exist or is set to "", creates text-only title slide
bioblitz_logo <- "Walpole-Wilderness-bioblitz.jpg"

# --- HQ Location ---
hq_lon <- 116.634398
hq_lat <- -34.992854

# --- Event Window ---
date_min <- as.Date("2025-10-04")
date_max <- as.Date("2025-10-05")
quality_grades <- c("research", "needs_id")

# --- Output Settings ---
out_dir <- "outputs/data_dive"  # Output directory (created automatically)
slides_dir <- file.path(out_dir, "slides")
styles_dir <- file.path(out_dir, "styles")

# --- Map Settings ---
# Map Provider Options (affects download speed):
#   "Esri.WorldImagery"     - High quality satellite imagery (SLOWEST, best quality)
#   "OpenStreetMap"         - Simple street map (FAST, clear but basic)
#   "CartoDB.Positron"      - Light minimal map (FAST, clean look)
#   "CartoDB.Voyager"       - Balanced detail map (FAST, good compromise)
#   "Esri.WorldTopoMap"     - Topographic map (MEDIUM speed, shows terrain)
# For LARGE areas, use "OpenStreetMap" or "CartoDB.Positron" for 10-20x faster downloads
map_provider <- "Esri.WorldImagery"  # Change to "OpenStreetMap" for large areas
base_map_zoom <- 14                  # Zoom level (13-15 recommended)
                                      # Lower zoom (12-13) = faster downloads for large areas
buffer_km <- 2.5                     # Buffer around observations in kilometers
                                      # Reduce to 1.5-2 for large areas to minimize download time

# PERFORMANCE TIPS FOR LARGE BIOBLITZES:
# 1. Set map_provider = "OpenStreetMap" or "CartoDB.Positron" (10-20x faster than satellite)
# 2. Reduce base_map_zoom to 12 or 13 (fewer tiles to download)
# 3. Reduce buffer_km to 1.5-2 (smaller area to download)

# --- Force rebuild ---
force_rebuild <- FALSE     # Set TRUE to regenerate all figures even if cached
use_cached_data <- TRUE    # Set FALSE to fetch fresh data from iNaturalist

# --- Output Format Options ---
render_html <- TRUE        # Generate HTML slideshow (revealjs)
render_powerpoint <- TRUE  # Generate PowerPoint (.pptx) for manual editing

# --- Figure 2 Display Option ---
fig2_use_treemap <- TRUE  # TRUE = treemap, FALSE = bar chart for observations by taxon

# --- Figure 3 Display Option ---
n_top_observers <- 15  # Number of top observers to display in the chart

# --- Title Formatting Options ---
plot_title_size <- 20        # Main title font size (points) for charts
plot_subtitle_size <- 12     # Subtitle font size (points) for charts

# --- Figure Dimensions (optimized for presentation) ---
map_fig_width <- 12          # Width for map figures (inches)
map_fig_height <- 10         # Height for map figures (inches)
chart_fig_width <- 12        # Width for chart figures (inches) 
chart_fig_height <- 8        # Height for chart figures (inches)

# --- Legend Settings (optimized for legibility) ---
legend_text_size <- 12       # Legend text size (points)
legend_title_size <- 14      # Legend title size (points)
axis_text_size <- 11         # Axis text size (points)
axis_title_size <- 13        # Axis title size (points)

# --- Slide Title Formatting (for presentation slides) ---
slide_title_size <- 48       # Main slide title font size (pixels)
slide_subtitle_size <- 24    # Slide subtitle font size (pixels)

# ==============================================================================
# HEATMAP ANALYSIS CONFIGURATION
# ==============================================================================
# These settings control the spatial richness visualizations
# Three types of maps are generated:
# 1. Grid-based raw richness (species count per cell)
# 2. Grid-based effort-corrected richness (species per observation)
# 3. Interpolated continuous surface (smooth IDW interpolation)
# ==============================================================================

# --- Grid Settings ---
# Grid cell size determines spatial resolution of the analysis
# Larger cells = more observations per cell = more reliable but less spatial detail
# Smaller cells = finer spatial resolution but may have sparse data
grid_cell_size_m <- 500    # Grid cell size in meters
# Recommended values: 250, 500, 750, 1000
# 500m provides good balance for most BioBlitz events

rank_level <- "species"    # Taxonomic rank to count
# Options: "species", "genus", "family"
# Species-level is standard for richness analysis

# --- Data Quality Thresholds ---
# These ensure statistical reliability by filtering cells with too few observations
min_obs_per_cell <- 3      # Minimum observations for a cell to be included in effort-corrected maps
# Cells with fewer observations are excluded to avoid unreliable ratios

warn_obs_per_cell <- 10    # Threshold for "Good" vs "Fair" data quality designation
# Cells with ≥10 observations are considered reliable
# Cells with 3-9 observations are flagged as "Fair" quality

# --- Interpolation Settings (for smooth continuous surface) ---
# These control the IDW (Inverse Distance Weighting) interpolation
use_interpolation <- TRUE  # Set FALSE to skip interpolation (saves time)

interp_buffer_m <- 250     # Buffer radius around each observation point for local richness calculation
# Larger buffer = smoother patterns, less spatial detail
# Smaller buffer = more spatial variation, may be noisy
# Recommended: 100-500m depending on observation density

interp_resolution <- 50    # Grid resolution for interpolation surface in meters
# Smaller = smoother appearance but slower computation
# Larger = faster but more blocky appearance
# Recommended: 25-100m (50m is good default)

idw_power <- 2             # Power parameter for IDW interpolation
# Controls how quickly influence decreases with distance
# Higher values (2-3) = nearby points have more influence (more "spiky")
# Lower values (1-1.5) = distant points have more influence (more smooth)
# Standard IDW uses power = 2

mask_distance_m <- 300     # Maximum distance from observations to show interpolation
# Prevents extrapolation into areas without data
# Should be larger than interp_buffer_m
# Recommended: 200-500m

# ==============================================================================
# RAREFACTION ANALYSIS CONFIGURATION  
# ==============================================================================
# Rarefaction curves show species accumulation with sampling effort
# They help assess:
# - Whether sampling effort was sufficient to capture most species
# - How different taxonomic groups compare in their diversity
# - Whether the survey is approaching an asymptote (diminishing returns)
# ==============================================================================

# --- Rarefaction Settings ---
n_permutations <- 100      # Number of random sample orderings to compute
# More permutations = more reliable confidence intervals but slower
# 100 is standard, 50 is faster but less precise
# Increase to 200-500 for publication-quality figures

step_size <- 10            # Sample every N observations for rarefaction points
# Larger step = faster computation, fewer points on curve
# Smaller step = more detailed curve but slower
# Recommended: 5-20 depending on total observations
# (e.g., 5 for <500 obs, 10 for 500-2000 obs, 20 for >2000 obs)

rarefaction_rank_level <- "species"  # Taxonomic rank for rarefaction
# Should typically match rank_level above

# --- Data Sufficiency Thresholds ---
# These ensure rarefaction curves are reliable
min_obs_reliable <- 200    # Minimum observations for a "Reliable" quality designation
# Groups with fewer observations have less confident curves

min_obs_warning <- 100     # Show warning if below this threshold
# Curves with <100 observations are quite uncertain

# ==============================================================================
# Day/Night Settings (automatically calculated from HQ location)
# ==============================================================================
# Manual override: uncomment and set these values to override automatic calculation
# sunrise_hour <- 6.5  # Approximate sunrise time (24-hour format, decimal)
# sunset_hour <- 18.5  # Approximate sunset time (24-hour format, decimal)

# ==============================================================================
# END OF CONFIGURATION
# ==============================================================================

# 
cat("=== CONFIGURATION LOADED ===\n")
cat("Project:", project_slug, "\n")
cat("Bioblitz:", bioblitz_name, "Bioblitz", bioblitz_year, "\n")
cat("Map provider:", map_provider, "\n")
cat("Output directory:", out_dir, "\n")

# Setup directories
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(slides_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(styles_dir, recursive = TRUE, showWarnings = FALSE)

Sys.setenv(TZ = "Australia/Perth")

# ==============================================================================
# LOAD PACKAGES
# ==============================================================================

cat("Loading packages...\n")
req_pkgs <- c(
  "httr2", "jsonlite", "dplyr", "tidyr", "purrr", "stringr", "lubridate",
  "janitor", "glue", "readr", "tibble", "ggplot2", "sf", "forcats",
  "maptiles", "terra", "tidyterra", "osmdata", "ggspatial", 
  "scales", "viridis", "patchwork", "cowplot", "treemapify", "ggimage", "magick", "rsvg", "suncalc", "stars"
)

to_install <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(to_install)) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
}
invisible(lapply(req_pkgs, function(p) {
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}))

cat("Packages loaded\n\n")

# ==============================================================================
# CALCULATE SUNRISE/SUNSET TIMES
# ==============================================================================

cat("Calculating sunrise and sunset times...\n")

# Check if manual override exists
if (!exists("sunrise_hour") || !exists("sunset_hour")) {
  # Calculate sunrise and sunset times for the first day of the event
  # using the HQ coordinates
  sun_times <- suncalc::getSunlightTimes(
    date = date_min,
    lat = hq_lat,
    lon = hq_lon,
    tz = "Australia/Perth"
  )
  
  # Extract sunrise and sunset times as decimal hours
  sunrise_hour <- as.numeric(format(sun_times$sunrise, "%H")) + 
    as.numeric(format(sun_times$sunrise, "%M")) / 60
  sunset_hour <- as.numeric(format(sun_times$sunset, "%H")) + 
    as.numeric(format(sun_times$sunset, "%M")) / 60
  
  cat("  Automatic calculation from HQ location:\n")
  cat("    Sunrise:", format(sun_times$sunrise, "%H:%M"), 
      sprintf("(%.2f hours)\n", sunrise_hour))
  cat("    Sunset:", format(sun_times$sunset, "%H:%M"), 
      sprintf("(%.2f hours)\n", sunset_hour))
} else {
  cat("  Using manual sunrise/sunset times:\n")
  cat("    Sunrise:", sprintf("%.2f hours\n", sunrise_hour))
  cat("    Sunset:", sprintf("%.2f hours\n", sunset_hour))
}

cat("\n")

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

cat("Defining helper functions...\n")

`%||%` <- function(a, b) if (is.null(a)) b else a

inat_get <- function(path, query_list = list()) {
  req <- httr2::request(paste0("https://api.inaturalist.org/v1/", path))
  for (name in names(query_list)) {
    value <- query_list[[name]]
    if (grepl("\\[\\]$", name)) {
      req <- httr2::req_url_query(req, !!name := value, .multi = "comma")
    } else {
      req <- httr2::req_url_query(req, !!name := value)
    }
  }
  req |>
    httr2::req_user_agent("bioblitz-datadive/1.0") |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = FALSE)
}

flatten_observation <- function(o) {
  coords <- o$geojson$coordinates %||% c(NA_real_, NA_real_)
  taxon  <- o$taxon %||% list()
  user   <- o$user  %||% list()
  
  tibble::tibble(
    obs_id            = o$id %||% NA_integer_,
    observed_on       = o$observed_on %||% NA_character_,
    time_observed_at  = o$time_observed_at %||% NA_character_,
    created_at        = o$created_at %||% NA_character_,
    quality_grade     = o$quality_grade %||% NA_character_,
    observer_login    = user$login %||% NA_character_,
    observer_name     = user$name %||% NA_character_,
    observer_icon_url = user$icon_url %||% NA_character_,
    taxon_id          = taxon$id %||% NA_integer_,
    taxon_rank        = taxon$rank %||% NA_character_,
    taxon_name        = taxon$name %||% NA_character_,
    taxon_common_name = taxon$preferred_common_name %||% NA_character_,
    iconic_taxon      = taxon$iconic_taxon_name %||% NA_character_,
    longitude         = suppressWarnings(as.numeric(coords[[1]])),
    latitude          = suppressWarnings(as.numeric(coords[[2]]))
  )
}

download_project_observations <- function(project_slug, per_page = 200) {
  page <- 1
  out <- list()
  
  cat("Fetching observations from iNaturalist...\n")
  
  repeat {
    res <- inat_get("observations", list(
      project_id = project_slug,
      per_page = per_page,
      page = page,
      order = "asc",
      order_by = "created_at"
    ))
    
    if (!length(res$results)) break
    
    out[[page]] <- purrr::map_dfr(res$results, flatten_observation)
    
    if (page %% 5 == 0) {
      cat("  Fetched", page * per_page, "observations...\n")
    }
    
    if (length(res$results) < per_page) break
    page <- page + 1
  }
  
  result <- dplyr::bind_rows(out)
  cat("  Total fetched:", nrow(result), "observations\n")
  result
}

cat("Helper functions defined\n\n")

# ==============================================================================
# FETCH OBSERVATIONS
# ==============================================================================

cat("=== FETCHING OBSERVATIONS ===\n")

obs_cache_file <- file.path(out_dir, "observations_filtered.csv")

if (use_cached_data && file.exists(obs_cache_file)) {
  cat("Loading cached observations from previous run...\n")
  obs <- readr::read_csv(obs_cache_file, show_col_types = FALSE) |>
    dplyr::mutate(
      observed_on = lubridate::ymd(observed_on),
      time_observed_at = lubridate::ymd_hms(time_observed_at, quiet = TRUE),
      created_at = lubridate::ymd_hms(created_at, quiet = TRUE)
    )
  
  # VALIDATION: Check if cached data has all required fields
  required_fields <- c("obs_id", "observed_on", "quality_grade", 
                       "observer_login", "observer_name", "observer_icon_url",
                       "taxon_id", "taxon_rank", "iconic_taxon", 
                       "longitude", "latitude")
  missing_fields <- setdiff(required_fields, names(obs))
  
  if (length(missing_fields) > 0) {
    cat("\n")
    cat("========================================\n")
    cat("!!! WARNING: CACHED DATA IS OUTDATED !!!\n")
    cat("========================================\n")
    cat("The cached data is missing required fields:\n")
    cat("  Missing:", paste(missing_fields, collapse = ", "), "\n")
    cat("\n")
    cat("This happens when the script has been updated with new features.\n")
    cat("\n")
    cat("SOLUTION: Choose one of these options:\n")
    cat("  1. Set use_cached_data = FALSE in the configuration section\n")
    cat("  2. Delete the cache file and re-run:\n")
    cat("     ", obs_cache_file, "\n")
    cat("\n")
    cat("The script will then fetch fresh data from iNaturalist with all fields.\n")
    cat("========================================\n\n")
    stop("Cannot proceed with incomplete cached data. Please fetch fresh data.")
  }
  
  cat("Loaded", nrow(obs), "cached observations\n")
  cat("* All required fields present in cached data\n\n")
} else {
  cat("Fetching fresh data from iNaturalist...\n")
  obs_raw <- download_project_observations(project_slug)
  
  if (!nrow(obs_raw)) stop("No observations returned for project.")
  
  obs <- obs_raw |>
    dplyr::mutate(
      observed_on      = lubridate::ymd(observed_on),
      time_observed_at = lubridate::ymd_hms(time_observed_at, quiet = TRUE),
      created_at       = lubridate::ymd_hms(created_at, quiet = TRUE),
      iconic_taxon     = dplyr::coalesce(iconic_taxon, "Unknown")
    ) |>
    dplyr::filter(
      !is.na(observed_on),
      observed_on >= date_min,
      observed_on <= date_max,
      quality_grade %in% quality_grades
    )
  
  if (!nrow(obs)) stop("No observations in selected date/quality window.")
  
  cat("Filtered observations:", nrow(obs), "\n")
  readr::write_csv(obs, obs_cache_file)
  cat("Saved observations to cache\n\n")
}

# ==============================================================================
# STYLING
# ==============================================================================

cat("=== SETTING UP STYLING ===\n")

# Iconic taxon colors (matching original script)
iconic_cols <- c(
  "Mammalia" = "#D55E00",
  "Aves" = "#0072B2",
  "Reptilia" = "#009E73",
  "Amphibia" = "#CC79A7",
  "Actinopterygii" = "#56B4E9",
  "Insecta" = "#F0E442",
  "Arachnida" = "#E69F00",
  "Mollusca" = "#8A2BE2",
  "Plantae" = "#228B22",
  "Fungi" = "#7F4F24",
  "Protozoa" = "#999999",
  "Chromista" = "#6A5ACD",
  "Unknown" = "#444444"
)

# Iconic taxon icons (matching slideshow script)
iconic_icons <- c(
  "Mammalia" = "🦘",
  "Aves" = "🦜",
  "Reptilia" = "🦎",
  "Amphibia" = "🐸",
  "Actinopterygii" = "🟠",
  "Insecta" = "🪲",
  "Arachnida" = "🕷️",
  "Mollusca" = "🌀",
  "Plantae" = "🌿",
  "Fungi" = "🍄",
  "Protozoa" = "🧫",
  "Chromista" = "🧪",
  "Unknown" = "❓"
)

# Helper to add icons to labels
label_with_icon <- function(x) {
  ifelse(x %in% names(iconic_icons), 
         paste0(iconic_icons[x], " ", x), 
         x)
}

# Custom theme matching slideshow aesthetic (for figures 4 & 5)
theme_bioblitz <- function(base_size = 14) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
      panel.background = ggplot2::element_rect(fill = "#0b1b2a", colour = NA),
      text = ggplot2::element_text(colour = "#F7FAFC"),
      axis.text = ggplot2::element_text(colour = "#CBD5E0"),
      plot.title = ggplot2::element_text(colour = "#F7FAFC", face = "bold", size = base_size * 0.85),
      plot.subtitle = ggplot2::element_text(colour = "#CBD5E0", size = base_size * 0.75),
      legend.text = ggplot2::element_text(colour = "#F7FAFC"),
      legend.title = ggplot2::element_text(colour = "#F7FAFC", face = "bold"),
      panel.grid.major = ggplot2::element_line(colour = "#1a2f3f"),
      panel.grid.minor = ggplot2::element_line(colour = "#162533")
    )
}

# Simple theme for other figures
base_theme <- ggplot2::theme_minimal(base_size = 14) +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
    panel.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
    panel.grid.major = ggplot2::element_line(color = "#333333", linewidth = 0.3),
    panel.grid.minor = ggplot2::element_line(color = "#2a2a2a", linewidth = 0.2),
    text = ggplot2::element_text(color = "#e0e0e0", family = "sans"),
    axis.text = ggplot2::element_text(color = "#b0b0b0"),
    axis.title = ggplot2::element_text(color = "#e0e0e0", face = "bold"),
    plot.title = ggplot2::element_text(color = "#ffffff", face = "bold", size = 18),
    plot.subtitle = ggplot2::element_text(color = "#b0b0b0", size = 12),
    legend.background = ggplot2::element_rect(fill = "#2a2a2a", color = NA),
    legend.text = ggplot2::element_text(color = "#e0e0e0"),
    legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold"),
    strip.background = ggplot2::element_rect(fill = "#2a2a2a", color = NA),
    strip.text = ggplot2::element_text(color = "#e0e0e0", face = "bold")
  )

cat("Styling configured\n\n")

# ==============================================================================
# SUMMARY STATISTICS
# ==============================================================================

cat("=== COMPUTING SUMMARY STATISTICS ===\n")

summary_stats <- list(
  total_observations = nrow(obs),
  unique_species = n_distinct(obs$taxon_id, na.rm = TRUE),
  unique_observers = n_distinct(obs$observer_login),
  date_range = paste(format(date_min, "%B %d"), "-", format(date_max, "%d, %Y"))
)

summary_df <- tibble::tibble(
  Metric = c("Total Observations", "Unique Species", "Unique Observers", "Date Range"),
  Value = c(
    summary_stats$total_observations,
    summary_stats$unique_species,
    summary_stats$unique_observers,
    summary_stats$date_range
  )
)

readr::write_csv(summary_df, file.path(slides_dir, "summary.csv"))
cat("Summary statistics saved\n\n")

# ==============================================================================
# CREATE SUMMARY SLIDE WITH PHOTO BORDER
# ==============================================================================

cat("=== CREATING SUMMARY SLIDE WITH PHOTO BORDER ===\n")

summary_card_path <- file.path(slides_dir, "fig_summary_with_photos.png")

if (!file.exists(summary_card_path) || force_rebuild) {
  
  # Download sample species photos
  cat("Selecting diverse species photos...\n")
  
  # Get observations with photos, selecting diverse taxa
  obs_with_photos <- obs |>
    dplyr::filter(!is.na(taxon_id), taxon_rank == "species") |>
    dplyr::arrange(iconic_taxon, taxon_id)
  
  # Sample up to 12 diverse species (prefer different iconic taxa)
  set.seed(123)  # For reproducibility
  species_sample <- obs_with_photos |>
    dplyr::group_by(iconic_taxon) |>
    dplyr::slice_sample(n = 2) |>
    dplyr::ungroup() |>
    dplyr::slice_head(n = 12)
  
  # Get photo URLs from iNaturalist
  cat("Downloading species photos from iNaturalist...\n")
  species_photos_dir <- file.path(slides_dir, "species_photos")
  dir.create(species_photos_dir, showWarnings = FALSE, recursive = TRUE)
  
  species_photos <- list()
  for (i in seq_len(nrow(species_sample))) {
    obs_id <- species_sample$obs_id[i]
    
    tryCatch({
      # Fetch observation details to get photo URL
      obs_detail <- inat_get(paste0("observations/", obs_id))
      
      if (length(obs_detail$results) > 0 && length(obs_detail$results[[1]]$photos) > 0) {
        photo_url <- obs_detail$results[[1]]$photos[[1]]$url
        # Use medium size photo
        photo_url <- gsub("/square\\.", "/medium.", photo_url)
        
        # Download photo
        photo_path <- file.path(species_photos_dir, paste0("species_", i, ".jpg"))
        resp <- httr2::request(photo_url) |>
          httr2::req_user_agent("bioblitz-datadive") |>
          httr2::req_perform()
        writeBin(httr2::resp_body_raw(resp), photo_path)
        
        species_photos[[length(species_photos) + 1]] <- photo_path
        cat("  Downloaded species photo", i, "\n")
      }
    }, error = function(e) {
      cat("  Failed to download species photo", i, ":", conditionMessage(e), "\n")
    })
    
    # Rate limiting
    Sys.sleep(0.5)
  }
  
  cat("Downloaded", length(species_photos), "species photos\n")
  
  # Get observer profile photos (top 8 observers)
  cat("Selecting observer profile photos...\n")
  top_observers_for_border <- obs |>
    dplyr::count(observer_login, observer_name, observer_icon_url) |>
    dplyr::arrange(dplyr::desc(n)) |>
    dplyr::slice_head(n = 8) |>
    dplyr::filter(!is.na(observer_icon_url), observer_icon_url != "")
  
  observer_photos <- list()
  for (i in seq_len(nrow(top_observers_for_border))) {
    icon_url <- top_observers_for_border$observer_icon_url[i]
    photo_path <- file.path(species_photos_dir, paste0("observer_", i, ".jpg"))
    
    tryCatch({
      resp <- httr2::request(icon_url) |>
        httr2::req_user_agent("bioblitz-datadive") |>
        httr2::req_perform()
      writeBin(httr2::resp_body_raw(resp), photo_path)
      observer_photos[[length(observer_photos) + 1]] <- photo_path
      cat("  Downloaded observer photo", i, "\n")
    }, error = function(e) {
      cat("  Failed to download observer photo", i, "\n")
    })
  }
  
  cat("Downloaded", length(observer_photos), "observer photos\n")
  
  # Combine all photos for border
  all_border_photos <- c(species_photos, observer_photos)
  
  if (length(all_border_photos) > 0) {
    cat("Creating summary card with photo border...\n")
    
    # Create canvas
    card_width <- 1920
    card_height <- 1080
    canvas <- magick::image_blank(card_width, card_height, color = "#1a1a1a")
    
    # Photo border settings
    thumb_size <- 120
    border_padding <- 20
    
    # Calculate positions for photos around the border
    # Top edge
    top_positions <- list()
    n_top <- min(ceiling(length(all_border_photos) * 0.4), 8)
    if (n_top > 0) {
      spacing_x <- (card_width - 2 * border_padding) / (n_top + 1)
      for (i in 1:n_top) {
        top_positions[[i]] <- c(x = border_padding + i * spacing_x, y = border_padding + thumb_size/2)
      }
    }
    
    # Bottom edge  
    bottom_positions <- list()
    n_bottom <- min(ceiling(length(all_border_photos) * 0.4), 8)
    if (n_bottom > 0) {
      spacing_x <- (card_width - 2 * border_padding) / (n_bottom + 1)
      for (i in 1:n_bottom) {
        bottom_positions[[i]] <- c(x = border_padding + i * spacing_x, y = card_height - border_padding - thumb_size/2)
      }
    }
    
    # Left edge
    left_positions <- list()
    n_left <- min(ceiling(length(all_border_photos) * 0.1), 4)
    if (n_left > 0) {
      spacing_y <- (card_height - 2 * border_padding - 2 * thumb_size) / (n_left + 1)
      for (i in 1:n_left) {
        left_positions[[i]] <- c(x = border_padding + thumb_size/2, y = border_padding + thumb_size + i * spacing_y)
      }
    }
    
    # Right edge
    right_positions <- list()
    n_right <- min(ceiling(length(all_border_photos) * 0.1), 4)
    if (n_right > 0) {
      spacing_y <- (card_height - 2 * border_padding - 2 * thumb_size) / (n_right + 1)
      for (i in 1:n_right) {
        right_positions[[i]] <- c(x = card_width - border_padding - thumb_size/2, y = border_padding + thumb_size + i * spacing_y)
      }
    }
    
    all_positions <- c(top_positions, bottom_positions, left_positions, right_positions)
    
    # Place photos in circular frames around border
    for (i in seq_along(all_positions)) {
      if (i > length(all_border_photos)) break
      
      pos <- all_positions[[i]]
      photo_path <- all_border_photos[[i]]
      
      tryCatch({
        # Read and process image
        img <- magick::image_read(photo_path)
        
        # Crop to square
        info <- magick::image_info(img)
        size <- min(info$width, info$height)
        x_offset <- floor((info$width - size) / 2)
        y_offset <- floor((info$height - size) / 2)
        img <- magick::image_crop(img, paste0(size, "x", size, "+", x_offset, "+", y_offset))
        
        # Resize
        img <- magick::image_scale(img, paste0(thumb_size, "x", thumb_size, "!"))
        
        # Create circular mask
        mask_svg <- sprintf(
          '<svg width="%d" height="%d"><circle cx="%d" cy="%d" r="%d" fill="white"/></svg>',
          thumb_size, thumb_size, thumb_size/2, thumb_size/2, thumb_size/2
        )
        mask <- magick::image_read_svg(mask_svg, width = thumb_size, height = thumb_size)
        
        # Apply mask
        img_circle <- magick::image_composite(img, mask, operator = "DstIn")
        
        # Add border
        border_svg <- sprintf(
          '<svg width="%d" height="%d"><circle cx="%d" cy="%d" r="%d" fill="none" stroke="#3498DB" stroke-width="3"/></svg>',
          thumb_size, thumb_size, thumb_size/2, thumb_size/2, thumb_size/2 - 2
        )
        border_overlay <- magick::image_read_svg(border_svg, width = thumb_size, height = thumb_size)
        img_final <- magick::image_composite(img_circle, border_overlay, operator = "Over")
        
        # Composite onto canvas
        offset_x <- as.integer(pos[1] - thumb_size/2)
        offset_y <- as.integer(pos[2] - thumb_size/2)
        canvas <- magick::image_composite(canvas, img_final, offset = sprintf("+%d+%d", offset_x, offset_y))
      }, error = function(e) {
        cat("  Error placing photo", i, ":", conditionMessage(e), "\n")
      })
    }
    
    # Add centered statistics as styled cards
    center_y <- card_height / 2
    center_x <- card_width / 2
    
    # Create stats overlay using magick annotate
    canvas <- magick::image_annotate(canvas, 
                                     text = format(summary_stats$total_observations, big.mark = ","),
                                     size = 120,
                                     color = "#3498DB",
                                     font = "sans",
                                     weight = 700,
                                     location = sprintf("+%d+%d", center_x - 400, center_y - 200),
                                     gravity = "northwest"
    )
    canvas <- magick::image_annotate(canvas,
                                     text = "OBSERVATIONS",
                                     size = 30,
                                     color = "#b0b0b0",
                                     font = "sans",
                                     location = sprintf("+%d+%d", center_x - 400, center_y - 60),
                                     gravity = "northwest"
    )
    
    canvas <- magick::image_annotate(canvas,
                                     text = format(summary_stats$unique_species, big.mark = ","),
                                     size = 120,
                                     color = "#E74C3C",
                                     font = "sans",
                                     weight = 700,
                                     location = sprintf("+%d+%d", center_x + 100, center_y - 200),
                                     gravity = "northwest"
    )
    canvas <- magick::image_annotate(canvas,
                                     text = "SPECIES",
                                     size = 30,
                                     color = "#b0b0b0",
                                     font = "sans",
                                     location = sprintf("+%d+%d", center_x + 100, center_y - 60),
                                     gravity = "northwest"
    )
    
    canvas <- magick::image_annotate(canvas,
                                     text = format(summary_stats$unique_observers, big.mark = ","),
                                     size = 120,
                                     color = "#F39C12",
                                     font = "sans",
                                     weight = 700,
                                     location = sprintf("+%d+%d", center_x - 400, center_y + 50),
                                     gravity = "northwest"
    )
    canvas <- magick::image_annotate(canvas,
                                     text = "OBSERVERS",
                                     size = 30,
                                     color = "#b0b0b0",
                                     font = "sans",
                                     location = sprintf("+%d+%d", center_x - 400, center_y + 190),
                                     gravity = "northwest"
    )
    
    canvas <- magick::image_annotate(canvas,
                                     text = summary_stats$date_range,
                                     size = 40,
                                     color = "#90EE90",
                                     font = "sans",
                                     location = sprintf("+%d+%d", center_x + 100, center_y + 120),
                                     gravity = "northwest"
    )
    
    # Save
    magick::image_write(canvas, summary_card_path, format = "png")
    cat("Summary card with photo border created\n")
  } else {
    cat("No photos available for border, skipping summary card creation\n")
  }
} else {
  cat("Using cached summary card\n")
}

cat("\n")

# ==============================================================================
# CREATE SPATIAL DATA & BASE MAP (for Figure 6)
# ==============================================================================

cat("=== CREATING BASE MAP DATA ===\n")

# Create SF object
obs_sf_full <- sf::st_as_sf(
  obs |> dplyr::filter(!is.na(longitude), !is.na(latitude)),
  coords = c("longitude", "latitude"),
  crs = 4326,
  remove = FALSE
)

# HQ location
hq_sf <- sf::st_sf(
  name = "Bioblitz HQ",
  geometry = sf::st_sfc(sf::st_point(c(hq_lon, hq_lat)), crs = 4326)
)

# Calculate bounding box
bbox_all <- sf::st_bbox(obs_sf_full)

# Expand bbox with buffer
buffer_deg <- buffer_km / 111.0
bbox_expanded <- c(
  xmin = bbox_all[["xmin"]] - buffer_deg,
  ymin = bbox_all[["ymin"]] - buffer_deg,
  xmax = bbox_all[["xmax"]] + buffer_deg,
  ymax = bbox_all[["ymax"]] + buffer_deg
)

aoi <- sf::st_as_sfc(sf::st_bbox(bbox_expanded, crs = 4326))

# Fetch map tiles
cat("  Downloading base map tiles (provider:", map_provider, ")...\n")
sat <- maptiles::get_tiles(
  x = aoi,
  provider = map_provider,
  zoom = base_map_zoom,
  crop = TRUE,
  cachedir = tempdir(),
  verbose = FALSE
)

cat("  Satellite imagery downloaded\n")

# Fetch OSM data
cat("  Fetching OSM roads and waterways...\n")
osmdata::set_overpass_url("https://overpass-api.de/api/interpreter")

# Roads
roads_sf <- tryCatch({
  q <- osmdata::opq(bbox = as.numeric(bbox_expanded), timeout = 60)
  q <- osmdata::add_osm_feature(q, key = "highway",
                                value = c("motorway", "trunk", "primary", "secondary",
                                          "tertiary", "unclassified", "residential"))
  osm_data <- osmdata::osmdata_sf(q, quiet = TRUE)
  if (!is.null(osm_data$osm_lines) && nrow(osm_data$osm_lines) > 0) {
    osm_data$osm_lines
  } else {
    NULL
  }
}, error = function(e) {
  cat("  Warning: Could not fetch road data:", conditionMessage(e), "\n")
  NULL
})

# Waterways
water_sf <- tryCatch({
  q <- osmdata::opq(bbox = as.numeric(bbox_expanded), timeout = 60)
  q <- osmdata::add_osm_feature(q, key = "waterway", value = c("river", "stream"))
  osm_data <- osmdata::osmdata_sf(q, quiet = TRUE)
  if (!is.null(osm_data$osm_lines) && nrow(osm_data$osm_lines) > 0) {
    osm_data$osm_lines
  } else {
    NULL
  }
}, error = function(e) {
  cat("  Warning: Could not fetch waterway data:", conditionMessage(e), "\n")
  NULL
})

cat("  OSM data fetched\n\n")

# ==============================================================================
# FIGURE 1: OBSERVATION HOTSPOTS (JITTERED MAP)
# ==============================================================================

cat("=== GENERATING FIGURE 1: OBSERVATION HOTSPOTS ===\n")

fig1_path <- file.path(slides_dir, "fig_observation_hotspots_jittered.png")

if (!file.exists(fig1_path) || force_rebuild) {
  cat("Creating hotspots map...\n")
  
  obs_sf <- obs |>
    dplyr::filter(!is.na(longitude), !is.na(latitude)) |>
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  # Get bounding box and buffer it
  bbox <- sf::st_bbox(obs_sf)
  
  # Create buffered bbox as a proper sf bbox object
  bbox_buffered <- sf::st_bbox(
    c(xmin = as.numeric(bbox["xmin"]) - buffer_km/111,
      ymin = as.numeric(bbox["ymin"]) - buffer_km/111,
      xmax = as.numeric(bbox["xmax"]) + buffer_km/111,
      ymax = as.numeric(bbox["ymax"]) + buffer_km/111),
    crs = 4326
  )
  
  bbox_sf <- sf::st_as_sfc(bbox_buffered)
  
  tiles <- maptiles::get_tiles(bbox_sf, provider = map_provider, zoom = base_map_zoom, crop = TRUE)
  
  # Extract coordinates and add jitter manually
  obs_coords <- obs_sf |>
    dplyr::mutate(
      lon = sf::st_coordinates(geometry)[, 1] + runif(n(), -0.001, 0.001),
      lat = sf::st_coordinates(geometry)[, 2] + runif(n(), -0.001, 0.001)
    ) |>
    sf::st_drop_geometry()
  
  p1 <- ggplot2::ggplot() +
    tidyterra::geom_spatraster_rgb(data = tiles, maxcell = 5e5) +
    # Add OSM overlays
    {if (!is.null(water_sf) && nrow(water_sf) > 0) {
      ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.8)
    }} +
    {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
      ggplot2::geom_sf(data = roads_sf, colour = "gold", linewidth = 0.7)
    }} +
    ggplot2::geom_point(data = obs_coords,
                        ggplot2::aes(x = lon, y = lat, color = iconic_taxon),
                        alpha = 0.7, size = 3) +
    ggplot2::scale_color_manual(
      name = "Taxon Group",
      values = iconic_cols,
      labels = label_with_icon
    ) +
    ggplot2::coord_sf(crs = 4326, 
                      xlim = c(bbox_buffered["xmin"], bbox_buffered["xmax"]),
                      ylim = c(bbox_buffered["ymin"], bbox_buffered["ymax"]),
                      expand = FALSE) +
    ggplot2::labs(title = NULL) +  # Remove title (slide has it)
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
      panel.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
      text = ggplot2::element_text(color = "#e0e0e0"),
      axis.text = ggplot2::element_text(color = "#b0b0b0", size = axis_text_size),
      legend.position = "right",
      legend.background = ggplot2::element_rect(fill = "#2a2a2a", color = NA),
      legend.text = ggplot2::element_text(color = "#e0e0e0", size = legend_text_size),
      legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = legend_title_size),
      legend.key.size = ggplot2::unit(1.8, "cm"),
      legend.key = ggplot2::element_rect(fill = "#2a2a2a"),
      legend.spacing.y = ggplot2::unit(0.2, "cm"),
      panel.grid = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank()
    )
  
  ggplot2::ggsave(fig1_path, p1, width = map_fig_width, height = map_fig_height, dpi = 150, bg = "#1a1a1a")
  cat("Hotspots map saved\n")
} else {
  cat("Using cached hotspots map\n")
}

# ==============================================================================
# FIGURE 1B: OBSERVATION HOTSPOTS WITHOUT PLANTS (JITTERED MAP)
# ==============================================================================

cat("=== GENERATING FIGURE 1B: OBSERVATION HOTSPOTS (NO PLANTS) ===\n")

fig1b_path <- file.path(slides_dir, "fig_observation_hotspots_no_plants.png")

if (!file.exists(fig1b_path) || force_rebuild) {
  cat("Creating hotspots map without plants...\n")
  
  # Filter out Plantae to show rarer taxa more clearly
  obs_no_plants <- obs |>
    dplyr::filter(iconic_taxon != "Plantae")
  
  cat("  Observations without plants:", nrow(obs_no_plants), "of", nrow(obs), "\n")
  
  obs_sf_no_plants <- obs_no_plants |>
    dplyr::filter(!is.na(longitude), !is.na(latitude)) |>
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  # Use same bounding box as original map for consistency
  bbox <- sf::st_bbox(obs_sf)
  
  bbox_buffered <- sf::st_bbox(
    c(xmin = as.numeric(bbox["xmin"]) - buffer_km/111,
      ymin = as.numeric(bbox["ymin"]) - buffer_km/111,
      xmax = as.numeric(bbox["xmax"]) + buffer_km/111,
      ymax = as.numeric(bbox["ymax"]) + buffer_km/111),
    crs = 4326
  )
  
  bbox_sf <- sf::st_as_sfc(bbox_buffered)
  
  # Reuse the same tiles to save time
  tiles_no_plants <- maptiles::get_tiles(bbox_sf, provider = map_provider, zoom = base_map_zoom, crop = TRUE)
  
  # Extract coordinates and add jitter
  obs_coords_no_plants <- obs_sf_no_plants |>
    dplyr::mutate(
      lon = sf::st_coordinates(geometry)[, 1] + runif(n(), -0.001, 0.001),
      lat = sf::st_coordinates(geometry)[, 2] + runif(n(), -0.001, 0.001)
    ) |>
    sf::st_drop_geometry()
  
  # Filter iconic_cols to only include taxa that are present (excluding Plantae)
  taxa_present_no_plants <- unique(obs_coords_no_plants$iconic_taxon)
  iconic_cols_no_plants <- iconic_cols[names(iconic_cols) %in% taxa_present_no_plants]
  
  p1b <- ggplot2::ggplot() +
    tidyterra::geom_spatraster_rgb(data = tiles_no_plants, maxcell = 5e5) +
    # Add OSM overlays
    {if (!is.null(water_sf) && nrow(water_sf) > 0) {
      ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.8)
    }} +
    {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
      ggplot2::geom_sf(data = roads_sf, colour = "gold", linewidth = 0.7)
    }} +
    ggplot2::geom_point(data = obs_coords_no_plants,
                        ggplot2::aes(x = lon, y = lat, color = iconic_taxon),
                        alpha = 0.7, size = 3) +
    ggplot2::scale_color_manual(
      name = "Taxon Group",
      values = iconic_cols_no_plants,
      labels = label_with_icon
    ) +
    ggplot2::coord_sf(crs = 4326, 
                      xlim = c(bbox_buffered["xmin"], bbox_buffered["xmax"]),
                      ylim = c(bbox_buffered["ymin"], bbox_buffered["ymax"]),
                      expand = FALSE) +
    ggplot2::labs(title = NULL) +  # Remove title (slide has it)
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
      panel.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
      text = ggplot2::element_text(color = "#e0e0e0"),
      axis.text = ggplot2::element_text(color = "#b0b0b0", size = axis_text_size),
      legend.position = "right",
      legend.background = ggplot2::element_rect(fill = "#2a2a2a", color = NA),
      legend.text = ggplot2::element_text(color = "#e0e0e0", size = legend_text_size),
      legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = legend_title_size),
      legend.key.size = ggplot2::unit(1.8, "cm"),
      legend.key = ggplot2::element_rect(fill = "#2a2a2a"),
      legend.spacing.y = ggplot2::unit(0.2, "cm"),
      panel.grid = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank()
    )
  
  ggplot2::ggsave(fig1b_path, p1b, width = map_fig_width, height = map_fig_height, dpi = 150, bg = "#1a1a1a")
  cat("Hotspots map (no plants) saved\n")
} else {
  cat("Using cached hotspots map (no plants)\n")
}


# ==============================================================================
# FIGURE 2: OBSERVATIONS BY TAXON GROUP (BAR CHART OR TREEMAP)
# ==============================================================================

cat("=== GENERATING FIGURE 2: OBSERVATIONS BY TAXON ===\n")

fig2_path <- file.path(slides_dir, "fig_observations_by_taxon.png")

if (!file.exists(fig2_path) || force_rebuild) {
  taxon_counts <- obs |>
    dplyr::count(iconic_taxon, sort = TRUE)
  
  if (fig2_use_treemap) {
    # TREEMAP VERSION with icons and percentages
    cat("  Creating treemap...\n")
    taxon_counts <- taxon_counts |>
      dplyr::mutate(
        label_with_icon = label_with_icon(iconic_taxon),
        percentage = round(100 * n / sum(n), 1),
        display_label = paste0(label_with_icon, "\n", n, " obs\n(", percentage, "%)")
      )
    
    p2 <- ggplot2::ggplot(taxon_counts, 
                          ggplot2::aes(area = n, fill = iconic_taxon, label = display_label)) +
      treemapify::geom_treemap(color = "#1a1a1a", size = 3) +
      treemapify::geom_treemap_text(
        color = "white",
        place = "centre",
        size = 16,
        fontface = "bold",
        grow = FALSE,
        reflow = TRUE
      ) +
      ggplot2::scale_fill_manual(values = iconic_cols, guide = "none") +
      ggplot2::theme_void() +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
        panel.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
        plot.margin = ggplot2::margin(5, 5, 5, 5)
      )
    
  } else {
    # BAR CHART VERSION
    cat("  Creating bar chart...\n")
    taxon_counts <- taxon_counts |>
      dplyr::mutate(iconic_taxon = forcats::fct_reorder(iconic_taxon, n))
    
    p2 <- ggplot2::ggplot(taxon_counts, ggplot2::aes(x = n, y = iconic_taxon, fill = iconic_taxon)) +
      ggplot2::geom_col() +
      ggplot2::scale_fill_manual(values = iconic_cols) +
      ggplot2::labs(x = "Number of Observations", y = NULL) +
      base_theme +
      ggplot2::theme(legend.position = "none",
                     axis.text.y = ggplot2::element_text(size = axis_text_size, face = "bold"))
  }
  
  ggplot2::ggsave(fig2_path, p2, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#1a1a1a")
  cat("Taxon chart saved:", if(fig2_use_treemap) "treemap" else "bar chart", "\n")
} else {
  cat("Using cached taxon chart\n")
}

# ==============================================================================
# FIGURE 3: TOP OBSERVERS
# ==============================================================================

cat("=== GENERATING FIGURE 3: TOP OBSERVERS ===\n")

fig3_path <- file.path(slides_dir, "fig_top_observers.png")

if (!file.exists(fig3_path) || force_rebuild) {
  # Use display name if available, otherwise fall back to login username
  # Also get the first icon_url for each observer
  top_observers <- obs |>
    dplyr::mutate(observer_display = dplyr::coalesce(observer_name, observer_login)) |>
    dplyr::group_by(observer_display) |>
    dplyr::summarise(
      n = dplyr::n(),
      icon_url = dplyr::first(observer_icon_url[!is.na(observer_icon_url)]),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(n)) |>
    dplyr::slice_head(n = n_top_observers) |>
    dplyr::mutate(
      # Clean up icon URLs
      icon_url = dplyr::if_else(
        is.na(icon_url) | icon_url == "", 
        NA_character_,
        icon_url
      )
    ) |>
    dplyr::mutate(observer_display = forcats::fct_reorder(observer_display, n))
  
  # Download profile images locally (required to avoid 403 errors)
  cat("Downloading profile images for top observers...\n")
  profile_img_dir <- file.path(slides_dir, "profile_images")
  dir.create(profile_img_dir, showWarnings = FALSE, recursive = TRUE)
  
  # DEBUG: Show URLs
  cat("\nDEBUG - Profile image URLs:\n")
  print(top_observers |> dplyr::select(observer_display, icon_url))
  cat("\n")
  
  # Function to download image with proper user agent (like original script)
  dl_profile_image <- function(url, path) {
    if (is.na(url)) {
      cat("  Skipping NA URL for", basename(path), "\n")
      return(FALSE)
    }
    cat("  Downloading:", url, "\n")
    tryCatch({
      resp <- httr2::request(url) |> 
        httr2::req_user_agent("bioblitz-datadive") |> 
        httr2::req_perform()
      writeBin(httr2::resp_body_raw(resp), path)
      cat("    -> SUCCESS:", basename(path), "\n")
      TRUE
    }, error = function(e) {
      cat("    -> FAILED:", conditionMessage(e), "\n")
      FALSE
    })
  }
  
  # Function to crop image to circle
  crop_to_circle <- function(input_path, output_path) {
    if (!file.exists(input_path)) {
      cat("  Crop skipped - input doesn't exist:", basename(input_path), "\n")
      return(FALSE)
    }
    cat("  Cropping to circle:", basename(input_path), "\n")
    tryCatch({
      # Read image
      img <- magick::image_read(input_path)
      
      # Get dimensions
      info <- magick::image_info(img)
      size <- min(info$width, info$height)
      
      # Crop to square centered (accounting for non-square images)
      x_offset <- floor((info$width - size) / 2)
      y_offset <- floor((info$height - size) / 2)
      img <- magick::image_crop(img, paste0(size, "x", size, "+", x_offset, "+", y_offset))
      
      # Ensure exact square dimensions
      img <- magick::image_scale(img, paste0(size, "x", size, "!"))
      
      # Convert to format that supports transparency
      img <- magick::image_convert(img, format = "png", type = "TrueColorAlpha")
      
      # Create a circular mask using SVG (white circle only, no background)
      size_int <- as.integer(size)
      center_int <- as.integer(size / 2)
      radius_int <- center_int  # Full radius for perfect circle
      
      mask_svg <- sprintf(
        '<svg width="%d" height="%d" xmlns="http://www.w3.org/2000/svg"><circle cx="%d" cy="%d" r="%d" fill="white"/></svg>',
        size_int, size_int, center_int, center_int, radius_int
      )
      
      # Read the SVG mask
      mask <- magick::image_read_svg(mask_svg, width = size_int, height = size_int)
      
      # Apply the mask using DstIn composition
      # DstIn keeps destination (image) pixels where source (mask) is opaque
      # This creates the circular cutout effect
      img_circle <- magick::image_composite(
        img, 
        mask, 
        operator = "DstIn",
        gravity = "center"
      )
      
      # Add a crisp, anti-aliased border to the circular image
      # This creates a much cleaner look than using ggplot background circles
      border_width <- 2  # Border width in pixels (reduced for thinner borders)
      border_color <- "#3498DB"  # Match the lollipop color
      
      # ImageMagick's border function adds a crisp, anti-aliased stroke
      # We use image_border with a transparent background, then composite
      # Alternatively, use annotate to draw a circle stroke
      
      # Get the image size
      circle_info <- magick::image_info(img_circle)
      circle_size <- circle_info$width
      center <- circle_size / 2
      radius <- center - 1  # Slight inset so border is fully visible
      
      # Create an overlay with just the border stroke
      # Use SVG to draw a crisp circle outline
      border_svg <- sprintf(
        '<svg width="%d" height="%d" xmlns="http://www.w3.org/2000/svg"><circle cx="%d" cy="%d" r="%d" fill="none" stroke="%s" stroke-width="%d"/></svg>',
        circle_size, circle_size, as.integer(center), as.integer(center), 
        as.integer(radius), border_color, border_width
      )
      border_overlay <- magick::image_read_svg(border_svg, width = circle_size, height = circle_size)
      
      # Composite the border on top of the circular image
      img_with_border <- magick::image_composite(img_circle, border_overlay, operator = "Over")
      
      # Save as PNG with transparency
      magick::image_write(img_with_border, output_path, format = "png")
      
      # Verify the output file was created
      if (file.exists(output_path)) {
        cat("    -> SUCCESS:", basename(output_path), "\n")
        return(TRUE)
      } else {
        cat("    -> FAILED: Output file not created\n")
        return(FALSE)
      }
    }, error = function(e) {
      cat("    -> FAILED:", conditionMessage(e), "\n")
      return(FALSE)
    })
  }
  
  # Download each profile image and crop to circle
  top_observers <- top_observers |>
    dplyr::mutate(
      temp_img_path = file.path(profile_img_dir, paste0("observer_", dplyr::row_number(), "_temp.jpg")),
      local_img_path = file.path(profile_img_dir, paste0("observer_", dplyr::row_number(), "_circle.png")),
      img_downloaded = purrr::map2_lgl(icon_url, temp_img_path, dl_profile_image),
      img_cropped = purrr::map2_lgl(temp_img_path, local_img_path, crop_to_circle)
    )
  
  # Clean up temporary files
  purrr::walk(top_observers$temp_img_path[top_observers$img_downloaded], 
              ~if(file.exists(.x)) file.remove(.x))
  
  cat("Downloaded and cropped", sum(top_observers$img_cropped), "of", nrow(top_observers), "profile images to circles\n")
  
  # Create lollipop chart
  p3 <- ggplot2::ggplot(top_observers, ggplot2::aes(x = n, y = observer_display)) +
    # Lollipop sticks
    ggplot2::geom_segment(
      ggplot2::aes(x = 0, xend = n, y = observer_display, yend = observer_display),
      color = "#3498DB", 
      linewidth = 1.5
    ) +
    # Background circles ONLY for observers without profile images
    {if (any(!top_observers$img_cropped)) {
      ggplot2::geom_point(
        data = top_observers |> dplyr::filter(!img_cropped),
        color = "#3498DB",
        size = 20
      )
    }} +
    # Profile images with crisp borders (for observers WITH images)
    {if (any(top_observers$img_cropped)) {
      ggimage::geom_image(
        data = top_observers |> dplyr::filter(img_cropped),
        ggplot2::aes(image = local_img_path),
        size = 0.07,  # Doubled from 0.035
        asp = 1
      )
    }} +
    # Add observation count labels
    ggplot2::geom_text(
      ggplot2::aes(label = paste0(n, " obs")),
      hjust = -0.5,
      color = "#e0e0e0",
      size = 5,
      fontface = "bold"
    ) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.02, 0.15))) +
    ggplot2::labs(
      title = NULL,
      x = "Number of Observations", 
      y = NULL
    ) +
    base_theme +
    ggplot2::theme(
      axis.text.y = ggplot2::element_text(size = axis_text_size, face = "bold"),
      panel.grid.major.x = ggplot2::element_line(color = "#333333", linewidth = 0.3),
      panel.grid.major.y = ggplot2::element_blank()
    )
  
  ggplot2::ggsave(fig3_path, p3, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#1a1a1a")
  cat("Top observers lollipop chart saved with", sum(top_observers$img_cropped), "circular profile images with crisp borders\n")
} else {
  cat("Using cached observers chart\n")
}

# ==============================================================================
# FIGURE 4: OBSERVATIONS PER HOUR
# ==============================================================================

cat("=== GENERATING FIGURE 4: OBSERVATIONS PER HOUR ===\n")

fig4_path <- file.path(slides_dir, "fig_observations_by_hour.png")

if (!file.exists(fig4_path) || force_rebuild) {
  hour_data <- obs |>
    dplyr::filter(!is.na(time_observed_at)) |>
    dplyr::mutate(
      time_perth = lubridate::with_tz(time_observed_at, "Australia/Perth"),
      # Calculate decimal hour and round to nearest 0.5 hour
      hour_decimal = lubridate::hour(time_perth) + lubridate::minute(time_perth) / 60,
      hour = floor(hour_decimal * 2) / 2,  # Round to nearest 0.5
      day = as.Date(time_perth),
      # Add day of week to facet label
      day_label = paste0(format(day, "%A"), ", ", format(day, "%B %d, %Y"))
    ) |>
    dplyr::filter(day >= date_min, day <= date_max) |>
    dplyr::count(day, day_label, hour, name = "observations")
  
  # Get the y-axis maximum for positioning sun/moon symbols
  y_max <- max(hour_data$observations) * 1.05
  
  p4 <- ggplot2::ggplot(hour_data, ggplot2::aes(x = hour, y = observations)) +
    # Day/night background shading
    ggplot2::annotate("rect", 
                      xmin = 0, xmax = sunrise_hour,
                      ymin = -Inf, ymax = Inf,
                      fill = "#1a1a2e", alpha = 0.3) +  # Night (before sunrise)
    ggplot2::annotate("rect", 
                      xmin = sunset_hour, xmax = 24,
                      ymin = -Inf, ymax = Inf,
                      fill = "#1a1a2e", alpha = 0.3) +  # Night (after sunset)
    # Day shading (lighter)
    ggplot2::annotate("rect", 
                      xmin = sunrise_hour, xmax = sunset_hour,
                      ymin = -Inf, ymax = Inf,
                      fill = "#fff8e7", alpha = 0.15) +  # Day
    # Sun and moon symbols
    ggplot2::annotate("text", x = (sunrise_hour + sunset_hour)/2, y = y_max,
                      label = "☀", size = 8, color = "#FFD700") +  # Sun symbol
    ggplot2::annotate("text", x = (0 + sunrise_hour)/2, y = y_max,
                      label = "☾", size = 8, color = "#B0C4DE") +  # Moon symbol (before sunrise)
    ggplot2::annotate("text", x = (sunset_hour + 24)/2, y = y_max,
                      label = "☾", size = 8, color = "#B0C4DE") +  # Moon symbol (after sunset)
    # Data bars
    ggplot2::geom_col(fill = "#BF6C3B") +
    ggplot2::facet_wrap(~ day_label, ncol = 2, scales = "free_y") +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 24, 3),  # Show labels every 3 hours
      limits = c(0, 24),
      expand = c(0, 0)
    ) +
    ggplot2::labs(
      title = NULL,  # No title - slide title provides context
      x = "Hour of Day", 
      y = "Number of Observations"
    ) +
    theme_bioblitz(base_size = 16) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(colour = "#F7FAFC", face = "bold", size = legend_text_size),
      plot.title = ggplot2::element_text(size = plot_title_size, hjust = 0.5, 
                                         color = "#F7FAFC", face = "bold")
    )
  
  ggplot2::ggsave(fig4_path, p4, width = chart_fig_width, height = chart_fig_height, dpi = 300)
  cat("Half-hourly observations chart saved (with day/night indicators)\n")
} else {
  cat("Using cached hourly chart\n")
}

# ==============================================================================
# FIGURE 5: OBSERVATIONS PER HOUR (STACKED BY TAXON)
# ==============================================================================

cat("=== GENERATING FIGURE 5: OBSERVATIONS PER HOUR (STACKED) ===\n")

fig5_path <- file.path(slides_dir, "fig_observations_by_hour_stacked.png")

if (!file.exists(fig5_path) || force_rebuild) {
  hour_taxon_data <- obs |>
    dplyr::filter(!is.na(time_observed_at)) |>
    dplyr::mutate(
      time_perth = lubridate::with_tz(time_observed_at, "Australia/Perth"),
      # Calculate decimal hour and round to nearest 0.5 hour
      hour_decimal = lubridate::hour(time_perth) + lubridate::minute(time_perth) / 60,
      hour = floor(hour_decimal * 2) / 2,  # Round to nearest 0.5
      day = as.Date(time_perth),
      # Add day of week to facet label
      day_label = paste0(format(day, "%A"), ", ", format(day, "%B %d, %Y"))
    ) |>
    dplyr::filter(day >= date_min, day <= date_max) |>
    dplyr::count(day, day_label, hour, iconic_taxon, name = "observations")
  
  # Get the y-axis maximum for positioning sun/moon symbols
  hour_totals <- hour_taxon_data |>
    dplyr::group_by(day, day_label, hour) |>
    dplyr::summarise(total = sum(observations), .groups = "drop")
  y_max <- max(hour_totals$total) * 1.05
  
  p5 <- ggplot2::ggplot(hour_taxon_data,
                        ggplot2::aes(x = hour, y = observations, fill = iconic_taxon)) +
    # Day/night background shading
    ggplot2::annotate("rect", 
                      xmin = 0, xmax = sunrise_hour,
                      ymin = -Inf, ymax = Inf,
                      fill = "#1a1a2e", alpha = 0.3) +  # Night (before sunrise)
    ggplot2::annotate("rect", 
                      xmin = sunset_hour, xmax = 24,
                      ymin = -Inf, ymax = Inf,
                      fill = "#1a1a2e", alpha = 0.3) +  # Night (after sunset)
    # Day shading (lighter)
    ggplot2::annotate("rect", 
                      xmin = sunrise_hour, xmax = sunset_hour,
                      ymin = -Inf, ymax = Inf,
                      fill = "#fff8e7", alpha = 0.15) +  # Day
    # Sun and moon symbols
    ggplot2::annotate("text", x = (sunrise_hour + sunset_hour)/2, y = y_max,
                      label = "☀", size = 8, color = "#FFD700") +  # Sun symbol
    ggplot2::annotate("text", x = (0 + sunrise_hour)/2, y = y_max,
                      label = "☾", size = 8, color = "#B0C4DE") +  # Moon symbol (before sunrise)
    ggplot2::annotate("text", x = (sunset_hour + 24)/2, y = y_max,
                      label = "☾", size = 8, color = "#B0C4DE") +  # Moon symbol (after sunset)
    # Data bars
    ggplot2::geom_col() +
    ggplot2::facet_wrap(~ day_label, ncol = 2, scales = "free_y") +
    ggplot2::scale_x_continuous(
      breaks = seq(0, 24, 3),  # Show labels every 3 hours
      limits = c(0, 24),
      expand = c(0, 0)
    ) +
    ggplot2::scale_fill_manual(
      "Taxon Groups",
      values = iconic_cols,
      labels = label_with_icon
    ) +
    ggplot2::labs(
      title = NULL,  # No title - slide title provides context
      x = "Hour of Day", 
      y = "Number of Observations"
    ) +
    theme_bioblitz(base_size = 16) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(colour = "#F7FAFC", face = "bold", size = legend_text_size),
      plot.title = ggplot2::element_text(size = plot_title_size, hjust = 0.5, 
                                         color = "#F7FAFC", face = "bold"),
      legend.position = "right"
    )
  
  ggplot2::ggsave(fig5_path, p5, width = chart_fig_width, height = chart_fig_height, dpi = 300)
  cat("Half-hourly stacked chart saved (with day/night indicators)\n")
} else {
  cat("Using cached stacked chart\n")
}

# ==============================================================================
# FIGURE 6: ENHANCED TAXON RICHNESS ANALYSIS
# ==============================================================================
# This section generates three types of species richness visualizations:
# 1. Raw species richness per grid cell
# 2. Effort-corrected richness (species per observation)
# 3. Interpolated continuous surface (IDW interpolation)
# ==============================================================================

cat("=== GENERATING FIGURE 6: ENHANCED TAXON RICHNESS ANALYSIS ===\n")

# Define file paths for all three heatmap variants
fig6a_path <- file.path(slides_dir, "fig_richness_raw.png")
fig6b_path <- file.path(slides_dir, "fig_richness_effort_corrected.png")
fig6c_path <- file.path(slides_dir, "fig_richness_interpolated.png")

if (!file.exists(fig6a_path) || !file.exists(fig6b_path) || !file.exists(fig6c_path) || force_rebuild) {
  
  # ==============================================================================
  # PREPARE SPATIAL DATA
  # ==============================================================================
  
  cat("Preparing spatial data for richness analysis...\n")
  
  # Filter to species with coordinates
  species_data <- obs |>
    dplyr::filter(
      taxon_rank == rank_level,
      !is.na(taxon_id),
      !is.na(longitude),
      !is.na(latitude)
    ) |>
    dplyr::distinct(obs_id, taxon_id, longitude, latitude)
  
  cat("Species observations with coordinates:", nrow(species_data), "\n")
  cat("Unique species:", dplyr::n_distinct(species_data$taxon_id), "\n")
  
  if (nrow(species_data) >= 10) {
    
    # Create spatial object
    species_sf <- sf::st_as_sf(
      species_data,
      coords = c("longitude", "latitude"),
      crs = 4326,
      remove = FALSE
    )
    
    # ==============================================================================
    # CREATE GRID AND CALCULATE RICHNESS
    # ==============================================================================
    
    cat("Creating", grid_cell_size_m, "m grid and calculating richness...\n")
    
    # Use UTM projection for accurate metric grid
    utm_crs <- 32750  # UTM Zone 50S for Western Australia
    species_utm <- sf::st_transform(species_sf, utm_crs)
    aoi_utm <- sf::st_transform(aoi, utm_crs)
    
    # Create grid
    grid_utm <- sf::st_make_grid(
      aoi_utm, 
      cellsize = grid_cell_size_m, 
      what = "polygons", 
      square = TRUE
    )
    grid_utm <- sf::st_sf(grid_id = seq_along(grid_utm), geometry = grid_utm)
    
    cat("Total grid cells:", nrow(grid_utm), "\n")
    
    # Join observations to grid cells
    joined <- sf::st_join(species_utm, grid_utm, join = sf::st_within)
    
    # Calculate metrics per cell
    cell_metrics <- joined |>
      sf::st_drop_geometry() |>
      dplyr::filter(!is.na(grid_id)) |>
      dplyr::group_by(grid_id) |>
      dplyr::summarise(
        n_obs = dplyr::n(),
        richness = dplyr::n_distinct(taxon_id),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        richness_per_obs = richness / n_obs,
        data_quality = dplyr::case_when(
          n_obs >= warn_obs_per_cell ~ "Good",
          n_obs >= min_obs_per_cell ~ "Fair",
          TRUE ~ "Poor"
        )
      )
    
    # Join back to grid
    grid_richness <- dplyr::left_join(grid_utm, cell_metrics, by = "grid_id") |>
      dplyr::mutate(
        richness = dplyr::coalesce(richness, 0L),
        n_obs = dplyr::coalesce(n_obs, 0L),
        richness_per_obs = dplyr::if_else(n_obs > 0, richness / n_obs, NA_real_),
        data_quality = dplyr::coalesce(data_quality, "No data")
      ) |>
      sf::st_transform(4326)
    
    cells_with_data <- cell_metrics
    cat("Grid cells with data:", nrow(cells_with_data), "\n")
    
    # ==============================================================================
    # PLOT 1: RAW SPECIES RICHNESS
    # ==============================================================================
    
    cat("Creating raw richness map...\n")
    
    p6a <- ggplot2::ggplot() +
      tidyterra::geom_spatraster_rgb(data = sat, maxcell = 5e5) +
      {if (!is.null(water_sf) && nrow(water_sf) > 0) {
        ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.8)
      }} +
      {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
        ggplot2::geom_sf(data = roads_sf, colour = "gold", linewidth = 0.7)
      }} +
      ggplot2::geom_sf(
        data = grid_richness |> dplyr::filter(richness > 0),
        ggplot2::aes(fill = richness),
        colour = NA, 
        alpha = 0.6
      ) +
      ggplot2::coord_sf(
        xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]),
        ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]),
        expand = FALSE
      ) +
      viridis::scale_fill_viridis(
        name = "Species\nRichness",
        option = "magma",
        direction = -1,
        na.value = NA
      ) +
      ggplot2::theme_void(base_size = 16) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "black", colour = NA),
        legend.position = "right",
        legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
        legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
        legend.key.width = ggplot2::unit(1.5, "cm"),
        legend.key.height = ggplot2::unit(3, "cm")
      )
    
    ggplot2::ggsave(fig6a_path, p6a, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "black")
    cat("Raw richness map saved\n")
    
    # ==============================================================================
    # PLOT 2: EFFORT-CORRECTED RICHNESS
    # ==============================================================================
    
    cat("Creating effort-corrected richness map...\n")
    
    # Filter to cells with minimum observations
    grid_effort <- grid_richness |>
      dplyr::filter(n_obs >= min_obs_per_cell)
    
    if (nrow(grid_effort) > 0) {
      p6b <- ggplot2::ggplot() +
        tidyterra::geom_spatraster_rgb(data = sat, maxcell = 5e5) +
        {if (!is.null(water_sf) && nrow(water_sf) > 0) {
          ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.8)
        }} +
        {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
          ggplot2::geom_sf(data = roads_sf, colour = "gold", linewidth = 0.7)
        }} +
        ggplot2::geom_sf(
          data = grid_effort,
          ggplot2::aes(fill = richness_per_obs),
          colour = NA, 
          alpha = 0.6
        ) +
        ggplot2::coord_sf(
          xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]),
          ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]),
          expand = FALSE
        ) +
        viridis::scale_fill_viridis(
          name = "Species per\nObservation",
          option = "plasma",
          direction = -1,
          na.value = NA
        ) +
        ggplot2::theme_void(base_size = 16) +
        ggplot2::theme(
          plot.background = ggplot2::element_rect(fill = "black", colour = NA),
          legend.position = "right",
          legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
          legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
          legend.key.width = ggplot2::unit(1.5, "cm"),
          legend.key.height = ggplot2::unit(3, "cm")
        )
      
      ggplot2::ggsave(fig6b_path, p6b, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "black")
      cat("Effort-corrected richness map saved\n")
    } else {
      cat("No cells meet minimum observation threshold - skipping effort-corrected map\n")
    }
    
    # ==============================================================================
    # PLOT 3: INTERPOLATED RICHNESS SURFACE (if enabled)
    # ==============================================================================
    
    if (use_interpolation) {
      cat("Creating interpolated richness surface...\n")
      
      # Get unique observation locations - keep geometry before distinct
      obs_locations <- species_sf |>
        sf::st_transform(utm_crs) |>
        dplyr::distinct(longitude, latitude, .keep_all = TRUE)
      
      # Create buffers and calculate local richness
      location_buffers <- sf::st_buffer(obs_locations, dist = interp_buffer_m)
      
      location_richness <- purrr::map_dfr(seq_len(nrow(location_buffers)), function(i) {
        if (i %% 200 == 0) cat("  Processing location", i, "/", nrow(location_buffers), "\n")
        
        buffer <- location_buffers[i, ]
        obs_in_buffer <- sf::st_intersection(species_utm, buffer)
        
        if (nrow(obs_in_buffer) > 0) {
          n_obs <- nrow(obs_in_buffer)
          richness <- dplyr::n_distinct(obs_in_buffer$taxon_id)
          
          tibble::tibble(
            location_id = i,
            n_obs = n_obs,
            richness = richness,
            richness_per_obs = richness / n_obs,
            geometry = sf::st_geometry(obs_locations[i, ])
          )
        } else {
          NULL
        }
      })
      
      location_richness <- sf::st_as_sf(location_richness, crs = utm_crs)
      
      # Filter to locations with sufficient data
      location_richness_filtered <- location_richness |>
        dplyr::filter(n_obs >= min_obs_per_cell)
      
      cat("Locations for interpolation:", nrow(location_richness_filtered), "\n")
      
      if (nrow(location_richness_filtered) >= 10) {
        # Create observation mask
        obs_mask <- sf::st_buffer(
          sf::st_union(location_richness_filtered), 
          dist = mask_distance_m
        )
        
        obs_extent <- sf::st_bbox(obs_mask)
        
        # Create interpolation grid
        grid_x <- seq(obs_extent["xmin"], obs_extent["xmax"], by = interp_resolution)
        grid_y <- seq(obs_extent["ymin"], obs_extent["ymax"], by = interp_resolution)
        
        interp_grid <- expand.grid(x = grid_x, y = grid_y) |>
          sf::st_as_sf(coords = c("x", "y"), crs = utm_crs)
        
        # Perform IDW interpolation
        obs_coords <- sf::st_coordinates(location_richness_filtered)
        grid_coords <- sf::st_coordinates(interp_grid)
        
        cat("Performing IDW interpolation...\n")
        interpolated_values <- sapply(seq_len(nrow(interp_grid)), function(i) {
          if (i %% 10000 == 0) cat("  Point", i, "/", nrow(interp_grid), "\n")
          
          distances <- sqrt(
            (grid_coords[i, 1] - obs_coords[, 1])^2 + 
              (grid_coords[i, 2] - obs_coords[, 2])^2
          )
          
          if (any(distances < 1)) {
            location_richness_filtered$richness_per_obs[which.min(distances)]
          } else {
            weights <- 1 / (distances ^ idw_power)
            sum(weights * location_richness_filtered$richness_per_obs) / sum(weights)
          }
        })
        
        interp_grid$richness_per_obs <- interpolated_values
        
        # Convert to raster
        cat("Converting to raster...\n")
        interp_coords <- sf::st_coordinates(interp_grid)
        interp_df <- data.frame(
          x = interp_coords[, 1],
          y = interp_coords[, 2],
          richness_per_obs = interp_grid$richness_per_obs
        )
        
        interp_rast <- terra::rast(interp_df, type = "xyz", crs = paste0("EPSG:", utm_crs))
        
        # Mask to observation buffer
        obs_mask_vect <- terra::vect(obs_mask)
        interp_rast_masked <- terra::mask(interp_rast, obs_mask_vect)
        
        # Transform to WGS84
        interp_rast_wgs84 <- terra::project(interp_rast_masked, "EPSG:4326", method = "bilinear")
        
        # Create plot
        p6c <- ggplot2::ggplot() +
          tidyterra::geom_spatraster_rgb(data = sat, maxcell = 5e5) +
          {if (!is.null(water_sf) && nrow(water_sf) > 0) {
            ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.8)
          }} +
          {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
            ggplot2::geom_sf(data = roads_sf, colour = "gold", linewidth = 0.7)
          }} +
          tidyterra::geom_spatraster(
            data = interp_rast_wgs84,
            ggplot2::aes(fill = richness_per_obs),
            alpha = 0.7,
            maxcell = 5e5
          ) +
          ggplot2::coord_sf(
            xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]),
            ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]),
            expand = FALSE
          ) +
          viridis::scale_fill_viridis(
            name = "Species per\nObservation",
            option = "plasma",
            direction = -1,
            na.value = NA
          ) +
          ggplot2::theme_void(base_size = 16) +
          ggplot2::theme(
            plot.background = ggplot2::element_rect(fill = "black", colour = NA),
            legend.position = "right",
            legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
            legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
            legend.key.width = ggplot2::unit(1.5, "cm"),
            legend.key.height = ggplot2::unit(3, "cm")
          )
        
        ggplot2::ggsave(fig6c_path, p6c, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "black")
        cat("Interpolated surface map saved\n")
      } else {
        cat("Insufficient data points for interpolation\n")
      }
    }
    
    cat("Enhanced richness analysis complete\n")
  } else {
    cat("Not enough species data for richness analysis\n")
  }
} else {
  cat("Using cached richness maps\n")
}
# ==============================================================================
# FIGURE 7: RAREFACTION CURVE ANALYSIS
# ==============================================================================
# This section generates species accumulation curves showing how species
# richness increases with observation effort
# ==============================================================================

cat("=== GENERATING FIGURE 7: RAREFACTION CURVE ANALYSIS ===\n")

fig7a_path <- file.path(slides_dir, "fig_rarefaction_all_taxa.png")
fig7b_path <- file.path(slides_dir, "fig_rarefaction_by_group.png")

if (!file.exists(fig7a_path) || !file.exists(fig7b_path) || force_rebuild) {
  
  # Filter to observations with species-level ID
  obs_species <- obs |>
    dplyr::filter(
      taxon_rank == rarefaction_rank_level,
      !is.na(taxon_id)
    )
  
  cat("Observations for rarefaction:", nrow(obs_species), "\n")
  cat("Unique species:", dplyr::n_distinct(obs_species$taxon_id), "\n")
  
  if (nrow(obs_species) >= 10) {
    
    # ==============================================================================
    # COMPUTE RAREFACTION - ALL TAXA
    # ==============================================================================
    
    cat("Computing rarefaction curves (", n_permutations, " permutations)...\n", sep = "")
    
    # Function to compute rarefaction for one permutation
    compute_rarefaction <- function(obs_df, step_size = 10) {
      obs_shuffled <- obs_df[sample(nrow(obs_df)), ]
      sample_sizes <- seq(step_size, nrow(obs_shuffled), by = step_size)
      
      purrr::map_dfr(sample_sizes, function(n) {
        obs_subset <- obs_shuffled[1:n, ]
        n_taxa <- dplyr::n_distinct(obs_subset$taxon_id)
        tibble::tibble(n_observations = n, n_taxa = n_taxa)
      })
    }
    
    # Run permutations
    set.seed(42)  # For reproducibility
    rarefaction_results <- purrr::map_dfr(1:n_permutations, function(perm) {
      if (perm %% 20 == 0) cat("  Permutation", perm, "/", n_permutations, "\n")
      compute_rarefaction(obs_species, step_size = step_size) |>
        dplyr::mutate(permutation = perm)
    })
    
    # Calculate summary statistics
    rarefaction_summary <- rarefaction_results |>
      dplyr::group_by(n_observations) |>
      dplyr::summarise(
        mean_taxa = mean(n_taxa),
        lower_95 = quantile(n_taxa, 0.025),
        upper_95 = quantile(n_taxa, 0.975),
        lower_50 = quantile(n_taxa, 0.25),
        upper_50 = quantile(n_taxa, 0.75),
        .groups = "drop"
      )
    
    cat("Rarefaction computed\n")
    
    # ==============================================================================
    # PLOT 1: ALL TAXA RAREFACTION
    # ==============================================================================
    
    cat("Creating all taxa rarefaction plot...\n")
    
    # Create dark theme
    theme_rarefaction <- ggplot2::theme_minimal(base_size = 14) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
        panel.background = ggplot2::element_rect(fill = "#1a1a1a", color = NA),
        panel.grid.major = ggplot2::element_line(color = "#333333", linewidth = 0.3),
        panel.grid.minor = ggplot2::element_line(color = "#2a2a2a", linewidth = 0.2),
        text = ggplot2::element_text(color = "#e0e0e0"),
        axis.text = ggplot2::element_text(color = "#b0b0b0"),
        axis.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = axis_title_size),
        plot.title = ggplot2::element_text(color = "#ffffff", face = "bold", size = 20),
        plot.subtitle = ggplot2::element_text(color = "#b0b0b0", size = 14),
        legend.background = ggplot2::element_rect(fill = "#2a2a2a", color = NA),
        legend.text = ggplot2::element_text(color = "#e0e0e0"),
        legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold")
      )
    
    p7a <- ggplot2::ggplot(rarefaction_summary, 
                           ggplot2::aes(x = n_observations, y = mean_taxa)) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_95, ymax = upper_95),
                           fill = "#3498DB", alpha = 0.2) +
      ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_50, ymax = upper_50),
                           fill = "#3498DB", alpha = 0.4) +
      ggplot2::geom_line(data = rarefaction_results,
                         ggplot2::aes(x = n_observations, y = n_taxa, group = permutation),
                         color = "#3498DB", alpha = 0.05, linewidth = 0.3) +
      ggplot2::geom_line(color = "#3498DB", linewidth = 1.5) +
      ggplot2::scale_x_continuous(
        labels = scales::comma,
        expand = ggplot2::expansion(mult = c(0.02, 0.02))
      ) +
      ggplot2::scale_y_continuous(
        labels = scales::comma,
        expand = ggplot2::expansion(mult = c(0.02, 0.05))
      ) +
      ggplot2::labs(
        x = "Number of Observations",
        y = paste("Number of Unique", stringr::str_to_title(rarefaction_rank_level))
      ) +
      theme_rarefaction
    
    ggplot2::ggsave(fig7a_path, p7a, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#1a1a1a")
    cat("All taxa rarefaction plot saved\n")
    
    # ==============================================================================
    # COMPUTE RAREFACTION BY GROUP
    # ==============================================================================
    
    cat("Computing rarefaction by taxonomic group...\n")
    
    # Classify into major groups
    obs_grouped <- obs_species |>
      dplyr::mutate(
        major_group = dplyr::case_when(
          iconic_taxon %in% c("Plantae", "Chromista") ~ "Plants",
          iconic_taxon == "Fungi" ~ "Fungi",
          TRUE ~ "Animals"
        )
      )
    
    # Count observations per group
    group_counts <- obs_grouped |>
      dplyr::count(major_group, name = "n_obs") |>
      dplyr::mutate(
        data_quality = dplyr::case_when(
          n_obs >= min_obs_reliable ~ "Reliable",
          n_obs >= min_obs_warning ~ "Warning",
          TRUE ~ "Poor"
        )
      )
    
    cat("Group sample sizes:\n")
    print(group_counts)
    
    # Compute rarefaction for each group with sufficient data
    group_rarefaction <- list()
    
    for (group in group_counts$major_group[group_counts$n_obs >= 10]) {
      cat("  Processing", group, "...\n")
      
      group_obs <- obs_grouped |> dplyr::filter(major_group == group)
      
      group_results <- purrr::map_dfr(1:n_permutations, function(perm) {
        compute_rarefaction(group_obs, step_size = step_size) |>
          dplyr::mutate(permutation = perm)
      })
      
      group_summary <- group_results |>
        dplyr::group_by(n_observations) |>
        dplyr::summarise(
          mean_taxa = mean(n_taxa),
          lower_95 = quantile(n_taxa, 0.025),
          upper_95 = quantile(n_taxa, 0.975),
          lower_50 = quantile(n_taxa, 0.25),
          upper_50 = quantile(n_taxa, 0.75),
          .groups = "drop"
        ) |>
        dplyr::mutate(group = group)
      
      group_rarefaction[[group]] <- list(
        results = group_results |> dplyr::mutate(group = group),
        summary = group_summary
      )
    }
    
    # ==============================================================================
    # PLOT 2: RAREFACTION BY GROUP
    # ==============================================================================
    
    if (length(group_rarefaction) > 0) {
      cat("Creating group comparison rarefaction plot...\n")
      
      # Combine all group summaries
      all_group_summaries <- purrr::map_dfr(group_rarefaction, ~.x$summary)
      all_group_results <- purrr::map_dfr(group_rarefaction, ~.x$results)
      
      # Assign colors
      group_colors <- c(
        "Plants" = "#2ECC71",  # Green
        "Fungi" = "#E67E22",   # Orange
        "Animals" = "#3498DB"  # Blue
      )
      
      p7b <- ggplot2::ggplot(all_group_summaries, 
                             ggplot2::aes(x = n_observations, y = mean_taxa, 
                                          color = group, fill = group)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_95, ymax = upper_95),
                             alpha = 0.2, color = NA) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = lower_50, ymax = upper_50),
                             alpha = 0.3, color = NA) +
        ggplot2::geom_line(data = all_group_results,
                           ggplot2::aes(x = n_observations, y = n_taxa, 
                                        group = interaction(group, permutation)),
                           alpha = 0.03, linewidth = 0.2) +
        ggplot2::geom_line(linewidth = 1.5) +
        ggplot2::scale_color_manual(values = group_colors, name = "Group") +
        ggplot2::scale_fill_manual(values = group_colors, name = "Group") +
        ggplot2::scale_x_continuous(
          labels = scales::comma,
          expand = ggplot2::expansion(mult = c(0.02, 0.02))
        ) +
        ggplot2::scale_y_continuous(
          labels = scales::comma,
          expand = ggplot2::expansion(mult = c(0.02, 0.05))
        ) +
        ggplot2::labs(
          x = "Number of Observations",
          y = paste("Number of Unique", stringr::str_to_title(rarefaction_rank_level))
        ) +
        theme_rarefaction +
        ggplot2::theme(
          legend.position = "right",
          legend.key.size = ggplot2::unit(1.5, "lines")
        )
      
      ggplot2::ggsave(fig7b_path, p7b, width = 14, height = 8, dpi = 300, bg = "#1a1a1a")
      cat("Group rarefaction plot saved\n")
    } else {
      cat("No groups had sufficient data for group comparison\n")
    }
    
    cat("Rarefaction analysis complete\n")
  } else {
    cat("Not enough observations for rarefaction analysis\n")
  }
} else {
  cat("Using cached rarefaction plots\n")
}

# ==============================================================================
# CUSTOM CSS FOR PRESENTATION
# ==============================================================================

cat("=== CREATING CUSTOM CSS ===\n")

# Use paste0() instead of glue() to avoid delimiter conflicts
css_content <- paste0('
/* Custom CSS for Bioblitz Data Dive Presentation */

.reveal .welcome-slide {
  background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
}

.reveal .welcome-slide .title-text {
  display: block !important;
  color: #ffffff !important;
  font-size: 72px !important;
  font-weight: bold !important;
  margin: 0.5em 0 0.3em 0 !important;
  text-align: center !important;
  text-shadow: 3px 3px 6px rgba(0, 0, 0, 0.7) !important;
}

.reveal .slides section.welcome-slide .date-text {
  display: block !important;
  font-size: 36px !important;
  color: #90EE90 !important;
  margin-top: 0.5em !important;
  text-align: center !important;
  font-weight: normal !important;
}

.reveal .slides .welcome-slide .date-text p {
  color: #90EE90 !important;
}

.reveal .welcome-slide .date-text * {
  color: #90EE90 !important;
}

.logo-container {
  text-align: center;
  margin: 2em 0;
}

.logo-container img {
  max-width: 400px;
  border-radius: 10px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}

/* Slide title styling - configurable size */
.reveal h2 {
  color: #ffffff !important;
  font-size: ', slide_title_size, 'px !important;
  font-weight: bold !important;
  margin-bottom: 0.1em !important;
  line-height: 1.2 !important;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5) !important;
}

/* Slide subtitle styling - half size, italics, as block element */
.reveal .subtitle {
  display: block !important;
  width: 100% !important;
  color: #b0b0b0 !important;
  font-size: ', slide_subtitle_size, 'px !important;
  font-weight: normal !important;
  font-style: italic !important;
  margin-top: 0 !important;
  margin-bottom: 1em !important;
  padding-top: 0 !important;
  text-align: center !important;
  line-height: 1.3 !important;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5) !important;
}

.reveal table {
  margin: 1em auto;
  border-collapse: collapse;
}

.reveal table th {
  background-color: #2a2a2a;
  color: #ffffff;
  font-weight: bold;
  padding: 0.8em;
  border-bottom: 2px solid #3498DB;
}

.reveal table td {
  padding: 0.6em;
  border-bottom: 1px solid #333333;
}

.reveal table tr:hover {
  background-color: #2a2a2a;
}

.reveal img {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
}

.reveal-viewport {
  background: #1a1a1a;
}

.reveal .slides {
  text-align: center;
}
')

css_path <- file.path(styles_dir, "custom.css")

if (file.exists(css_path)) {
  cat("Deleting old CSS file...\n")
  file.remove(css_path)
}

writeLines(css_content, css_path)
cat("CSS file written:", css_path, "\n")
cat("  File size:", file.size(css_path), "bytes\n\n")

# ==============================================================================
# GENERATE QUARTO PRESENTATION - WITH SUBTITLES
# ==============================================================================

cat("=== GENERATING QUARTO PRESENTATION ===\n")

# Check if logo exists to determine title slide format
logo_exists <- file.exists(bioblitz_logo)
cat("Logo file check:", if(logo_exists) "FOUND" else "NOT FOUND", "\n")
cat("  Path checked:", bioblitz_logo, "\n")

# Generate QMD with conditional title slide
# Use paste0() to avoid glue() delimiter conflicts with R code chunks
if (logo_exists) {
  # Logo provided: Use graphic title slide with date subtitle
  cat("Using graphic title slide with logo\n")
  qmd_content <- paste0('
---
title: ""
format:
  revealjs:
    theme: [simple, night]
    slide-number: true
    transition: slide
    controls: true
css:
  - styles/custom.css
execute:
  echo: false
  warning: false
  message: false
---

## {.welcome-slide}

<div class="logo-container">
![](logo.jpg)
</div>

<div class="title-text">Data Dive</div>

<div class="date-text" style="color: #90EE90 !important; font-size: 36px !important;">', summary_stats$date_range, '</div>

## Summary

![](fig_summary_with_photos.png)

## Observation Hotspots

![](fig_observation_hotspots_jittered.png)

## Observation Hotspots

<div class="subtitle">excluding plants</div>

![](fig_observation_hotspots_no_plants.png)

## Observations by Taxon Group

![](fig_observations_by_taxon.png)

## Top Observers

![](fig_top_observers.png)

## Observations per Half Hour

![](fig_observations_by_hour.png)

## Observations per Half Hour

<div class="subtitle">by taxon group</div>

![](fig_observations_by_hour_stacked.png)

## Taxon Richness Heatmap

## Species Accumulation Curve
<div class="subtitle">all taxa combined</div>

![](fig_rarefaction_all_taxa.png)

## Species Accumulation by Group
<div class="subtitle">plants, fungi, and animals</div>

![](fig_rarefaction_by_group.png)

## Species Richness (Raw)
<div class="subtitle">grid-based analysis</div>

![](fig_richness_raw.png)

## Species Richness (Effort-Corrected)
<div class="subtitle">species per observation</div>

![](fig_richness_effort_corrected.png)

## Species Richness (Interpolated Surface)
<div class="subtitle">smooth continuous surface</div>

![](fig_richness_interpolated.png)

')
} else {
  # No logo: Use text-only title slide
  cat("Using text-only title slide (no logo provided)\n")
  qmd_content <- paste0('
---
title: ""
format:
  revealjs:
    theme: [simple, night]
    slide-number: true
    transition: slide
    controls: true
css:
  - styles/custom.css
execute:
  echo: false
  warning: false
  message: false
---

## ', bioblitz_name, ' Bioblitz ', bioblitz_year, '

<span class="small">Data Dive: ', summary_stats$date_range, '</span>

## Summary

![](fig_summary_with_photos.png)

## Observation Hotspots

![](fig_observation_hotspots_jittered.png)

## Observation Hotspots

<div class="subtitle">excluding plants</div>

![](fig_observation_hotspots_no_plants.png)

## Observations by Taxon Group

![](fig_observations_by_taxon.png)

## Top Observers

![](fig_top_observers.png)

## Observations per Half Hour

![](fig_observations_by_hour.png)

## Observations per Half Hour

<div class="subtitle">by taxon group</div>

![](fig_observations_by_hour_stacked.png)

## Taxon Richness Heatmap

## Species Accumulation Curve
<div class="subtitle">all taxa combined</div>

![](fig_rarefaction_all_taxa.png)

## Species Accumulation by Group
<div class="subtitle">plants, fungi, and animals</div>

![](fig_rarefaction_by_group.png)

## Species Richness (Raw)
<div class="subtitle">grid-based analysis</div>

![](fig_richness_raw.png)

## Species Richness (Effort-Corrected)
<div class="subtitle">species per observation</div>

![](fig_richness_effort_corrected.png)

## Species Richness (Interpolated Surface)
<div class="subtitle">smooth continuous surface</div>

![](fig_richness_interpolated.png)
')
}

qmd_path <- file.path(slides_dir, "data_dive_presentation.qmd")

if (file.exists(qmd_path)) {
  cat("Deleting old QMD file...\n")
  file.remove(qmd_path)
}

writeLines(qmd_content, qmd_path)
cat("QMD file written:", qmd_path, "\n")
cat("  File size:", file.size(qmd_path), "bytes\n\n")

# VALIDATION - Verify the file was written correctly
cat("=== CRITICAL VALIDATION ===\n")
qmd_check <- readLines(qmd_path)

has_double_hash <- any(grepl("^## ", qmd_check))
has_single_hash_summary <- any(grepl("^# Summary", qmd_check))
has_triple_dash_separator <- any(grepl("^---$", qmd_check[20:50]))

cat("QMD file structure check:\n")
cat("  * Uses ## headers:", has_double_hash, ifelse(has_double_hash, " - CORRECT", " - ERROR"), "\n")
cat("  * Has # Summary (wrong):", has_single_hash_summary, ifelse(!has_single_hash_summary, " - CORRECT", " - ERROR"), "\n")
cat("  * Has --- separators (wrong):", has_triple_dash_separator, ifelse(!has_triple_dash_separator, " - CORRECT", " - ERROR"), "\n")

slide_count <- sum(grepl("^## ", qmd_check))
cat("  Number of ## slides:", slide_count, "(expected: 13 - 1 welcome + 12 content)\n\n")

cat("Headers found in file:\n")
header_lines <- grep("^##? ", qmd_check)
for (line_num in header_lines) {
  cat("  Line", line_num, ":", qmd_check[line_num], "\n")
}

if (!has_double_hash || has_single_hash_summary || has_triple_dash_separator) {
  cat("\n!!! ERROR: QMD format incorrect !!!\n\n")
} else {
  cat("\n*** QMD VALIDATION PASSED ***\n")
  cat("All slides use proper ## headers for horizontal navigation\n\n")
}

# Copy logo if it exists
if (logo_exists) {
  logo_dest <- file.path(slides_dir, "logo.jpg")
  if (!file.exists(logo_dest)) {
    file.copy(bioblitz_logo, logo_dest)
    cat("Logo copied to slides directory\n")
  } else {
    cat("Logo already exists in slides directory\n")
  }
} else {
  cat("No logo to copy (none provided)\n")
}

# ==============================================================================
# RENDER PRESENTATIONS
# ==============================================================================

if (requireNamespace("quarto", quietly = TRUE)) {
  
  # Render HTML slideshow
  if (render_html) {
    cat("\n=== RENDERING HTML PRESENTATION ===\n")
    tryCatch({
      quarto::quarto_render(qmd_path, output_format = "revealjs", quiet = FALSE)
      html_file <- sub("\\.qmd$", ".html", qmd_path)
      if (file.exists(html_file)) {
        cat("\n*** HTML SUCCESS ***\n")
        cat("HTML presentation created:", html_file, "\n")
        cat("  File size:", round(file.size(html_file)/1024), "KB\n\n")
      }
    }, error = function(e) {
      cat("\nHTML render failed:", conditionMessage(e), "\n")
      cat("Render manually with: quarto render", qmd_path, "\n\n")
    })
  }
  
  # Render PowerPoint slideshow
  if (render_powerpoint) {
    cat("\n=== RENDERING POWERPOINT PRESENTATION ===\n")
    tryCatch({
      quarto::quarto_render(qmd_path, output_format = "pptx", quiet = FALSE)
      pptx_file <- sub("\\.qmd$", ".pptx", qmd_path)
      if (file.exists(pptx_file)) {
        cat("\n*** POWERPOINT SUCCESS ***\n")
        cat("PowerPoint presentation created:", pptx_file, "\n")
        cat("  File size:", round(file.size(pptx_file)/1024), "KB\n")
        cat("\nYou can now open and edit this file in PowerPoint!\n\n")
      }
    }, error = function(e) {
      cat("\nPowerPoint render failed:", conditionMessage(e), "\n")
      cat("Render manually with: quarto render", qmd_path, "--to pptx\n\n")
    })
  }
  
  if (!render_html && !render_powerpoint) {
    cat("\nNo output formats selected. Set render_html or render_powerpoint to TRUE.\n\n")
  }
  
} else {
  cat("\nQuarto package not available\n")
  cat("Install with: install.packages('quarto')\n")
}

cat("\n=== DATA DIVE COMPLETE ===\n")
cat("Script Version: 4.0 - ENHANCED SPATIAL & RAREFACTION ANALYSIS\n")
cat("Output directory:", normalizePath(out_dir), "\n")
cat("Slides directory:", normalizePath(slides_dir), "\n")

cat("\n=== KEY UPDATES ===\n")
cat("* ENHANCED SPATIAL ANALYSIS:\n")
cat("  - Three types of richness maps: raw, effort-corrected, interpolated\n")
cat("  - Grid-based analysis with data quality metrics\n")
cat("  - IDW interpolation for smooth continuous surfaces\n")
cat("  - Masked to observation areas (no extrapolation to water/unsampled areas)\n")
cat("* RAREFACTION CURVES:\n")
cat("  - Species accumulation curves with confidence intervals\n")
cat("  - Comparison across major taxonomic groups\n")
cat("  - Assessment of sampling completeness\n")
if (logo_exists) {
  cat("  - Logo displayed prominently\n")
} else {
  cat("  - Text-only title slide (no logo)\n")
}
cat("* Content slide subtitles: 'excluding plants' and 'by taxon group'\n")

cat("\n=== TITLE SLIDE BEHAVIOR ===\n")
cat("To use graphic title slide:\n")
cat("  1. Set bioblitz_logo variable to your logo file path\n")
cat("  2. Make sure the file exists before running the script\n")
cat("  3. Script will use logo slide with date subtitle\n")
cat("\nTo use text-only title slide:\n")
cat("  1. Set bioblitz_logo to a non-existent file or empty string\n")
cat("  2. Script will use simple text title slide\n")
cat("  3. No graphic title slide will be generated\n\n")

cat("=== SCRIPT COMPLETE ===\n")
