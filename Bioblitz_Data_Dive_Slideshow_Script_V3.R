# ==============================================================================
# iNaturalist Bioblitz - Data Dive Analysis
#
# Companion to the photo slideshow (Bioblitz_Slideshow_Script_V4.R). Shares the
# same iNaturalist project, HQ location, map styling and outputs/ layout, so the
# two decks can be run and shown together. Produces a Quarto reveal.js deck (and
# a matching .pptx) covering taxon breakdown, richness, rarefaction, spatial
# hotspots, rank abundance and species tiers.
# ==============================================================================

cat("=== DATA DIVE SCRIPT STARTING ===\n\n")

# If run in RStudio, anchor the working directory to THIS script's folder so that
# bioblitz_style.R and the relative output paths resolve regardless of where R started.
try(if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable())
      setwd(dirname(rstudioapi::getSourceEditorContext()$path)), silent = TRUE)
cat("Working directory:", getwd(), "\n")

# ==============================================================================
# CONFIGURATION - EDIT THESE SETTINGS
# ==============================================================================

# --- Project Settings ---
project_slug <- "walpole-wilderness-bioblitz-2025"

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

# --- Bioblitz Identity (shown on the title slide) ---
bioblitz_name <- "Walpole Wilderness Bioblitz"   # Your bioblitz name, as it should appear on the title
bioblitz_year <- format(date_min, "%Y")           # Auto-filled from your event dates; or set manually, e.g. "2025"

# --- Output Settings ---
# Derived from project_slug so each bioblitz gets its own cache + outputs; running
# different bioblitzes sequentially will not cross-contaminate obs/OSM/figures.
out_dir <- file.path("outputs", paste0(gsub("[^a-z0-9]+", "_", tolower(project_slug)), "_data_dive"))
slides_dir <- file.path(out_dir, "slides")
styles_dir <- file.path(slides_dir, "styles")   # must sit beside the qmd so the css: link resolves
base_map_dir <- file.path(out_dir, "base_map_cache")  # persistent satellite-tile + OSM cache (survives figure rebuilds)

# --- Map Settings ---
base_map_zoom <- 14    # Zoom level for satellite imagery (higher = more detail)
buffer_km <- 2.5       # Buffer around observations in kilometers for map extent (optimized for tighter framing)

# --- Force rebuild ---
force_rebuild <- FALSE      # Set TRUE to regenerate all figures even if cached (revert to FALSE after a full run)
use_cached_data <- TRUE    # Set FALSE to fetch fresh data from iNaturalist

# --- Map caching ---
# Satellite tiles and OSM overlays are expensive network fetches. They are
# cached on disk under base_map_cache/ and reused even when force_rebuild
# rebuilds the figures, so a slide rebuild does not re-download them. Set this
# TRUE only when the map area or the OSM data has actually changed.
force_refetch_maps <- FALSE
force_refetch_photos <- FALSE  # TRUE = re-download species/observer/showcase photos.
                               # Leave FALSE to reuse cached photos even when
                               # force_rebuild rebuilds the figures.
vary_summary_photos  <- TRUE   # TRUE = vary the slide-2 border photos between runs
                               #        (fresh species sample + shuffled order);
                               #        FALSE = fixed/reproducible (seed 123).

# --- Output Format Options ---
render_html <- TRUE        # Generate HTML slideshow (revealjs)
render_powerpoint <- FALSE  # Generate PowerPoint (.pptx) for manual editing
render_pdf <- FALSE         # Generate a PDF copy of the HTML deck (needs Chrome + chromote)
pdf_wait_s <- 6            # Seconds to let figures/fonts settle before printing.
                           #   Raise this if the PDF comes out with blank/partial slides.
pdf_timeout_s <- 300       # Seconds Chrome gets to rasterise the PDF. chromote defaults
                           #   to only 10s, which a figure-heavy deck blows straight past.
pdf_max_px <- 1600         # Longest edge (px) for figures IN THE PDF ONLY. Figures are saved
                           #   at 300 dpi (maps reach 4500px) but never display taller than
                           #   700px, so the PDF embeds ~10x more pixels than it can show.
                           #   Figures are downsampled into a temporary copy of the deck just
                           #   for printing; the HTML deck and the PNGs are left untouched.
                           #   1200 = smaller, 2400 = sharper, 0 = off (print at full size).

# --- Slideshow Timing (revealjs auto-advance, matches the photo slideshow) ---
auto_advance_ms      <- 15000   # Auto-advance time in milliseconds (7000 = 7 seconds; 0 = disabled)
auto_slide_stoppable <- TRUE   # Allow the viewer to pause auto-advance (press A, or interact)
slideshow_loop       <- TRUE   # Loop back to the first slide when the deck reaches the end

# --- Figure 2 Display Option ---
fig2_use_treemap <- TRUE  # TRUE = treemap, FALSE = bar chart for observations by taxon

# --- Figure 3 Display Option ---
n_top_observers <- 15  # Number of top observers to display in the chart

# --- Title Formatting Options ---
plot_title_size <- 34        # Main title font size (points) for charts
plot_subtitle_size <- 22     # Subtitle font size (points) for charts

# --- Figure Dimensions (optimized for presentation) ---
map_fig_width <- 15          # Width for map figures (inches)
map_fig_height <- 10         # Height for map figures (inches)
chart_fig_width <- 12        # Width for chart figures (inches) 
chart_fig_height <- 8        # Height for chart figures (inches)

# --- Legend Settings (optimized for legibility) ---
legend_text_size <- 22       # Legend text size (points)
legend_title_size <- 26      # Legend title size (points)
axis_text_size <- 26         # Axis text size (points)
axis_title_size <- 30         # Axis title size (points)
chart_base_size <- 28        # Base font size for theme_bioblitz charts
legend_ncol <- 2             # Columns in taxa map legends

# --- Slide Title Formatting (for presentation slides) ---
slide_title_size <- 88       # Main slide title font size (pixels)
slide_subtitle_size <- 44    # Slide subtitle font size (pixels)

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

# ==============================================================================
# SITE GROUPING (optional module)
# ==============================================================================
# Groups observations by survey site, using NEAREST SITE POINT. Each observation
# is assigned to the closest site anchor; anything further than site_max_dist_m
# from every anchor is reported as "Elsewhere" rather than dropped.
#
# Supply sites in ONE of two ways:
#   1. sites_csv - a CSV with columns: site, lat, lon   (simplest, portable)
#   2. sites_kmz - a Google Earth .kmz/.kml; each FOLDER becomes a site, and its
#      Points become that site's anchors (falls back to LineString vertices for
#      folders that contain only tracks)
# A site may have SEVERAL anchors (site centre, car park, two ends of a
# transect): list one row per anchor, repeating the site name. The observation is
# assigned to the site owning the nearest anchor, so extra anchors simply widen
# that site's catchment - they cannot cause a mis-assignment.
include_sites <- TRUE     # TRUE = build the site module (needs sites_csv or sites_kmz)
sites_csv <- "walpole_sites.csv" # e.g. "walpole_sites.csv" with columns site, lat, lon
sites_kmz <- ""            # e.g. "WWBB2025_Site_Locations.kmz" (used if sites_csv is empty)
site_max_dist_m <- 500     # Max distance from an anchor to count as "at" that site.
                           #   Check the printed sensitivity table: pick a value where
                           #   the unassigned count stops falling quickly.
site_min_obs <- 30         # Sites below this are shown in the bar chart (greyed) but
                           #   excluded from the rarefaction and PCoA, where small
                           #   samples produce confident-looking nonsense.
site_label_max <- 26       # Truncate long site names to this many characters
site_show_elsewhere <- TRUE  # Show the unassigned records as a reference row
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

# Setup directories
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(slides_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(styles_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(base_map_dir, recursive = TRUE, showWarnings = FALSE)

Sys.setenv(TZ = "Australia/Perth")

# ==============================================================================
# LOAD PACKAGES
# ==============================================================================

cat("Loading packages...\n")
req_pkgs <- c(
  "httr2", "jsonlite", "dplyr", "tidyr", "purrr", "stringr", "lubridate",
  "janitor", "glue", "readr", "tibble", "ggplot2", "sf", "forcats",
  "maptiles", "terra", "tidyterra", "osmdata", "ggspatial", 
  "scales", "viridis", "patchwork", "cowplot", "treemapify", "ggimage", "magick", "rsvg", "suncalc", "stars",
  "wesanderson", "ggtext", "rphylopic", "png"
)

to_install <- setdiff(req_pkgs, rownames(installed.packages()))
if (length(to_install)) {
  install.packages(to_install, repos = "https://cloud.r-project.org")
}
invisible(lapply(req_pkgs, function(p) {
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}))

# xml2 parses the KML inside a KMZ for the site module. Installed lazily so it is
# only required by people who actually supply a .kmz.
if (isTRUE(include_sites) && nzchar(sites_kmz) && !requireNamespace("xml2", quietly = TRUE)) {
  cat("Installing xml2 (to read the KMZ site file)...\n")
  tryCatch(install.packages("xml2", repos = "https://cloud.r-project.org"),
           error = function(e) cat("  xml2 install failed; supply sites_csv instead.\n"))
}
# ggrepel spreads the site labels on the PCoA, scatter and accumulation slides
if (isTRUE(include_sites) && !requireNamespace("ggrepel", quietly = TRUE)) {
  cat("Installing ggrepel (for non-overlapping site labels)...\n")
  tryCatch(install.packages("ggrepel", repos = "https://cloud.r-project.org"),
           error = function(e) cat("  ggrepel install failed; labels may overlap.\n"))
}

# chromote drives headless Chrome for the PDF export (render_pdf). Installed
# lazily so people who don't want a PDF are not forced to take the dependency.
if (isTRUE(render_pdf) && !requireNamespace("chromote", quietly = TRUE)) {
  cat("Installing chromote (for PDF export)...\n")
  tryCatch(install.packages("chromote", repos = "https://cloud.r-project.org"),
           error = function(e) cat("  chromote install failed; PDF export will be skipped.\n"))
}

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
    httr2::req_user_agent("walpole-datadive/1.0") |>
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

# Guarantee the timestamp column exists so the hourly plots and time-based awards
# never error on a missing column (older caches or sparse records may lack it).
if (!("time_observed_at" %in% names(obs))) obs$time_observed_at <- as.POSIXct(NA)

# ==============================================================================
# REFINE "ANIMALIA" INTO MEANINGFUL GROUPS (via iNaturalist ancestry)
# ==============================================================================
# iNaturalist tags every record with one of a small FIXED set of "iconic taxa".
# For animals only eight exist (Insecta, Arachnida, Mollusca, Aves, Mammalia,
# Reptilia, Amphibia, Actinopterygii), so every OTHER animal lineage - millipedes,
# centipedes, worms, springtails, slaters, sharks - is lumped as plain "Animalia"
# even when identified to species. This step looks up each Animalia taxon's
# ancestry once and relabels it to a readable group, so the taxonomic figures
# carry real signal instead of one vague bucket.
#
# It is event-agnostic: the lookup is keyed on STANDARD higher-taxon names
# (Diplopoda, Annelida, ...) that are identical in any bioblitz. The taxon->group
# map is cached to animalia_group_map.csv, so later runs only hit the API for
# taxa they have not seen. A new column, display_taxon, holds iconic_taxon for
# everything and the refined label for Animalia; the taxon figures use it.
refine_animalia   <- TRUE                 # FALSE = leave Animalia as one category
animalia_fallback <- "Other invertebrates"  # animal groups not in the table below

# Standard ancestor name -> (display label, PhyloPic silhouette name). Deepest
# match wins, so ordering does not matter and coarse + fine entries can coexist.
# Extend this freely for groups your event turns up.
# Labels are kept SHORT so they fit the treemap tiles; edit to taste.
animalia_group_tbl <- tibble::tribble(
  ~ancestor,         ~label,        ~icon,
  "Diplopoda",       "Millipedes",  "Diplopoda",
  "Chilopoda",       "Centipedes",  "Chilopoda",
  "Collembola",      "Springtails", "Collembola",
  "Isopoda",         "Slaters",     "Isopoda",
  "Amphipoda",       "Amphipods",   "Amphipoda",
  "Decapoda",        "Decapods",    "Decapoda",
  "Malacostraca",    "Crustaceans", "Malacostraca",
  "Annelida",        "Worms",       "Annelida",
  "Platyhelminthes", "Flatworms",   "Platyhelminthes",
  "Nematoda",        "Roundworms",  "Nematoda",
  "Nemertea",        "Ribbon worms","Nemertea",
  "Onychophora",     "Velvet worms","Onychophora",
  "Cnidaria",        "Cnidarians",  "Cnidaria",
  "Echinodermata",   "Echinoderms", "Echinodermata",
  "Porifera",        "Sponges",     "Porifera",
  "Chondrichthyes",  "Sharks",      "Chondrichthyes"
)

obs$display_taxon   <- obs$iconic_taxon      # default: unchanged
animalia_cols       <- character(0)          # palette additions for refined groups
animalia_icon_names <- character(0)          # refined label -> PhyloPic name

if (isTRUE(refine_animalia) && any(obs$iconic_taxon == "Animalia", na.rm = TRUE)) {
  cat("\n=== REFINING ANIMALIA (ancestry lookup) ===\n")
  is_ani  <- obs$iconic_taxon == "Animalia" & !is.na(obs$iconic_taxon)
  ani_ids <- sort(unique(obs$taxon_id[is_ani & !is.na(obs$taxon_id)]))
  map_file <- file.path(out_dir, "animalia_group_map.csv")

  known <- if (file.exists(map_file))
    suppressWarnings(readr::read_csv(map_file, show_col_types = FALSE)) else
    tibble::tibble(taxon_id = integer(0), label = character(0), icon = character(0))
  todo <- setdiff(ani_ids, known$taxon_id)

  # deepest ancestor match: ancestors come root -> tip, so scan tip -> root
  classify <- function(anc_names) {
    for (nm in rev(anc_names)) {
      m <- which(animalia_group_tbl$ancestor == nm)
      if (length(m)) return(c(animalia_group_tbl$label[m[1]], animalia_group_tbl$icon[m[1]]))
    }
    c(NA_character_, NA_character_)
  }

  if (length(todo)) {
    cat("  Looking up ancestry for", length(todo), "taxa (cached after this)...\n")
    fetched <- list()
    for (b in split(todo, ceiling(seq_along(todo) / 30))) {
      dat <- tryCatch({
        req <- httr2::request(paste0("https://api.inaturalist.org/v1/taxa/", paste(b, collapse = ",")))
        req <- httr2::req_timeout(httr2::req_user_agent(req, "walpole-datadive/1.0"), 30)
        httr2::resp_body_json(httr2::req_perform(req), simplifyVector = FALSE)$results
      }, error = function(e) { cat("    taxa lookup failed:", conditionMessage(e), "\n"); list() })
      for (t in dat) {
        anc <- vapply(t$ancestors %||% list(), function(a) a$name %||% NA_character_, character(1))
        cl  <- classify(c(anc, t$name %||% NA_character_))
        fetched[[length(fetched) + 1]] <- tibble::tibble(taxon_id = t$id, label = cl[1], icon = cl[2])
      }
    }
    if (length(fetched)) {
      known <- dplyr::distinct(dplyr::bind_rows(known, dplyr::bind_rows(fetched)),
                               taxon_id, .keep_all = TRUE)
      tryCatch(readr::write_csv(known, map_file), error = function(e) NULL)
    }
  } else cat("  Using cached ancestry map\n")

  lut <- dplyr::filter(known, !is.na(label))
  m   <- match(obs$taxon_id, lut$taxon_id)
  obs$display_taxon[is_ani] <- ifelse(!is.na(m[is_ani]), lut$label[m[is_ani]], animalia_fallback)

  present <- sort(setdiff(unique(obs$display_taxon[is_ani]), NA))
  .ani_pal <- c("#D1603D", "#8E5572", "#4F7CAC", "#3C887E", "#B5A642", "#A0522D",
                "#6A5ACD", "#C25B56", "#5F9EA0", "#9C6B30", "#7B8B6F", "#B0724A")
  animalia_cols <- setNames(rep(.ani_pal, length.out = length(present)), present)
  if (animalia_fallback %in% present) animalia_cols[[animalia_fallback]] <- "#8A8A82"
  animalia_icon_names <- setNames(vapply(present, function(lb) {
    ic <- animalia_group_tbl$icon[match(lb, animalia_group_tbl$label)]
    if (is.na(ic)) "Animalia" else ic }, character(1)), present)
  cat("  Animalia refined into:", paste(present, collapse = ", "), "\n")
}

# palettes and icon lookup used by the taxon figures (iconic + refined animals)
treemap_cols   <- c(taxon_cols,  animalia_cols)
bar_cols       <- c(iconic_cols, animalia_cols)
icon_name_for  <- function(g) if (g %in% names(animalia_icon_names)) animalia_icon_names[[g]] else g

# ==============================================================================
# STYLING
# ==============================================================================

cat("=== SETTING UP STYLING ===\n")

# Taxon palette + silhouette icons now come from the shared style file
# (Wes Anderson palette; PhyloPic silhouettes shared with the slideshow).
if (!file.exists("bioblitz_style.R"))
  stop("Cannot find bioblitz_style.R in the working directory:\n  ", getwd(),
       "\nSet the working directory to the folder that holds this script AND bioblitz_style.R,"
       , "\nthen re-run. In RStudio: Session > Set Working Directory > To Source File Location.")
source("bioblitz_style.R")

# Custom theme matching slideshow aesthetic (for figures 4 & 5)
theme_bioblitz <- function(base_size = chart_base_size) {
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
    plot.background = ggplot2::element_rect(fill = "#040a11", color = NA),
    panel.background = ggplot2::element_rect(fill = "#040a11", color = NA),
    panel.grid.major = ggplot2::element_line(color = "#333333", linewidth = 0.3),
    panel.grid.minor = ggplot2::element_line(color = "#0b1b2a", linewidth = 0.2),
    text = ggplot2::element_text(color = "#e0e0e0", family = "sans"),
    axis.text = ggplot2::element_text(color = "#b0b0b0"),
    axis.title = ggplot2::element_text(color = "#e0e0e0", face = "bold"),
    plot.title = ggplot2::element_text(color = "#ffffff", face = "bold", size = 18),
    plot.subtitle = ggplot2::element_text(color = "#b0b0b0", size = 12),
    legend.background = ggplot2::element_rect(fill = "#0b1b2a", color = NA),
    legend.text = ggplot2::element_text(color = "#e0e0e0"),
    legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold"),
    strip.background = ggplot2::element_rect(fill = "#0b1b2a", color = NA),
    strip.text = ggplot2::element_text(color = "#e0e0e0", face = "bold")
  )


# ==============================================================================
# SHARED SIDE-LEGEND / HQ / AXIS HELPERS (transferred from approved prototype)
# ==============================================================================
hq_layers <- function(bbox_buffered, hq_lon, hq_lat,
                      hq_scale = 0.8, hq_label_size = 6) {
  bb_m  <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(bbox_buffered), 3857))
  hq_w  <- as.numeric(bb_m["xmax"] - bb_m["xmin"])
  hq_xy <- sf::st_coordinates(sf::st_transform(
    sf::st_sfc(sf::st_point(c(hq_lon, hq_lat)), crs = 4326), 3857))
  hq_cx <- hq_xy[1]; hq_cy <- hq_xy[2]; s <- hq_scale
  bw <- hq_w*0.015*s; bh <- hq_w*0.017*s; rw <- hq_w*0.026*s; rh <- hq_w*0.015*s
  dw <- hq_w*0.005*s; dh <- hq_w*0.010*s; by <- hq_cy - (bh + rh)/2
  hq_body <- data.frame(
    x = c(hq_cx-bw, hq_cx-bw, hq_cx+bw, hq_cx+bw, hq_cx+dw, hq_cx+dw, hq_cx-dw, hq_cx-dw),
    y = c(by, by+bh, by+bh, by, by, by+dh, by+dh, by))
  hq_roof <- data.frame(x = c(hq_cx-rw, hq_cx+rw, hq_cx), y = c(by+bh, by+bh, by+bh+rh))
  hq_px <- hq_cx + hq_w*0.010*s; hq_poletop <- by + bh + rh + hq_w*0.025*s; pole_hw <- hq_w*0.002*s
  hq_pole <- data.frame(x = c(hq_px-pole_hw, hq_px+pole_hw, hq_px+pole_hw, hq_px-pole_hw),
                        y = c(by+bh, by+bh, hq_poletop, hq_poletop))
  fh <- hq_w*0.010*s; fw <- hq_w*0.017*s
  hq_flag <- data.frame(
    x = c(hq_px, hq_px+fw, hq_px+fw*0.80, hq_px+fw, hq_px),
    y = c(hq_poletop, hq_poletop-fh*0.15, hq_poletop-fh*0.5, hq_poletop-fh*0.85, hq_poletop-fh))
  to_sf <- function(df) {
    ring <- as.matrix(df[, c("x","y")]); ring <- rbind(ring, ring[1, ])
    sf::st_transform(sf::st_sfc(sf::st_polygon(list(ring)), crs = 3857), 4326)
  }
  list(
    ggplot2::geom_sf(data = to_sf(hq_body), fill = "white", colour = NA, inherit.aes = FALSE),
    ggplot2::geom_sf(data = to_sf(hq_pole), fill = "white", colour = NA, inherit.aes = FALSE),
    ggplot2::geom_sf(data = to_sf(hq_roof), fill = "white", colour = NA, inherit.aes = FALSE),
    ggplot2::geom_sf(data = to_sf(hq_flag), fill = "white", colour = NA, inherit.aes = FALSE)
  )
}

