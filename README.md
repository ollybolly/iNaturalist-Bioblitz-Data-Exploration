# 🦘📊 iNaturalist Bioblitz Data Dive

Turn an iNaturalist bioblitz into a statistical story. This R script fetches your project's observations and builds a presentation of charts, maps and spatial analyses, ready as an interactive reveal.js deck or an editable PowerPoint, so you can share the bigger picture with participants and stakeholders.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![R](https://img.shields.io/badge/R-%3E%3D4.0-blue)](https://www.r-project.org/)

---

## ✨ What you get

- **A full analytical deck.** Around a dozen and a half figures covering effort, spatial, temporal and taxonomic patterns.
- **Spatial analyses.** Observation hotspots, and species-richness heatmaps in three flavours: raw count, effort-corrected, and a smooth IDW-interpolated surface.
- **Temporal patterns.** Activity by hour of day, with sunrise and sunset worked out for your location so day and night are shaded correctly.
- **Statistical rigour.** Rarefaction curves with confidence intervals from repeated permutations, overall and per taxon group.
- **Consistent identity.** Shared Wes Anderson palette and PhyloPic taxon silhouettes via `bioblitz_style.R`, matched to the photo Slideshow deck.
- **Two output formats.** An interactive reveal.js HTML deck, and optionally a PowerPoint for manual editing.
- **Fast reruns.** Observations and figures are cached, so repeat runs take minutes.

---

## 🎯 What it does

The script talks to the iNaturalist API and then:

