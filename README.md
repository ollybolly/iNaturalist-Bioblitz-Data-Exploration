[Data_Dive_User_Guide.md](https://github.com/user-attachments/files/23147550/Data_Dive_User_Guide.md)
---
title: "iNaturalist Bioblitz Data Dive - User Guide"
format: pdf
---

# iNaturalist Bioblitz Data Dive
## Complete User Guide

**Version 1.0 | October 2025**

---

## Table of Contents

1. [Introduction](#introduction)
2. [What This Script Does](#what-this-script-does)
3. [Prerequisites](#prerequisites)
4. [Initial Setup](#initial-setup)
5. [Understanding the Configuration Section](#understanding-the-configuration-section)
6. [Running the Script](#running-the-script)
7. [Output Files](#output-files)
8. [Troubleshooting](#troubleshooting)
9. [Tips and Best Practices](#tips-and-best-practices)

---

## Introduction

This script automatically creates comprehensive analytical presentations from iNaturalist bioblitz data. It generates beautiful charts, maps, and statistical analyses that tell the complete story of your bioblitz event.

The presentation includes:
- Summary statistics with featured photos
- Observation hotspot maps (with and without plants)
- Temporal patterns showing when observations were made
- Taxon diversity analysis
- Top observer contributions
- Species richness heatmaps with spatial analysis
- Species accumulation curves
- Both HTML and PowerPoint outputs for easy sharing and editing

**Who is this guide for?** Anyone who wants to create professional data presentations from an iNaturalist bioblitz, even if you're new to R and RStudio.

---

## What This Script Does

### The Process

1. **Connects to iNaturalist**: Downloads all observation data from your specified project
2. **Calculates Statistics**: Computes key metrics:
   - Total observations, species, and observers
   - Taxonomic diversity
   - Temporal patterns (day vs night, hourly trends)
   - Observer contributions
3. **Creates Maps**: Generates satellite-based maps showing:
   - Where observations were made (hotspots)
   - Spatial distribution by taxon groups
   - Species richness patterns across the landscape
4. **Builds Charts**: Creates professional visualizations:
   - Taxon group distributions (treemaps or bar charts)
   - Temporal activity patterns
   - Top observer rankings
   - Species accumulation curves
5. **Generates Heatmaps**: Advanced spatial analysis:
   - Grid-based species richness
   - Effort-corrected richness (accounting for sampling bias)
   - Interpolated continuous surfaces
6. **Produces Presentations**: Creates both:
   - **HTML slideshow** (interactive, works in any browser)
   - **PowerPoint file** (fully editable for customization)

### Key Features

- **Comprehensive Analysis**: 13+ slides covering all aspects of your event
- **Professional Quality**: Publication-ready charts and maps
- **Spatial Intelligence**: Advanced heatmaps show biodiversity hotspots
- **Statistical Rigor**: Rarefaction curves assess sampling completeness
- **Efficient Caching**: After first run, only checks for new data (much faster!)
- **Customizable**: Extensive options for maps, charts, and analysis parameters
- **Dual Output**: Get both HTML and PowerPoint versions automatically

---

## Prerequisites

### Required Software

1. **R** (version 4.0 or higher)
   - Download from: https://cran.r-project.org/
   - Choose your operating system and follow installation instructions

2. **RStudio** (Desktop version)
   - Download from: https://posit.co/download/rstudio-desktop/
   - Install after R is installed

3. **Quarto** (for presentation generation)
   - Download from: https://quarto.org/docs/get-started/
   - Required for creating HTML and PowerPoint outputs
   - Install after R and RStudio

### R Packages (Installed Automatically)

The script will automatically install these packages the first time you run it:
- `httr2`, `jsonlite` - For connecting to iNaturalist
- `dplyr`, `tidyr`, `purrr` - For data manipulation
- `ggplot2`, `sf` - For creating charts and maps
- `maptiles`, `terra`, `tidyterra`, `osmdata` - For satellite imagery and spatial analysis
- `viridis`, `scales` - For color schemes
- `treemapify` - For treemap visualizations
- `suncalc` - For sunrise/sunset calculations
- `stars` - For raster analysis
- `quarto` - For presentation generation
- And several others

**This may take 15-20 minutes the first time**, so be patient!

---

## Initial Setup

### Step 1: Install R, RStudio, and Quarto

1. First install R from https://cran.r-project.org/
2. Then install RStudio from https://posit.co/download/rstudio-desktop/
3. Finally install Quarto from https://quarto.org/docs/get-started/
4. Open RStudio - you should see 4 panes (Console, Source, Environment, Files/Plots)

### Step 2: Create a New Project

Creating a project keeps all your files organized in one place.

1. In RStudio, click **File** → **New Project**
2. Choose **New Directory**
3. Choose **New Project**
4. **Directory name**: Give it a name like `MyBioblitz_DataDive`
5. **Create project as subdirectory of**: Click **Browse** and choose where to save it (e.g., your Documents folder)
6. Click **Create Project**

RStudio will restart with your new project open.

### Step 3: Prepare Your Files

1. **Get the Script**:
   - Save the data dive script file (e.g., `Data_Dive_V3.R`) into your project folder
   - You can see where your project folder is by looking at the Files pane (bottom right) - it shows your working directory

2. **Add Your Logo** (Optional but recommended):
   - Find your bioblitz logo image (JPG, PNG, etc.)
   - Copy it into the same project folder
   - Remember the exact filename - you'll need it later
   - Example: `My-Bioblitz-Logo.jpg`

3. **Verify File Locations**:
   - In RStudio's Files pane (bottom right), you should see:
     - Your script file (`.R` extension)
     - Your logo file (if you have one)

### Step 4: Open the Script

1. In RStudio's Files pane (bottom right), find your script file
2. Click on it to open it in the Source pane (top left)
3. You should now see all the script code

---

## Understanding the Configuration Section

The top of the script has a **CONFIGURATION** section. This is where you customize the script for your needs. Everything between these lines can be changed:

```r
# ==============================================================================
# CONFIGURATION - EDIT THESE SETTINGS
# ==============================================================================
```

and

```r
# ==============================================================================
# END OF CONFIGURATION
# ==============================================================================
```

**⚠️ IMPORTANT**: Only edit settings in the CONFIGURATION section. Don't change anything below the "END OF CONFIGURATION" line unless you know what you're doing!

### Project Settings

```r
project_slug <- "walpole-wilderness-bioblitz-2025"
bioblitz_logo <- "Walpole-Wilderness-bioblitz.jpg"
```

**What to change:**

- `project_slug`: Your iNaturalist project identifier
  - **How to find it**: Go to your project page on iNaturalist.org
  - Look at the URL: `https://www.inaturalist.org/projects/YOUR-PROJECT-NAME`
  - Copy everything after `/projects/`
  - Example: For `https://www.inaturalist.org/projects/city-nature-challenge-2025`, use `"city-nature-challenge-2025"`

- `bioblitz_logo`: Your logo filename
  - **Must be exact**, including capitals and file extension
  - Example: `"My-Bioblitz-Logo.jpg"` or `"logo.png"`
  - If you don't have a logo, leave as is (script will use text-only title slide)

### HQ Location (for maps)

```r
hq_lon <- 116.634398
hq_lat <- -34.992854
```

**What to change:**

These are the coordinates of your bioblitz headquarters or main meeting point. This appears on maps for context.

**How to find your coordinates:**
1. Go to Google Maps
2. Find your headquarters location
3. Right-click on the spot
4. Click on the coordinates (they'll be copied)
5. Paste them into the script
6. Format: First number is longitude (`hq_lon`), second is latitude (`hq_lat`)

Example: If Google Maps shows `-34.992854, 116.634398`, use:
```r
hq_lon <- 116.634398
hq_lat <- -34.992854
```

### Event Window

```r
date_min <- as.Date("2025-10-04")
date_max <- as.Date("2025-10-05")
quality_grades <- c("research", "needs_id")
```

**What to change:**

- `date_min`: First day of your bioblitz
  - Format: `as.Date("YYYY-MM-DD")`
  - Example: `as.Date("2025-10-04")` for October 4, 2025

- `date_max`: Last day of your bioblitz
  - Same format as date_min
  - For single-day events, use same date as date_min

- `quality_grades`: Which observation quality levels to include
  - `"research"` = Research Grade (ID confirmed by community)
  - `"needs_id"` = Needs ID (awaiting confirmation)
  - Default includes both for comprehensive coverage
  - **To include only confirmed IDs**: `quality_grades <- c("research")`

### Map Settings

```r
base_map_zoom <- 14
buffer_km <- 2.5
```

**What these do:**

- `base_map_zoom`: Detail level of satellite imagery
  - **Range**: 10-16
  - **10-12**: Regional view, less detail
  - **13-14**: Good balance (recommended)
  - **15-16**: Very detailed, may be slow
  - **Default**: 14 works well for most bioblitzes

- `buffer_km`: How much area around observations to show
  - **In kilometers** - shows this much beyond the outermost observations
  - **Smaller values** (1.5-2.0): Tight focus on observation area
  - **Medium values** (2.5-3.5): Good context (recommended)
  - **Larger values** (4.0-5.0): Wider regional view
  - **Default**: 2.5 provides good balance

### Data Caching

```r
force_rebuild <- FALSE
use_cached_data <- TRUE
```

**What these do:**

These control whether to reuse previously fetched data or fetch fresh from iNaturalist.

- `force_rebuild`: Regenerate all figures even if they already exist
  - `FALSE` = Skip figures that already exist (faster)
  - `TRUE` = Remake all figures from scratch
  - **When to use TRUE**: After changing map settings or visual parameters
  - **Default**: `FALSE` for efficiency

- `use_cached_data`: Use previously downloaded observation data
  - `TRUE` = Use cached data if available (much faster!)
  - `FALSE` = Fetch fresh data from iNaturalist
  - **When to use FALSE**: 
    - First run
    - When new observations have been added
    - If you want the absolute latest data
  - **When to use TRUE**:
    - After first run
    - When you're just adjusting visualization settings
    - For quick re-runs with different parameters

### Output Format Options

```r
render_html <- TRUE
render_powerpoint <- TRUE
```

**What these do:**

Control which presentation formats to generate.

- `render_html`: Create HTML slideshow
  - Interactive presentation that works in any browser
  - Best for sharing via email or website
  - Press 'F' for fullscreen, arrow keys to navigate

- `render_powerpoint`: Create PowerPoint file
  - Fully editable .pptx file
  - Great for customizing before presenting
  - Can adjust layouts, add slides, change text

**Common configurations:**
- Both TRUE (default): Get both formats for maximum flexibility
- HTML only: `render_powerpoint <- FALSE`
- PowerPoint only: `render_html <- FALSE`

### Figure Display Options

```r
fig2_use_treemap <- TRUE
n_top_observers <- 15
```

**What these control:**

- `fig2_use_treemap`: How to display taxon diversity
  - `TRUE` = Treemap (colorful boxes, shows proportions well)
  - `FALSE` = Bar chart (traditional, easier to read exact numbers)
  - **Treemaps are recommended** for visual impact

- `n_top_observers`: How many top observers to show in the chart
  - **Common values**: 10, 15, 20
  - **15 (default)** works well for most events
  - **Larger values** if you have many active observers
  - **Smaller values** for cleaner, less crowded charts

### Visual Settings (Advanced)

```r
# Figure dimensions
map_fig_width <- 12
map_fig_height <- 10
chart_fig_width <- 12
chart_fig_height <- 8

# Text sizes
legend_text_size <- 12
legend_title_size <- 14
axis_text_size <- 11
axis_title_size <- 13
```

**When to adjust:**

These control the size and legibility of your presentations.

**For large screens or projectors:**
```r
map_fig_width <- 14
map_fig_height <- 12
legend_text_size <- 14
legend_title_size <- 16
```

**For reports or documents:**
```r
map_fig_width <- 10
map_fig_height <- 8
legend_text_size <- 10
legend_title_size <- 12
```

**Usually best to leave at defaults** unless you have specific presentation needs.

### Heatmap Analysis Settings (Advanced)

```r
grid_cell_size_m <- 500
rank_level <- "species"
min_obs_per_cell <- 3
use_interpolation <- TRUE
```

**What these control:**

These affect the species richness heatmap analysis. Most users can leave these at defaults.

- `grid_cell_size_m`: Size of grid cells for spatial analysis (in meters)
  - **Smaller (250-400)**: More detail but may have gaps
  - **Medium (500-750)**: Good balance (recommended)
  - **Larger (1000+)**: Smoother but less spatial detail

- `rank_level`: What taxonomic level to count
  - `"species"` (default): Count unique species
  - `"genus"`: Count unique genera (less specific)
  - `"family"`: Count unique families (even broader)
  - **Stick with "species"** for most analyses

- `min_obs_per_cell`: Minimum observations needed per grid cell
  - Filters out unreliable cells with too little data
  - **3 (default)** is conservative and reliable
  - **2**: More cells shown but less reliable
  - **5+**: Very reliable but may exclude edges

- `use_interpolation`: Create smooth continuous richness surface
  - `TRUE` (default): Creates beautiful interpolated heatmap
  - `FALSE`: Skip interpolation (faster, but missing this visualization)
  - **Keep TRUE** unless script is very slow

### Rarefaction Settings (Advanced)

```r
n_permutations <- 100
step_size <- 10
rarefaction_rank_level <- "species"
```

**What these control:**

These affect the species accumulation curve analysis. Most users can leave at defaults.

- `n_permutations`: Number of random orderings to compute
  - **Higher values** = More reliable confidence intervals but slower
  - **50**: Fast but less precise
  - **100** (default): Good balance
  - **200+**: Publication quality but takes longer

- `step_size`: How often to sample the accumulation curve
  - **Smaller (5-10)**: More detailed curve but slower
  - **10** (default): Good balance for most events
  - **Larger (15-20)**: Faster but less smooth curve

- `rarefaction_rank_level`: What to count
  - `"species"` (default): Count unique species
  - Should match `rank_level` above

### Sunrise/Sunset Settings

```r
# Manual override: uncomment and set these values
# sunrise_hour <- 6.5
# sunset_hour <- 18.5
```

**What these do:**

The script automatically calculates sunrise and sunset times based on your HQ location and event date. This is used to classify observations as "day" or "night" in the temporal analysis charts.

**Usually you don't need to change this!** The automatic calculation is accurate.

**When to manually set:**
- If automatic calculation seems wrong for your location
- If you want to use different day/night boundaries
- Format: decimal hours (6.5 = 6:30 AM, 18.5 = 6:30 PM)

To use manual settings:
1. Remove the `#` from the start of both lines (uncomment)
2. Set your desired times

---

## Running the Script

### First Run (Initial Setup)

This is when you run the script for the very first time.

**Settings to use:**
```r
use_cached_data <- FALSE    # Fetch fresh data
force_rebuild <- TRUE        # Generate all figures
render_html <- TRUE
render_powerpoint <- TRUE
```

**Steps:**

1. **Configure the script**:
   - Edit all required settings in the CONFIGURATION section
   - Pay special attention to: `project_slug`, `hq_lon`, `hq_lat`, `date_min`, `date_max`

2. **Save your changes**: Click the Save icon or press `Ctrl+S` (Windows) / `Cmd+S` (Mac)

3. **Run the entire script**:
   - Click the **Source** button at the top of the Source pane
   - Or press `Ctrl+Shift+S` (Windows) / `Cmd+Shift+S` (Mac)

4. **Watch the Console** (bottom-left pane):
   - You'll see progress messages like "=== FETCHING OBSERVATIONS ==="
   - Package installation happens first (15-20 minutes first time)
   - Data fetching takes 2-10 minutes depending on project size
   - Figure generation takes 5-15 minutes
   - Presentation rendering takes 1-2 minutes
   - **Total first run: 20-40 minutes**

5. **Wait for completion**:
   - Look for "=== DATA DIVE COMPLETE ===" in the Console
   - The script will report file locations
   - Don't close RStudio until you see this message!

### Subsequent Runs (Updates)

After your first successful run, subsequent runs are much faster.

**Settings to use:**
```r
use_cached_data <- TRUE     # Use existing data
force_rebuild <- FALSE       # Skip existing figures
```

**When to run again:**
- To fetch new observations added since last run
- To change visualization settings
- To generate different output formats
- To adjust map or chart parameters

**Typical runtime: 2-5 minutes** (vs 20-40 first time!)

### Running Specific Sections

Advanced users can run individual sections:

1. Place your cursor anywhere in the section you want
2. Click **Code** → **Run Region** → **Run Section**
3. Or select specific lines and press `Ctrl+Enter` (Windows) / `Cmd+Enter` (Mac)

**Useful for:**
- Testing configuration changes
- Regenerating specific figures
- Troubleshooting problems

---

## Output Files

After running the script successfully, you'll find several outputs in your project directory.

### Output Directory Structure

```
outputs/
└── [project_name]_data_dive/
    ├── slides/
    │   ├── data_dive_presentation.html   ← HTML slideshow
    │   ├── data_dive_presentation.pptx   ← PowerPoint file
    │   ├── fig_summary_with_photos.png
    │   ├── fig_observation_hotspots_jittered.png
    │   ├── fig_observation_hotspots_no_plants.png
    │   ├── fig_observations_by_taxon.png
    │   ├── fig_top_observers.png
    │   ├── fig_observations_by_hour.png
    │   ├── fig_observations_by_hour_stacked.png
    │   ├── fig_richness_raw.png
    │   ├── fig_richness_effort_corrected.png
    │   ├── fig_richness_interpolated.png
    │   ├── fig_rarefaction_all_taxa.png
    │   ├── fig_rarefaction_by_group.png
    │   └── logo.jpg (if provided)
    ├── styles/
    │   └── custom.css
    └── observations_filtered.csv  ← Cached data
```

### Main Output Files

#### 1. data_dive_presentation.html

**The HTML Slideshow**

- **What it is**: Interactive web-based presentation
- **How to use**:
  1. Double-click to open in your default browser
  2. Press 'F' for fullscreen mode
  3. Use arrow keys or space bar to navigate
  4. Press 'S' for speaker view (shows next slide)
  5. Press 'Esc' to exit fullscreen
- **Best for**: 
  - Sharing via email or website
  - Presenting directly from browser
  - Viewers who don't have PowerPoint

#### 2. data_dive_presentation.pptx

**The PowerPoint File**

- **What it is**: Editable presentation in Microsoft PowerPoint format
- **How to use**:
  1. Open in PowerPoint, Google Slides, or LibreOffice
  2. Edit slides, text, layouts as needed
  3. Add your own slides or notes
  4. Save and share
- **Best for**:
  - Customizing before presenting
  - Adding additional information
  - Incorporating into larger presentations
  - Printing handouts

### Figure Files

All individual charts and maps are saved as PNG files:

- **fig_summary_with_photos.png**: Overview statistics with sample photos
- **fig_observation_hotspots_jittered.png**: Map showing where all observations were made
- **fig_observation_hotspots_no_plants.png**: Same map excluding plants (shows animals/fungi better)
- **fig_observations_by_taxon.png**: Distribution across organism groups
- **fig_top_observers.png**: Bar chart of most active participants
- **fig_observations_by_hour.png**: Activity patterns throughout the day
- **fig_observations_by_hour_stacked.png**: Same but separated by organism type
- **fig_richness_raw.png**: Grid-based species richness heatmap
- **fig_richness_effort_corrected.png**: Richness adjusted for sampling effort
- **fig_richness_interpolated.png**: Smooth continuous richness surface
- **fig_rarefaction_all_taxa.png**: Species accumulation curve (all organisms)
- **fig_rarefaction_by_group.png**: Accumulation curves by major groups

**These files can be used:**
- In reports or publications
- On websites or social media
- In custom presentations
- For print materials

### Data Files

#### observations_filtered.csv

**Cached observation data**

- All observations from your project
- Filtered to your date range and quality settings
- Used for faster subsequent runs
- Can be opened in Excel or other spreadsheet software
- Useful for custom analysis

**Columns include:**
- obs_id, observed_on, time_observed_at
- observer_login, observer_name
- taxon_id, taxon_name, taxon_common_name
- iconic_taxon, taxon_rank
- longitude, latitude
- quality_grade
- And more...

---

## Troubleshooting

### Problem: "Package installation failed"

**Cause**: A required package couldn't be installed.

**Solutions**:
1. Check your internet connection
2. Try running the script again (it will retry installation)
3. Manually install the problematic package:
   ```r
   install.packages("PACKAGE_NAME")
   ```
4. Some packages require system dependencies:
   - **On Windows**: Usually works automatically
   - **On Mac**: May need Xcode Command Line Tools
   - **On Linux**: May need `libgdal-dev`, `libudunits2-dev`, `libproj-dev`

### Problem: "Quarto not found" or "Rendering failed"

**Cause**: Quarto is not installed or not found by R.

**Solutions**:
1. Install Quarto from https://quarto.org/docs/get-started/
2. Restart RStudio after installing Quarto
3. Verify installation by running in R Console:
   ```r
   quarto::quarto_version()
   ```
4. If still not working, try manually:
   ```r
   install.packages("quarto")
   ```

### Problem: "No observations returned for project"

**Cause**: Script can't find observations for your project slug.

**Solutions**:
1. **Verify project slug**:
   - Go to your project on iNaturalist.org
   - Copy the exact project ID from the URL
   - Check for typos or incorrect capitalization
2. **Check project has observations**:
   - Make sure observations exist in your date range
   - Verify observations meet quality grade criteria
3. **Try simpler test**:
   ```r
   project_slug <- "city-nature-challenge-2020"  # Known large project
   date_min <- as.Date("2020-04-24")
   date_max <- as.Date("2020-04-27")
   ```

### Problem: "Cached data is outdated"

**Cause**: Cached data file is from an older version of the script.

**Solution**:
1. Set `use_cached_data <- FALSE` in configuration
2. Run the script (it will fetch fresh data)
3. Or manually delete the cache file:
   - Navigate to `outputs/[project]_data_dive/` folder
   - Delete `observations_filtered.csv`
   - Run script again

### Problem: Script is very slow

**Causes**: Large project, slow internet, complex analysis.

**Solutions**:
- **First run**: Be patient! 20-40 minutes is normal for projects with 1000+ observations
- **Subsequent runs**: Make sure `use_cached_data <- TRUE` and `force_rebuild <- FALSE`
- **Speed up heatmaps**:
  ```r
  grid_cell_size_m <- 750        # Larger cells
  use_interpolation <- FALSE     # Skip interpolation
  n_permutations <- 50           # Fewer rarefaction iterations
  ```
- **Skip PowerPoint** if you only need HTML:
  ```r
  render_powerpoint <- FALSE
  ```

### Problem: Maps show wrong area or too much empty space

**Cause**: Buffer setting or HQ coordinates need adjustment.

**Solutions**:
1. **Adjust buffer**:
   ```r
   buffer_km <- 2.0    # Smaller for tighter view
   buffer_km <- 4.0    # Larger for more context
   ```
2. **Verify HQ coordinates**:
   - Check `hq_lon` and `hq_lat` are correct
   - Make sure longitude comes first
3. **Force map regeneration**:
   ```r
   force_rebuild <- TRUE
   ```

### Problem: "Error in get_tiles" or "Cannot fetch base map"

**Cause**: Problem downloading satellite imagery.

**Solutions**:
1. Check internet connection
2. Try running again (sometimes servers are temporarily busy)
3. Try different zoom level:
   ```r
   base_map_zoom <- 13  # Less detailed, may be more reliable
   ```
4. If persistent, may be temporary service outage - try again later

### Problem: Figures look too small or text is illegible

**Cause**: Default figure sizes may not be optimal for your display.

**Solutions**:
For **large screens/projectors**:
```r
map_fig_width <- 14
map_fig_height <- 12
legend_text_size <- 14
axis_text_size <- 12
```

For **small screens/documents**:
```r
map_fig_width <- 10
map_fig_height <- 8
legend_text_size <- 10
axis_text_size <- 9
```

Then regenerate:
```r
force_rebuild <- TRUE
```

### Problem: PowerPoint file is very large

**Cause**: All images are embedded at high resolution.

**Solutions**:
1. **This is normal** for quality output (10-30 MB is typical)
2. To reduce size:
   ```r
   map_fig_width <- 10
   chart_fig_width <- 10
   ```
3. Or compress in PowerPoint:
   - File → Compress Pictures
   - Apply to all images
   - Choose lower quality

### Problem: HTML works but PowerPoint is blank or corrupted

**Cause**: PowerPoint rendering issue.

**Solutions**:
1. Check Quarto is properly installed
2. Try rendering manually in Console:
   ```r
   quarto::quarto_render(
     "outputs/[project]/slides/data_dive_presentation.qmd",
     output_format = "pptx"
   )
   ```
3. Check for error messages in Console
4. Try just HTML first, then add PowerPoint after:
   ```r
   render_html <- TRUE
   render_powerpoint <- FALSE
   ```

---

## Tips and Best Practices

### For First-Time Users

1. **Start with defaults**: Don't change too many settings initially
2. **Test with known project**: Try a large, well-known project first (like City Nature Challenge)
3. **Check each step**: Watch Console output for errors
4. **Be patient**: First run takes time - 20-40 minutes is normal
5. **Keep cache**: After first run, set `use_cached_data <- TRUE`

### For Regular Users

1. **Optimize settings**:
   ```r
   use_cached_data <- TRUE
   force_rebuild <- FALSE
   ```
2. **Update strategically**: Only fetch new data when needed
3. **Customize visuals**: Adjust figure sizes for your specific presentation needs
4. **Save variations**: Create different versions by changing `out_dir`

### Creating Multiple Versions

Want different presentations from the same event?

**Example: Separate presentations for different audiences**

```r
# Technical/detailed version
out_dir <- "outputs/bioblitz_detailed"
use_interpolation <- TRUE
n_permutations <- 200

# Quick/simple version
out_dir <- "outputs/bioblitz_summary"
use_interpolation <- FALSE
n_permutations <- 50
```

Each version gets its own output folder!

### Optimizing Performance

1. **Efficient caching**:
   - Keep `.csv` and `.png` files between runs
   - Don't delete cache files unnecessarily
   - Only fetch new data when observations added

2. **Faster development/testing**:
   ```r
   use_cached_data <- TRUE
   force_rebuild <- FALSE
   use_interpolation <- FALSE
   n_permutations <- 50
   render_powerpoint <- FALSE  # Skip if only testing
   ```

3. **Best quality for final**:
   ```r
   use_interpolation <- TRUE
   n_permutations <- 200
   render_html <- TRUE
   render_powerpoint <- TRUE
   ```

### Understanding Your Results

#### Summary Statistics
- **Total observations**: All qualifying observations in date range
- **Species identified**: Unique species (may include unknowns)
- **Research grade**: Community-confirmed identifications
- **Observers**: Unique participants

#### Hotspot Maps
- **All observations**: Shows complete spatial coverage
- **Excluding plants**: Better view of animal/fungi distribution
- **Jittering**: Points slightly moved to prevent overlap (actual locations nearby)
- **HQ marker**: Shows your headquarters location for context

#### Temporal Patterns
- **Day vs Night**: Based on sunrise/sunset at your location
- **Hourly patterns**: Shows peak activity times
- **Stacked by taxon**: Reveals which groups were observed when

#### Top Observers
- Shows most active participants
- Good for recognizing key contributors
- Default shows top 15 (adjustable)

#### Species Richness Heatmaps
- **Raw richness**: Number of species per grid cell
- **Effort-corrected**: Accounts for sampling intensity
- **Interpolated**: Smooth continuous surface
- **Warmer colors** (red/yellow) = higher diversity
- **Cooler colors** (blue/purple) = lower diversity

#### Rarefaction Curves
- **Steep upward**: Many species still being discovered
- **Flattening**: Approaching complete sampling
- **Confidence bands**: Gray area shows uncertainty
- **By group**: Compares sampling completeness across taxa

### Customizing PowerPoint Output

After generating the PowerPoint file, you can:

1. **Adjust layouts**:
   - Resize images to fit your preferred layout
   - Move or remove elements
   - Add your organization's branding

2. **Add content**:
   - Insert additional slides
   - Add speaker notes
   - Include acknowledgments or conclusions

3. **Modify text**:
   - Edit titles or subtitles
   - Change fonts or colors
   - Add captions or explanations

4. **Apply themes**:
   - Use your organization's PowerPoint template
   - Apply consistent color schemes
   - Add headers/footers

### Sharing Your Presentation

**HTML version** (best for most uses):
- Share the entire `slides` folder
- Anyone can open `data_dive_presentation.html` in any browser
- No special software required
- Interactive navigation

**PowerPoint version**:
- Single file, easy to email
- Editable by recipients
- Works offline
- Can print handouts
- Compatible with most presentation software

**For websites**:
- Upload the entire `slides` folder to web server
- Link to `data_dive_presentation.html`
- Works on any web hosting service

**Individual figures**:
- All PNG files can be used independently
- Great for reports, posters, or social media
- High resolution suitable for print

### Best Practices for Analysis

1. **Check data quality**:
   - Look at rarefaction curves - are they flattening?
   - Check effort-corrected richness - does it make sense?
   - Review temporal patterns - do they match expectations?

2. **Interpret carefully**:
   - Hotspots show where people looked, not necessarily where biodiversity is highest
   - Richness affected by observer effort and expertise
   - Plants often over-represented (easier to photograph)

3. **Context matters**:
   - Compare day vs night patterns
   - Consider weather or event schedule effects
   - Think about accessibility of different areas

4. **Communicate clearly**:
   - Explain what rarefaction curves mean
   - Note that heatmaps show sampling, not true biodiversity
   - Acknowledge biases in citizen science data

### Advanced Tips

#### Custom Color Schemes

To match your organization's branding, you can edit the `custom.css` file after generation:
```css
:root {
  --r-link-color: #YOUR_COLOR_HERE;
  --r-heading-color: #YOUR_COLOR_HERE;
}
```

#### Combining with Slideshow Script

If you're also using the bioblitz slideshow script:
1. Use same `project_slug` and settings in both
2. Run data dive first to get overview
3. Run slideshow for beautiful photo presentation
4. Present data dive first, then show slideshow
5. Creates comprehensive event summary!

#### Automating for Multiple Events

For organizations running regular bioblitzes:
1. Keep a template configuration
2. Only change: `project_slug`, dates, HQ coordinates
3. Run script after each event
4. Build library of presentations

---

## Getting Help

### Console Output

The Console (bottom-left pane) shows detailed progress. Look for:

- **=== SECTION NAMES ===**: Shows which part is running
- **Progress indicators**: E.g., "Fetching observations page 3 of 25"
- **Red text**: Errors that need attention
- **"WARNING:"**: Potential problems
- **"SUCCESS"**: Confirming completion of steps

### Common Patterns

**Script stops early?**
- Scroll up in Console to find red error text
- Error message usually explains the problem
- Check configuration settings mentioned in error

**Script seems frozen?**
- Check if RStudio shows [BUSY] or red stop icon
- If busy, be patient - complex analyses take time
- If truly frozen (>5 minutes no output), press ESC to stop
- Check what section it was running

**Unexpected results?**
- Verify project_slug is correct
- Check date range captures your event
- Confirm HQ coordinates are right
- Try with `force_rebuild <- TRUE`

### Documentation References

- **iNaturalist**: https://www.inaturalist.org/pages/help
- **R Documentation**: https://www.r-project.org/help.html
- **RStudio Help**: Help → RStudio Docs
- **Quarto**: https://quarto.org/docs/guide/
- **ggplot2** (for understanding charts): https://ggplot2.tidyverse.org/

---

## Appendix: Quick Reference

### Configuration Quick Checklist

Must configure for first run:
- [ ] `project_slug` - Your iNaturalist project ID
- [ ] `hq_lon` - Headquarters longitude  
- [ ] `hq_lat` - Headquarters latitude
- [ ] `date_min` - Event start date
- [ ] `date_max` - Event end date
- [ ] `bioblitz_logo` - Your logo filename (optional)

Often adjusted:
- [ ] `use_cached_data` - TRUE after first run
- [ ] `force_rebuild` - TRUE when changing visuals
- [ ] `buffer_km` - Adjust map extent
- [ ] `render_html` / `render_powerpoint` - Choose outputs

### Common Setting Combinations

**First time setup:**
```r
project_slug <- "your-project-name-here"
hq_lon <- YOUR_LONGITUDE
hq_lat <- YOUR_LATITUDE
date_min <- as.Date("YYYY-MM-DD")
date_max <- as.Date("YYYY-MM-DD")
use_cached_data <- FALSE
force_rebuild <- TRUE
render_html <- TRUE
render_powerpoint <- TRUE
```

**Fast updates (already cached):**
```r
use_cached_data <- TRUE
force_rebuild <- FALSE
# Everything else stays the same
```

**Testing/development:**
```r
use_cached_data <- TRUE
force_rebuild <- FALSE
use_interpolation <- FALSE
n_permutations <- 50
render_powerpoint <- FALSE
```

**Final high-quality output:**
```r
use_cached_data <- TRUE  # If data is current
force_rebuild <- TRUE
use_interpolation <- TRUE
n_permutations <- 200
render_html <- TRUE
render_powerpoint <- TRUE
```

**Tight map focus:**
```r
buffer_km <- 2.0
base_map_zoom <- 15
```

**Wide regional context:**
```r
buffer_km <- 4.0
base_map_zoom <- 12
```

---

## Version History

**Version 1.0 (October 2025)**
- Initial release
- Comprehensive statistical analysis
- Multiple visualization types
- Spatial richness analysis (grid, effort-corrected, interpolated)
- Rarefaction curve analysis
- Dual output (HTML + PowerPoint)
- Optimized figure dimensions and legibility
- Extensive configuration options

---

## Credits

This script was developed for comprehensive bioblitz data analysis and is designed to work with any iNaturalist project.

**Technologies used:**
- R and RStudio
- Quarto for presentation generation
- Reveal.js for HTML presentations
- ggplot2 for charts and visualizations
- sf and terra for spatial analysis
- Esri satellite imagery
- OpenStreetMap data
- iNaturalist API

**Analysis methods:**
- Grid-based species richness
- Inverse Distance Weighting (IDW) interpolation
- Rarefaction analysis with bootstrapping
- Temporal pattern analysis
- Effort-corrected diversity metrics

---

**Happy Data Diving! 📊🗺️🦋**

If you create insightful analyses with this script, consider sharing your results with the iNaturalist community!
