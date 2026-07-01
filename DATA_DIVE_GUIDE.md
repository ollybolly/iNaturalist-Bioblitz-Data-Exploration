# iNaturalist Bioblitz Data Dive
## Complete Guide

**Version 3**

---

## Table of contents

1. [Introduction](#introduction)
2. [What the script produces](#what-the-script-produces)
3. [Prerequisites](#prerequisites)
4. [The companion style file](#the-companion-style-file)
5. [Setup and configuration](#setup-and-configuration)
6. [Running the script](#running-the-script)
7. [Configuration reference](#configuration-reference)
8. [The figures explained](#the-figures-explained)
9. [Output files](#output-files)
10. [Reruns and the figure cache](#reruns-and-the-figure-cache)
11. [Performance](#performance)
12. [Troubleshooting](#troubleshooting)
13. [Tips and best practices](#tips-and-best-practices)
14. [Companion: the photo Slideshow deck](#companion-the-photo-slideshow-deck)

---

## Introduction

The Data Dive script builds an analytical presentation from an iNaturalist bioblitz project. It fetches your observations, produces a set of charts, maps and spatial analyses, and assembles them into a Quarto reveal.js deck, with an optional PowerPoint. It works for any project once you set a few values at the top of the script.

It is the analytical companion to the photo Slideshow deck. Where the Slideshow celebrates individual finds, the Data Dive tells the quantitative story: how much was recorded, by whom, where, when, and how completely.

**What changed in version 3**

- The script now loads the shared `bioblitz_style.R` for the palette and PhyloPic taxon icons, so its colours and icons match the photo deck. That file must sit next to the script.
- Maps use a satellite base map controlled by `base_map_zoom` and `buffer_km`. The old `map_provider` option is gone.
- Rendering is done by Quarto (HTML and PowerPoint both come from `quarto::quarto_render`). PowerPoint is off by default.
- New figures were added: species tiers, species rank abundance (with a plants-excluded view), an environmental module (distance to track and rank abundance), stacked observations by hour, and a chart collage.
- Reveal.js playback settings were added (`auto_advance_ms`, `auto_slide_stoppable`, `slideshow_loop`).
- The title slide and the map projection now build from your settings and HQ location, so the deck rebrands and reprojects itself for any bioblitz.

---

## What the script produces

Working from your project data, the script generates these analyses. Each becomes a figure in the deck (see [The figures explained](#the-figures-explained)):

- Headline summary with a photo collage.
- Observation hotspots (all taxa, and a plants-excluded view).
- Taxonomic breakdown as a treemap or bar chart.
- Top observers.
- Activity by hour of day, with day and night shaded, and a stacked-by-taxon view.
- Species richness heatmaps: raw, effort-corrected, and IDW-interpolated.
- Rarefaction curves for all taxa and by group.
- Species rank abundance, annotated, with a plants-excluded view.
- A species tiers photo grid.
- An environmental module: distance to track and rank abundance.
- A chart collage.

Outputs are a reveal.js HTML deck and, optionally, a PowerPoint.

---

## Prerequisites

### Software

1. **R** 4.0 or newer. https://cran.r-project.org/
2. **RStudio Desktop.** https://posit.co/download/rstudio-desktop/
3. **Quarto.** https://quarto.org/ Needed to render the deck. RStudio ships with a copy; if rendering fails, install Quarto and the `quarto` R package.

### R packages (installed automatically on first run)

- **Core and data:** `httr2`, `jsonlite`, `dplyr`, `tidyr`, `purrr`, `stringr`, `lubridate`, `janitor`, `glue`, `readr`, `tibble`, `forcats`
- **Maps and spatial:** `sf`, `maptiles`, `terra`, `tidyterra`, `osmdata`, `ggspatial`, `stars`
- **Plotting:** `ggplot2`, `scales`, `viridis`, `patchwork`, `cowplot`, `treemapify`, `ggimage`, `magick`, `rsvg`
- **Analysis:** `suncalc`
- **Palette and taxon icons:** `wesanderson`, `ggtext`, `rphylopic`, `png`
- **Rendering:** `quarto`

First-time installation can take 15 to 20 minutes.

### Your bioblitz information

- **Project slug**, from the project URL after `/projects/`.
- **Event dates**, as `as.Date("YYYY-MM-DD")`.
- **HQ coordinates**, from Google Maps (right-click and copy). Longitude first, latitude second.
- Optionally a **logo** (JPG or PNG).

---

## The companion style file

Version 3 loads `bioblitz_style.R` on startup for the shared Wes Anderson palette and the PhyloPic taxon-icon helpers. **It must be in the same folder as the script.**

If you ever see an error about `bioblitz_style.R` not being found, this is the cause. Put the file next to the script and run from that folder.

### Where to put everything

The simplest setup is one folder containing the script and the style file. If you also run the photo Slideshow deck, keeping everything together lets both decks share a single style file and icon cache:

```
your-project-folder/
├── Walpole_Bioblitz_Data_Dive_Slideshow_Script_V3.R
├── bioblitz_style.R
├── taxon_icons/            # created automatically on first run
└── outputs/               # created automatically
```

### The taxon icon cache

On the first run, the style file fetches taxon silhouettes from PhyloPic (internet needed once), recolours them to the palette, and caches them in a `taxon_icons/` folder created **next to the script**, not inside the output folder. After that it works offline, and the cache is shared with the photo deck.

### Using your own taxon icons

Drop a PNG named after the iconic taxon, in lowercase letters only, into `taxon_icons/`, and it is used as-is. Recognised names include `plantae.png`, `aves.png`, `insecta.png`, `mammalia.png`, `actinopterygii.png`, `amphibia.png`, `reptilia.png`, `fungi.png`, `arachnida.png`, `mollusca.png`, `animalia.png`, `chromista.png` and `protozoa.png`.

### Changing the palette

The taxon colours come from the `taxon_cols` vector at the top of `bioblitz_style.R`. Edit a colour there and it flows through to every chart, map legend and icon. After a palette change, delete the cached icons (or set the icon rebuild flag in the style file) so the silhouettes are re-tinted.

---

## Setup and configuration

Open the script in RStudio and set the working directory to its folder (Session, Set Working Directory, To Source File Location). Then edit the settings near the top.

### Essential settings

```r
project_slug   <- "your-project-slug"          # from your iNaturalist project URL
bioblitz_name  <- "Your Bioblitz"               # shown on the title slide
date_min       <- as.Date("2025-10-04")         # first day of the event
date_max       <- as.Date("2025-10-05")         # last day
hq_lon         <- 116.634398                     # headquarters longitude
hq_lat         <- -34.992854                     # headquarters latitude
bioblitz_logo  <- "your-logo.jpg"                # same folder, or "" for none
quality_grades <- c("research", "needs_id")      # observation grades to include
out_dir        <- "outputs/your_project_data_dive"
```

**Finding your project slug.** On your iNaturalist project page, copy everything after `/projects/` in the URL.

**Finding your coordinates.** Right-click your HQ in Google Maps and copy the numbers. Longitude is the first, latitude the second.

**Event dates.** Use `as.Date("YYYY-MM-DD")`. For a multi-day event, set `date_min` to the first day and `date_max` to the last.

### The title slide

The title slide reads two settings near the top of the script:

```r
bioblitz_name <- "Walpole Wilderness Bioblitz"   # your bioblitz name
bioblitz_year <- format(date_min, "%Y")           # auto from your event dates, or set e.g. "2025"
```

The text-only title slide then reads "Walpole Wilderness Bioblitz 2025", or your own name and year. If you supply a logo, the welcome slide uses the logo with the date range beneath it instead, so it is branded for your event either way. The map projection also derives from your HQ location, so the deck is not tied to the original Walpole run.

---

## Running the script

**In RStudio.** Click **Source** at the top right, or press `Ctrl+Shift+S` (Windows and Linux) or `Cmd+Shift+S` (Mac). Progress prints to the console. Watch for the section markers and the final completion message.

**From a terminal.**

```bash
Rscript Walpole_Bioblitz_Data_Dive_Slideshow_Script_V3.R
```

Run it from the script's folder so `bioblitz_style.R` and the relative output path resolve.

**Timing.** The first run takes roughly 15 to 30 minutes: installing packages, downloading data, building the base map and OSM layers, and rendering more than a dozen figures. Later runs are much faster because observations, spatial layers and figures are cached.

**Viewing.** Open `outputs/<project>_data_dive/slides/data_dive_presentation.html` in a browser. Press **F** for fullscreen, **Space** or the arrow keys to move, **S** for speaker view, **Esc** to exit. If you enabled PowerPoint, open the `.pptx` in PowerPoint or Google Slides.

---

## Configuration reference

### Project and data

| Parameter | Meaning | Default |
|---|---|---|
| `project_slug` | iNaturalist project identifier | (required) |
| `bioblitz_name` | Name on the title slide | Walpole Wilderness Bioblitz |
| `bioblitz_year` | Year on the title slide | from `date_min` |
| `date_min` / `date_max` | Event window | 2025-10-04 / 2025-10-05 |
| `hq_lon` / `hq_lat` | Headquarters coordinates | 116.634398 / -34.992854 |
| `quality_grades` | Grades to include | c("research", "needs_id") |
| `bioblitz_logo` | Logo file, or "" | Walpole-Wilderness-bioblitz.jpg |
| `out_dir` | Output folder | outputs/..._data_dive |

### Maps

| Parameter | Meaning | Default |
|---|---|---|
| `base_map_zoom` | Satellite base map zoom (13 to 15) | 14 |
| `buffer_km` | Map extent around observations (km) | 2.5 |

The base map is satellite imagery. There is no `map_provider` setting in this version.

### Run mode, caching and output

| Parameter | Meaning | Default |
|---|---|---|
| `force_rebuild` | Regenerate all figures even if cached | TRUE |
| `use_cached_data` | Reuse the cached observations | TRUE |
| `render_html` | Render the reveal.js HTML deck | TRUE |
| `render_powerpoint` | Render a PowerPoint | FALSE |

### Slideshow playback (reveal.js)

| Parameter | Meaning | Default |
|---|---|---|
| `auto_advance_ms` | Auto-advance time (ms, 0 disables) | 15000 |
| `auto_slide_stoppable` | Let the viewer pause auto-advance | TRUE |
| `slideshow_loop` | Loop at the end | TRUE |

### Chart and slide sizing

| Parameter | Meaning | Default |
|---|---|---|
| `fig2_use_treemap` | Treemap vs bar for taxa | TRUE |
| `n_top_observers` | Observers shown | 15 |
| `plot_title_size` / `plot_subtitle_size` | Chart title and subtitle (pt) | 34 / 22 |
| `map_fig_width` / `map_fig_height` | Map figure size (in) | 15 / 10 |
| `chart_fig_width` / `chart_fig_height` | Chart figure size (in) | 12 / 8 |
| `legend_text_size` / `legend_title_size` | Legend text and title (pt) | 22 / 26 |
| `axis_text_size` / `axis_title_size` | Axis text and title (pt) | 26 / 30 |
| `chart_base_size` | Base font for the chart theme (pt) | 28 |
| `legend_ncol` | Legend columns on taxa maps | 2 |
| `slide_title_size` / `slide_subtitle_size` | Slide heading and subheading (px) | 88 / 44 |

### Richness heatmaps

| Parameter | Meaning | Default |
|---|---|---|
| `grid_cell_size_m` | Grid resolution (m) | 500 |
| `rank_level` | Taxonomic rank to count | species |
| `min_obs_per_cell` | Minimum observations per cell (effort-corrected) | 3 |
| `warn_obs_per_cell` | Threshold for "Good" vs "Fair" quality | 10 |
| `use_interpolation` | Build the smooth IDW surface | TRUE |
| `interp_buffer_m` | Local richness buffer around each point (m) | 250 |
| `interp_resolution` | Interpolation grid resolution (m) | 50 |
| `idw_power` | IDW power parameter | 2 |
| `mask_distance_m` | Maximum distance from observations to show (m) | 300 |

### Rarefaction

| Parameter | Meaning | Default |
|---|---|---|
| `n_permutations` | Random orderings for the curve | 100 |
| `step_size` | Sample every N observations | 10 |
| `rarefaction_rank_level` | Rank for accumulation | species |
| `min_obs_reliable` | Threshold for a "Reliable" designation | 200 |
| `min_obs_warning` | Warn below this many observations | 100 |

---

## The figures explained

### Effort and summary

- **Summary with photos** (`fig_summary_with_photos.png`). Headline counts: observations, species, observers and quality grades, with a photo collage.
- **Top observers** (`fig_top_observers.png`). The biggest contributors, up to `n_top_observers`.
- **Chart collage** (`fig_chart_collage.png`). A montage of the key charts for a single overview slide.

### Spatial

- **Observation hotspots** (`fig_observation_hotspots_jittered.png`, and `fig_observation_hotspots_no_plants.png`). Where observations fell, jittered to reduce overplotting, coloured by taxon. The second view drops plants, which often dominate, so animal patterns are easier to see.
- **Species richness heatmaps.** Three complementary views:
  - **Raw** (`fig_richness_raw.png`): total species per grid cell, an absolute view of hotspots.
  - **Effort-corrected** (`fig_richness_effort_corrected.png`): species per observation, which accounts for uneven sampling. Only cells with at least `min_obs_per_cell` observations are shown.
  - **Interpolated** (`fig_richness_interpolated.png`): a smooth IDW surface, masked to within `mask_distance_m` of the data so it does not extrapolate into unsampled ground.

### Temporal

- **Observations by hour** (`fig_observations_by_hour.png`, and `fig_observations_by_hour_stacked.png`). Activity across the day, with night shaded using sunrise and sunset for your location. The stacked version splits each hour by taxon.

### Taxonomic and species

- **Observations by taxon** (`fig_observations_by_taxon.png`). A treemap (or bar chart) of the taxonomic mix.
- **Species rank abundance** (`fig_species_rank_annotated.png`, and `fig_species_rank_annotated_no_plants.png`). The most-recorded species, ranked and annotated, with a plants-excluded view.
- **Species tiers** (`fig_species_tiers.png`). A photo grid of representative species.

### Sampling completeness

- **Rarefaction curves** (`fig_rarefaction_all_taxa.png`, and `fig_rarefaction_by_group.png`). Species accumulation against effort, with confidence intervals from `n_permutations` orderings. A steep curve means many species remain unfound; a flattening curve means most were captured. The by-group version compares taxa.

### Environmental module

- **Distance to track** (`fig_env_distance_track.png`). How observations sit relative to tracks and paths, a proxy for where sampling effort was concentrated.
- **Rank abundance** (`fig_env_rank_abundance.png`). An abundance-ordered view for the environmental context.

---

## Output files

Everything is written under `outputs/<project>_data_dive/`:

- `observations_filtered.csv` : the cached observations. Reused on later runs unless you turn caching off.
- `slides/` : the generated deck and its assets.
  - `data_dive_presentation.qmd` : the Quarto source.
  - `data_dive_presentation.html` : the rendered reveal.js deck.
  - `data_dive_presentation.pptx` : the PowerPoint, if you enabled it.
  - `fig_*.png` : all the figures.
  - `styles/custom.css` : the deck styling.
- `*.gpkg` : cached OSM tracks and other spatial layers.

### The HTML is not self-contained

The rendered deck references its figures and CSS by relative path.

- **Open `data_dive_presentation.html` from inside the `slides/` folder.** Moving it on its own breaks the figures.
- **To share it, zip the whole `slides/` folder** so the figures and styling travel with it. Or enable and send the PowerPoint, which is a single portable file.

---

## Reruns and the figure cache

Figures are cached as PNGs so reruns are quick. The trade-off is that a change will not appear until the cached image is refreshed.

- To refresh **one** figure, delete its PNG (for example `fig_species_tiers.png`) and run again. Only that figure is rebuilt.
- To refresh **everything**, set `force_rebuild <- TRUE`.
- Observations are cached separately in `observations_filtered.csv`. Set `use_cached_data <- FALSE` to fetch fresh data from iNaturalist.

The species tiers figure in particular is worth remembering here: if you adjust its photo-grid layout and the slide looks unchanged, delete `fig_species_tiers.png` before re-rendering so the new layout is picked up.

---

## Performance

The slowest steps are the base map, the OSM layers and the interpolation. To speed a run up:

- Lower `base_map_zoom` to 12 or 13, and reduce `buffer_km`, for fewer and smaller map tiles.
- Set `use_interpolation <- FALSE` to skip the smooth richness surface.
- Reduce `n_permutations` (try 50) for faster rarefaction, at the cost of slightly rougher confidence bands.
- Raise `grid_cell_size_m` (try 750 or 1000) so the heatmaps have fewer cells to compute.
- Keep `use_cached_data <- TRUE` after the first run so data is not re-fetched.

---

## Troubleshooting

### The run stops with a `bioblitz_style.R` not found error

Put `bioblitz_style.R` in the same folder as the script, and run from that folder so the relative `source()` resolves.

### A figure did not update after a change

Figures are cached. Delete the specific PNG (for example `fig_species_tiers.png`) or set `force_rebuild <- TRUE`, then run again.

### Rendering fails

Install Quarto (https://quarto.org/) and the `quarto` R package. You can render the deck by hand:

```bash
quarto render outputs/<project>_data_dive/slides/data_dive_presentation.qmd
```

Add `--to pptx` for the PowerPoint.

### No observations found

Check the project slug is exact, and that `date_min` and `date_max` cover your event. Confirm the project has observations in the chosen quality grades.

### Map shows the wrong area

Verify `hq_lon` and `hq_lat`, and that you have not swapped longitude and latitude (longitude first).

### Not enough data for heatmaps

Lower `min_obs_per_cell` (try 2), or raise `grid_cell_size_m` (try 750 or 1000). Sparse data needs larger cells.

### Package installation fails

Update R and RStudio, then install the named package by hand with `install.packages("package_name")` and read the console for the specific error.

---

## Tips and best practices

- **Test small first.** Point at a small project or a short date window to check your coordinates and settings before a full run.
- **Check the HQ marker.** It is the quickest way to confirm your coordinates are the right way round.
- **HTML for viewing, PowerPoint for editing.** Present from the HTML deck; enable the PowerPoint when you want to add slides or tweak wording by hand.
- **Keep the caches.** They cut reruns from half an hour to a few minutes. Only clear them for a deliberate full refresh.
- **Match the two decks.** Because both the Data Dive and the photo Slideshow load the same `bioblitz_style.R`, editing the palette once updates both.

---

## Companion: the photo Slideshow deck

This Data Dive pairs with the [iNaturalist Bioblitz Slideshow Generator](https://github.com/ollybolly/iNaturalist_Bioblitz_photo_presentations), which builds a photo-and-map slideshow from the same project and shares the same style file.

| | Data Dive | Photo Slideshow |
|---|---|---|
| Purpose | Analysis and reporting | Visual celebration |
| Output | Charts, maps, statistics | Photo slideshow |
| Format | HTML and PowerPoint | HTML |
| Best for | Wrap-up reports, insights | Event displays, outreach |

Use both: the slideshow for public display, the data dive for the numbers behind it.

---

**Happy analysing.** 📊🔬🌿

---

*Version 3*