axis_two_breaks <- function(bbox_buffered) {
  xb <- round(as.numeric(bbox_buffered["xmin"]) +
          c(0.25, 0.75) * (as.numeric(bbox_buffered["xmax"]) - as.numeric(bbox_buffered["xmin"])), 2)
  yb <- round(as.numeric(bbox_buffered["ymin"]) +
          c(0.25, 0.75) * (as.numeric(bbox_buffered["ymax"]) - as.numeric(bbox_buffered["ymin"])), 2)
  list(
    ggplot2::scale_x_continuous(breaks = xb),
    ggplot2::scale_y_continuous(breaks = yb),
    ggplot2::theme(
      axis.text         = ggplot2::element_text(colour = "#b0b0b0", size = 16),
      axis.ticks        = ggplot2::element_line(colour = "#b0b0b0", linewidth = 0.4),
      axis.ticks.length = grid::unit(5, "pt"))
  )
}

build_taxon_legend <- function(present, legend_ncol = 2, legend_icon_sz = 0.08,
                               legend_text_sz = 9, legend_colgap = 7.5,
                               legend_lmar = 10, legend_rpad = 6.0, legend_lpad = -1.3,
                               show_hq = FALSE) {
  present <- c(setdiff(present, "Unknown"), if ("Unknown" %in% present) "Unknown")
  n <- length(present); nrows <- ceiling(n / legend_ncol)
  leg <- data.frame(taxon = present, idx = seq_len(n) - 1) |>
    dplyr::mutate(row = idx %/% legend_ncol, coli = idx %% legend_ncol,
                  x = coli * legend_colgap, y = nrows - row,
                  col  = vapply(taxon, taxon_color, character(1)),
                  icon = vapply(taxon, function(t) tryCatch(ensure_taxon_icon(t),
                                error = function(e) NA_character_), character(1)))
  leg$has_icon <- vapply(leg$icon, function(p) !is.na(p) && nzchar(p) && file.exists(p), logical(1))
  ggplot2::ggplot(leg, ggplot2::aes(x, y)) +
    ggimage::geom_image(data = leg[leg$has_icon, ],
                        ggplot2::aes(x = x, image = icon), size = legend_icon_sz, asp = 1) +
    ggplot2::geom_point(data = leg[!leg$has_icon, ],
                        ggplot2::aes(x = x, colour = col), size = 8, show.legend = FALSE) +
    ggplot2::scale_colour_identity() +
    ggplot2::geom_text(ggplot2::aes(x = x + 1.15, label = taxon), hjust = 0,
                       colour = "#F7FAFC", size = legend_text_sz) +
    ggplot2::annotate("text", x = max(-1.0, legend_lpad + 0.1), y = nrows + 1.0, label = "Taxa",
                      hjust = 0, fontface = "bold", colour = "#F7FAFC", size = legend_text_sz + 2) +
    ggplot2::scale_x_continuous(limits = c(legend_lpad, (legend_ncol - 1) * legend_colgap + legend_rpad)) +
    ggplot2::scale_y_continuous(limits = c(if (show_hq) -1.0 else 0.3, nrows + 1.5)) +
    {if (show_hq && file.exists(hut_icon_path))
       ggimage::geom_image(data = data.frame(x = 0, y = -0.35, img = hut_icon_path),
                           ggplot2::aes(x = x, y = y, image = img), size = legend_icon_sz * 1.15, asp = 1)} +
    {if (show_hq) ggplot2::annotate("text", x = 1.15, y = -0.35, label = "Bioblitz Headquarters",
                                    hjust = 0, colour = "#F7FAFC", size = legend_text_sz)} +
    ggplot2::theme_void() +
    ggplot2::theme(plot.background  = ggplot2::element_rect(fill = "#040a11", colour = NA),
                   panel.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
                   plot.margin = ggplot2::margin(10, 10, 10, legend_lmar))
}

# Compose any legend-free plot beside the shared taxon legend into one 16:9 PNG.
# map_frac = % width for the plot (54 for square maps; ~80 for wide charts).
compose_with_legend <- function(p, present, path, map_frac = 64, w = 16, h = 9,
                                leg_icon = 0.08, leg_text = 9, leg_colgap = 7.5,
                                leg_lmar = 10, leg_rpad = 6.0, leg_lpad = -1.3,
                                show_hq = FALSE) {
  p_leg <- build_taxon_legend(present, legend_icon_sz = leg_icon,
                              legend_text_sz = leg_text, legend_colgap = leg_colgap,
                              legend_lmar = leg_lmar, legend_rpad = leg_rpad, legend_lpad = leg_lpad,
                              show_hq = show_hq)
  combo <- patchwork::wrap_plots(p, p_leg, nrow = 1, widths = c(map_frac, 100 - map_frac)) &
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA))
  ggplot2::ggsave(path, combo, width = w, height = h, dpi = 150, bg = "#040a11")
}

cat("Styling configured\n\n")

# Original Wes Anderson Zissou1 palette (low -> high) for the richness heatmaps
zissou1_heat <- c("#3B9AB2", "#78B7C5", "#EBCC2A", "#E1AF00", "#F21A00")

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
  if (isTRUE(vary_summary_photos)) set.seed(NULL) else set.seed(123)  # NULL = fresh RNG each run
  species_sample <- obs_with_photos |>
    dplyr::group_by(iconic_taxon) |>
    dplyr::slice_sample(n = 2) |>
    dplyr::ungroup()
  if (isTRUE(vary_summary_photos)) species_sample <- dplyr::slice_sample(species_sample, prop = 1)
  species_sample <- dplyr::slice_head(species_sample, n = 12)
  
  # Get photo URLs from iNaturalist
  cat("Downloading species photos from iNaturalist...\n")
  species_photos_dir <- file.path(slides_dir, "species_photos")
  dir.create(species_photos_dir, showWarnings = FALSE, recursive = TRUE)
  
  species_photos <- list()
  for (i in seq_len(nrow(species_sample))) {
    obs_id <- species_sample$obs_id[i]
    photo_path <- file.path(species_photos_dir, paste0("species_obs_", obs_id, ".jpg"))
    if (file.exists(photo_path) && !force_refetch_photos) {
      species_photos[[length(species_photos) + 1]] <- photo_path
      cat("  Using cached species photo", i, "\n")
      next
    }
    
    tryCatch({
      # Fetch observation details to get photo URL
      obs_detail <- inat_get(paste0("observations/", obs_id))
      
      if (length(obs_detail$results) > 0 && length(obs_detail$results[[1]]$photos) > 0) {
        photo_url <- obs_detail$results[[1]]$photos[[1]]$url
        # Use medium size photo
        photo_url <- gsub("/square\\.", "/medium.", photo_url)
        
        # Download photo
        resp <- httr2::request(photo_url) |>
          httr2::req_user_agent("walpole-bioblitz-datadive") |>
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
  observer_pool <- obs |>
    dplyr::count(observer_login, observer_name, observer_icon_url) |>
    dplyr::filter(!is.na(observer_icon_url), observer_icon_url != "") |>
    dplyr::arrange(dplyr::desc(n))
  top_observers_for_border <- if (isTRUE(vary_summary_photos))
    dplyr::slice_sample(dplyr::slice_head(observer_pool, n = 16), n = min(8, nrow(observer_pool)))
  else dplyr::slice_head(observer_pool, n = 8)
  
  observer_photos <- list()
  for (i in seq_len(nrow(top_observers_for_border))) {
    icon_url <- top_observers_for_border$observer_icon_url[i]
    photo_path <- file.path(species_photos_dir, paste0("observer_", i, ".jpg"))
    
    tryCatch({
      resp <- httr2::request(icon_url) |>
        httr2::req_user_agent("walpole-bioblitz-datadive") |>
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
  if (isTRUE(vary_summary_photos)) all_border_photos <- all_border_photos[sample(length(all_border_photos))]
  
  if (length(all_border_photos) > 0) {
    cat("Creating summary card with photo border...\n")
    
    # Create canvas
    card_width <- 1920
    card_height <- 1080
    canvas <- magick::image_blank(card_width, card_height, color = "#040a11")
    
    # Photo border settings
    thumb_size <- 240
    border_padding <- 20
    
    # Calculate positions for photos around the border
    # Top edge
    top_positions <- list()
    n_top <- min(ceiling(length(all_border_photos) * 0.4), 6)
    if (n_top > 0) {
      spacing_x <- (card_width - 2 * border_padding) / (n_top + 1)
      for (i in 1:n_top) {
        top_positions[[i]] <- c(x = border_padding + i * spacing_x, y = border_padding + thumb_size/2)
      }
    }
    
    # Bottom edge  
    bottom_positions <- list()
    n_bottom <- min(ceiling(length(all_border_photos) * 0.4), 6)
    if (n_bottom > 0) {
      spacing_x <- (card_width - 2 * border_padding) / (n_bottom + 1)
      for (i in 1:n_bottom) {
        bottom_positions[[i]] <- c(x = border_padding + i * spacing_x, y = card_height - border_padding - thumb_size/2)
      }
    }
    
    # Left edge
    left_positions <- list()
    n_left <- min(ceiling(length(all_border_photos) * 0.1), 1)
    if (n_left > 0) {
      spacing_y <- (card_height - 2 * border_padding - 2 * thumb_size) / (n_left + 1)
      for (i in 1:n_left) {
        left_positions[[i]] <- c(x = border_padding + thumb_size/2, y = border_padding + thumb_size + i * spacing_y)
      }
    }
    
    # Right edge
    right_positions <- list()
    n_right <- min(ceiling(length(all_border_photos) * 0.1), 1)
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
                                     text = paste0(format(date_min, "%B %d"), " - ", format(date_max, "%d"), "\n", format(date_max, "%Y")),
                                     size = 80,
                                     color = "#90EE90",
                                     font = "sans",
                                     location = sprintf("+%d+%d", center_x + 100, center_y + 50),
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

# Fetch satellite tiles
cat("  Downloading satellite imagery...\n")
sat <- maptiles::get_tiles(
  x = aoi,
  provider = "Esri.WorldImagery",
  zoom = base_map_zoom,
  crop = TRUE,
  cachedir = base_map_dir,
  forceDownload = force_refetch_maps,
  verbose = FALSE
)

cat("  Satellite imagery downloaded\n")

# Fetch OSM data
overpass_urls <- c(
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
)
fetch_osm_lines <- function(key, values, bb) {
  for (u in overpass_urls) {
    res <- tryCatch({
      osmdata::set_overpass_url(u)
      q <- osmdata::opq(bbox = as.numeric(bb), timeout = 90)
      q <- osmdata::add_osm_feature(q, key = key, value = values)
      d <- osmdata::osmdata_sf(q, quiet = TRUE)
      if (!is.null(d$osm_lines) && nrow(d$osm_lines) > 0) d$osm_lines else NULL
    }, error = function(e) NULL)
    if (!is.null(res)) { cat("  OSM", key, "via", u, "-", nrow(res), "lines\n"); return(res) }
  }
  cat("  Warning: OSM", key, "fetch failed on all mirrors\n"); NULL
}

# Map extent (always needed - the zoom locator figures use bbox_master too)
obs_xy_tmp <- obs |> dplyr::filter(!is.na(longitude), !is.na(latitude))
bbox_master <- sf::st_bbox(c(
  xmin = min(obs_xy_tmp$longitude) - buffer_km/111, ymin = min(obs_xy_tmp$latitude) - buffer_km/111,
  xmax = max(obs_xy_tmp$longitude) + buffer_km/111, ymax = max(obs_xy_tmp$latitude) + buffer_km/111),
  crs = 4326)

# OSM overlays. Roads and tracks share the OSM "highway" key, so they are fetched
# in ONE query and split by tag (avoids a second, late tracks download). Water is a
# separate "waterway" query. Each layer caches to its own .gpkg, with a .none marker
# for empty layers, so nothing re-downloads once resolved (unless force_refetch_maps).
road_types  <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential")
track_types <- c("path", "track", "footway", "bridleway", "cycleway")
roads_cache  <- file.path(out_dir, "osm_roads.gpkg");  roads_none  <- file.path(out_dir, "osm_roads.none")
tracks_cache <- file.path(out_dir, "osm_tracks.gpkg"); tracks_none <- file.path(out_dir, "osm_tracks.none")
water_cache  <- file.path(out_dir, "osm_water.gpkg");  water_none  <- file.path(out_dir, "osm_water.none")
.osm_ready <- function(cache, none) !force_refetch_maps && (file.exists(cache) || file.exists(none))
.osm_load  <- function(cache) if (file.exists(cache)) tryCatch(sf::st_read(cache, quiet = TRUE), error = function(e) NULL) else NULL
.osm_save  <- function(ly, cache, none) {
  if (!is.null(ly) && nrow(ly) > 0) {
    tryCatch(sf::st_write(ly, cache, delete_dsn = TRUE, quiet = TRUE), error = function(e) NULL)
    if (file.exists(none)) unlink(none)
  } else writeLines("no features", none)   # skip-marker so this layer is not re-queried
}
if (.osm_ready(roads_cache, roads_none) && .osm_ready(tracks_cache, tracks_none)) {
  roads_sf <- .osm_load(roads_cache); tracks_sf <- .osm_load(tracks_cache)
  cat("  Using cached OSM roads + tracks\n")
} else {
  cat("  Fetching OSM highways (roads + tracks in one query)...\n")
  hw <- fetch_osm_lines("highway", c(road_types, track_types), bbox_expanded)
  if (!is.null(hw)) hw <- tryCatch(suppressWarnings(sf::st_crop(hw, bbox_master)), error = function(e) hw)
  if (!is.null(hw) && "highway" %in% names(hw)) {
    roads_sf  <- hw[hw$highway %in% road_types, ]
    tracks_sf <- hw[hw$highway %in% track_types, ]
  } else { roads_sf <- NULL; tracks_sf <- NULL }
  .osm_save(roads_sf,  roads_cache,  roads_none)
  .osm_save(tracks_sf, tracks_cache, tracks_none)
}
if (.osm_ready(water_cache, water_none)) {
  water_sf <- .osm_load(water_cache); cat("  Using cached OSM water\n")
} else {
  cat("  Fetching OSM water...\n")
  water_sf <- fetch_osm_lines("waterway", c("river", "stream"), bbox_expanded)
  if (!is.null(water_sf)) water_sf <- tryCatch(suppressWarnings(sf::st_crop(water_sf, bbox_master)), error = function(e) water_sf)
  .osm_save(water_sf, water_cache, water_none)
}
cat("\n")

# ==============================================================================
# FIGURE 1: OBSERVATION HOTSPOTS (JITTERED MAP)
# ==============================================================================

# Plantae point ring: only slightly brighter than the base Plantae fill (not neon)
.lighten <- function(col, amt) { v <- grDevices::col2rgb(col)[,1]/255; v <- v + (1 - v) * amt; grDevices::rgb(v[1], v[2], v[3]) }
plantae_ring_col <- tryCatch(.lighten(iconic_cols[["Plantae"]], 0.28), error = function(e) "#8FBF8F")

# Render the HQ hut as a square PNG (drawn 1:1 like the slideshow, so it is NOT
# aspect-distorted by the legend panel) for use as a legend icon.
hut_icon_path <- file.path(slides_dir, "hq_hut_icon.png")
if (!file.exists(hut_icon_path) || force_rebuild) {
  tryCatch({
    .Wp <- 240; .cx <- .Wp/2; .s <- .Wp*0.42
    .hi <- magick::image_draw(magick::image_blank(.Wp, .Wp, "none"))
    .base <- .Wp*0.86; .top <- .base - .s*0.75
    .bw <- .s*0.55; .dw <- .s*0.16; .dh <- .s*0.42
    graphics::polygon(c(.cx-.bw,.cx-.bw,.cx+.bw,.cx+.bw,.cx+.dw,.cx+.dw,.cx-.dw,.cx-.dw),
                      c(.base,.top,.top,.base,.base,.base-.dh,.base-.dh,.base), col="white", border=NA)
    .rw <- .s*0.85; .rh <- .s*0.5
    graphics::polygon(c(.cx-.rw,.cx+.rw,.cx), c(.top,.top,.top-.rh), col="white", border=NA)
    .px <- .cx+.s*0.45; .ptop <- .top-.rh-.s*0.55; .phw <- .s*0.06
    graphics::polygon(c(.px-.phw,.px+.phw,.px+.phw,.px-.phw), c(.top,.top,.ptop,.ptop), col="white", border=NA)
    .fh <- .s*0.32; .fw <- .s*0.5
    graphics::polygon(c(.px,.px+.fw,.px+.fw*0.8,.px+.fw,.px),
                      c(.ptop,.ptop+.fh*0.15,.ptop+.fh*0.5,.ptop+.fh*0.85,.ptop+.fh), col="white", border=NA)
    grDevices::dev.off(); magick::image_write(.hi, hut_icon_path)
  }, error = function(e) cat("  hut icon render failed:", conditionMessage(e), "\n"))
}

cat("=== GENERATING FIGURE 1: OBSERVATION HOTSPOTS ===\n")

fig1_path <- file.path(slides_dir, "fig_observation_hotspots_jittered.png")

if (!file.exists(fig1_path) || force_rebuild) {
  cat("Creating hotspots map...\n")
  tryCatch({
  
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
  
  tiles <- maptiles::get_tiles(bbox_sf, provider = "Esri.WorldImagery", zoom = base_map_zoom, crop = TRUE, cachedir = base_map_dir, forceDownload = force_refetch_maps)
  
  # Extract coordinates and add jitter manually
  obs_coords <- obs_sf |>
    dplyr::mutate(
      lon = sf::st_coordinates(geometry)[, 1] + runif(n(), -0.001, 0.001),
      lat = sf::st_coordinates(geometry)[, 2] + runif(n(), -0.001, 0.001)
    ) |>
    sf::st_drop_geometry() |>
    dplyr::add_count(iconic_taxon, name = "ntax") |>
    dplyr::arrange(dplyr::desc(ntax))
  
  p1 <- ggplot2::ggplot() +
    tidyterra::geom_spatraster_rgb(data = tiles, maxcell = 5e5) +
    # Add OSM overlays
    {if (!is.null(water_sf) && nrow(water_sf) > 0) {
      ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.5, alpha = 0.7)
    }} +
    {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
      ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.4, alpha = 0.7)
    }} +
    {if (any(obs_coords$iconic_taxon == "Plantae"))
       ggplot2::geom_point(data = obs_coords[obs_coords$iconic_taxon == "Plantae", ],
                           ggplot2::aes(x = lon, y = lat),
                           shape = 21, fill = iconic_cols[["Plantae"]], colour = plantae_ring_col,
                           size = 3, stroke = 0.55, alpha = 0.5, inherit.aes = FALSE, show.legend = FALSE)} +
    ggplot2::geom_point(data = obs_coords[obs_coords$iconic_taxon != "Plantae", ],
                        ggplot2::aes(x = lon, y = lat, color = iconic_taxon),
                        alpha = 0.47, size = 3, shape = 16, stroke = 0) +
    ggplot2::scale_color_manual(
      name = "Taxon Group",
      values = iconic_cols,
      labels = label_with_icon_md
    ) +
    ggplot2::coord_sf(crs = 4326, 
                      xlim = c(bbox_buffered["xmin"], bbox_buffered["xmax"]),
                      ylim = c(bbox_buffered["ymin"], bbox_buffered["ymax"]),
                      expand = FALSE) +
    ggplot2::labs(title = NULL) +  # Remove title (slide has it)
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#040a11", color = NA),
      panel.background = ggplot2::element_rect(fill = "#040a11", color = NA),
      text = ggplot2::element_text(color = "#e0e0e0"),
      axis.text = ggplot2::element_text(color = "#b0b0b0", size = axis_text_size),
      legend.position = "right",
      legend.background = ggplot2::element_rect(fill = "#0b1b2a", color = NA),
      legend.text = ggplot2::element_text(color = "#e0e0e0", size = legend_text_size),
      legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = legend_title_size),
      legend.key.size = ggplot2::unit(1.1, "cm"),
      legend.key = ggplot2::element_rect(fill = "#0b1b2a"),
      legend.spacing.y = ggplot2::unit(0.2, "cm"),
      panel.grid = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank()
    )
  
  p1 <- p1 + ggplot2::theme(legend.text = ggtext::element_markdown(size = legend_text_size)) +
    ggplot2::guides(colour = ggplot2::guide_legend(ncol = legend_ncol, byrow = TRUE))
  p1 <- p1 + ggplot2::theme(legend.position = "none") +
    hq_layers(bbox_buffered, hq_lon, hq_lat) + axis_two_breaks(bbox_buffered)
  compose_with_legend(p1, sort(unique(obs$iconic_taxon)), fig1_path, map_frac = 66, show_hq = TRUE,
                      leg_text = 7, leg_colgap = 7.0, leg_lmar = 0, leg_lpad = -0.3, leg_rpad = 6.0)
  cat("Hotspots map saved\n")
  }, error = function(e) cat("  *** HOTSPOTS MAP (fig1) FAILED:", conditionMessage(e), "***\n"))
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
  tiles_no_plants <- maptiles::get_tiles(bbox_sf, provider = "Esri.WorldImagery", zoom = base_map_zoom, crop = TRUE, cachedir = base_map_dir, forceDownload = force_refetch_maps)
  
  # Extract coordinates and add jitter
  obs_coords_no_plants <- obs_sf_no_plants |>
    dplyr::mutate(
      lon = sf::st_coordinates(geometry)[, 1] + runif(n(), -0.001, 0.001),
      lat = sf::st_coordinates(geometry)[, 2] + runif(n(), -0.001, 0.001)
    ) |>
    sf::st_drop_geometry() |>
    dplyr::add_count(iconic_taxon, name = "ntax") |>
    dplyr::arrange(dplyr::desc(ntax))
  
  # Filter iconic_cols to only include taxa that are present (excluding Plantae)
  taxa_present_no_plants <- unique(obs_coords_no_plants$iconic_taxon)
  iconic_cols_no_plants <- iconic_cols[names(iconic_cols) %in% taxa_present_no_plants]
  
  p1b <- ggplot2::ggplot() +
    tidyterra::geom_spatraster_rgb(data = tiles_no_plants, maxcell = 5e5) +
    # Add OSM overlays
    {if (!is.null(water_sf) && nrow(water_sf) > 0) {
      ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.5, alpha = 0.7)
    }} +
    {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
      ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.4, alpha = 0.7)
    }} +
    ggplot2::geom_point(data = obs_coords_no_plants,
                        ggplot2::aes(x = lon, y = lat, color = iconic_taxon),
                        alpha = 0.47, size = 3, shape = 16, stroke = 0) +
    ggplot2::scale_color_manual(
      name = "Taxon Group",
      values = iconic_cols_no_plants,
      labels = label_with_icon_md
    ) +
    ggplot2::coord_sf(crs = 4326, 
                      xlim = c(bbox_buffered["xmin"], bbox_buffered["xmax"]),
                      ylim = c(bbox_buffered["ymin"], bbox_buffered["ymax"]),
                      expand = FALSE) +
    ggplot2::labs(title = NULL) +  # Remove title (slide has it)
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "#040a11", color = NA),
      panel.background = ggplot2::element_rect(fill = "#040a11", color = NA),
      text = ggplot2::element_text(color = "#e0e0e0"),
      axis.text = ggplot2::element_text(color = "#b0b0b0", size = axis_text_size),
      legend.position = "right",
      legend.background = ggplot2::element_rect(fill = "#0b1b2a", color = NA),
      legend.text = ggplot2::element_text(color = "#e0e0e0", size = legend_text_size),
      legend.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = legend_title_size),
      legend.key.size = ggplot2::unit(1.1, "cm"),
      legend.key = ggplot2::element_rect(fill = "#0b1b2a"),
      legend.spacing.y = ggplot2::unit(0.2, "cm"),
      panel.grid = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank()
    )
  
  p1b <- p1b + ggplot2::theme(legend.text = ggtext::element_markdown(size = legend_text_size)) +
    ggplot2::guides(colour = ggplot2::guide_legend(ncol = legend_ncol, byrow = TRUE))
  p1b <- p1b + ggplot2::theme(legend.position = "none") +
    hq_layers(bbox_buffered, hq_lon, hq_lat) + axis_two_breaks(bbox_buffered)
  compose_with_legend(p1b, sort(unique(obs_no_plants$iconic_taxon)), fig1b_path, map_frac = 66, show_hq = TRUE,
                      leg_text = 7, leg_colgap = 7.0, leg_lmar = 0, leg_lpad = -0.3, leg_rpad = 6.0)
  cat("Hotspots map (no plants) saved\n")
} else {
  cat("Using cached hotspots map (no plants)\n")
}