1. Fetches observations for your project within a date window, filtered by quality grade.
2. Builds a satellite base map for the survey area.
3. Generates the analytical figures (see the [figure list](#-the-figures)).
4. Writes a Quarto reveal.js deck that pulls the figures together, with an auto-advancing, loopable slideshow.
5. Renders the deck to HTML, and optionally to PowerPoint.

---

## 📦 Repository contents

```
.
├── Walpole_Bioblitz_Data_Dive_Slideshow_Script_V3.R   # The analysis script
├── bioblitz_style.R                                    # Shared palette + taxon icons (REQUIRED, see below)
├── taxon_icons/                                         # Icon cache, created on first run (shared, safe to keep)
├── README.md                                            # This file
├── DATA_DIVE_GUIDE.md                                   # Full documentation
├── LICENSE.txt                                          # GPL v3
└── outputs/                                             # Created automatically
    └── <project>_data_dive/
        ├── observations_filtered.csv    # Cached observations (speeds up reruns)
        ├── slides/
        │   ├── data_dive_presentation.qmd      # The generated deck
        │   ├── data_dive_presentation.html     # Rendered slideshow (open from here)
        │   ├── data_dive_presentation.pptx     # Optional PowerPoint
        │   ├── fig_*.png                        # All the figures
        │   └── styles/custom.css                # Deck styling
        └── *.gpkg                        # Cached OSM tracks and other spatial layers
```

> ⚠️ **`bioblitz_style.R` must sit in the same folder as the script.** It is loaded on startup for the shared palette and the PhyloPic taxon icons. On the first run it fetches taxon silhouettes from PhyloPic (internet needed once), recolours them and caches them in a `taxon_icons/` folder next to the script. After that it works offline, and the same cache is shared with the photo Slideshow deck. If you keep both projects in one folder, they share a single copy of the style file and its icon cache.

---

## 🚀 Quick start

### 1. Put the files together

Keep `Walpole_Bioblitz_Data_Dive_Slideshow_Script_V3.R` and `bioblitz_style.R` in the same folder. Open the script in RStudio and set that folder as the working directory (Session, Set Working Directory, To Source File Location) so the relative `source("bioblitz_style.R")` resolves.

### 2. Configure your bioblitz

Edit the settings near the top of the script:

```r
project_slug   <- "your-project-slug"          # from your iNaturalist project URL
bioblitz_name  <- "Your Bioblitz"               # shown on the title slide
date_min       <- as.Date("2025-10-04")         # first day of your event
date_max       <- as.Date("2025-10-05")         # last day
hq_lon         <- 116.634398                     # headquarters longitude
hq_lat         <- -34.992854                     # headquarters latitude
bioblitz_logo  <- "your-logo.jpg"                # in the same folder, or "" for none
quality_grades <- c("research", "needs_id")      # which observations to include
out_dir        <- "outputs/your_project_data_dive"
```

The title slide reads `bioblitz_name` and the year (taken from your dates), so it rebrands itself automatically. See [The title slide](#the-title-slide) below.

### 3. Run it

Click **Source** in RStudio (or `Ctrl+Shift+S` / `Cmd+Shift+S`), or run:

```bash
Rscript Walpole_Bioblitz_Data_Dive_Slideshow_Script_V3.R
```

Run it from the script's folder so `bioblitz_style.R` is found. The first run takes roughly 15 to 30 minutes (packages, data, maps and figures). Later runs are much quicker thanks to caching.

### 4. View your deck

Open `outputs/<project>_data_dive/slides/data_dive_presentation.html` in a browser. Press **F** for fullscreen, **Space** or the arrow keys to move, **S** for speaker view, **Esc** to exit. If you enabled PowerPoint, open `data_dive_presentation.pptx` in PowerPoint or Google Slides.

---

## 📋 Prerequisites

**Software**

- **R** 4.0 or newer. https://cran.r-project.org/
- **RStudio Desktop.** https://posit.co/download/rstudio-desktop/
- **Quarto.** https://quarto.org/ Needed to render the deck. RStudio bundles a copy; if rendering fails, install Quarto and the `quarto` R package.

**R packages** (installed automatically on first run)

Core and data: `httr2`, `jsonlite`, `dplyr`, `tidyr`, `purrr`, `stringr`, `lubridate`, `janitor`, `glue`, `readr`, `tibble`, `forcats`. Maps and spatial: `sf`, `maptiles`, `terra`, `tidyterra`, `osmdata`, `ggspatial`, `stars`. Plotting: `ggplot2`, `scales`, `viridis`, `patchwork`, `cowplot`, `treemapify`, `ggimage`, `magick`, `rsvg`. Analysis: `suncalc`. Palette and icons: `wesanderson`, `ggtext`, `rphylopic`, `png`. Rendering: `quarto`.

First-time installation can take 15 to 20 minutes. You only do it once.

**Your bioblitz information**

- **Project slug**, the part of the project URL after `/projects/`.
- **Event dates** as `as.Date("YYYY-MM-DD")`.
- **HQ coordinates** from Google Maps (right-click, copy).
- Optionally a **logo** (JPG or PNG).

---

## 📊 The figures

The deck assembles these, all saved as PNGs in the `slides/` folder:

- **Summary with photos** : headline counts (observations, species, observers, quality grades) with a photo collage.
- **Observation hotspots** : where people recorded, jittered to reduce overplotting, coloured by taxon, with an all-taxa version and a plants-excluded version.
- **Observations by taxon** : a treemap (or bar chart) of the taxonomic mix.
- **Top observers** : the biggest contributors.
- **Observations by hour** : activity across the day with day and night shaded, plus a stacked-by-taxon version.
- **Species richness heatmaps** : raw richness, effort-corrected richness (species per observation), and a smooth IDW-interpolated surface masked to the sampled area.
- **Rarefaction curves** : species accumulation with confidence intervals, for all taxa and by group.
- **Species rank abundance** : the most-recorded species, annotated, with a plants-excluded version.
- **Species tiers** : a photo grid of representative species.
- **Environmental module** : distance-to-track (a proxy for sampling effort) and a rank-abundance view.
- **Chart collage** : a montage of the key charts.

---

## 🎛️ Key settings at a glance

| Setting | Meaning | Default |
|---|---|---|
| `project_slug` | iNaturalist project identifier | (required) |
| `bioblitz_name` | Name on the title slide | Walpole Wilderness Bioblitz |
| `bioblitz_year` | Year on the title slide | from `date_min` |
| `date_min` / `date_max` | Event window | 2025-10-04 / 2025-10-05 |
| `hq_lon` / `hq_lat` | Headquarters coordinates | 116.634398 / -34.992854 |
| `quality_grades` | Observation grades to include | research, needs_id |
| `base_map_zoom` | Satellite base map zoom | 14 |
| `buffer_km` | Map extent around observations | 2.5 |
| `force_rebuild` | Regenerate all figures | TRUE |
| `use_cached_data` | Reuse the cached observations | TRUE |
| `render_html` / `render_powerpoint` | Output formats | TRUE / FALSE |
| `auto_advance_ms` | Slide auto-advance (ms) | 15000 |
| `fig2_use_treemap` | Treemap vs bar for taxa | TRUE |
| `n_top_observers` | Observers shown | 15 |
| `grid_cell_size_m` | Heatmap grid resolution (m) | 500 |
| `n_permutations` | Rarefaction permutations | 100 |

The full reference, including the interpolation, rarefaction and figure-sizing options, is in [DATA_DIVE_GUIDE.md](DATA_DIVE_GUIDE.md).

---

## 🗂️ About the output

The rendered HTML **references its figures and CSS by relative path**, so it is not a single self-contained file.

- **Open `data_dive_presentation.html` from inside the `slides/` folder.** Moving it on its own will break the figures.
- **To share it, keep the `slides/` folder together** (zip it), or use the PowerPoint, which is a single portable file.

The cache files (`observations_filtered.csv`, the `.gpkg` spatial layers, and the figure PNGs) make reruns fast. Keep them unless you want a full refresh.

---

## 🔁 The title slide

The title slide builds itself from two settings near the top of the script:

```r
bioblitz_name <- "Walpole Wilderness Bioblitz"   # your bioblitz name
bioblitz_year <- format(date_min, "%Y")           # auto from your event dates, or set e.g. "2025"
```

The text-only title slide then reads, for example, "Walpole Wilderness Bioblitz 2025". If you provide a logo, the welcome slide shows your logo instead, with the date range beneath it, so it is already branded for your event. The map projection also adapts to your HQ location automatically, so nothing is tied to the original Walpole run.

---

## 🛠️ Troubleshooting quick hits

- **The run stops with a `bioblitz_style.R` not found error.** Put `bioblitz_style.R` in the same folder as the script and run from that folder.
- **A figure did not update after a change.** Figures are cached as PNGs. Delete the specific file (for example `fig_species_tiers.png`) or set `force_rebuild <- TRUE`, then run again.
- **Rendering fails.** Install Quarto (https://quarto.org/) and the `quarto` R package. You can also render by hand: `quarto render outputs/<project>_data_dive/slides/data_dive_presentation.qmd`.
- **No observations found.** Check the project slug, and confirm the date window covers your event.
- **Map shows the wrong area.** Check `hq_lon` and `hq_lat`, and that you have not swapped longitude and latitude.
- **Not enough data for heatmaps.** Lower `min_obs_per_cell`, or raise `grid_cell_size_m`.

Full troubleshooting is in the [guide](DATA_DIVE_GUIDE.md#troubleshooting).

---

## 🌟 Companion: the photo Slideshow deck

This Data Dive pairs with the [iNaturalist Bioblitz Slideshow Generator](https://github.com/ollybolly/iNaturalist_Bioblitz_photo_presentations), which builds a photo-and-map slideshow from the same project. Both share `bioblitz_style.R`, so the two decks use identical taxon colours and icons.

| | Data Dive | Photo Slideshow |
|---|---|---|
| Purpose | Analysis and reporting | Visual celebration |
| Output | Charts, maps, statistics | Photo slideshow |
| Format | HTML and PowerPoint | HTML |
| Best for | Wrap-up reports, insights | Event displays, outreach |

Use both: the slideshow for public display, the data dive for the numbers behind it.

---

## 📄 License

Licensed under the GNU General Public License v3.0. See [LICENSE.txt](LICENSE.txt). You are free to use, change and share the software and your changes, provided you share modifications under the same licence and keep the original notices.

---

## 👥 Authors and acknowledgements

**Olly Berry** and **Claude**.

With thanks to the organisers and participants of the **Walpole Wilderness Bioblitzes**, to [iNaturalist](https://www.inaturalist.org/) for the API, to [PhyloPic](https://www.phylopic.org/) for the silhouettes, to [Quarto](https://quarto.org/) and [reveal.js](https://revealjs.com/) for the deck, to the map data providers (Esri, OpenStreetMap), and to the R spatial and statistics communities.

---

**Happy analysing.** 📊🔬🌿 If you produce something worth sharing, consider giving it back to the iNaturalist community.
