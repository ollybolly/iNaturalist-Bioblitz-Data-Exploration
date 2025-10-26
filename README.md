# 🦘📊 iNaturalist Bioblitz Data Dive

Statistical analysis and visualization toolkit for iNaturalist bioblitz projects. Transform your bioblitz into charts and spatial analyses to help you and your participants share the bigger picture in a presentation

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![R](https://img.shields.io/badge/R-%3E%3D4.0-blue)](https://www.r-project.org/)

---

## ✨ Features

- **📈 Comprehensive Analysis**: 10+ figures covering spatial, temporal, and taxonomic patterns
- **🗺️ Advanced Mapping**: Observation hotspots, species richness heatmaps, and effort-corrected visualizations
- **📉 Statistical Rigor**: Rarefaction curves, confidence intervals, and quality thresholds
- **🎯 Smart Interpolation**: IDW interpolation for smooth spatial patterns
- **⚡ Performance Optimized**: Fast map providers and intelligent caching for large bioblitzes
- **📑 Multiple Outputs**: Interactive HTML slideshow (Reveal.js) and editable PowerPoint
- **🔄 Incremental Updates**: Smart caching makes subsequent runs 10x faster
- **🎨 Publication-Ready**: High-resolution figures with customizable styling

## 🎯 What It Does

The Data Dive script creates a comprehensive analytical presentation from your iNaturalist bioblitz data:

### Core Analyses

1. **Summary Statistics** - Total observations, species, observers, and quality grades with photo collage
2. **Observation Hotspots** - Spatial maps showing where observations occurred with jittered points
3. **Taxonomic Breakdown** - Distribution across taxon groups (Plants, Insects, Birds, etc.) as treemap or bar chart
4. **Top Observers** - Who contributed the most observations (configurable N)
5. **Temporal Patterns** - Day vs. night activity with automatic sunrise/sunset calculation
6. **Species Richness Heatmaps** - Three types:
   - Raw species count per grid cell
   - Effort-corrected richness (species per observation)
   - Smooth interpolated surface (IDW)
7. **Rarefaction Curves** - Species accumulation patterns showing:
   - Overall sampling completeness
   - Per-taxon accumulation rates
   - Confidence intervals from 100+ permutations

### Output Formats

- **HTML Slideshow** - Interactive Reveal.js presentation with:
  - Fullscreen mode (press 'F')
  - Navigation controls
  - Speaker view (press 'S')
  
- **PowerPoint (.pptx)** - Editable presentation with:
  - All figures as high-resolution images
  - Ready for customization
  - Compatible with Google Slides

## 📋 Prerequisites

### Required Software

- **R** (version 4.0 or higher) - [Download here](https://cran.r-project.org/)
- **RStudio** (Desktop version) - [Download here](https://posit.co/download/rstudio-desktop/)

### R Packages

The script will automatically install all required packages on first run:
- `httr2`, `jsonlite` - iNaturalist API connection
- `dplyr`, `tidyr`, `purrr`, `stringr` - Data manipulation
- `ggplot2`, `sf` - Visualization and mapping
- `maptiles`, `terra`, `osmdata` - Map tiles and geographic data
- `scales`, `viridis`, `patchwork` - Advanced plotting
- `treemapify` - Treemap visualizations
- `suncalc` - Sunrise/sunset calculations
- `quarto` - HTML slideshow generation
- `officer` - PowerPoint generation

*First-time setup may take 15-20 minutes while packages install.*

## 🚀 Quick Start

### 1. Installation

Clone or download this repository:

```bash
git clone https://github.com/yourusername/inaturalist-bioblitz-datadive.git
cd inaturalist-bioblitz-datadive
```

### 2. Configure Your Bioblitz

Open `Bioblitz_Data_Dive.R` in RStudio and edit the configuration section:

```r
# --- Essential Settings ---
project_slug <- "your-project-name-here"  # From your iNaturalist project URL
bioblitz_name <- "Your Location"          # Appears on slides
bioblitz_year <- 2025                     # Year of your bioblitz

# --- Event Window ---
date_min <- as.Date("2025-10-15")
date_max <- as.Date("2025-10-16")

# --- HQ Location (for maps) ---
hq_lon <- 116.634398  # Your headquarters longitude
hq_lat <- -34.992854  # Your headquarters latitude

# --- Optional: Add Your Logo ---
bioblitz_logo <- "your-logo.jpg"  # Place logo file in project root
```

**Finding your project slug:**
- Go to your iNaturalist project page
- Copy everything after `/projects/` in the URL
- Example: `https://www.inaturalist.org/projects/city-nature-challenge-2025` → `"city-nature-challenge-2025"`

**Finding your coordinates:**
- Right-click your HQ location in Google Maps
- Click the coordinates to copy them
- Format: longitude first (e.g., 116.634398), latitude second (e.g., -34.992854)

### 3. Run the Script

In RStudio:
1. Open the R script file
2. Click **Source** (top right of the script pane), or press `Ctrl+Shift+S` (Windows/Linux) or `Cmd+Shift+S` (Mac)
3. Wait for the script to complete (15-30 minutes first run, progress messages will appear in Console)
4. Find your analysis in the `outputs/data_dive/` folder

**First run takes longer:**
- Package installation (if needed): ~5-10 minutes
- Data download from iNaturalist: ~2-5 minutes
- Map tile downloads: ~5-15 minutes (depends on map provider)
- Figure generation: ~5-10 minutes

**Subsequent runs are much faster** (~2-5 minutes) thanks to caching!

### 4. View Your Analysis

**HTML Slideshow:**
Open `outputs/data_dive/datadive.html` in your web browser:
- Press `F` for fullscreen
- Press `Space` or arrow keys to navigate
- Press `S` for speaker view (shows next slide)
- Press `ESC` to exit fullscreen

**PowerPoint:**
Open `outputs/data_dive/datadive.pptx` in PowerPoint or Google Slides for editing

## 📖 Documentation

For detailed instructions, configuration options, and troubleshooting, see:

- **[📘 Complete Data Dive Guide](DATA_DIVE_GUIDE.md)** - Comprehensive documentation covering:
  - Detailed configuration options
  - All analysis types explained
  - Advanced heatmap settings
  - Rarefaction curve interpretation
  - Performance optimization strategies
  - Troubleshooting common issues

## 🎛️ Key Configuration Options

### Project Settings
```r
project_slug <- "your-project-slug"   # iNaturalist project identifier
bioblitz_name <- "Your Location"      # Name for slides
bioblitz_year <- 2025                 # Year for slides
date_min <- as.Date("2025-10-15")     # Start date
date_max <- as.Date("2025-10-16")     # End date
```

### Map Customization
```r
# Choose your map style:
map_provider <- "Esri.WorldImagery"    # Satellite (high quality, slower)
map_provider <- "OpenStreetMap"        # Street map (fast - recommended for large areas)
map_provider <- "CartoDB.Positron"     # Minimal clean (fastest)
map_provider <- "CartoDB.Voyager"      # Balanced (fast, detailed)
map_provider <- "Esri.WorldTopoMap"    # Topographic (medium speed)

base_map_zoom <- 14                    # Zoom level (13-15)
buffer_km <- 2.5                       # Area around observations (km)
```

### Analysis Parameters
```r
# Heatmap analysis
grid_cell_size_m <- 500         # Grid resolution (250-1000m)
min_obs_per_cell <- 3           # Quality threshold
use_interpolation <- TRUE       # Smooth IDW surface

# Rarefaction analysis
n_permutations <- 100           # More = smoother curves (50-500)
step_size <- 10                 # Sample frequency (5-20)

# Display options
n_top_observers <- 15           # Number of top observers to show
fig2_use_treemap <- TRUE        # Treemap vs. bar chart for taxa
```

### Output Options
```r
render_html <- TRUE             # Generate HTML slideshow
render_powerpoint <- TRUE       # Generate PowerPoint
force_rebuild <- FALSE          # Regenerate all figures
use_cached_data <- TRUE         # Use cached observation data
```

### Performance Optimization
For large bioblitz areas (>50 km²), use these settings for 10-20x faster generation:

```r
map_provider <- "OpenStreetMap"     # Fast map provider
base_map_zoom <- 12                 # Lower zoom = fewer tiles
buffer_km <- 1.5                    # Smaller area
```

**Speed comparison for 100km² area:**
- With satellite imagery: 20-30 minutes
- With OpenStreetMap: 2-3 minutes

## 💡 Common Use Cases

### First-Time Analysis
```r
project_slug <- "your-project-2024"
bioblitz_name <- "Your Location"
bioblitz_year <- 2024
use_cached_data <- FALSE        # Fresh data download
force_rebuild <- TRUE           # Generate all figures
```

### Quick Update (After First Run)
```r
use_cached_data <- TRUE         # Reuse downloaded data
force_rebuild <- FALSE          # Only regenerate missing figures
# Much faster: 2-5 minutes instead of 15-30!
```

### Large Regional Bioblitz
```r
map_provider <- "OpenStreetMap"
base_map_zoom <- 13
buffer_km <- 5
grid_cell_size_m <- 1000        # Larger cells for sparser data
```

### Small Urban Bioblitz
```r
map_provider <- "Esri.WorldImagery"  # Beautiful satellite
base_map_zoom <- 15                  # High detail
buffer_km <- 1.5
grid_cell_size_m <- 250              # Fine spatial resolution
```

### Publication-Quality Figures
```r
n_permutations <- 200           # Smoother rarefaction curves
step_size <- 5                  # More detailed curves
plot_title_size <- 22           # Larger text
render_powerpoint <- TRUE       # For manual editing
```

## 📊 Output Files

After running successfully, check `outputs/data_dive/`:

### Main Files
- **datadive.html** - Interactive HTML slideshow
- **datadive.pptx** - Editable PowerPoint presentation

### Individual Figures (in `slides/` folder)
- `fig_summary_with_photos.png` - Overview statistics with photo collage
- `fig_observation_hotspots_jittered.png` - Spatial distribution map
- `fig_observations_by_taxon.png` - Taxonomic breakdown (treemap or bar)
- `fig_top_observers.png` - Top contributors
- `fig_observations_by_hour.png` - Temporal patterns (day/night)
- `fig_richness_raw.png` - Raw species richness heatmap
- `fig_richness_effort_corrected.png` - Effort-corrected richness
- `fig_richness_interpolated.png` - Smooth interpolated surface
- `fig_rarefaction_all.png` - Overall rarefaction curve
- `fig_rarefaction_by_taxon.png` - Per-taxon accumulation curves

### Cache Files (for faster reruns)
- `obs_cache.rds` - Cached observation data
- `photo_cache/` - Downloaded photos for summary
- `*.rds` files - Individual figure caches

**Important:** Don't delete cache files - they make subsequent runs much faster!

## 🗺️ Analysis Types Explained

### Spatial Analyses

**1. Observation Hotspots**
- Shows where observations occurred
- Jittered points prevent overplotting
- Color-coded by iconic taxon group
- Includes HQ location marker

**2. Species Richness Heatmaps**
Three complementary views:

- **Raw Richness**: Total species per grid cell
  - Shows absolute biodiversity hotspots
  - Not corrected for sampling effort
  
- **Effort-Corrected**: Species per observation
  - Accounts for uneven sampling
  - More accurate comparison across areas
  - Only cells with 3+ observations
  
- **Interpolated Surface**: Smooth continuous pattern
  - IDW (Inverse Distance Weighting) interpolation
  - Shows biodiversity gradients
  - Masked to data coverage area

### Temporal Analyses

**Observations by Hour**
- Automatic sunrise/sunset calculation for your location
- Day vs. night observation patterns
- Identifies peak activity times
- Shows nocturnal vs. diurnal sampling

### Statistical Analyses

**Rarefaction Curves**
- Species accumulation with sampling effort
- Confidence intervals from 100+ permutations
- Shows if sampling was adequate
- Per-taxon comparison of diversity

**Interpretation:**
- Steep curve → Many species not yet found
- Flattening curve → Most species captured
- Per-taxon curves show which groups are diverse

## 🛠️ Troubleshooting

### Common Issues

**"No observations found"**
- Check `project_slug` is correct
- Verify `date_min` and `date_max` cover your event
- Ensure observations have photos and quality grades

**"Map shows wrong area"**
- Verify `hq_lon` and `hq_lat` are correct
- Remember: longitude first, latitude second
- Check if coordinates are swapped

**Script is very slow (>30 minutes)**
- Switch to faster map provider: `map_provider <- "OpenStreetMap"`
- Reduce zoom: `base_map_zoom <- 12`
- Reduce buffer: `buffer_km <- 1.5`
- Set `use_cached_data <- TRUE` after first run

**"Not enough data for heatmaps"**
- Reduce `min_obs_per_cell` (try 2 instead of 3)
- Increase `grid_cell_size_m` (try 750 or 1000)
- Some analyses require minimum observation density

**Figures look wrong or cut off**
- Delete specific figure PNG files to regenerate
- Set `force_rebuild <- TRUE` to regenerate all
- Check that logo file path is correct (or set to "")

**Package installation fails**
- Update R and RStudio to latest versions
- Try manual install: `install.packages("package_name")`
- Check Console for specific error messages

For more help, see the [Troubleshooting section](DATA_DIVE_GUIDE.md#troubleshooting) in the complete guide.

## 📁 Repository Structure

```
.
├── Bioblitz_Data_Dive.R                    # Main analysis script
├── DATA_DIVE_GUIDE.md                      # Comprehensive documentation
├── README.md                               # This file
├── LICENSE.txt                             # GPL v3 license
└── outputs/                                # Generated analyses (created automatically)
    └── data_dive/
        ├── datadive.html                   # HTML slideshow
        ├── datadive.pptx                   # PowerPoint
        ├── slides/                         # Individual figure PNGs
        ├── styles/                         # CSS styling
        ├── obs_cache.rds                   # Cached data
        └── photo_cache/                    # Photo cache
```

## 🔬 Technical Details

### Statistical Methods

**Rarefaction Analysis**
- Individual-based rarefaction (not sample-based)
- 100+ random permutations for confidence intervals
- Interpolation for unsampled points
- Asymptotic richness estimation

**Spatial Analysis**
- Grid-based binning for discrete cells
- IDW interpolation (power = 2) for continuous surfaces
- Distance masking to prevent extrapolation
- Effort correction using observations per cell

**Quality Thresholds**
- Minimum 3 observations per cell for effort-corrected maps
- Cells with 10+ observations marked as "Good" quality
- Rarefaction curves require 100+ observations for reliability

### Performance Optimizations

**Caching Strategy**
- Observation data cached as `.rds`
- Individual figures cached as PNGs
- Only regenerate when source data changes or `force_rebuild = TRUE`
- Can reduce runtime from 30 minutes to 2-5 minutes

**Map Tile Management**
- Automatic tile provider selection
- Zoom level optimization
- Spatial extent buffering
- Efficient tile download and caching

## 🌟 Comparison with Slideshow Generator

This Data Dive script complements the [iNaturalist Bioblitz Slideshow Generator](https://github.com/yourusername/inaturalist-bioblitz-slideshow):

| Feature | Data Dive | Slideshow Generator |
|---------|-----------|-------------------|
| **Purpose** | Statistical analysis | Visual presentation |
| **Output** | Charts, maps, statistics | Photo slideshow |
| **Best for** | Research, reporting | Event displays, outreach |
| **Figures** | 10+ analytical figures | Random photo selection |
| **Format** | HTML + PowerPoint | HTML slideshow |
| **Timing** | One-time or periodic | Daily updates |

**Use both!** The slideshow for public display, the data dive for analysis and reporting.

## 🤝 Contributing

Contributions are welcome! If you've made improvements or have suggestions:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-analysis`)
3. Commit your changes (`git commit -m 'Add amazing analysis'`)
4. Push to the branch (`git push origin feature/amazing-analysis`)
5. Open a Pull Request

## 📄 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE.txt](LICENSE.txt) file for details.

This means you are free to:
- Use the software for any purpose
- Change the software to suit your needs
- Share the software with others
- Share the changes you make

Under the following conditions:
- You must share your modifications under the same GPL v3 license
- You must include the original copyright notice
- You must include a copy of the GPL v3 license

## 👥 Authors

**Olly Berry** and **Claude**

## 🙏 Acknowledgements

- Thanks to all organizers and participants in the **Walpole Wilderness Bioblitzes**
- [iNaturalist](https://www.inaturalist.org/) for providing the API and platform
- The R community for excellent statistical and mapping packages
- [Quarto](https://quarto.org/) and [Reveal.js](https://revealjs.com/) for slideshow capabilities
- Map data providers: Esri, OpenStreetMap, CartoDB
- `officer` package developers for PowerPoint generation

## 📞 Support

- **Documentation**: See [DATA_DIVE_GUIDE.md](DATA_DIVE_GUIDE.md)
- **Issues**: Open an issue on GitHub
- **Questions**: Contact through GitHub discussions

## 🔗 Related Resources

- [iNaturalist Help](https://www.inaturalist.org/pages/help)
- [R Documentation](https://www.r-project.org/help.html)
- [RStudio Documentation](https://support.posit.co/hc/en-us)
- [Quarto Documentation](https://quarto.org/docs/guide/)
- [Spatial Analysis in R](https://r-spatial.org/)

## 📚 Citation

If you use this script in research or publications, please cite:

```
Berry, O., & Claude (2025). iNaturalist Bioblitz Data Dive: 
Comprehensive Analysis Toolkit for Bioblitz Projects. 
GitHub: https://github.com/yourusername/inaturalist-bioblitz-datadive
```

---

**Happy Analyzing!** 📊🔬🌿

*If you create cool analyses with this script, please consider sharing them back with the iNaturalist community!*
