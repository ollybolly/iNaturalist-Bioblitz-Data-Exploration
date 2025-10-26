# Data Dive Script - Generalization Guide

## Overview

The Data Dive script has been generalized to work with any iNaturalist bioblitz project. This guide explains what changed and how to adapt it for your bioblitz.

---

## What This Script Does

The Data Dive script creates a comprehensive analytical presentation from your iNaturalist bioblitz data, including:

1. **Summary Statistics** - Total observations, species, observers, quality grades
2. **Observation Hotspots** - Spatial maps showing where observations occurred
3. **Taxonomic Breakdown** - Distribution across taxon groups (plants, insects, birds, etc.)
4. **Top Observers** - Who contributed the most observations
5. **Temporal Patterns** - Observations by time of day (day vs. night activity)
6. **Species Richness Heatmaps** - Where the most species were found
7. **Rarefaction Curves** - Species accumulation patterns showing sampling completeness
8. **Multiple Output Formats** - HTML slideshow (Reveal.js) and PowerPoint (.pptx)

---

## Key Changes from Original Version

### 1. **New Configuration Variables**

Added two new variables to customize the presentation:

```r
bioblitz_name <- "Walpole Wilderness"   # Your bioblitz location name
bioblitz_year <- 2025                   # Year of your bioblitz
```

These automatically update:
- Title slide: "{bioblitz_name} Bioblitz {bioblitz_year}"
- All slide headers and labels

### 2. **Simplified Output Directory**

Changed from:
```r
out_dir <- "outputs/walpole_wilderness_bioblitz_2025_data_dive"
```

To:
```r
out_dir <- "outputs/data_dive"  # Created automatically
```

All output files go into `outputs/data_dive/` with subdirectories for slides and styles.

### 3. **Generic Script Header**

Changed from "Walpole Wilderness Bioblitz 2025 - Data Dive Analysis" to:
```r
# iNaturalist Bioblitz Data Dive Analysis
```

### 4. **Usage Instructions Added**

Added clear comments at the top of the configuration section listing what needs to be changed:
1. project_slug
2. bioblitz_name
3. bioblitz_year
4. date_min and date_max
5. hq_lon and hq_lat
6. bioblitz_logo (optional)

---

## How to Use This Script for Your Bioblitz

### Required Changes (Minimum Configuration)

At the top of the script, update these settings:

```r
# --- Project Settings ---
project_slug <- "your-project-slug-2024"           # Your iNaturalist project
bioblitz_name <- "Your Bioblitz Location"          # Appears on slides
bioblitz_year <- 2024                              # Year

# --- HQ Location ---
hq_lon <- 123.456789    # Your HQ longitude
hq_lat <- -12.345678    # Your HQ latitude

# --- Event Window ---
date_min <- as.Date("2024-10-15")
date_max <- as.Date("2024-10-16")

# --- Logo (optional) ---
bioblitz_logo <- "your-logo.jpg"  # Or "" if no logo
```

### How to Find Your Values

**project_slug:**
- Go to your iNaturalist project page
- URL format: `https://www.inaturalist.org/projects/YOUR-PROJECT-SLUG`
- Copy everything after `/projects/`

**HQ Coordinates:**
- Go to Google Maps
- Right-click on your meeting/HQ location
- Click the coordinates to copy
- Format: longitude first, then latitude

**Event Dates:**
- Use the format: `as.Date("YYYY-MM-DD")`
- For multi-day events, set date_min to first day, date_max to last day

---

## Output Files

After running successfully, check `outputs/data_dive/`:

### Main Files:
- **datadive.html** - Interactive HTML slideshow (Reveal.js)
  - Press 'F' for fullscreen
  - Arrow keys to navigate
  - Press 'S' for speaker view
  
- **datadive.pptx** - PowerPoint presentation
  - Editable in PowerPoint/Google Slides
  - All figures included as images