# ==============================================================================
# FIGURE 1C: HOTSPOT CLOSE-UPS (ZOOM-INS)
# ==============================================================================
cat("=== GENERATING HOTSPOT CLOSE-UPS (ZOOM-INS) ===\n")

zoom_enable    <- TRUE
zoom_window_m  <- 800     # square close-up side length in metres (use 500-1000)
n_zooms        <- 3       # how many close-ups to show
zoom_min_sep_m <- 1200    # keep chosen windows at least this far apart (metres; >window = distinct hotspots)
zoom_min_obs   <- 20      # require at least this many observations in a window
zoom_utm       <- (if (hq_lat < 0) 32700 else 32600) + (floor((hq_lon + 180) / 6) + 1)  # UTM zone auto-derived from HQ

zoom_slides_md <- ""
if (zoom_enable && nrow(obs) > 0) {
  zoom_pts <- obs |>
    dplyr::filter(!is.na(longitude), !is.na(latitude)) |>
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  xy <- sf::st_coordinates(sf::st_transform(zoom_pts, zoom_utm))
  cs <- zoom_window_m
  cell_x <- floor(xy[, 1] / cs); cell_y <- floor(xy[, 2] / cs)
  gt <- as.data.frame(table(cell_x = cell_x, cell_y = cell_y), stringsAsFactors = FALSE)
  gt <- gt[gt$Freq > 0, ]
  gt$cx <- (as.numeric(gt$cell_x) + 0.5) * cs
  gt$cy <- (as.numeric(gt$cell_y) + 0.5) * cs
  gt <- gt[order(-gt$Freq), ]

  # greedy: densest cells first, kept at least zoom_min_sep_m apart
  chosen <- gt[0, ]
  for (i in seq_len(nrow(gt))) {
    if (gt$Freq[i] < zoom_min_obs) next
    if (nrow(chosen) == 0 ||
        all(sqrt((chosen$cx - gt$cx[i])^2 + (chosen$cy - gt$cy[i])^2) >= zoom_min_sep_m)) {
      chosen <- rbind(chosen, gt[i, ])
    }
    if (nrow(chosen) >= n_zooms) break
  }

  if (nrow(chosen) > 0) {
    loc_tiles <- tryCatch(maptiles::get_tiles(sf::st_as_sfc(bbox_master),
                            provider = "Esri.WorldImagery",
                            zoom = max(11L, base_map_zoom - 2L), crop = TRUE, cachedir = base_map_dir, forceDownload = force_refetch_maps),
                          error = function(e) NULL)
    for (k in seq_len(nrow(chosen))) {
      # centre the close-up on the cluster density (median of the cell's points),
      # not the grid-cell centre, so observations sit in the middle of the frame
      in_cell <- cell_x == as.numeric(chosen$cell_x[k]) & cell_y == as.numeric(chosen$cell_y[k])
      cx <- stats::median(xy[in_cell, 1]); cy <- stats::median(xy[in_cell, 2]); nobs <- chosen$Freq[k]
      win_m <- sf::st_sfc(sf::st_polygon(list(matrix(c(
        cx - cs/2, cy - cs/2,  cx + cs/2, cy - cs/2,  cx + cs/2, cy + cs/2,
        cx - cs/2, cy + cs/2,  cx - cs/2, cy - cs/2), ncol = 2, byrow = TRUE))), crs = zoom_utm)
      win_ll <- sf::st_transform(win_m, 4326)
      win_bb <- sf::st_bbox(win_ll)
      win_pts <- sf::st_filter(zoom_pts, win_ll)
      wc <- sf::st_coordinates(win_pts)
      set.seed(k)
      win_df <- data.frame(
        lon = wc[, 1] + runif(nrow(wc), -0.00003, 0.00003),
        lat = wc[, 2] + runif(nrow(wc), -0.00003, 0.00003),
        iconic_taxon = win_pts$iconic_taxon) |>
        dplyr::add_count(iconic_taxon, name = "ntax") |>
        dplyr::arrange(dplyr::desc(ntax))

      figz_path <- file.path(slides_dir, sprintf("fig_zoom_%d.png", k))
      if (!file.exists(figz_path) || force_rebuild) {
        tryCatch({
          zlvl <- if (zoom_window_m <= 600) 18L else 17L
          tiles_z <- maptiles::get_tiles(win_ll, provider = "Esri.WorldImagery",
                                         zoom = zlvl, crop = TRUE, cachedir = base_map_dir, forceDownload = force_refetch_maps)
          p_zoom <- ggplot2::ggplot() +
            tidyterra::geom_spatraster_rgb(data = tiles_z, maxcell = 5e5) +
            {if (any(win_df$iconic_taxon == "Plantae"))
               ggplot2::geom_point(data = win_df[win_df$iconic_taxon == "Plantae", ],
                                   ggplot2::aes(lon, lat), shape = 21,
                                   fill = iconic_cols[["Plantae"]], colour = plantae_ring_col,
                                   size = 3.2, stroke = 0.55, alpha = 0.85, inherit.aes = FALSE, show.legend = FALSE)} +
            ggplot2::geom_point(data = win_df[win_df$iconic_taxon != "Plantae", ],
                                ggplot2::aes(lon, lat, colour = iconic_taxon),
                                alpha = 0.85, size = 3.2, shape = 16, stroke = 0) +
            ggplot2::scale_colour_manual(values = iconic_cols, guide = "none") +
            ggspatial::annotation_scale(location = "br", width_hint = 0.3,
                                        bar_cols = c("#F7FAFC", "#222222"),
                                        text_col = "#F7FAFC", line_col = "#F7FAFC",
                                        height = grid::unit(0.4, "cm")) +
            ggplot2::coord_sf(crs = 4326,
                              xlim = c(win_bb["xmin"], win_bb["xmax"]),
                              ylim = c(win_bb["ymin"], win_bb["ymax"]), expand = FALSE) +
            ggplot2::labs(x = NULL, y = NULL) +
            ggplot2::theme_void() +
            ggplot2::theme(plot.background  = ggplot2::element_rect(fill = "#040a11", colour = NA),
                           panel.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
                           legend.position = "none")
          # small locator: satellite thumbnail + roads/water + bright window box
          p_loc <- ggplot2::ggplot()
          if (!is.null(loc_tiles))
            p_loc <- p_loc + tidyterra::geom_spatraster_rgb(data = loc_tiles, maxcell = 2e5)
          if (!is.null(water_sf))
            p_loc <- p_loc + ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.3, alpha = 0.7)
          if (!is.null(roads_sf))
            p_loc <- p_loc + ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.25, alpha = 0.7)
          p_loc <- p_loc +
            ggplot2::geom_sf(data = win_ll, fill = NA, colour = "#FFD400", linewidth = 1.2) +
            ggplot2::coord_sf(crs = 4326,
                              xlim = c(bbox_master["xmin"], bbox_master["xmax"]),
                              ylim = c(bbox_master["ymin"], bbox_master["ymax"]), expand = FALSE) +
            ggplot2::theme_void() +
            ggplot2::theme(plot.background  = ggplot2::element_rect(fill = "#040a11", colour = NA),
                           panel.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
                           legend.position = "none", plot.margin = ggplot2::margin(4, 4, 4, 4))
          present_w <- sort(unique(win_pts$iconic_taxon))
          p_leg <- build_taxon_legend(present_w,
                     legend_ncol = if (length(present_w) > 9) 2 else 1, legend_text_sz = 11)
          right_col <- patchwork::wrap_plots(p_loc, p_leg, ncol = 1, heights = c(32, 68))
          combo_z <- patchwork::wrap_plots(p_zoom, right_col, nrow = 1, widths = c(68, 32)) &
            ggplot2::theme(plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA))
          ggplot2::ggsave(figz_path, combo_z, width = 16, height = 9, dpi = 150, bg = "#040a11")
          cat(sprintf("  Zoom %d saved (%d obs)\n", k, nobs))
        }, error = function(e) cat(sprintf("  Zoom %d skipped: %s\n", k, conditionMessage(e))))
      } else {
        cat(sprintf("  Using cached zoom %d\n", k))
      }
      if (file.exists(figz_path)) {
        zoom_slides_md <- paste0(zoom_slides_md, sprintf(
          "## Hotspot Close-Up %d\n\n::: {.slide-subtitle}\n~%g km window \u00b7 %d observations\n:::\n\n![](fig_zoom_%d.png)\n\n",
          k, zoom_window_m / 1000, nobs, k))
      }
    }
    cat(sprintf("Hotspot close-ups: %d window(s)\n", nrow(chosen)))
  } else {
    cat("No qualifying hotspot windows (try lowering zoom_min_obs)\n")
  }
}
cat("\n")

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
        percentage    = round(100 * n / sum(n), 1),
        n_obs         = n,
        display_label = paste0(iconic_taxon, "\n", n, " obs\n(", percentage, "%)")
      )

    # White silhouettes per tile (read on the coloured fills). Layout uses the
    # same args as geom_treemap so icons land on their tiles; nudge cy/size below.
    # one shared layout so tiles, labels and icons all align
    # label line colours (tweak freely): taxon name / obs count / percentage
    lab_name_col <- "#000000"
    lab_n_col    <- "#FFD27F"
    lab_pct_col  <- "#9FD0B6"
    icon_size  <- 0.10   # max silhouette size (used on the big tiles)
    icon_gap   <- 0.012  # horizontal gap between the name and the icon
    icon_char  <- 0.011  # approx x-width per name character
    icon_scale <- 0.33   # icon scales with sqrt(tile area), capped at icon_size
    stats_min_pct <- 3   # tiles below this % show only the taxon name (no obs/%)

    tm <- treemapify::treemapify(taxon_counts, area = "n",
                                 layout = "squarified", start = "bottomleft") |>
      dplyr::mutate(
        cx = (xmin + xmax) / 2, cy = (ymin + ymax) / 2,
        w  = xmax - xmin,       h  = ymax - ymin,
        icon = vapply(as.character(iconic_taxon),
                      function(t) { p <- ensure_taxon_icon_tint(t, "#FFFFFF")
                                    if (is.na(p)) "" else p }, character(1)),
        show_icon  = percentage > 1 & nzchar(icon),   # no icon for taxa <= 1%
        lsize      = dplyr::if_else(percentage >= stats_min_pct,
                       pmax(2.9, pmin(8, 32 * pmin(w, h))),                                   # >=3%: reduced 1/3
                       pmax(3.2, pmin(8, 44 * pmin(w, h) * 8 / pmax(nchar(as.character(iconic_taxon)), 8)))),  # name-only: fit to box
        dy         = pmin(0.075, h * 0.22),                 # gap between the 3 lines (widened for the larger labels)
        name_chars = nchar(as.character(iconic_taxon)),
        name_w     = icon_char * name_chars,                    # approx name width
        isize      = pmin(icon_size, icon_scale * sqrt(w * h)), # shrink icon on small tiles
        # group the name + icon and centre the pair on the tile: shift the text
        # block left by half the (gap + icon), drop the icon to the right
        text_cx    = dplyr::if_else(show_icon, cx - (icon_gap + isize * 0.5) / 2, cx),
        icon_x     = cx + (name_w + icon_gap) / 2,
        show_stats = percentage >= stats_min_pct,             # below this -> name only
        name_y     = dplyr::if_else(show_stats, cy + dy, cy), # centre the name when alone
        lab_n      = paste0(n_obs, " obs"),
        lab_pct    = paste0("(", percentage, "%)")
      )

    p2 <- ggplot2::ggplot(tm) +
      ggplot2::geom_rect(ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
                                      fill = iconic_taxon),
                         colour = "#040a11", linewidth = 0.8) +
      ggplot2::scale_fill_manual(values = taxon_cols, guide = "none") +
      ggplot2::geom_text(ggplot2::aes(x = text_cx, y = name_y, label = iconic_taxon, size = lsize),
                         colour = lab_name_col, fontface = "bold") +
      ggplot2::geom_text(data = subset(tm, show_stats),
                         ggplot2::aes(x = text_cx, y = cy, label = lab_n,
                                      size = lsize * 0.85), colour = lab_n_col) +
      ggplot2::geom_text(data = subset(tm, show_stats),
                         ggplot2::aes(x = text_cx, y = cy - dy, label = lab_pct,
                                      size = lsize * 0.85), colour = lab_pct_col) +
      ggplot2::scale_size_identity() +
      ggimage::geom_image(data = subset(tm, show_icon),
                          ggplot2::aes(x = icon_x, y = name_y, image = icon, size = isize),
                          inherit.aes = FALSE) +
      ggplot2::theme_void() +
      ggplot2::theme(
        plot.background  = ggplot2::element_rect(fill = "#040a11", color = NA),
        panel.background = ggplot2::element_rect(fill = "#040a11", color = NA),
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
  
  ggplot2::ggsave(fig2_path, p2, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#040a11")
  cat("Taxon chart saved:", if(fig2_use_treemap) "treemap" else "bar chart", "\n")
} else {
  cat("Using cached taxon chart\n")
}

# ------------------------------------------------------------------------------
# FIGURE 2b: INSIDE THE "OTHER ANIMALS" GROUP (the refined Animalia breakdown)
# ------------------------------------------------------------------------------
# Keeps the main treemap tidy (one "Animalia" tile) and gives that bucket its own
# readable slide. Only appears when refine_animalia found sub-groups.
fig_ani_path <- file.path(slides_dir, "fig_animalia_breakdown.png")
animalia_slide_md <- ""
if (isTRUE(refine_animalia) && any(obs$iconic_taxon == "Animalia", na.rm = TRUE)) {
  if (force_rebuild || !file.exists(fig_ani_path)) {
    cat("  Creating the 'other animals' breakdown...\n")
    tryCatch({
      ab <- obs |>
        dplyr::filter(iconic_taxon == "Animalia") |>
        dplyr::count(display_taxon, name = "n") |>
        dplyr::arrange(n) |>
        dplyr::mutate(grp = factor(display_taxon, levels = display_taxon))
      pal <- animalia_cols
      miss <- setdiff(as.character(ab$display_taxon), names(pal))
      if (length(miss)) pal[miss] <- "#8A8A82"
      pab <- ggplot2::ggplot(ab, ggplot2::aes(n, grp, fill = display_taxon)) +
        ggplot2::geom_col(width = 0.72, colour = "#040a11", linewidth = 0.3) +
        ggplot2::geom_text(ggplot2::aes(label = n), hjust = -0.35,
                           colour = "#CBD5E0", size = 6) +
        ggplot2::scale_fill_manual(values = pal, guide = "none") +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.12))) +
        ggplot2::labs(x = "Number of observations", y = NULL) +
        theme_bioblitz() +
        ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
      ggplot2::ggsave(fig_ani_path, pab, width = chart_fig_width + 2,
                      height = chart_fig_height + 1, dpi = 300, bg = "#040a11")
      cat("    saved fig_animalia_breakdown.png\n")
    }, error = function(e) cat("    breakdown failed:", conditionMessage(e), "\n"))
  }
  if (file.exists(fig_ani_path))
    animalia_slide_md <- paste0(
      "## Inside the Other Animals\n\n::: {.slide-subtitle}\n",
      "what the \"Animalia\" group is made of\n:::\n\n",
      "![](fig_animalia_breakdown.png)\n\n")
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
    dplyr::mutate(observer_display = forcats::fct_reorder(observer_display, n)) |>
    # Alternate row colour (blue / subtitle-green) by rank, for readability
    dplyr::mutate(rcol = ifelse(dplyr::row_number() %% 2 == 1, "#3498DB", "#9FD0B6"))
  
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
    if (file.exists(path) && !force_refetch_photos) return(TRUE)
    if (is.na(url)) {
      cat("  Skipping NA URL for", basename(path), "\n")
      return(FALSE)
    }
    cat("  Downloading:", url, "\n")
    tryCatch({
      resp <- httr2::request(url) |> 
        httr2::req_user_agent("walpole-bioblitz-datadive") |> 
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
  
  # y-axis labels in factor-level order; colour each to match its row line
  name_cols <- top_observers$rcol[match(levels(top_observers$observer_display),
                                        as.character(top_observers$observer_display))]

  # Create lollipop chart
  p3 <- ggplot2::ggplot(top_observers, ggplot2::aes(x = n, y = observer_display)) +
    # Lollipop sticks
    ggplot2::geom_segment(
      ggplot2::aes(x = 0, xend = n, y = observer_display, yend = observer_display,
                   colour = rcol),
      linewidth = 1.5
    ) +
    ggplot2::scale_colour_identity() +
    # Background circles ONLY for observers without profile images
    {if (any(!top_observers$img_cropped)) {
      ggplot2::geom_point(
        data = top_observers |> dplyr::filter(!img_cropped),
        ggplot2::aes(colour = rcol),
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
      axis.text.y = ggplot2::element_text(size = axis_text_size, face = "bold", colour = name_cols),
      panel.grid.major.x = ggplot2::element_line(color = "#333333", linewidth = 0.3),
      panel.grid.major.y = ggplot2::element_blank()
    )
  
  ggplot2::ggsave(fig3_path, p3, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#040a11")
  cat("Top observers lollipop chart saved with", sum(top_observers$img_cropped), "circular profile images with crisp borders\n")
} else {
  cat("Using cached observers chart\n")
}

# ==============================================================================
# FIGURE 4: OBSERVATIONS PER HOUR
# ==============================================================================

cat("=== GENERATING FIGURE 4: OBSERVATIONS PER HOUR ===\n")

# Day-aware layout shared by both hourly plots: 1-3 days in ONE row (a single day
# fills the full width), 4 days as a 2x2 grid; height grows if days wrap to more rows.
# Uses observed_on (a required field, always present) so it never depends on the time.
# base R (length/unique) so it never pipes a dplyr chain into terra/sf's S4 nrow(),
# which would break dplyr masking and error with "<col> not found"
.dd <- obs$observed_on
.dd <- .dd[!is.na(.dd) & .dd >= date_min & .dd <= date_max]
.hourly_days <- length(unique(.dd))
n_days_h     <- max(1L, .hourly_days)
facet_ncol_h <- if (n_days_h <= 3) n_days_h else 2L   # 1-3 in one row, 4 as 2x2 (5+ wraps in 2 cols)
facet_nrow_h <- ceiling(n_days_h / facet_ncol_h)
hourly_h     <- 5.5 + 2.0 * facet_nrow_h              # scales with the actual number of rows

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
    ggplot2::facet_wrap(~ day_label, ncol = facet_ncol_h) +   # shared y -> single axis on the left only
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
    theme_bioblitz() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(colour = "#F7FAFC", face = "bold", size = legend_text_size),
      panel.spacing.x = ggplot2::unit(0.5, "lines"),   # tighter gap between day panels
      plot.title = ggplot2::element_text(size = plot_title_size, hjust = 0.5, 
                                         color = "#F7FAFC", face = "bold")
    )
  
  # wider aspect than the other charts so the distributions fill more of the slide
  ggplot2::ggsave(fig4_path, p4, width = 16, height = hourly_h, dpi = 300)
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
    ggplot2::facet_wrap(~ day_label, ncol = facet_ncol_h) +   # shared y -> single axis on the left only
    ggplot2::scale_x_continuous(
      breaks = seq(0, 24, 3),  # Show labels every 3 hours
      limits = c(0, 24),
      expand = c(0, 0)
    ) +
    ggplot2::scale_fill_manual(
      "Taxon Groups",
      values = iconic_cols,
      labels = label_with_icon_md
    ) +
    ggplot2::labs(
      title = NULL,  # No title - slide title provides context
      x = "Hour of Day", 
      y = "Number of Observations"
    ) +
    theme_bioblitz() +
    ggplot2::theme(
      strip.text = ggplot2::element_text(colour = "#F7FAFC", face = "bold", size = legend_text_size),
      panel.spacing.x = ggplot2::unit(0.5, "lines"),   # tighter gap between day panels
      plot.title = ggplot2::element_text(size = plot_title_size, hjust = 0.5, 
                                         color = "#F7FAFC", face = "bold"),
      legend.position = "right"
    )
  
  p5 <- p5 + ggplot2::theme(legend.text = ggtext::element_markdown(size = legend_text_size)) +
    ggplot2::guides(fill = ggplot2::guide_legend(ncol = legend_ncol, byrow = TRUE))
  p5 <- p5 + ggplot2::theme(legend.position = "none")
  compose_with_legend(p5, sort(unique(obs$iconic_taxon)), fig5_path, map_frac = 68, h = hourly_h,
                      leg_icon = 0.07, leg_text = 6, leg_colgap = 9,
                      leg_lmar = 0, leg_rpad = 7, leg_lpad = -0.4)
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
        ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.5, alpha = 0.7)
      }} +
      {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
        ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.4, alpha = 0.7)
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
      ggplot2::scale_fill_gradientn(
        name = "Species\nRichness",
        colours = zissou1_heat,
        na.value = NA
      ) +
      ggplot2::theme_void(base_size = 16) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
        legend.position = "right",
        legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
        legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
        legend.key.width = ggplot2::unit(1.5, "cm"),
        legend.key.height = ggplot2::unit(3, "cm")
      )
    
    ggplot2::ggsave(fig6a_path, p6a, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "#040a11")
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
          ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.5, alpha = 0.7)
        }} +
        {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
          ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.4, alpha = 0.7)
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
        ggplot2::scale_fill_gradientn(
          name = "Species per\nObservation",
          colours = zissou1_heat,
          na.value = NA
        ) +
        ggplot2::theme_void(base_size = 16) +
        ggplot2::theme(
          plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
          legend.position = "right",
          legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
          legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
          legend.key.width = ggplot2::unit(1.5, "cm"),
          legend.key.height = ggplot2::unit(3, "cm")
        )
      
      ggplot2::ggsave(fig6b_path, p6b, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "#040a11")
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
            ggplot2::geom_sf(data = water_sf, colour = "#4FA3FF", linewidth = 0.5, alpha = 0.7)
          }} +
          {if (!is.null(roads_sf) && nrow(roads_sf) > 0) {
            ggplot2::geom_sf(data = roads_sf, colour = "#B0B0B0", linewidth = 0.4, alpha = 0.7)
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
          ggplot2::scale_fill_gradientn(
            name = "Species per\nObservation",
            colours = zissou1_heat,
            na.value = NA
          ) +
          ggplot2::theme_void(base_size = 16) +
          ggplot2::theme(
            plot.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
            legend.position = "right",
            legend.text = ggplot2::element_text(colour = "white", size = legend_text_size),
            legend.title = ggplot2::element_text(colour = "white", size = legend_title_size, face = "bold"),
            legend.key.width = ggplot2::unit(1.5, "cm"),
            legend.key.height = ggplot2::unit(3, "cm")
          )
        
        ggplot2::ggsave(fig6c_path, p6c, width = map_fig_width, height = map_fig_height, dpi = 300, bg = "#040a11")
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
        plot.background = ggplot2::element_rect(fill = "#040a11", color = NA),
        panel.background = ggplot2::element_rect(fill = "#040a11", color = NA),
        panel.grid.major = ggplot2::element_line(color = "#333333", linewidth = 0.3),
        panel.grid.minor = ggplot2::element_line(color = "#0b1b2a", linewidth = 0.2),
        text = ggplot2::element_text(color = "#e0e0e0"),
        axis.text = ggplot2::element_text(color = "#b0b0b0", size = 28),
        axis.title = ggplot2::element_text(color = "#e0e0e0", face = "bold", size = axis_title_size),
        plot.title = ggplot2::element_text(color = "#ffffff", face = "bold", size = 20),
        plot.subtitle = ggplot2::element_text(color = "#b0b0b0", size = 14),
        legend.background = ggplot2::element_rect(fill = "#0b1b2a", color = NA),
        legend.text = ggplot2::element_text(color = "#e0e0e0", size = 34),
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
    
    ggplot2::ggsave(fig7a_path, p7a, width = chart_fig_width, height = chart_fig_height, dpi = 300, bg = "#040a11")
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
      
      ggplot2::ggsave(fig7b_path, p7b, width = 14, height = 8, dpi = 300, bg = "#040a11")
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
# SITE GROUPING MODULE - composition, PCoA and per-site rarefaction
# ==============================================================================
# Assigns each observation to its NEAREST site anchor (within site_max_dist_m)
# and builds three figures. Everything here works on TAXON, not species rank:
# the composition figures use iconic_taxon, and the rarefaction accumulates
# distinct taxon_id at ANY rank. That is deliberate - filtering to
# taxon_rank == "species" throws away roughly half the records and guts the
# smaller sites.
# Expects: obs, slides_dir, theme_bioblitz(), iconic_cols, chart_fig_width/height,
#          plot_title_size, force_rebuild, n_permutations, step_size
# ==============================================================================

if (isTRUE(include_sites)) {
  cat("\n=== SITE GROUPING ===\n")

  # --- read the site anchors --------------------------------------------------
  read_sites_csv <- function(path) {
    df <- readr::read_csv(path, show_col_types = FALSE) |> janitor::clean_names()
    nm <- names(df)
    site_col <- nm[nm %in% c("site", "name", "site_name", "location")][1]
    lat_col  <- nm[nm %in% c("lat", "latitude", "y")][1]
    lon_col  <- nm[nm %in% c("lon", "long", "lng", "longitude", "x")][1]
    if (any(is.na(c(site_col, lat_col, lon_col))))
      stop("sites_csv needs columns for site, lat and lon (found: ",
           paste(nm, collapse = ", "), ")")
    tibble::tibble(site = as.character(df[[site_col]]),
                   lat  = as.numeric(df[[lat_col]]),
                   lon  = as.numeric(df[[lon_col]]))
  }

  # Each leaf Folder = one site. Its Points are the anchors; if a folder holds
  # only tracks (a trapping line, say), fall back to the LineString vertices so
  # the site is still represented.
  read_sites_kml <- function(path) {
    kml <- path
    if (grepl("\\.kmz$", path, ignore.case = TRUE)) {
      td <- file.path(tempdir(), "bb_kmz"); unlink(td, recursive = TRUE)
      dir.create(td, recursive = TRUE, showWarnings = FALSE)
      utils::unzip(path, exdir = td)
      cand <- list.files(td, pattern = "\\.kml$", recursive = TRUE, full.names = TRUE)
      if (!length(cand)) stop("no .kml found inside ", basename(path))
      kml <- cand[1]
    }
    doc <- xml2::read_xml(kml); xml2::xml_ns_strip(doc)
    folders <- xml2::xml_find_all(doc, "//Folder[not(.//Folder)]")
    if (!length(folders)) stop("no site folders found in ", basename(kml))
    out <- purrr::map_dfr(folders, function(f) {
      nm <- xml2::xml_text(xml2::xml_find_first(f, "./name"))
      cs <- xml2::xml_text(xml2::xml_find_all(f, ".//Point/coordinates"))
      if (!length(cs)) cs <- xml2::xml_text(xml2::xml_find_all(f, ".//LineString/coordinates"))
      if (!length(cs)) return(NULL)
      toks <- unlist(strsplit(trimws(paste(cs, collapse = " ")), "[[:space:]]+"))
      toks <- toks[nzchar(toks)]
      xy <- do.call(rbind, lapply(strsplit(toks, ","), function(p) {
        if (length(p) < 2) return(NULL)
        data.frame(lon = as.numeric(p[1]), lat = as.numeric(p[2]))
      }))
      if (is.null(xy)) return(NULL)
      tibble::tibble(site = trimws(nm), lat = xy$lat, lon = xy$lon)
    })
    out
  }

  site_anchors <- tryCatch({
    if (nzchar(sites_csv) && file.exists(sites_csv)) {
      cat("Reading sites from CSV:", sites_csv, "\n"); read_sites_csv(sites_csv)
    } else if (nzchar(sites_kmz) && file.exists(sites_kmz)) {
      cat("Reading sites from KML/KMZ:", sites_kmz, "\n")
      if (!requireNamespace("xml2", quietly = TRUE)) stop("xml2 not installed")
      read_sites_kml(sites_kmz)
    } else {
      stop("set sites_csv or sites_kmz to an existing file")
    }
  }, error = function(e) { cat("  Site file problem:", conditionMessage(e), "\n"); NULL })

  if (!is.null(site_anchors)) {
    site_anchors <- site_anchors |>
      dplyr::filter(!is.na(lat), !is.na(lon), nzchar(site))
  }

  if (is.null(site_anchors) || nrow(site_anchors) == 0) {
    cat("  No usable site anchors - skipping the site module.\n")
  } else {
    n_sites_in <- length(unique(site_anchors$site))
    cat("  ", nrow(site_anchors), "anchors across", n_sites_in, "sites\n")

    # --- assign each observation to its nearest anchor -------------------------
    obs_xy <- obs |> dplyr::filter(!is.na(longitude), !is.na(latitude))
    o_sf <- sf::st_as_sf(obs_xy, coords = c("longitude", "latitude"), crs = 4326,
                         remove = FALSE)
    a_sf <- sf::st_as_sf(site_anchors, coords = c("lon", "lat"), crs = 4326)
    # metres, not degrees: project both to Web Mercator scaled at this latitude
    o_m <- sf::st_transform(o_sf, 3857); a_m <- sf::st_transform(a_sf, 3857)
    merc_scale <- cos(hq_lat * pi / 180)   # 3857 exaggerates distance by 1/cos(lat)
    idx <- sf::st_nearest_feature(o_m, a_m)
    dmin <- as.numeric(sf::st_distance(o_m, a_m[idx, ], by_element = TRUE)) * merc_scale

    obs_site <- obs_xy |>
      dplyr::mutate(
        site_raw = site_anchors$site[idx],
        site_dist_m = dmin,
        site = ifelse(dmin <= site_max_dist_m, site_raw, NA_character_)
      )

    # sensitivity table: is site_max_dist_m a sensible cut?
    cat("\n  Unassigned rate vs cutoff (pick a value where this stops falling fast):\n")
    for (cut in c(250, 500, 750, 1000, 1500, 2000)) {
      k <- sum(dmin <= cut)
      cat(sprintf("    %5dm  assigned %5d   unassigned %5d  (%4.1f%%)\n",
                  cut, k, nrow(obs_site) - k, 100 * (nrow(obs_site) - k) / nrow(obs_site)))
    }
    n_ass <- sum(!is.na(obs_site$site))
    cat("\n  Using", site_max_dist_m, "m ->", n_ass, "assigned,",
        nrow(obs_site) - n_ass, "elsewhere\n")

    site_n <- obs_site |> dplyr::filter(!is.na(site)) |>
      dplyr::count(site, name = "n_obs")
    keep_sites <- site_n$site[site_n$n_obs >= site_min_obs]
    cat("  ", length(keep_sites), "of", nrow(site_n), "sites have >=", site_min_obs,
        "observations\n")

    short <- function(x) ifelse(nchar(x) > site_label_max,
                                paste0(substr(x, 1, site_label_max - 1), "\u2026"), x)
    # keep an optional leading "N." then at most two words (for the scatter/PCoA/
    # rarefaction/equal-effort labels, which have no room for full names)
    two_words <- function(x) {
      pre  <- ifelse(grepl("^[0-9]+\\.", x), sub("^([0-9]+\\.[[:space:]]*).*$", "\\1", x), "")
      body <- sub("^[0-9]+\\.[[:space:]]*", "", x)
      w    <- vapply(strsplit(body, "[[:space:]]+"),
                     function(t) paste(utils::head(t, 2), collapse = " "), character(1))
      paste0(pre, w)
    }
    ELSE_LAB <- "Elsewhere (unassigned)"
    have_repel <- requireNamespace("ggrepel", quietly = TRUE)

    # --- per-site richness + completeness stats (Good-Turing) -----------------
    # coverage / new-taxon probability use the same distinct-taxon_id-at-any-rank
    # basis as the accumulation curve. Feeds the scatter (slide A) and the
    # equal-effort bar (slide C).
    site_tax <- obs_site |> dplyr::filter(!is.na(site), !is.na(taxon_id))
    gt_stats <- function(ids) {
      n <- length(ids); cnt <- table(ids); S <- length(cnt)
      f1 <- sum(cnt == 1); f2 <- sum(cnt == 2)
      cover <- if (f1 > 0 && n > 1)
        1 - (f1 / n) * ((n - 1) * f1 / ((n - 1) * f1 + 2 * max(f2, 1))) else 1
      tibble::tibble(n_obs = n, n_taxa = S,
                     new_p = if (n > 0) 100 * f1 / n else 0,
                     coverage = 100 * cover)
    }
    site_stats <- site_tax |> dplyr::group_by(site) |>
      dplyr::group_modify(~ gt_stats(.x$taxon_id)) |> dplyr::ungroup()

    # richness rarefied to a common effort = the smallest KEPT site (analytic
    # Hurlbert; lchoose keeps it stable for large n)
    rarefy_to <- function(ids, m) {
      cnt <- as.numeric(table(ids)); n <- sum(cnt)
      if (m > n) return(NA_real_)
      sum(1 - exp(lchoose(n - cnt, m) - lchoose(n, m)))
    }
    base_n <- if (length(keep_sites))
      min(site_stats$n_obs[site_stats$site %in% keep_sites]) else NA_integer_
    if (!is.na(base_n)) {
      std_tbl <- site_tax |> dplyr::filter(site %in% keep_sites) |>
        dplyr::group_by(site) |>
        dplyr::group_modify(~ tibble::tibble(rich_std = rarefy_to(.x$taxon_id, base_n))) |>
        dplyr::ungroup()
      site_stats <- dplyr::left_join(site_stats, std_tbl, by = "site")
    } else site_stats$rich_std <- NA_real_

    # plant-dominated vs mixed, reused for point colour on A and C
    grp_tbl <- obs_site |> dplyr::filter(!is.na(site)) |>
      dplyr::group_by(site) |>
      dplyr::summarise(plant_pct = 100 * mean(iconic_taxon == "Plantae", na.rm = TRUE),
                       .groups = "drop") |>
      dplyr::mutate(grp = ifelse(plant_pct >= 70, "Plant-dominated", "Mixed / diverse"))
    site_stats <- dplyr::left_join(site_stats, grp_tbl, by = "site")
    grp_pal <- c("Plant-dominated" = "#4C7A5D", "Mixed / diverse" = "#EBCC2A")

    # non-overlapping site labels (ggrepel if available, else plain text)
    site_label_layer <- function(df, xcol, ycol, lab_colour = "#F7FAFC") {
      aes_lab <- ggplot2::aes(x = .data[[xcol]], y = .data[[ycol]], label = two_words(site))
      if (have_repel) {
        ggrepel::geom_text_repel(data = df, mapping = aes_lab, size = 6.2,
          fontface = "bold", colour = lab_colour, box.padding = 0.9,
          point.padding = 0.5, min.segment.length = 0, segment.colour = "#5a6b78",
          segment.size = 0.3, max.overlaps = Inf, seed = 7, show.legend = FALSE)
      } else {
        ggplot2::geom_text(data = df, mapping = aes_lab, size = 6.2, fontface = "bold",
          colour = lab_colour, vjust = -1.3, show.legend = FALSE)
      }
    }

    # ==========================================================================
    # FIGURE A: taxon composition per site (horizontal stacked bars)
    # ==========================================================================
    figA <- file.path(slides_dir, "fig_site_composition.png")
    if (force_rebuild || !file.exists(figA)) {
      cat("  Building site composition figure...\n")
      tryCatch({
        comp_dat <- obs_site |>
          dplyr::mutate(grp = ifelse(is.na(site), ELSE_LAB, site)) |>
          dplyr::filter(grp != ELSE_LAB | isTRUE(site_show_elsewhere)) |>
          dplyr::mutate(iconic_taxon = ifelse(is.na(iconic_taxon) | !nzchar(iconic_taxon),
                                              "Unknown", iconic_taxon)) |>
          dplyr::count(grp, iconic_taxon, name = "n") |>
          dplyr::group_by(grp) |>
          dplyr::mutate(pct = 100 * n / sum(n), n_site = sum(n)) |>
          dplyr::ungroup()

        # order sites by % plants, with Elsewhere pinned to the bottom as reference
        plant_pct <- comp_dat |>
          dplyr::filter(iconic_taxon == "Plantae") |>
          dplyr::select(grp, pp = pct)
        ord <- comp_dat |> dplyr::distinct(grp, n_site) |>
          dplyr::left_join(plant_pct, by = "grp") |>
          dplyr::mutate(pp = ifelse(is.na(pp), 0, pp),
                        is_else = grp == ELSE_LAB) |>
          dplyr::arrange(is_else, pp)
        comp_dat <- comp_dat |>
          dplyr::mutate(grp = factor(grp, levels = ord$grp))

        lab_map <- setNames(
          paste0(two_words(as.character(ord$grp)), "  (", ord$n_site, ")"), ord$grp)
        # sites below the threshold are greyed, not hidden - the reader sees them
        # and sees why they are not in the other two figures
        faint <- ord$grp[ord$n_site < site_min_obs & !ord$is_else]

        tax_lv <- comp_dat |> dplyr::group_by(iconic_taxon) |>
          dplyr::summarise(t = sum(n), .groups = "drop") |>
          dplyr::arrange(dplyr::desc(t)) |> dplyr::pull(iconic_taxon)
        comp_dat <- comp_dat |>
          dplyr::mutate(iconic_taxon = factor(iconic_taxon, levels = rev(tax_lv)))

        pal <- iconic_cols[levels(comp_dat$iconic_taxon)]
        pal[is.na(pal)] <- "#888780"
        names(pal) <- levels(comp_dat$iconic_taxon)

        pA <- ggplot2::ggplot(comp_dat,
                ggplot2::aes(x = pct, y = grp, fill = iconic_taxon)) +
          ggplot2::geom_col(width = 0.82, colour = "#040a11", linewidth = 0.3) +
          ggplot2::scale_fill_manual(values = pal, name = NULL,
                                     guide = ggplot2::guide_legend(reverse = TRUE, ncol = 1)) +
          ggplot2::scale_y_discrete(labels = lab_map) +
          ggplot2::scale_x_continuous(expand = c(0, 0), breaks = c(0, 25, 50, 75, 100),
                                      labels = function(x) paste0(x, "%")) +
          ggplot2::labs(title = NULL, x = "Percent of the observations at that site", y = NULL) +
          theme_bioblitz() +
          ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                         legend.text   = ggplot2::element_text(size = 22),
                         legend.key    = ggplot2::element_rect(fill = NA, colour = NA),
                         legend.key.height = grid::unit(2.9, "lines"),
                         legend.key.width  = grid::unit(1.6, "lines"),
                         legend.spacing.y  = grid::unit(0.9, "lines"),
                         axis.text.y = ggplot2::element_text(hjust = 1))
        # wide landscape aspect: the deck shows figures at a fixed HEIGHT, so a
        # wide figure fills the slide width instead of sitting in a narrow strip
        ggplot2::ggsave(figA, pA, width = 19, height = 10,
                        dpi = 300, bg = "#040a11")
        cat("    saved fig_site_composition.png\n")
      }, error = function(e) cat("    composition figure failed:", conditionMessage(e), "\n"))
    }

    # ==========================================================================
    # FIGURE B: PCoA of sites by taxon composition (Bray-Curtis)
    # ==========================================================================
    figB <- file.path(slides_dir, "fig_site_pcoa.png")
    if ((force_rebuild || !file.exists(figB)) && length(keep_sites) >= 4) {
      cat("  Building site PCoA...\n")
      tryCatch({
        wide <- obs_site |>
          dplyr::filter(site %in% keep_sites) |>
          dplyr::mutate(iconic_taxon = ifelse(is.na(iconic_taxon) | !nzchar(iconic_taxon),
                                              "Unknown", iconic_taxon)) |>
          dplyr::count(site, iconic_taxon, name = "n") |>
          tidyr::pivot_wider(names_from = iconic_taxon, values_from = n, values_fill = 0)
        M <- as.matrix(wide[, -1, drop = FALSE])
        rownames(M) <- wide$site
        P <- M / rowSums(M)            # proportions: removes the effort signal

        # Bray-Curtis. On proportions each row sums to 1, so this reduces to
        # half the total absolute difference, but keep the general form.
        nS <- nrow(P); D <- matrix(0, nS, nS)
        for (i in seq_len(nS)) for (j in seq_len(nS))
          D[i, j] <- sum(abs(P[i, ] - P[j, ])) / sum(P[i, ] + P[j, ])
        dimnames(D) <- list(rownames(P), rownames(P))

        pc <- stats::cmdscale(stats::as.dist(D), k = 2, eig = TRUE)
        ev <- pc$eig[pc$eig > 0]; ve <- round(100 * ev / sum(ev))

        pts <- tibble::tibble(
          site = rownames(P), x = pc$points[, 1], y = pc$points[, 2],
          n_obs = as.numeric(rowSums(M)),
          plant_pct = 100 * P[, match("Plantae", colnames(P))]
        ) |>
          dplyr::mutate(plant_pct = ifelse(is.na(plant_pct), 0, plant_pct),
                        grp = ifelse(plant_pct >= 70, "Plant-dominated", "Mixed / diverse"))

        # taxon arrows: correlation of each taxon proportion with the two axes.
        # Not a formal biplot - a readable gradient guide.
        arr <- purrr::map_dfr(colnames(P), function(t) {
          v <- P[, t]
          if (stats::sd(v) == 0) return(NULL)
          tibble::tibble(taxon = t,
                         ax = stats::cor(pts$x, v), ay = stats::cor(pts$y, v))
        }) |> dplyr::filter(pmax(abs(ax), abs(ay)) > 0.45)
        sc <- 0.7 * max(abs(c(pts$x, pts$y))) / max(abs(c(arr$ax, arr$ay)), na.rm = TRUE)
        # colour the taxon arrows with the SAME palette the other plots use
        arr_cols <- iconic_cols[arr$taxon]; arr_cols[is.na(arr_cols)] <- "#B8C4CE"
        names(arr_cols) <- arr$taxon
        # taxon labels repel too, so site names and vector labels avoid each other
        taxon_lab_layer <- if (have_repel)
          ggrepel::geom_text_repel(data = arr,
            ggplot2::aes(x = ax * sc * 1.12, y = ay * sc * 1.12, label = taxon, colour = taxon),
            size = 6.4, fontface = "bold", box.padding = 0.5, point.padding = 0.2,
            min.segment.length = Inf, max.overlaps = Inf, seed = 7, show.legend = FALSE)
        else
          ggplot2::geom_text(data = arr,
            ggplot2::aes(x = ax * sc * 1.12, y = ay * sc * 1.12, label = taxon, colour = taxon),
            size = 6.4, fontface = "bold", show.legend = FALSE)

        pB <- ggplot2::ggplot() +
          ggplot2::geom_hline(yintercept = 0, colour = "#2c3a4a", linetype = "dashed") +
          ggplot2::geom_vline(xintercept = 0, colour = "#2c3a4a", linetype = "dashed") +
          ggplot2::geom_segment(data = arr,
            ggplot2::aes(x = 0, y = 0, xend = ax * sc, yend = ay * sc, colour = taxon),
            linewidth = 0.9, arrow = grid::arrow(length = grid::unit(0.22, "cm")),
            show.legend = FALSE) +
          taxon_lab_layer +
          ggplot2::scale_colour_manual(values = arr_cols, guide = "none") +
          ggplot2::geom_point(data = pts,
            ggplot2::aes(x = x, y = y, size = n_obs, fill = grp),
            shape = 21, colour = "#040a11", alpha = 0.85, stroke = 0.8) +
          ggplot2::scale_size_area(max_size = 16, name = "Observations",
            # without this the size-legend keys inherit no fill and vanish on the
            # dark background - force a visible neutral disc
            guide = ggplot2::guide_legend(
              override.aes = list(fill = "#B8C4CE", colour = "#040a11",
                                  shape = 21, stroke = 0.8))) +
          ggplot2::scale_fill_manual(values = grp_pal, name = NULL,
            guide = ggplot2::guide_legend(
              override.aes = list(size = 6, shape = 21, colour = "#040a11"))) +
          site_label_layer(pts, "x", "y") +
          ggplot2::labs(
            x = paste0("Axis 1 (", ve[1], "%)"),
            y = paste0("Axis 2 (", ve[2], "%)")) +
          ggplot2::coord_cartesian(clip = "off") +
          theme_bioblitz()
        ggplot2::ggsave(figB, pB, width = chart_fig_width + 3, height = chart_fig_height + 1,
                        dpi = 300, bg = "#040a11")
        cat("    saved fig_site_pcoa.png (axes 1+2 = ", ve[1] + ve[2], "% of variation)\n", sep = "")
      }, error = function(e) cat("    PCoA failed:", conditionMessage(e), "\n"))
    }

    # ==========================================================================
    # FIGURE C: per-site rarefaction (taxon accumulation, ALL ranks)
    # ==========================================================================
    figC <- file.path(slides_dir, "fig_site_rarefaction.png")
    if ((force_rebuild || !file.exists(figC)) && length(keep_sites) >= 2) {
      cat("  Building per-site rarefaction (", n_permutations, " permutations)...\n", sep = "")
      tryCatch({
        rare_dat <- obs_site |>
          dplyr::filter(site %in% keep_sites, !is.na(taxon_id))

        # accumulate distinct taxon_id at ANY rank - see the module note above
        curve_one <- function(df, step) {
          nn <- nrow(df)
          steps <- unique(c(seq(step, nn, by = step), nn))
          purrr::map_dfr(seq_len(n_permutations), function(perm) {
            sh <- df[sample(nn), ]
            purrr::map_dfr(steps, function(k) {
              tibble::tibble(n_observations = k,
                             n_taxa = dplyr::n_distinct(sh$taxon_id[1:k]),
                             permutation = perm)
            })
          })
        }

        set.seed(42)
        site_curves <- purrr::map_dfr(sort(keep_sites), function(s) {
          d <- rare_dat |> dplyr::filter(site == s)
          if (nrow(d) < 10) return(NULL)
          st <- max(1, floor(nrow(d) / 40))   # ~40 points per curve regardless of n
          curve_one(d, st) |>
            dplyr::group_by(n_observations) |>
            dplyr::summarise(mean_taxa = mean(n_taxa),
                             lo = stats::quantile(n_taxa, 0.025),
                             hi = stats::quantile(n_taxa, 0.975),
                             .groups = "drop") |>
            dplyr::mutate(site = s)
        })

        ends <- site_curves |> dplyr::group_by(site) |>
          dplyr::filter(n_observations == max(n_observations)) |> dplyr::ungroup()

        # tracking-line layout: a dashed horizontal from each curve's end runs
        # to a common right gutter, then ggrepel stacks the names in a tidy
        # column there instead of piling them onto the curves
        x_max <- max(site_curves$n_observations)
        gutter <- x_max * 1.02
        end_lab <- ends |> dplyr::mutate(gx = gutter)

        lab_layer <- if (have_repel)
          ggrepel::geom_text_repel(data = end_lab,
            ggplot2::aes(x = gx, y = mean_taxa, label = two_words(site), colour = site),
            hjust = 0, direction = "y", size = 6, fontface = "bold", xlim = c(gutter, NA),
            segment.colour = "#5a6b78", segment.size = 0.3, min.segment.length = 0,
            box.padding = 0.28, max.overlaps = Inf, seed = 7, show.legend = FALSE)
        else
          ggplot2::geom_text(data = end_lab,
            ggplot2::aes(x = gx, y = mean_taxa, label = two_words(site), colour = site),
            hjust = 0, size = 5.4, fontface = "bold", show.legend = FALSE)

        pC <- ggplot2::ggplot(site_curves,
                ggplot2::aes(x = n_observations, y = mean_taxa,
                             group = site, colour = site)) +
          ggplot2::geom_ribbon(ggplot2::aes(ymin = lo, ymax = hi, fill = site),
                               alpha = 0.12, colour = NA) +
          ggplot2::geom_line(linewidth = 1.1) +
          ggplot2::geom_segment(data = ends,
            ggplot2::aes(x = n_observations, xend = gutter,
                         y = mean_taxa, yend = mean_taxa, colour = site),
            linetype = "dashed", linewidth = 0.4, alpha = 0.55) +
          ggplot2::geom_point(data = ends, size = 2.6) +
          lab_layer +
          ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.01, 0.40))) +
          ggplot2::labs(x = "Observations", y = "Distinct taxa recorded") +
          ggplot2::coord_cartesian(clip = "off") +
          theme_bioblitz() +
          ggplot2::theme(legend.position = "none")
        ggplot2::ggsave(figC, pC, width = chart_fig_width + 3, height = chart_fig_height + 1,
                        dpi = 300, bg = "#040a11")
        cat("    saved fig_site_rarefaction.png\n")
      }, error = function(e) cat("    rarefaction failed:", conditionMessage(e), "\n"))
    }

    # ==========================================================================
    # FIGURE D (slide A): richness vs completeness scatter
    # ==========================================================================
    figD <- file.path(slides_dir, "fig_site_completeness_scatter.png")
    if (force_rebuild || !file.exists(figD)) {
      cat("  Building richness-vs-completeness scatter...\n")
      tryCatch({
        sc_dat <- site_stats |> dplyr::mutate(sparse = n_obs < site_min_obs)
        mx <- stats::median(sc_dat$coverage); my <- stats::median(sc_dat$n_taxa)
        xr <- range(sc_dat$coverage, na.rm = TRUE); yr <- range(sc_dat$n_taxa, na.rm = TRUE)
        yspan <- diff(yr)
        quad <- tibble::tibble(   # top labels sit up near the top edge, clear of the points
          x = c(xr[2], xr[1], xr[1], xr[2]),
          y = c(yr[2] + yspan * 0.13, yr[2] + yspan * 0.13, yr[1], yr[1]),
          h = c(1, 0, 0, 1), v = c(1, 1, 1, 1),
          lab = c("rich + well sampled", "rich, more to find", "sparse", "species-poor"))

        pD <- ggplot2::ggplot(sc_dat,
                ggplot2::aes(x = coverage, y = n_taxa)) +
          ggplot2::annotate("rect", xmin = mx, xmax = Inf, ymin = my, ymax = Inf,
                            fill = "#12331f", alpha = 0.35) +
          ggplot2::geom_vline(xintercept = mx, linetype = "dashed", colour = "#2c3a4a") +
          ggplot2::geom_hline(yintercept = my, linetype = "dashed", colour = "#2c3a4a") +
          ggplot2::geom_text(data = quad, ggplot2::aes(x = x, y = y, label = lab),
            hjust = quad$h, vjust = quad$v, fontface = "bold.italic",
            colour = "#8FB0C4", size = 6.4, inherit.aes = FALSE) +
          ggplot2::geom_point(ggplot2::aes(size = n_obs, fill = grp, alpha = sparse),
                              shape = 21, colour = "#040a11", stroke = 0.8) +
          site_label_layer(sc_dat, "coverage", "n_taxa") +
          ggplot2::scale_size_area(max_size = 17, name = "Observations",
            guide = ggplot2::guide_legend(
              override.aes = list(fill = "#B8C4CE", colour = "#040a11", shape = 21))) +
          ggplot2::scale_fill_manual(values = grp_pal, name = NULL,
            guide = ggplot2::guide_legend(
              override.aes = list(size = 6, shape = 21, colour = "#040a11"))) +
          ggplot2::scale_alpha_manual(values = c("FALSE" = 0.85, "TRUE" = 0.4),
                                      guide = "none") +
          ggplot2::scale_x_continuous(labels = function(x) paste0(x, "%"),
                                      expand = ggplot2::expansion(mult = 0.08)) +
          ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0.05, 0.18))) +
          ggplot2::labs(x = "Estimated completeness  (% of taxa found)",
                        y = "Taxa recorded") +
          ggplot2::coord_cartesian(clip = "off") +
          theme_bioblitz() +
          ggplot2::theme(panel.grid = ggplot2::element_blank())
        ggplot2::ggsave(figD, pD, width = chart_fig_width + 3, height = chart_fig_height + 1,
                        dpi = 300, bg = "#040a11")
        cat("    saved fig_site_completeness_scatter.png\n")
      }, error = function(e) cat("    scatter failed:", conditionMessage(e), "\n"))
    }

    # ==========================================================================
    # FIGURE E (slide C): richness at equal effort (rarefied to base_n)
    # ==========================================================================
    figE <- file.path(slides_dir, "fig_site_richness_std.png")
    if ((force_rebuild || !file.exists(figE)) && !is.na(base_n)) {
      cat("  Building equal-effort richness bar (base n = ", base_n, ")...\n", sep = "")
      tryCatch({
        std_dat <- site_stats |> dplyr::filter(!is.na(rich_std)) |>
          dplyr::mutate(site = two_words(site),
                        site = forcats::fct_reorder(site, rich_std))
        pE <- ggplot2::ggplot(std_dat,
                ggplot2::aes(x = rich_std, y = site, fill = grp)) +
          ggplot2::geom_col(width = 0.74, colour = "#040a11", linewidth = 0.3) +
          ggplot2::geom_text(ggplot2::aes(label = round(rich_std)),
                             hjust = -0.25, colour = "#CBD5E0", size = 5) +
          ggplot2::scale_fill_manual(values = grp_pal, name = NULL) +
          ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.10))) +
          ggplot2::labs(x = paste0("Taxa per ", base_n, " observations (equal effort)"),
                        y = NULL) +
          theme_bioblitz() +
          ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
        ggplot2::ggsave(figE, pE, width = 16, height = 10, dpi = 300, bg = "#040a11")
        cat("    saved fig_site_richness_std.png\n")
      }, error = function(e) cat("    equal-effort bar failed:", conditionMessage(e), "\n"))
    }

    # a curve still climbing steeply = that site had more to find
    site_summary <- obs_site |>
      dplyr::filter(!is.na(site)) |>
      dplyr::group_by(site) |>
      dplyr::summarise(n_obs = dplyr::n(),
                       n_taxa = dplyr::n_distinct(taxon_id), .groups = "drop") |>
      dplyr::arrange(dplyr::desc(n_obs))
    readr::write_csv(site_summary, file.path(slides_dir, "site_summary.csv"))
    cat("  Wrote site_summary.csv\n")
  }
}

# ==============================================================================
# CUSTOM CSS FOR PRESENTATION
# ==============================================================================

cat("=== CREATING CUSTOM CSS ===\n")

# Use paste0() instead of glue() to avoid delimiter conflicts
css_content <- paste0('
/* Custom CSS for ', bioblitz_name, ' data dive presentation */
@import url("https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&family=Open+Sans:wght@400;600&display=swap");

/* Fonts harmonised with the image/map slideshow */
.reveal { font-family: "Open Sans", sans-serif; }
.reveal h1, .reveal h2, .reveal h3, .reveal .title-text, .reveal .date-text { font-family: "Montserrat", sans-serif !important; }
.reveal .subtitle, .reveal .slide-subtitle { font-family: "Open Sans", sans-serif !important; }

.reveal .welcome-slide {
  background: linear-gradient(135deg, #040a11 0%, #0b1b2a 100%);
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
  max-width: 1000px !important;
  height: auto !important;
  width: auto !important;
  border-radius: 10px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}

/* Slide title styling - configurable size */
.reveal h2 {
  color: #ffffff !important;
  font-size: ', slide_title_size, 'px !important;
  font-weight: bold !important;
  white-space: nowrap !important;
  text-align: left !important;
  padding-left: 0.6em !important;
  margin-top: 0 !important;
  margin-bottom: 0.1em !important;
  line-height: 1.05 !important;
  text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.5) !important;
}

/* Slide subtitle styling - half size, italics, as block element */
.reveal .subtitle {
  position: absolute !important;
  top: 0.05em !important;
  right: 0.7em !important;
  width: auto !important;
  max-width: 46% !important;
  color: #9FD0B6 !important;
  font-size: ', slide_subtitle_size, 'px !important;
  font-weight: normal !important;
  font-style: italic !important;
  margin: 0 !important;
  padding: 0 !important;
  text-align: right !important;
  line-height: 1.05 !important;
  z-index: 6 !important;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5) !important;
}