### Supporting Files:
- **slides/** - Individual figure PNG files
  - `fig_summary_with_photos.png`
  - `fig_observation_hotspots_jittered.png`
  - `fig_observations_by_taxon.png`
  - `fig_top_observers.png`
  - `fig_observations_by_hour.png`
  - `fig_richness_raw.png`
  - `fig_rarefaction_all.png`
  - And more...

- **styles/** - CSS styling files
  - `custom.css` - Presentation styling

### Cache Files:
- **obs_cache.rds** - Cached observation data
- **photo_cache/** - Downloaded photos for summary slide

**Don't delete cache files!** They make subsequent runs much faster.

---

## Advanced Configuration

### Map Settings

Control map appearance and coverage:

```r
map_provider <- "Esri.WorldImagery"  # Type of map
base_map_zoom <- 14                  # Zoom level (13-15 recommended)
buffer_km <- 2.5                     # Buffer around observations (km)
```

**Map Provider Options (affects download speed!):**
- `"Esri.WorldImagery"` - Beautiful satellite imagery (SLOW for large areas)
- `"OpenStreetMap"` - Fast street map (10-20x faster)
- `"CartoDB.Positron"` - Minimal clean map (FASTEST)
- `"CartoDB.Voyager"` - Balanced map (FAST, good looking)
- `"Esri.WorldTopoMap"` - Topographic map (MEDIUM speed)

**Performance Optimization for Large Areas:**

If your bioblitz covers >50km², map downloads can be very slow with satellite imagery. Use these settings for 10-20x faster generation:

```r
map_provider <- "OpenStreetMap"  # or "CartoDB.Positron"
base_map_zoom <- 12              # Reduce detail
buffer_km <- 1.5                 # Smaller area
```

**Example:** A 100km² bioblitz:
- With satellite: 20-30 minutes map download
- With OpenStreetMap: 2-3 minutes map download

### Figure Display Options

```r
fig2_use_treemap <- TRUE       # TRUE = treemap, FALSE = bar chart
n_top_observers <- 15          # Number of observers to show
```

### Output Format Options

```r
render_html <- TRUE            # Generate HTML slideshow
render_powerpoint <- TRUE      # Generate PowerPoint
```

### Heatmap Analysis

Fine-tune spatial richness analysis:

```r
grid_cell_size_m <- 500        # Grid resolution (250-1000m)
min_obs_per_cell <- 3          # Minimum observations per cell
use_interpolation <- TRUE      # Smooth interpolated surface
```

### Rarefaction Analysis

Control species accumulation curves:

```r
n_permutations <- 100          # More = smoother curves (50-500)
step_size <- 10                # Sample frequency (5-20)
```

---

## Example Configurations

### Small Urban Bioblitz
```r
project_slug <- "city-park-bioblitz-2024"
bioblitz_name <- "City Park"
bioblitz_year <- 2024
date_min <- as.Date("2024-06-15")
date_max <- as.Date("2024-06-15")
base_map_zoom <- 15
buffer_km <- 1.5
grid_cell_size_m <- 250
```

### Large Regional Bioblitz
```r
project_slug <- "regional-biodiversity-survey-2024"
bioblitz_name <- "Regional Nature Reserve"
bioblitz_year <- 2024
date_min <- as.Date("2024-09-20")
date_max <- as.Date("2024-09-22")
base_map_zoom <- 13
buffer_km <- 5
grid_cell_size_m <- 1000
```

### Weekend Nature Challenge
```r
project_slug <- "weekend-nature-challenge-fall-2024"
bioblitz_name <- "Fall Nature Challenge"
bioblitz_year <- 2024
date_min <- as.Date("2024-10-12")
date_max <- as.Date("2024-10-13")
```

---

## Tips and Best Practices

### First Run
1. **Be patient!** First run takes 15-30 minutes:
   - Package installation (if needed)
   - Data download from iNaturalist
   - Figure generation (10+ complex figures)
   - Map tile downloads

2. **Use caching:**
   ```r
   use_cached_data <- TRUE
   force_rebuild <- FALSE
   ```

### Subsequent Runs
- Set `use_cached_data <- TRUE` (reuse downloaded data)
- Set `force_rebuild <- FALSE` (reuse generated figures)
- Only regenerate specific figures by deleting their PNG files

### Testing
- Start with a small project to test your configuration
- Check that coordinates are correct (HQ marker should appear in right place)
- Verify date range captures your event

### Presentation
- HTML version is best for interactive viewing
- PowerPoint version allows manual editing and customization
- Can add extra slides, annotations, or custom branding

---

## Troubleshooting

### "No observations found"
- Check `project_slug` is correct
- Verify `date_min` and `date_max` include your event
- Ensure project has observations with photos

### "Map shows wrong area"
- Verify `hq_lon` and `hq_lat` coordinates
- Remember: longitude first, latitude second
- Check if you accidentally swapped them

### "Script is slow"
- First run always takes longer (15-30 minutes normal)
- Increase `grid_cell_size_m` for faster heatmap generation
- Set `use_interpolation <- FALSE` to skip interpolation
- Reduce `n_permutations` for faster rarefaction (try 50)

### "Figures look wrong"
- Delete specific figure PNG files to regenerate them
- Set `force_rebuild <- TRUE` to regenerate everything
- Check figure dimensions if text is cut off

### "Not enough data for heatmaps"
- Reduce `min_obs_per_cell` to lower threshold
- Increase `grid_cell_size_m` to larger cells
- Some analyses require minimum observation density

---

## What Makes This Script Special

### Comprehensive Analysis
- Covers spatial, temporal, taxonomic, and effort dimensions
- Publication-quality figures with proper legends and scales
- Automated quality checks and data validation

### Smart Caching
- Remembers downloaded data between runs
- Only regenerates figures when needed
- Dramatically faster subsequent runs (2-5 minutes)

### Professional Output
- Multiple output formats for different uses
- Consistent styling and branding
- Ready for immediate presentation

### Effort-Corrected Metrics
- Accounts for uneven sampling effort
- Shows species richness per observation
- More accurate than raw species counts

### Statistical Rigor
- Rarefaction analysis with confidence intervals
- Data quality thresholds
- Clear visualization of uncertainty

---

## Technical Requirements

### Required R Packages (installed automatically):
- httr2, jsonlite - iNaturalist API
- dplyr, tidyr, purrr - Data manipulation
- ggplot2, sf - Visualization and mapping
- maptiles, terra, osmdata - Map tiles and geographic data
- quarto - Slideshow generation
- officer - PowerPoint generation

### System Requirements:
- R version 4.0 or higher
- RStudio (recommended)
- ~500 MB free disk space per project
- Internet connection for initial data download

---

## Comparison with Slideshow Script

The Data Dive script is complementary to the Slideshow Generator:

**Slideshow Generator:**
- Beautiful photo presentation
- Random selection for variety
- Event display and outreach
- Auto-advancing slides

**Data Dive Script:**
- Comprehensive analysis
- Statistical summaries
- Scientific visualizations
- Research and reporting

**Use both!** The slideshow for public display, the data dive for analysis and reporting.

---

## Credits

This script was originally developed for the Walpole Wilderness Bioblitz 2025 and has been generalized to work with any iNaturalist bioblitz project worldwide.

**Technologies used:**
- R and RStudio
- Quarto for slideshow generation
- Reveal.js for HTML presentations
- officer package for PowerPoint generation
- iNaturalist API
- OpenStreetMap and Esri map tiles

---

**Happy Analyzing! 📊🔬🌿**

If you create cool analyses with this script, consider sharing them back with the iNaturalist community!