.reveal section .slide-subtitle {
  position: static !important;
  display: block !important;
  width: auto !important;
  color: #9FD0B6 !important;
  font-size: ', slide_subtitle_size, 'px !important;
  font-weight: normal !important;
  font-style: italic !important;
  margin: 0 0 0.3em 0 !important;
  padding-right: 0.6em !important;
  text-align: right !important;
  line-height: 1.05 !important;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.5) !important;
}

.reveal section .slide-subtitle, .reveal section .slide-subtitle * {
  color: #9FD0B6 !important;
  font-style: italic !important;
  font-weight: normal !important;
}
.reveal section .slide-subtitle p {
  margin: 0 !important;
  padding: 0 !important;
}

.reveal table {
  margin: 1em auto;
  border-collapse: collapse;
}

.reveal table th {
  background-color: #0b1b2a;
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
  background-color: #0b1b2a;
}

.reveal img {
  max-width: 100%;
  max-height: 90vh;
  height: auto;
  width: auto;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
}

/* Force the main figure on a content slide to fill available height */
.reveal section img {
  height: 84vh;
  width: auto;
  max-width: 100%;
}

.reveal-viewport {
  background: radial-gradient(ellipse at 60% 40%, #0b1b2a 0%, #040a11 60%, #000 100%);
}

.reveal .slides {
  text-align: center;
}

/* --- PDF export (Chrome print view; add ?print-pdf to the URL) ---------------
   FIGURE HEIGHT. On screen the figure uses viewport units (84vh), which measure
   the browser window; reveal then scales the whole 1600x900 slide to fit, so it
   looks right. In print each slide is a fixed 900px page and vh no longer
   tracks it, so the figure must be capped in px AND must leave room for the
   heading (~101px at 88px type) and, where present, the subtitle (~60px at 44px
   type - it is position:static, so it DOES take vertical space).
   If the figure does not fit in what is left, Chrome does NOT clip it: images
   are atomic in paged media, so it moves the WHOLE figure to the next page, and
   reveal hides that (overflow:hidden on .pdf-page). The figure vanishes.
   That is why a 756px cap lost the figure on every subtitled slide
   (101 + 60 + 756 = 917 > 900) while unsubtitled slides survived (101 + 756 =
   857 < 900). 700px leaves ~40px of headroom in the worst case, and height:auto
   lets the figure scale down instead of overflowing.
   BACKGROUNDS are forced here too: the deck stacks a LIGHT theme (simple) under
   night, and the reveal print stylesheet is injected at runtime, so either can
   reassert a pale background on the printed page. */
@media print {
  html, body, .reveal, .reveal-viewport {
    background: #040a11 !important;
  }
  /* Give every printed page its own copy of the radial gradient. On screen you
     see one slide filling the viewport with that gradient, so a per-page copy
     is what matches the HTML; leaving the gradient on .reveal-viewport would
     stretch ONE gradient down the whole stack of pages and give each page a
     thin slice of it. */
  .reveal .slides section {
    background: radial-gradient(ellipse at 60% 40%, #0b1b2a 0%, #040a11 60%, #000 100%) !important;
  }
  .reveal img,
  .reveal section img {
    height: auto !important;
    max-height: 700px !important;
    width: auto !important;
    max-width: 100% !important;
    box-shadow: none !important;
  }
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
# SAMPLING EFFORT & ABUNDANCE (merged; wrapped in local())
# ==============================================================================
local({
# ==============================================================================
# DATA DIVE - SAMPLING EFFORT & ABUNDANCE MODULE  (trimmed)
# ==============================================================================
# Keeps only the two analyses worth showing at this sampling level in low-relief
# country: distance to track (sampling effort) and rank abundance. The water,
# elevation, aspect, terrain, and community-type analyses were removed, along
# with the DEM (elevatr) and waterway fetches. Only the lighter OSM tracks
# layer is still fetched.
#
# Expects obs, out_dir, slides_dir, theme_bioblitz(), chart_fig_width/height,
# force_rebuild, and bbox_expanded to exist.
# ==============================================================================

cat("\n=== SAMPLING EFFORT & ABUNDANCE MODULE ===\n")

stopifnot(exists("obs"), exists("slides_dir"), exists("theme_bioblitz"))
if (!exists("force_rebuild")) force_rebuild <- FALSE
if (!exists("chart_fig_width"))  chart_fig_width  <- 12
if (!exists("chart_fig_height")) chart_fig_height <- 8

ref_line <- "#CBD5E0"

# (OSM highways+water are fetched once earlier; tracks are reused below.)

# --- Local projected CRS (auto UTM-south zone) -------------------------------
ok <- !is.na(obs$longitude) & !is.na(obs$latitude)
utm_zone   <- floor((mean(obs$longitude[ok]) + 180) / 6) + 1
metric_crs <- 32700 + utm_zone
cat("  Using projected CRS EPSG:", metric_crs, "\n")
obs_sf   <- sf::st_as_sf(obs[ok, ], coords = c("longitude", "latitude"), crs = 4326)
obs_proj <- sf::st_transform(obs_sf, metric_crs)

# --- Tracks: reuse the layer split from the early combined highway fetch -----
tracks <- if (exists("tracks_sf")) tracks_sf else NULL

tracks_u <- if (!is.null(tracks) && nrow(tracks) > 0)
              sf::st_union(sf::st_transform(tracks, metric_crs)) else NULL
env <- obs[ok, ] |>
  dplyr::mutate(dist_track = if (!is.null(tracks_u))
                  as.numeric(sf::st_distance(obs_proj, tracks_u)) else NA_real_)

save_env <- function(p, name, w = chart_fig_width, h = chart_fig_height) {
  path <- file.path(slides_dir, name)
  if (force_rebuild || !file.exists(path)) {
    ggplot2::ggsave(path, p, width = w, height = h, dpi = 300, bg = "#040a11")
    cat("  saved", name, "\n")
  }
  invisible(path)
}

env_placeholder <- function(name, msg) {
  p <- ggplot2::ggplot() +
    ggplot2::annotate("text", 0, 0, label = msg, colour = ref_line, size = 6, lineheight = 1.1) +
    ggplot2::theme_void() +
    ggplot2::theme(plot.background  = ggplot2::element_rect(fill = "#040a11", colour = NA),
                   panel.background = ggplot2::element_rect(fill = "#040a11", colour = NA))
  ggplot2::ggsave(file.path(slides_dir, name), p, width = chart_fig_width,
                  height = chart_fig_height, dpi = 150, bg = "#040a11")
  cat("  placeholder for", name, "\n")
}

# ===== Distance to track (sampling effort) ===================================
if (any(!is.na(env$dist_track))) {
  p_track <- ggplot2::ggplot(env, ggplot2::aes(dist_track)) +
    ggplot2::geom_histogram(bins = 40, fill = "#E69F00") +
    ggplot2::geom_vline(xintercept = stats::median(env$dist_track, na.rm = TRUE),
                        colour = ref_line, linewidth = 1) +
    ggplot2::labs(x = "Distance to nearest track (m)", y = "Observations") +
    theme_bioblitz()
  save_env(p_track, "fig_env_distance_track.png")
} else env_placeholder("fig_env_distance_track.png", "Track layer unavailable\nrerun, or supply a trail/GPX layer")

# ===== Rank abundance ========================================================
# Moved to species_showcase.R so the plain and annotated curves share ONE
# species-only table (sp) -> identical data, axis and line profile.

cat("=== SAMPLING EFFORT & ABUNDANCE MODULE COMPLETE ===\n\n")
})

# ==============================================================================
# SPECIES SHOWCASE - common vs rare with event photos (local())
# ==============================================================================
local({
# ==============================================================================
# DATA DIVE - SPECIES SHOWCASE MODULE  (common vs rare, with event photos)
# ==============================================================================
# Builds two layouts so you can compare:
#   A. Abundance tiers  -> fig_species_tiers.png
#   B. Annotated curve  -> fig_species_rank_annotated.png
# Both use your actual event observation photos, fetched from iNaturalist by
# observation id (the same approach as the summary card), centre-cropped square
# and cached in slides_dir/showcase_photos.
#
# Expects: obs (taxon_name, taxon_id, taxon_rank, obs_id, quality_grade),
#          slides_dir, theme_bioblitz(), chart_fig_width/height, force_rebuild,
#          and the inat_get() helper from the main script.
# Packages used: ggplot2, dplyr, ggimage, magick, httr2 (all already loaded).
#
# NOTE: photo placement with ggimage is resolution-sensitive. Render once and
# nudge `thumb_size` (and the curve thumbnail band) to taste, exactly as with
# the treemap. Photos carry mixed iNaturalist licences, so a credit line is
# included; set photo_credit_each <- TRUE to also caption each observer.
# ==============================================================================

cat("\n=== SPECIES SHOWCASE MODULE ===\n")
stopifnot(exists("obs"), exists("slides_dir"), exists("theme_bioblitz"), exists("inat_get"))
if (!exists("force_rebuild")) force_rebuild <- FALSE
if (!exists("chart_fig_width"))  chart_fig_width  <- 13
if (!exists("chart_fig_height")) chart_fig_height <- 7.5

# ---- tunables ---------------------------------------------------------------
n_per_tier   <- 5      # example species shown per abundance tier
tier_breaks  <- c(-Inf, 1, 3, 9, 29, Inf)            # count cut points
tier_levels  <- c("Most recorded", "Frequently seen", "Occasional",
                  "Seldom seen", "Seen just once")    # high -> low
thumb_px     <- 320    # cached thumbnail size (square)
thumb_size   <- 0.085  # ggimage size for the tier grid (fraction of panel)
n_curve_pts  <- 6      # thumbnails along the annotated curve
photo_credit_each <- FALSE

INK <- "#F7FAFC"; MUT <- "#CBD5E0"; GOLD <- "#E69F00"; GREEN <- "#90EE90"

showcase_dir <- file.path(slides_dir, "showcase_photos")
dir.create(showcase_dir, showWarnings = FALSE, recursive = TRUE)

# ---- photo fetch: observation id -> cached square thumbnail -----------------
fetch_obs_thumb <- function(obs_id, key, px = thumb_px) {
  out <- file.path(showcase_dir, paste0(key, ".jpg"))
  if (file.exists(out) && !force_refetch_photos) return(out)
  tryCatch({
    d <- inat_get(paste0("observations/", obs_id))
    if (length(d$results) == 0 || length(d$results[[1]]$photos) == 0) return(NA_character_)
    url <- gsub("/square\\.", "/medium.", d$results[[1]]$photos[[1]]$url)
    raw <- httr2::request(url) |> httr2::req_user_agent("walpole-bioblitz-datadive") |>
      httr2::req_perform()
    tmp <- tempfile(fileext = ".jpg"); writeBin(httr2::resp_body_raw(raw), tmp)
    img  <- magick::image_read(tmp); info <- magick::image_info(img)
    s <- min(info$width, info$height)
    img <- magick::image_crop(img, sprintf("%dx%d+%d+%d", s, s,
                              (info$width - s) %/% 2, (info$height - s) %/% 2)) |>
           magick::image_resize(sprintf("%dx%d", px, px))
    magick::image_write(img, out, format = "jpg")
    Sys.sleep(0.4)
    out
  }, error = function(e) { cat("   photo fail", key, "-", conditionMessage(e), "\n"); NA_character_ })
}

# Up to 4 candidate observations per species (research-grade first); return the
# first that yields a usable photo.
cand <- obs |>
  dplyr::filter(taxon_rank == "species", !is.na(obs_id), !is.na(taxon_name)) |>
  dplyr::mutate(rg = quality_grade == "research") |>
  dplyr::arrange(taxon_name, dplyr::desc(rg)) |>
  dplyr::group_by(taxon_name) |> dplyr::slice_head(n = 4) |>
  dplyr::summarise(ids = list(obs_id), observer = dplyr::first(observer_login), .groups = "drop")

species_thumb <- function(taxon_name, key) {
  i <- match(taxon_name, cand$taxon_name)
  if (is.na(i)) return(NA_character_)
  for (id in cand$ids[[i]]) { p <- fetch_obs_thumb(id, key); if (!is.na(p)) return(p) }
  NA_character_
}

# ---- species abundance table ------------------------------------------------
sp <- obs |>
  dplyr::filter(taxon_rank == "species", !is.na(taxon_name)) |>
  dplyr::count(taxon_name, name = "n") |>
  dplyr::arrange(dplyr::desc(n)) |>
  dplyr::mutate(rank = dplyr::row_number(),
                tier = factor(cut(n, tier_breaks, labels = rev(tier_levels)),
                              levels = tier_levels))
sp_np <- obs |>
  dplyr::filter(taxon_rank == "species", !is.na(taxon_name), iconic_taxon != "Plantae") |>
  dplyr::count(taxon_name, name = "n") |>
  dplyr::arrange(dplyr::desc(n)) |>
  dplyr::mutate(rank = dplyr::row_number())
credit <- "Photos: your event's observations, via iNaturalist (each \u00a9 its observer)"

# ============================================================================
# LAYOUT A. Abundance tiers (photo grid)
# ============================================================================
tiers_path <- file.path(slides_dir, "fig_species_tiers.png")
if (force_rebuild || !file.exists(tiers_path)) {
  set.seed(42)
  grid <- sp |> dplyr::filter(!is.na(tier)) |>
    dplyr::group_by(tier) |>
    dplyr::group_modify(~ dplyr::slice_sample(.x, n = min(n_per_tier, nrow(.x)))) |>
    dplyr::ungroup()
  grid$image <- vapply(seq_len(nrow(grid)),
                       function(i) species_thumb(grid$taxon_name[i], paste0("tier_", i)),
                       character(1))
  grid <- grid |> dplyr::filter(!is.na(image)) |>
    dplyr::group_by(tier) |> dplyr::mutate(col = dplyr::row_number()) |> dplyr::ungroup() |>
    dplyr::mutate(yrow = as.integer(factor(tier, levels = tier_levels)))   # 1 = top

  tier_info <- sp |> dplyr::group_by(tier) |>
    dplyr::summarise(nsp = dplyr::n(), lo = min(n), hi = max(n), .groups = "drop") |>
    dplyr::mutate(yrow = as.integer(factor(tier, levels = tier_levels)),
                  rng = ifelse(lo == hi, paste0(lo, " record", ifelse(lo == 1, "", "s"), " each"),
                               paste0(lo, "\u2013", hi, " records each")))

  ny <- length(tier_levels)
  # --- tunable layout (nudge after first render) ---
  half_x <- 0.48    # image half-width  (x units) - match to rendered photo size
  half_y <- 0.48    # image half-height (y units)
  lab_x   <- -3.7    # left x for the tier labels
  x_right <- 6.6     # rightmost photo column (grid sits in the right ~60%, clear of labels)
  col_gap <- 1.68    # wider column spacing so long species names clear the next photo
  grid$cx <- x_right - (n_per_tier - grid$col) * col_gap
  # subtle lighter-navy bands behind rows 1, 3, 5 (full width, through the photo gaps)
  # so each row's left label reads as belonging to its row of photos
  .band_y   <- (ny - c(1L, 3L, 5L)); .band_y <- .band_y[.band_y >= 0]
  row_bands <- data.frame(ymin = .band_y - 0.5, ymax = .band_y + 0.5)
  p_tiers <- ggplot2::ggplot(grid, ggplot2::aes(cx, ny - yrow)) +
    ggplot2::geom_rect(data = row_bands, inherit.aes = FALSE,
                       ggplot2::aes(xmin = lab_x - 0.2, xmax = x_right + 0.7, ymin = ymin, ymax = ymax),
                       fill = "#122b45", colour = NA) +
    ggimage::geom_image(ggplot2::aes(image = image), size = thumb_size, asp = 2.5) +
    # species name along the BOTTOM of each photo, on a semi-transparent strip
    ggplot2::geom_label(ggplot2::aes(x = cx - half_x, y = (ny - yrow) - half_y, label = taxon_name),
                        hjust = 0, vjust = 0, fontface = "italic", colour = INK, size = 4.2,
                        fill = "#000000B3", label.size = 0,
                        label.padding = ggplot2::unit(0.08, "lines")) +
    # observation count in the TOP-RIGHT corner of each photo
    ggplot2::geom_label(ggplot2::aes(x = cx + half_x, y = (ny - yrow) + half_y, label = n),
                        hjust = 1, vjust = 1, fill = GOLD, colour = "#0b1b2a",
                        label.size = 0, size = 5.6) +
    ggplot2::geom_text(data = tier_info, ggplot2::aes(x = lab_x, y = ny - yrow, label = tier),
                       hjust = 0, vjust = -0.3, fontface = "bold", colour = INK, size = 11) +
    ggplot2::geom_text(data = tier_info,
                       ggplot2::aes(x = lab_x, y = ny - yrow,
                                    label = paste0(nsp, " species \u00b7 ", rng)),
                       hjust = 0, vjust = 1.4, colour = MUT, size = 6) +
    ggplot2::scale_x_continuous(limits = c(lab_x - 0.2, x_right + 0.7)) +
    ggplot2::scale_y_continuous(limits = c(-0.6, ny - 0.4)) +
    ggplot2::labs(caption = sub("your event's observations, ", "", credit, fixed = TRUE),
                  x = NULL, y = NULL) +
    theme_bioblitz() +
    ggplot2::theme(axis.text = ggplot2::element_blank(),
                   panel.grid = ggplot2::element_blank())
  ggplot2::ggsave(tiers_path, p_tiers, width = 16, height = 8,
                  dpi = 300, bg = "#040a11")
  cat("  saved fig_species_tiers.png\n")
}

# ============================================================================
# LAYOUT B. Annotated rank-abundance curve
# ============================================================================
credit_curve <- sub("your event's observations, ", "", credit, fixed = TRUE)
make_rank_curve <- function(sp_tbl, out_path, key) {
  if (!(force_rebuild || !file.exists(out_path))) return(invisible())
  nsp <- nrow(sp_tbl)
  picks <- unique(round(exp(seq(log(1), log(nsp), length.out = n_curve_pts))))
  pick_df <- sp_tbl |> dplyr::filter(rank %in% picks) |> dplyr::arrange(rank)
  pick_df$image <- vapply(seq_len(nrow(pick_df)),
                          function(i) species_thumb(pick_df$taxon_name[i], paste0(key, i)),
                          character(1))
  pick_df <- pick_df |> dplyr::filter(!is.na(image))

  ymax  <- max(sp_tbl$n); band <- ymax * 2.3          # thumbnail row height (log axis)
  pick_df$tx <- seq(nsp * 0.06, nsp * 0.94, length.out = nrow(pick_df))
  pick_df$ty <- ymax * 1.25

  p_curve <- ggplot2::ggplot(sp_tbl, ggplot2::aes(rank, n)) +
    ggplot2::geom_area(fill = "#228B22", alpha = 0.22) +
    ggplot2::geom_line(colour = INK, linewidth = 0.7) +
    ggplot2::geom_segment(data = pick_df,
                          ggplot2::aes(x = rank, y = n, xend = tx, yend = ty),
                          colour = MUT, linewidth = 0.3, alpha = 0.7) +
    ggplot2::geom_point(data = pick_df, ggplot2::aes(rank, n), colour = GOLD, size = 2) +
    ggimage::geom_image(data = pick_df, ggplot2::aes(tx, ty, image = image),
                        size = 0.075, asp = 2.5) +
    ggplot2::geom_text(data = pick_df,
                       ggplot2::aes(tx, band, label = sub(" ", "\n", taxon_name)),
                       fontface = "italic", colour = INK, size = 6.3, vjust = 0, lineheight = 0.9) +
    ggplot2::scale_y_log10(limits = c(0.8, band * 1.65)) +
    ggplot2::labs(caption = credit_curve,
                  x = "Species rank (commonest to rarest)", y = "Observations (log)") +
    theme_bioblitz()
  ggplot2::ggsave(out_path, p_curve, width = 16, height = 8,
                  dpi = 300, bg = "#040a11")
  cat("  saved", basename(out_path), "\n")
}
make_rank_curve(sp, file.path(slides_dir, "fig_species_rank_annotated.png"), "curve_")
make_rank_curve(sp_np, file.path(slides_dir, "fig_species_rank_annotated_no_plants.png"), "curve_np_")

# ---- plain rank-abundance: SAME sp table as the annotated curve above, so the
#      two slides share data, x-axis and line profile (only photos differ) -----
rank_ab_path <- file.path(slides_dir, "fig_env_rank_abundance.png")
if (force_rebuild || !file.exists(rank_ab_path)) {
  singles    <- sum(sp$n == 1)
  pct_single <- 100 * singles / nrow(sp)
  rare_msg   <- if (pct_single >= 40) "most species are rare" else
                if (pct_single >= 20) "many species are rare" else
                "abundance is relatively even"
  rank_lab <- tibble::tibble(x = Inf, y = max(sp$n),
    label = sprintf("%d species<br>%d seen once (%.0f%%)<br><span style='color:#EBCC2A'>**%s**</span>",
                    nrow(sp), singles, pct_single, rare_msg))
  p_plain <- ggplot2::ggplot(sp, ggplot2::aes(rank, n)) +
    ggplot2::geom_area(fill = "#228B22", alpha = 0.22) +
    ggplot2::geom_line(colour = INK, linewidth = 0.7) +
    ggplot2::scale_y_log10() +
    ggtext::geom_richtext(data = rank_lab, ggplot2::aes(x = x, y = y, label = label),
      hjust = 1.05, vjust = 1, fill = "#0b1b2a", label.colour = NA,
      colour = INK, size = 11, inherit.aes = FALSE) +
    ggplot2::labs(x = "Species rank (commonest to rarest)", y = "Observations (log)") +
    theme_bioblitz()
  ggplot2::ggsave(rank_ab_path, p_plain, width = 16, height = 8, dpi = 300, bg = "#040a11")
  cat("  saved fig_env_rank_abundance.png (species-only, matches annotated)\n")
}

# ---- FINAL COLLAGE: every hero chart as a polaroid on a pinboard ------------
chart_collage_specs <- list(
  c("fig_observation_hotspots_jittered.png", "Observation hotspots"),
  c("fig_observations_by_taxon.png",         "Observations by taxon"),
  c("fig_top_observers.png",                 "Top observers"),
  c("fig_observations_by_hour.png",          "Activity by hour"),
  c("fig_richness_interpolated.png",         "Species richness"),
  c("fig_rarefaction_by_group.png",          "Species accumulation"),
  c("fig_species_rank_annotated.png",        "Common to rare"),
  c("fig_species_tiers.png",                 "Most and least recorded")
)

make_chart_collage <- function(specs, out_path, max_w = 1920, max_h = 1080) {
  present <- Filter(function(sp) file.exists(file.path(slides_dir, sp[1])), specs)
  k <- length(present)
  if (k == 0) return(FALSE)
  set.seed(42)

  # dark pinboard, lifted slightly off the slide navy, with soft noise
  canvas <- magick::image_blank(max_w, max_h, color = "#0b1b2a")
  canvas <- magick::image_noise(canvas, "gaussian")
  canvas <- magick::image_modulate(canvas, brightness = 74)

  box_w <- 470; box_h <- 300               # chart area inside each polaroid
  b_lr  <- 8;   b_top <- 8;   b_bot <- 46  # white frame, wider bottom lip
  frame_w <- box_w + b_lr * 2
  frame_h <- box_h + b_top + b_bot

  cols   <- ceiling(sqrt(k * (max_w / max_h)))
  rows   <- ceiling(k / cols)
  cell_w <- floor(max_w / cols)
  cell_h <- floor(max_h / rows)
  jit_x  <- floor(cell_w * 0.10)
  jit_y  <- floor(cell_h * 0.10)

  # pull the two chart rows together so the top and bottom photo bands grow
  row_gap   <- round((cell_h - frame_h) * 0.30)   # ~1/3 of the old inter-row gap
  row_pitch <- frame_h + row_gap
  y0        <- max_h / 2 - (rows - 1) * row_pitch / 2

  # scattered species photos, drawn BEHIND the charts so they peek out around
  # the edges (less prominent). Reuses the cached tier/curve thumbnails.
  photo_files <- if (dir.exists(showcase_dir))
    list.files(showcase_dir, pattern = "\\.jpg$", full.names = TRUE) else character(0)
  if (length(photo_files) > 0) {
    set.seed(7)
    # Fill the EMPTY bands around the chart grid, not the space under the charts.
    # Ranges are photo-CENTRE targets: top strip, the gap between the two chart
    # rows, and the bottom strip (all full width, so the top-right fills too).
    zones <- list(c(110, 1810,   25,  100),     # top band (deeper now)
                  c(110, 1810,  515,  565),     # narrow inter-row gap
                  c(110, 1810,  955, 1050))     # bottom band (deeper now)
    zw  <- c(4, 2, 5)                            # weight the bottom + top heaviest
    sel <- sample(photo_files, 60, replace = TRUE)
    for (f in sel) {
      pim <- try(magick::image_read(f), silent = TRUE)
      if (inherits(pim, "try-error")) next
      side <- sample(150:190, 1)
      pim  <- magick::image_resize(pim, paste0(side, "x", side, "^"))
      pim  <- magick::image_extent(pim, paste0(side, "x", side),
                                   gravity = "center", color = "white")
      pf   <- magick::image_border(pim, "white", "7x7")
      pf   <- magick::image_extent(pf, paste0(side + 14, "x", side + 23),
                                   gravity = "north", color = "white")
      pf   <- magick::image_background(pf, "transparent")
      pf   <- magick::image_rotate(pf, sample(c(seq(-12, -3), seq(3, 12)), 1))
      pinf <- magick::image_info(pf)
      z    <- zones[[sample(seq_along(zones), 1, prob = zw)]]
      cx_p <- sample(z[1]:z[2], 1); cy_p <- sample(z[3]:z[4], 1)
      px   <- min(max(0, cx_p - pinf$width  %/% 2), max_w - pinf$width)
      py   <- min(max(0, cy_p - pinf$height %/% 2), max_h - pinf$height)
      canvas <- magick::image_composite(canvas, pf, offset = sprintf("+%d+%d", px, py))
    }
  }
  set.seed(42)   # restore RNG so the chart-polaroid layout is unchanged

  for (i in seq_len(k)) {
    p   <- file.path(slides_dir, present[[i]][1])
    cap <- present[[i]][2]
    img <- try(magick::image_read(p), silent = TRUE)
    if (inherits(img, "try-error")) next

    # fit chart inside the box (keep aspect), pad with the chart's own navy
    img <- magick::image_resize(img, paste0(box_w, "x", box_h))
    img <- magick::image_extent(img, paste0(box_w, "x", box_h),
                                gravity = "center", color = "#040a11")
    # white polaroid frame with a wider bottom lip for the caption
    framed <- magick::image_border(img, "white", paste0(b_lr, "x", b_top))
    framed <- magick::image_extent(framed, paste0(frame_w, "x", frame_h),
                                   gravity = "north", color = "white")
    # pencilled caption in the bottom lip
    framed <- magick::image_annotate(framed, cap, gravity = "south",
                                     size = 28, weight = 600, font = "sans",
                                     color = "#33404d",
                                     location = paste0("+0+", round(b_bot * 0.30)))
    # rotate with transparent corners so the pinboard shows through
    angle  <- sample(c(seq(-7, -2), seq(2, 7)), 1)
    framed <- magick::image_background(framed, "transparent")
    framed <- magick::image_rotate(framed, angle)

    fi    <- magick::image_info(framed)
    row_i <- (i - 1) %/% cols
    col_i <- (i - 1) %% cols
    cx    <- floor(cell_w * col_i + cell_w / 2)
    cy    <- floor(y0 + row_pitch * row_i)
    x     <- max(0, cx + sample(-jit_x:jit_x, 1) - fi$width  %/% 2)
    y     <- max(0, cy + sample(-jit_y:jit_y, 1) - fi$height %/% 2)
    canvas <- magick::image_composite(canvas, framed, offset = sprintf("+%d+%d", x, y))
  }
  magick::image_write(canvas, out_path, format = "png")
  file.exists(out_path)
}

collage_out <- file.path(slides_dir, "fig_chart_collage.png")
if (force_rebuild || !file.exists(collage_out)) {
  ok <- make_chart_collage(chart_collage_specs, collage_out)
  cat(if (isTRUE(ok)) "  saved fig_chart_collage.png\n" else
        "  chart collage skipped (no figures found)\n")
}

cat("=== SPECIES SHOWCASE MODULE COMPLETE ===\n\n")
})

# ==============================================================================
# GENERATE QUARTO PRESENTATION - WITH SUBTITLES
# ==============================================================================

cat("=== GENERATING QUARTO PRESENTATION ===\n")

# Check if logo exists to determine title slide format
# Site slides are only wired in if the module actually produced its figures
site_slides_md <- ""
if (isTRUE(include_sites)) {
  .sf1 <- file.exists(file.path(slides_dir, "fig_site_composition.png"))
  .sf2 <- file.exists(file.path(slides_dir, "fig_site_pcoa.png"))
  .sf3 <- file.exists(file.path(slides_dir, "fig_site_rarefaction.png"))
  .sf4 <- file.exists(file.path(slides_dir, "fig_site_completeness_scatter.png"))
  .sf5 <- file.exists(file.path(slides_dir, "fig_site_richness_std.png"))
  site_slides_md <- paste0(
    if (.sf1) "## Sites: What Each Group Found\n\n::: {.slide-subtitle}\ntaxon mix at each survey site\n:::\n\n![](fig_site_composition.png)\n\n" else "",
    if (.sf2) "## Sites: How They Differ\n\n::: {.slide-subtitle}\nsites near each other found similar things\n:::\n\n![](fig_site_pcoa.png)\n\n" else "",
    if (.sf3) "## Sites: Was There More to Find?\n\n::: {.slide-subtitle}\ntaxon accumulation per site\n:::\n\n![](fig_site_rarefaction.png)\n\n" else "",
    if (.sf4) "## Sites: Rich, or Well-Searched?\n\n::: {.slide-subtitle}\ntaxa found vs how completely each was sampled\n:::\n\n![](fig_site_completeness_scatter.png)\n\n" else "",
    if (.sf5) "## Sites: Richest at Equal Effort\n\n::: {.slide-subtitle}\ntaxa at a common sampling effort\n:::\n\n![](fig_site_richness_std.png)\n\n")
  cat("Site slides wired in:", sum(.sf1, .sf2, .sf3, .sf4, .sf5), "of 5\n")
}

logo_exists <- file.exists(bioblitz_logo)
cat("Logo file check:", if(logo_exists) "FOUND" else "NOT FOUND", "\n")
cat("  Path checked:", bioblitz_logo, "\n")

# ============================================================================
# CONTRIBUTOR AWARDS (podium slides) - one slide per category, top-3 podium
# ============================================================================
include_awards <- TRUE   # FALSE = skip the awards section entirely
award_min_obs  <- 5      # a person needs at least this many observations to be eligible

award_slides_md <- ""
if (isTRUE(include_awards)) {
  award_dir <- file.path(slides_dir, "award_photos")
  dir.create(award_dir, recursive = TRUE, showWarnings = FALSE)

  .haversine <- function(lon1, lat1, lon2, lat2) {
    r <- 6371; d <- pi/180
    a <- sin((lat2-lat1)*d/2)^2 + cos(lat1*d)*cos(lat2*d)*sin((lon2-lon1)*d/2)^2
    2*r*asin(pmin(1, sqrt(a)))
  }
  award_photo <- function(login, icon_url) {
    if (is.na(login) || is.na(icon_url) || !nzchar(icon_url)) return(NA_character_)
    out  <- file.path(award_dir, paste0("obs_", gsub("[^A-Za-z0-9_-]", "_", login), ".png"))
    fail <- paste0(out, ".fail")
    if (file.exists(out) && !isTRUE(force_refetch_photos)) return(out)
    # a URL that already failed once is remembered, so we do not wait on it every
    # run (delete the .fail marker, or set force_refetch_photos, to retry)
    if (file.exists(fail) && !isTRUE(force_refetch_photos)) return(NA_character_)
    ok <- tryCatch({
      # req_timeout is essential: without it a slow or dead icon URL blocks the
      # whole script indefinitely, which looks like a hang in the awards section
      raw <- httr2::resp_body_raw(httr2::req_perform(
               httr2::req_timeout(httr2::request(icon_url), 15)))
      img <- magick::image_crop(magick::image_scale(magick::image_read(raw), "400x400^"),
                                "400x400+0+0", gravity = "center")
      mask <- magick::image_read_svg('<svg width="400" height="400"><circle cx="200" cy="200" r="198" fill="white"/></svg>', width = 400, height = 400)
      ring <- magick::image_read_svg('<svg width="400" height="400"><circle cx="200" cy="200" r="195" fill="none" stroke="#3498DB" stroke-width="9"/></svg>', width = 400, height = 400)
      img <- magick::image_composite(magick::image_composite(img, mask, operator = "DstIn"), ring)
      img <- magick::image_background(img, "#040a11")   # flatten corners to the (flat) podium background
      magick::image_write(img, out); TRUE
    }, error = function(e) FALSE)
    if (isTRUE(ok)) out else { try(file.create(fail), silent = TRUE); NA_character_ }
  }
  render_podium <- function(win, out_path, suffix = "") {
    win <- win[order(win$rank), , drop = FALSE]
    win$observer_name <- ifelse(is.na(win$observer_name) | win$observer_name == "",
                                win$observer_login, win$observer_name)
    win$x     <- c(`1` = 2, `2` = 1, `3` = 3)[as.character(win$rank)]
    win$py    <- c(`1` = 0.60, `2` = 0.50, `3` = 0.50)[as.character(win$rank)]
    win$medal <- c(`1` = "1st", `2` = "2nd", `3` = "3rd")[as.character(win$rank)]
    win$rcol  <- c(`1` = "#E6B800", `2` = "#C9CDD2", `3` = "#CD7F32")[as.character(win$rank)]
    win$vlab  <- paste0(prettyNum(round(win$value, 1), big.mark = ","), suffix)
    win$podh  <- c(`1` = 0.16, `2` = 0.11, `3` = 0.07)[as.character(win$rank)]
    hp <- !is.na(win$photo)
    g <- ggplot2::ggplot(win, ggplot2::aes(x, py)) +
      ggplot2::geom_rect(ggplot2::aes(xmin = x - 0.36, xmax = x + 0.36, ymin = 0, ymax = podh, fill = rcol), alpha = 0.6, colour = NA) +
      ggplot2::scale_fill_identity() +
      { if (any(win$rank == 1 & hp)) ggimage::geom_image(data = win[win$rank == 1 & hp, ], ggplot2::aes(image = photo), size = 0.34, asp = 1) } +
      { if (any(win$rank != 1 & hp)) ggimage::geom_image(data = win[win$rank != 1 & hp, ], ggplot2::aes(image = photo), size = 0.26, asp = 1) } +
      ggplot2::geom_text(ggplot2::aes(x, py + 0.25, label = medal, colour = rcol), fontface = "bold", size = 13) +
      ggplot2::geom_text(ggplot2::aes(x, py - 0.25, label = observer_name), colour = "#F7FAFC", fontface = "bold", size = 18) +
      ggplot2::geom_text(ggplot2::aes(x, py - 0.36, label = vlab), colour = "#9FD0B6", fontface = "bold", size = 14) +
      ggplot2::scale_colour_identity() +
      ggplot2::scale_x_continuous(limits = c(0.4, 3.6)) +
      ggplot2::scale_y_continuous(limits = c(0, 1.0)) +
      ggplot2::labs(x = NULL, y = NULL) +
      theme_bioblitz() +
      ggplot2::theme(axis.text = ggplot2::element_blank(), axis.title = ggplot2::element_blank(),
                     panel.grid.major = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(),
                     panel.background = ggplot2::element_rect(fill = "#040a11", colour = NA),
                     plot.background  = ggplot2::element_rect(fill = "#040a11", colour = NA))
    ggplot2::ggsave(out_path, g, width = 16, height = 9, dpi = 300, bg = "#040a11")
  }

  .elig_ids <- obs |> dplyr::filter(!is.na(observer_login)) |>
    dplyr::count(observer_login, name = "._n") |>
    dplyr::filter(`._n` >= award_min_obs) |> dplyr::pull(observer_login)
  obs_a <- obs |> dplyr::filter(observer_login %in% .elig_ids)
  .grp <- function(d) dplyr::group_by(d, observer_login, observer_name, observer_icon_url)

  specs <- list()
  add <- function(id, title, subtitle, suffix, fn, dir = "desc")
    specs[[length(specs) + 1]] <<- list(id = id, title = title, subtitle = subtitle,
                                        suffix = suffix, fn = fn, dir = dir)

  add("most_obs", "Most Observations", "the biggest contributors overall", " obs",
      function(d) dplyr::summarise(.grp(d), value = dplyr::n(), .groups = "drop"))
  add("most_species", "Most Diverse", "the most different species recorded", " species",
      function(d) dplyr::summarise(.grp(dplyr::filter(d, taxon_rank == "species")), value = dplyr::n_distinct(taxon_name), .groups = "drop"))
  add("well_rounded", "Jack of All Trades", "recorded across the most groups of life", " groups",
      function(d) dplyr::summarise(.grp(d), value = dplyr::n_distinct(iconic_taxon), .groups = "drop"))
  add("specialised", "The Specialist", "the highest share of records in one group", "%",
      function(d) dplyr::summarise(.grp(d), value = round(100 * max(table(iconic_taxon)) / dplyr::n()), .groups = "drop"))
  add("completist", "The Completist", "the most records of a single species", " obs",
      function(d) dplyr::summarise(.grp(dplyr::count(dplyr::filter(d, taxon_rank == "species"), observer_login, observer_name, observer_icon_url, taxon_name)), value = max(n), .groups = "drop"))
  add("explorer", "The Explorer", "the observation furthest from HQ", " km",
      function(d) dplyr::summarise(.grp(dplyr::mutate(dplyr::filter(d, !is.na(longitude), !is.na(latitude)), dkm = .haversine(longitude, latitude, hq_lon, hq_lat))), value = round(max(dkm), 1), .groups = "drop"))
  add("ground_covered", "Ground Covered", "the widest spread of observations", " km",
      function(d) dplyr::summarise(.grp(dplyr::filter(d, !is.na(longitude), !is.na(latitude))), value = round(.haversine(min(longitude), min(latitude), max(longitude), max(latitude)), 1), .groups = "drop"))
  add("night_owl", "Night Owl", "the most observations after dark", " obs",
      function(d) dplyr::summarise(.grp(dplyr::filter(dplyr::mutate(dplyr::filter(d, !is.na(time_observed_at)), .h = lubridate::hour(lubridate::with_tz(lubridate::as_datetime(time_observed_at), "Australia/Perth"))), .h >= 20 | .h < 5)), value = dplyr::n(), .groups = "drop"))
  add("early_bird", "Early Bird", "the most observations around dawn", " obs",
      function(d) dplyr::summarise(.grp(dplyr::filter(dplyr::mutate(dplyr::filter(d, !is.na(time_observed_at)), .h = lubridate::hour(lubridate::with_tz(lubridate::as_datetime(time_observed_at), "Australia/Perth"))), .h >= 4 & .h < 8)), value = dplyr::n(), .groups = "drop"))
  add("power_hour", "Power Hour", "the most observations in one half-hour", " obs",
      function(d) dplyr::summarise(.grp(dplyr::count(dplyr::mutate(dplyr::filter(d, !is.na(time_observed_at)), .b = floor(as.numeric(lubridate::as_datetime(time_observed_at)) / 1800)), observer_login, observer_name, observer_icon_url, .b)), value = max(n), .groups = "drop"))
  add("rarest_find", "Rarest Finds", "the most conservation-listed species", " listed",
      function(d) dplyr::summarise(.grp(dplyr::filter(d, !is.na(conservation_status), conservation_status != "")), value = dplyr::n_distinct(taxon_name), .groups = "drop"))
  add("marathon", "The Marathon", "the most observations in a single day", " obs",
      function(d) dplyr::summarise(.grp(dplyr::count(dplyr::filter(d, !is.na(observed_on)), observer_login, observer_name, observer_icon_url, observed_on)), value = max(n), .groups = "drop"))
  add("gold_standard", "Gold Standard", "the most research-grade observations", " obs",
      function(d) dplyr::summarise(.grp(dplyr::filter(d, quality_grade == "research")), value = dplyr::n(), .groups = "drop"))

  .champ <- c(Plantae = "Most Plants", Fungi = "Most Fungi", Insecta = "Most Insects",
              Arachnida = "Most Spiders", Aves = "Most Birds", Mollusca = "Most Molluscs",
              Reptilia = "Most Reptiles", Amphibia = "Most Amphibians",
              Mammalia = "Most Mammals", Actinopterygii = "Most Fish")
  for (grp in intersect(names(.champ), unique(obs_a$iconic_taxon))) local({
    g0 <- grp
    add(paste0("most_", tolower(g0)), .champ[[g0]], paste0("who recorded the most ", tolower(g0)), " obs",
        function(d) dplyr::summarise(.grp(dplyr::filter(d, iconic_taxon == g0)), value = dplyr::n(), .groups = "drop"))
  })

  # Which awards to include (edit to a subset once you have picked favourites):
  award_ids <- vapply(specs, function(s) s$id, character(1))   # default = all defined

  # Fallback avatars for winners with no profile photo. Built ONCE here, not per
  # award: names with no PhyloPic silhouette (Unknown etc.) fail, a failed fetch
  # is never cached, so re-sweeping per award re-hit the network every time.
  .avatar_pool  <- setdiff(names(iconic_cols), c("Unknown", "Chromista", "Protozoa"))
  .avatar_icons <- unlist(lapply(.avatar_pool,
                     function(t) tryCatch(ensure_taxon_icon(t), error = function(e) NA_character_)))
  .avatar_icons <- .avatar_icons[!is.na(.avatar_icons) & nzchar(.avatar_icons)]

  n_awards <- 0
  for (sp in specs) {
    if (!(sp$id %in% award_ids)) next
    res <- tryCatch(sp$fn(obs_a), error = function(e) NULL)
    if (is.null(res) || nrow(res) == 0) next
    res <- res[is.finite(res$value) & res$value > 0, , drop = FALSE]
    if (nrow(res) == 0) next
    res <- res[order(if (sp$dir == "asc") res$value else -res$value), , drop = FALSE]
    res <- utils::head(res, 3); res$rank <- seq_len(nrow(res))
    res$photo <- vapply(seq_len(nrow(res)),
                        function(i) award_photo(res$observer_login[i], res$observer_icon_url[i]), character(1))
    noph <- is.na(res$photo)
    if (any(noph) && length(.avatar_icons))   # no profile pic -> random taxon silhouette
      res$photo[noph] <- sample(.avatar_icons, sum(noph), replace = TRUE)
    png <- file.path(slides_dir, paste0("award_", sp$id, ".png"))
    if (force_rebuild || !file.exists(png))
      tryCatch(render_podium(res, png, sp$suffix),
               error = function(e) cat("  award render failed:", sp$id, conditionMessage(e), "\n"))
    if (file.exists(png)) {
      award_slides_md <- paste0(award_slides_md,
        sprintf("## %s\n\n::: {.slide-subtitle}\n%s\n:::\n\n![](%s)\n\n", sp$title, sp$subtitle, basename(png)))
      n_awards <- n_awards + 1
    }
  }
  cat(sprintf("Contributor awards: %d slide(s)\n", n_awards))
}


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
    width: 1600
    height: 900
    margin: 0.02
    auto-stretch: true
    slide-number: true
    transition: slide
    controls: true
    auto-slide: ', auto_advance_ms, '
    auto-slide-stoppable: ', tolower(auto_slide_stoppable), '
    loop: ', tolower(slideshow_loop), '
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

::: {.slide-subtitle}
excluding plants
:::

![](fig_observation_hotspots_no_plants.png)

', zoom_slides_md, '## Observations by Taxon

![](fig_observations_by_taxon.png)

', animalia_slide_md, '## Top Observers

![](fig_top_observers.png)

## Observations per Half Hour

![](fig_observations_by_hour.png)

## Observations per Half Hour

::: {.slide-subtitle}
by taxon group
:::

![](fig_observations_by_hour_stacked.png)

## Species Accumulation Curve

::: {.slide-subtitle}
all taxa combined
:::

![](fig_rarefaction_all_taxa.png)

## Species Accumulation by Group

::: {.slide-subtitle}
plants, fungi, and animals
:::

![](fig_rarefaction_by_group.png)

## Species Richness

::: {.slide-subtitle}
grid-based analysis
:::

![](fig_richness_raw.png)

## Species Richness

::: {.slide-subtitle}
probability of a new species per observation
:::

![](fig_richness_effort_corrected.png)

## Species Richness

::: {.slide-subtitle}
probability of a new species per observation (interpolated)
:::

![](fig_richness_interpolated.png)

## Sampling Effort

::: {.slide-subtitle}
distance from tracks
:::

![](fig_env_distance_track.png)

## How Much Did We Find?

::: {.slide-subtitle}
rank abundance and rare species
:::

![](fig_env_rank_abundance.png)

## From Common to Rare

::: {.slide-subtitle}
the abundance curve, with examples
:::

![](fig_species_rank_annotated.png)

## From Common to Rare

::: {.slide-subtitle}
excluding plants
:::

![](fig_species_rank_annotated_no_plants.png)

## What Did We Find Most?

::: {.slide-subtitle}
example species, common to rare
:::

![](fig_species_tiers.png)

', site_slides_md, '', award_slides_md, '## The Big Picture

![](fig_chart_collage.png)

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
    width: 1600
    height: 900
    margin: 0.02
    auto-stretch: true
    slide-number: true
    transition: slide
    controls: true
    auto-slide: ', auto_advance_ms, '
    auto-slide-stoppable: ', tolower(auto_slide_stoppable), '
    loop: ', tolower(slideshow_loop), '
css:
  - styles/custom.css
execute:
  echo: false
  warning: false
  message: false
---

## ', bioblitz_name, ' ', bioblitz_year, '

<span class="small">Data Dive: ', summary_stats$date_range, '</span>

## Summary

![](fig_summary_with_photos.png)

## Observation Hotspots

![](fig_observation_hotspots_jittered.png)

## Observation Hotspots

::: {.slide-subtitle}
excluding plants
:::

![](fig_observation_hotspots_no_plants.png)

', zoom_slides_md, '## Observations by Taxon

![](fig_observations_by_taxon.png)

', animalia_slide_md, '## Top Observers

![](fig_top_observers.png)

## Observations per Half Hour

![](fig_observations_by_hour.png)

## Observations per Half Hour

::: {.slide-subtitle}
by taxon group
:::

![](fig_observations_by_hour_stacked.png)

## Species Accumulation Curve

::: {.slide-subtitle}
all taxa combined
:::

![](fig_rarefaction_all_taxa.png)

## Species Accumulation by Group

::: {.slide-subtitle}
plants, fungi, and animals
:::

![](fig_rarefaction_by_group.png)

## Species Richness

::: {.slide-subtitle}
grid-based analysis
:::

![](fig_richness_raw.png)

## Species Richness

::: {.slide-subtitle}
species per observation
:::

![](fig_richness_effort_corrected.png)

## Species Richness

::: {.slide-subtitle}
smooth continuous surface
:::

![](fig_richness_interpolated.png)

## Sampling Effort

::: {.slide-subtitle}
distance from tracks
:::

![](fig_env_distance_track.png)

## How Much Did We Find?

::: {.slide-subtitle}
rank abundance and rare species
:::

![](fig_env_rank_abundance.png)

## From Common to Rare

::: {.slide-subtitle}
the abundance curve, with examples
:::

![](fig_species_rank_annotated.png)

## From Common to Rare

::: {.slide-subtitle}
excluding plants
:::

![](fig_species_rank_annotated_no_plants.png)

## What Did We Find Most?

::: {.slide-subtitle}
example species, common to rare
:::

![](fig_species_tiers.png)

', site_slides_md, '', award_slides_md, '## The Big Picture

![](fig_chart_collage.png)
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

# Embedded post-processor: makes the .pptx look like the HTML (navy full-bleed).
# Needs python3 + python-pptx (pip install python-pptx); skipped gracefully if absent.
pptx_fullbleed_py <- r"---(import sys
try:
    from pptx import Presentation
    from pptx.util import Emu
    from pptx.dml.color import RGBColor
    from pptx.enum.shapes import MSO_SHAPE_TYPE
except Exception as e:
    sys.stderr.write("python-pptx not available: %s\n" % e); sys.exit(2)

NAVY = RGBColor(0x04, 0x0a, 0x11)
INK  = RGBColor(0xF7, 0xFA, 0xFC)

def main(path):
    prs = Presentation(path)
    SW, SH = prs.slide_width, prs.slide_height
    top_m = int(SH * 0.145)
    a_top, a_h = top_m, SH - top_m - int(SH * 0.02)
    a_left, a_w = int(SW * 0.02), int(SW * 0.96)
    for slide in prs.slides:
        try:
            fill = slide.background.fill; fill.solid(); fill.fore_color.rgb = NAVY
            for shape in list(slide.shapes):
                if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
                    iw, ih = shape.image.size
                    asp = iw / ih if ih else 1.0
                    w = a_w; h = int(w / asp)
                    if h > a_h:
                        h = a_h; w = int(h * asp)
                    shape.width, shape.height = Emu(w), Emu(h)
                    shape.left = Emu(a_left + (a_w - w) // 2)
                    shape.top  = Emu(a_top  + (a_h - h) // 2)
                if shape.has_text_frame:
                    for para in shape.text_frame.paragraphs:
                        para.font.color.rgb = INK
                        for run in para.runs:
                            run.font.color.rgb = INK
        except Exception as e:
            sys.stderr.write("slide skipped: %s\n" % e)
    prs.save(path)
    print("restyled %d slides" % len(prs.slides._sldIdLst))

if __name__ == "__main__":
    main(sys.argv[1])
)---"

# ==============================================================================
# PDF EXPORT HELPER
# ==============================================================================
# reveal.js only lays every slide out as its own page when it is in PRINT VIEW,
# and print view is triggered by the ?print-pdf query string on the URL. Note
# pagedown::chrome_print() cannot pass one: it treats anything that is not
# ^https?:// as a file path and runs it through normalizePath(), so the query
# string is lost and Chrome prints only the current slide. We therefore drive
# headless Chrome through chromote and navigate to the query URL ourselves.
#   printBackground   = keeps the navy background (the Background graphics box)
#   preferCSSPageSize = lets reveal's own @page rule set the 16:9 page size
# Build a throwaway copy of the deck with downsampled figures, and return the path to
# its HTML. Only what the deck actually loads is copied (the html, the Quarto libs, the
# css and the logo), so the photo caches are skipped. The figures are shrunk to fit
# max_px on the longest edge; the ">" geometry flag means never enlarge a small figure.
build_pdf_copy <- function(slides_dir, html_file, max_px) {
  bd <- file.path(slides_dir, "_pdf_build")
  unlink(bd, recursive = TRUE)
  dir.create(bd, recursive = TRUE, showWarnings = FALSE)
  file.copy(html_file, bd, overwrite = TRUE)
  for (d in list.files(slides_dir, pattern = "_files$", full.names = TRUE))
    file.copy(d, bd, recursive = TRUE, overwrite = TRUE)
  if (dir.exists(file.path(slides_dir, "styles")))
    file.copy(file.path(slides_dir, "styles"), bd, recursive = TRUE, overwrite = TRUE)
  for (f in list.files(slides_dir, pattern = "\\.(jpg|jpeg)$", ignore.case = TRUE,
                       full.names = TRUE))
    file.copy(f, bd, overwrite = TRUE)

  pngs <- list.files(slides_dir, pattern = "\\.png$", ignore.case = TRUE, full.names = TRUE)
  n <- 0
  for (p in pngs) {
    done <- tryCatch({
      magick::image_write(
        magick::image_resize(magick::image_read(p), paste0(max_px, "x", max_px, ">")),
        file.path(bd, basename(p)))
      TRUE
    }, error = function(e) FALSE)
    if (isTRUE(done)) n <- n + 1 else file.copy(p, bd, overwrite = TRUE)   # fall back to full size
  }
  cat("    downsampled", n, "of", length(pngs), "figures to", max_px, "px\n")
  file.path(bd, basename(html_file))
}

export_deck_pdf <- function(html_file, pdf_file, wait = 6, timeout_s = 300) {
  if (!requireNamespace("chromote", quietly = TRUE)) {
    cat("  chromote not installed - skipping PDF. install.packages('chromote')\n")
    return(FALSE)
  }
  if (file.exists(pdf_file)) {
    can_write <- tryCatch({ con <- file(pdf_file, "w"); close(con); TRUE },
                          error = function(e) FALSE)
    if (!can_write) {
      cat("  WARNING: the existing PDF looks open in another program - close it and re-run.\n")
      return(FALSE)
    }
  }
  ok <- tryCatch({
    fp <- normalizePath(html_file, winslash = "/", mustWork = TRUE)
    if (substr(fp, 1, 1) != "/") fp <- paste0("/", fp)   # Windows: file:///C:/...
    url <- paste0("file://", utils::URLencode(fp), "?print-pdf")
    cat("  Printing", basename(html_file), "in reveal.js print view...\n")
    # chromote applies getOption("chromote.timeout", 10) to EVERY command, including
    # Page.printToPDF. Rasterising ~45 full-page figures takes far longer than 10s, so
    # raise it BEFORE the session is created (the option is read when the connection
    # opens). Restored on exit so we do not leak the setting into the rest of the run.
    old_to <- getOption("chromote.timeout", 10)
    options(chromote.timeout = timeout_s)
    on.exit(options(chromote.timeout = old_to), add = TRUE)
    b <- chromote::ChromoteSession$new()
    on.exit(try(b$close(), silent = TRUE), add = TRUE)
    b$Page$navigate(url)
    try(b$Page$loadEventFired(), silent = TRUE)
    Sys.sleep(wait)   # let the figures, fonts and reveal's print layout settle
    # transferMode = "ReturnAsStream" is essential. The default returns the WHOLE
    # PDF as base64 inside a single WebSocket message, and a figure-heavy deck
    # blows the websocketpp message-size limit: the socket dies with
    # "consume error: websocketpp.processor:4 (A message was too large)", the
    # reply never arrives, and chromote then reports a misleading printToPDF
    # timeout. Streaming hands back a handle instead, which we drain in chunks,
    # so deck size stops mattering.
    res <- b$Page$printToPDF(printBackground = TRUE, preferCSSPageSize = TRUE,
                             marginTop = 0, marginBottom = 0,
                             marginLeft = 0, marginRight = 0,
                             transferMode = "ReturnAsStream")
    con <- file(pdf_file, "wb")
    on.exit(try(close(con), silent = TRUE), add = TRUE)
    repeat {
      chunk <- b$IO$read(handle = res$stream, size = 524288)   # 512 KB at a time
      if (!is.null(chunk$data) && nzchar(chunk$data)) {
        writeBin(if (isTRUE(chunk$base64Encoded)) jsonlite::base64_dec(chunk$data)
                 else charToRaw(chunk$data), con)
      }
      if (isTRUE(chunk$eof)) break
    }
    close(con)
    try(b$IO$close(handle = res$stream), silent = TRUE)
    file.exists(pdf_file) && file.size(pdf_file) > 0
  }, error = function(e) {
    cat("  PDF export failed:", conditionMessage(e), "\n")
    cat("  Chrome not installed, PDF open in another app, or a slow render - raise\n")
    cat("  pdf_timeout_s, currently", timeout_s, "seconds.\n")
    FALSE
  })
  isTRUE(ok)
}

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

        # Restyle to full-bleed navy so the pptx matches the HTML
        py_path <- file.path(slides_dir, "_pptx_fullbleed.py")
        writeLines(pptx_fullbleed_py, py_path)
        pp <- suppressWarnings(try(system2("python3", c(shQuote(py_path), shQuote(pptx_file)),
                                           stdout = TRUE, stderr = TRUE), silent = TRUE))
        if (!inherits(pp, "try-error") && is.null(attr(pp, "status"))) {
          cat("PowerPoint restyled to full-bleed navy (matches the HTML).\n\n")
        } else {
          cat("Full-bleed restyle skipped - install it with: pip install python-pptx\n\n")
        }
      }
    }, error = function(e) {
      cat("\nPowerPoint render failed:", conditionMessage(e), "\n")
      cat("Render manually with: quarto render", qmd_path, "--to pptx\n\n")
    })
  }
  
  # Export a PDF copy of the HTML deck
  if (render_pdf) {
    cat("\n=== EXPORTING PDF ===\n")
    html_out <- sub("\\.qmd$", ".html", qmd_path)
    pdf_out  <- sub("\\.qmd$", ".pdf",  qmd_path)
    if (!file.exists(html_out)) {
      cat("  No HTML deck found - set render_html <- TRUE and re-run.\n\n")
    } else {
      # Print from a downsampled copy so the PDF is not 10x bigger than it needs to be
      src_html  <- html_out
      build_dir <- NULL
      if (is.numeric(pdf_max_px) && pdf_max_px > 0) {
        cat("  Preparing a downsampled copy of the deck...\n")
        src_html <- tryCatch(build_pdf_copy(slides_dir, html_out, pdf_max_px),
                             error = function(e) {
                               cat("    downsample failed:", conditionMessage(e),
                                   "- printing at full size\n")
                               html_out
                             })
        if (!identical(src_html, html_out)) build_dir <- dirname(src_html)
      }
      pdf_ok <- export_deck_pdf(src_html, pdf_out, wait = pdf_wait_s,
                                timeout_s = pdf_timeout_s)
      if (!is.null(build_dir)) unlink(build_dir, recursive = TRUE)
      if (pdf_ok) {
        cat("\n*** PDF SUCCESS ***\n")
        cat("PDF created:", pdf_out, "\n")
        cat("  File size:", round(file.size(pdf_out)/1024/1024, 1), "MB")
        if (!is.null(build_dir)) cat("  (figures capped at ", pdf_max_px, "px)", sep = "")
        cat("\n  Too big? Lower pdf_max_px. Too soft? Raise it, or set 0 for full size.\n\n")
      } else {
        cat("\n  PDF not created. To export it by hand:\n")
        cat("    1. Open", basename(html_out), "in Chrome from inside the slides folder\n")
        cat("    2. Add ?print-pdf to the end of the address and reload\n")
        cat("    3. Ctrl+P > Save as PDF; Margins: None; Background graphics: ON\n\n")
      }
    }
  }

  if (!render_html && !render_powerpoint && !render_pdf) {
    cat("\nNo output formats selected. Set render_html, render_powerpoint or render_pdf to TRUE.\n\n")
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
