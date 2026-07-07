# iNaturalist Bioblitz Data Dive
## Complete Guide

**Version 4**

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
9. [Contributor awards](#contributor-awards)
10. [Output files](#output-files)
11. [Reruns and the caches](#reruns-and-the-caches)
12. [Performance](#performance)
13. [Troubleshooting](#troubleshooting)
14. [Tips and best practices](#tips-and-best-practices)
15. [Companion: the photo Slideshow deck](#companion-the-photo-slideshow-deck)

---

## Introduction

The Data Dive script builds an analytical presentation from an iNaturalist bioblitz project. It fetches your observations, produces a set of charts, maps, spatial analyses and contributor awards, and assembles them into a Quarto reveal.js deck, with an optional PowerPoint. It works for any project once you set a few values at the top of the script.

It is the analytical companion to the photo Slideshow deck. Where the Slideshow celebrates individual finds, the Data Dive tells the quantitative story: how much was recorded, by whom, where, when, and how completely.

**What changed in version 4**

- **Contributor awards.** A new section builds top-three podium slides (gold, silver, bronze) for a roster of categories, each with the observer's profile photo. See [Contributor awards](#contributor-awards).
- **Hotspot close-ups.** The script now finds the densest observation clusters and renders zoom-in slides for them, captioned with the window size and observation count.
- **A persistent map cache.** Satellite tiles now cache to `base_map_cache/` and survive figure rebuilds, so rebuilding the slides no longer re-downloads them. New flags `force_refetch_maps` and `force_refetch_photos` let you force a refresh when the data has actually changed.
- **Named OSM caches.** The road, track and water layers cache to `osm_roads.gpkg`, `osm_tracks.gpkg` and `osm_water.gpkg`, with `.none` marker files for layers that returned nothing.
- **PowerPoint restyle.** When you render a PowerPoint, an embedded Python step restyles it to full-bleed navy so it matches the HTML. It needs `python-pptx` and is skipped gracefully if that is absent.
- **Photo caching and variety.** Species, observer and award photos cache under `slides/`. `vary_summary_photos` controls whether the summary border reshuffles between runs or stays reproducible.

Everything from version 3 carries over: the shared `bioblitz_style.R` palette and PhyloPic icons, the satellite base map, Quarto rendering, the expanded figure set, the reveal.js playback settings, and the self-rebranding title slide and map projection.

---

## What the script produces

Working from your project data, the script generates these analyses. Each becomes a figure or a slide in the deck (see [The figures explained](#the-figures-explained)):

- Headline summary with a photo collage.
- Observation hotspots (all taxa, and a plants-excluded view).
- Hotspot close-ups on the densest clusters.
- Taxonomic breakdown as a treemap or bar chart.
- Top observers.
- Activity by hour of day, with day and night shaded, and a stacked-by-taxon view.
- Species richness heatmaps: raw, effort-corrected, and IDW-interpolated.
- Rarefaction curves for all taxa and by group.
- Species rank abundance, annotated, with a plants-excluded view.
- A species tiers photo grid.
- An environmental module: distance to track and rank abundance.
- Contributor awards, one podium slide per category.
- A chart collage.

Outputs are a reveal.js HTML deck and, optionally, a PowerPoint.

---

## Prerequisites

### Software

1. **R** 4.0 or newer. https://cran.r-project.org/
2. **RStudio Desktop.** https://posit.co/download/rstudio-desktop/
3. **Quarto.** https://quarto.org/ Needed to render the deck. RStudio ships with a copy. The script also needs the `quarto` R package, which it does **not** install for you, so run `install.packages("quarto")` once if rendering reports it is missing.
4. **Optional: Python 3 with `python-pptx`.** Used only to restyle the PowerPoint to full-bleed navy. Install with `pip install python-pptx`. Without it, the PowerPoint still renders, just without the restyle.

### R packages (installed automatically on first run)

- **Core and data:** `httr2`, `jsonlite`, `dplyr`, `tidyr`, `purrr`, `stringr`, `lubridate`, `janitor`, `glue`, `readr`, `tibble`, `forcats`
- **Maps and spatial:** `sf`, `maptiles`, `terra`, `tidyterra`, `osmdata`, `ggspatial`, `stars`
- **Plotting:** `ggplot2`, `scales`, `viridis`, `patchwork`, `cowplot`, `treemapify`, `ggimage`, `magick`, `rsvg`
- **Analysis:** `suncalc`
- **Palette and taxon icons:** `wesanderson`, `ggtext`, `rphylopic`, `png`

The `quarto` R package is handled separately and is not in the auto-install list, so install it by hand if the render step reports it missing. First-time installation of the rest can take 15 to 20 minutes.

### Your bioblitz information

- **Project slug**, from the project URL after `/projects/`.
- **Event dates**, as `as.Date("YYYY-MM-DD")`.
- **HQ coordinates**, from Google Maps (right-click and copy). Longitude first, latitude second.
- Optionally a **logo** (JPG or PNG).

---

## The companion style file

The script loads `bioblitz_style.R` on startup for the shared Wes Anderson palette and the PhyloPic taxon-icon helpers. **It must be in the same folder as the script.**

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

Open the script in RStudio and set the working directory to its folder (Session, Set Working Directory, To Source File Location). When run in RStudio the script also anchors the working directory to its own location, so the relative `source()` and output paths resolve either way. Then edit the settings near the top.

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
```

The output folder is derived from `project_slug`, so you do not set it by hand and different bioblitzes never share a cache.

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

**Timing.** The first run takes roughly 15 to 30 minutes: installing packages, downloading data and photos, building the base map and OSM layers, and rendering the figures, close-ups and award podiums. Later runs are much faster because observations, spatial layers, photos and figures are all cached.

**Viewing.** Open `outputs/<project>_data_dive/slides/data_dive_presentation.html` in a browser. Press **F** for fullscreen, **Space** or the arrow keys to move, **S** for speaker view, **A** to pause auto-advance, **Esc** to exit. If you enabled PowerPoint, open the `.pptx` in PowerPoint or Google Slides.

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

The output folder is derived from `project_slug` and is not set directly.

### Maps

| Parameter | Meaning | Default |
|---|---|---|
| `base_map_zoom` | Satellite base map zoom (13 to 15) | 14 |
| `buffer_km` | Map extent around observations (km) | 2.5 |

The base map is Esri satellite imagery. There is no `map_provider` setting in this version.

### Run mode, caching and output

| Parameter | Meaning | Default |
|---|---|---|
| `force_rebuild` | Regenerate all figures even if cached | TRUE |
| `use_cached_data` | Reuse the cached observations | TRUE |
| `force_refetch_maps` | Re-download satellite tiles and OSM layers | FALSE |
| `force_refetch_photos` | Re-download species, observer and award photos | FALSE |
| `vary_summary_photos` | Reshuffle the summary border photos each run | TRUE |
| `render_html` | Render the reveal.js HTML deck | TRUE |
| `render_powerpoint` | Render a PowerPoint | FALSE |

`force_refetch_maps` and `force_refetch_photos` are independent of `force_rebuild`, so a figure rebuild reuses the cached tiles and photos unless you turn these on. Set `vary_summary_photos <- FALSE` for a fixed, reproducible border (seed 123).

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

### Hotspot close-ups

These live in the Figure 1C block, not the top configuration:

| Parameter | Meaning | Default |
|---|---|---|
| `zoom_enable` | Build the hotspot close-ups | TRUE |
| `zoom_window_m` | Close-up window side length (m) | 800 |
| `n_zooms` | How many close-ups to show | 3 |
| `zoom_min_sep_m` | Minimum spacing between chosen windows (m) | 1200 |
| `zoom_min_obs` | Minimum observations in a window to qualify | 20 |

### Contributor awards

These live in the awards block near the end of the script:

| Parameter | Meaning | Default |
|---|---|---|
| `include_awards` | Build the awards section | TRUE |
| `award_min_obs` | Minimum observations to be eligible | 5 |
| `award_ids` | Which award categories to include | all defined |

---

## The figures explained

### Effort and summary

- **Summary with photos** (`fig_summary_with_photos.png`). Headline counts: observations, species, observers and quality grades, with a photo collage border. `vary_summary_photos` controls whether the border photos reshuffle between runs.
- **Top observers** (`fig_top_observers.png`). The biggest contributors, up to `n_top_observers`.
- **Chart collage** (`fig_chart_collage.png`). A montage of the key charts for a single overview slide.

### Spatial

- **Observation hotspots** (`fig_observation_hotspots_jittered.png`, and `fig_observation_hotspots_no_plants.png`). Where observations fell, jittered to reduce overplotting, coloured by taxon. The second view drops plants, which often dominate, so animal patterns are easier to see.
- **Hotspot close-ups** (`fig_zoom_1.png`, `fig_zoom_2.png`, ...). The script grids the observations, picks the densest windows (kept `zoom_min_sep_m` apart so they are distinct hotspots), and renders a high-zoom satellite close-up of each, captioned with its window size and observation count. Controlled by the settings in the Figure 1C block.
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

## Contributor awards

The awards section (set `include_awards <- TRUE`) builds a podium slide for each category that has data. Each slide shows the top three contributors as a gold, silver and bronze podium, with the observer's iNaturalist profile photo (or a random taxon silhouette if they have none). A contributor must have at least `award_min_obs` observations to be eligible. The podium PNGs are saved as `award_<id>.png` in the `slides/` folder, and profile photos cache under `slides/award_photos/`.

The standard categories are:

- **Most Observations** : the biggest contributors overall.
- **Most Diverse** : the most different species recorded.
- **Jack of All Trades** : recorded across the most groups of life.
- **The Specialist** : the highest share of records in one group.
- **The Completist** : the most records of a single species.
- **The Explorer** : the observation furthest from HQ.
- **Ground Covered** : the widest spread of observations.
- **Night Owl** : the most observations after dark.
- **Early Bird** : the most observations around dawn.
- **Power Hour** : the most observations in one half-hour.
- **Rarest Finds** : the most conservation-listed species.
- **The Marathon** : the most observations in a single day.
- **Gold Standard** : the most research-grade observations.

On top of these, a per-group **champion** award is added for each iconic taxon present in the data, for example Most Plants, Most Birds, Most Insects, Most Spiders, Most Fungi, Most Molluscs, Most Reptiles, Most Amphibians, Most Mammals and Most Fish. Groups with no records are skipped.

To trim the list once you have picked favourites, edit `award_ids` (it defaults to every category defined). To drop the section entirely, set `include_awards <- FALSE`.

---

## Output files

Everything is written under `outputs/<project>_data_dive/`:

- `observations_filtered.csv` : the cached observations. Reused on later runs unless you turn caching off.
- `base_map_cache/` : cached satellite tiles. Survives figure rebuilds; refreshed only when `force_refetch_maps` is TRUE.
- `osm_roads.gpkg`, `osm_tracks.gpkg`, `osm_water.gpkg` : cached OSM layers. A matching `.none` marker means that layer returned nothing for your area.
- `slides/` : the generated deck and its assets.
  - `data_dive_presentation.qmd` : the Quarto source.
  - `data_dive_presentation.html` : the rendered reveal.js deck.
  - `data_dive_presentation.pptx` : the PowerPoint, if you enabled it.
  - `summary.csv` : the headline counts, saved for reference.
  - `fig_*.png` : the figures.
  - `fig_zoom_*.png` : the hotspot close-ups.
  - `award_*.png` : the contributor award podiums.
  - `species_photos/` : cached species and observer photos.
  - `award_photos/` : cached observer profile photos for the podiums.
  - `styles/custom.css` : the deck styling.

### The HTML is not self-contained

The rendered deck references its figures and CSS by relative path.

- **Open `data_dive_presentation.html` from inside the `slides/` folder.** Moving it on its own breaks the figures.
- **To share it, zip the whole `slides/` folder** so the figures and styling travel with it. Or enable and send the PowerPoint, which is a single portable file.

---

## Reruns and the caches

Several layers are cached so reruns are quick. The trade-off is that a change will not appear until the relevant cache is refreshed.

- **Figures** are cached as PNGs. To refresh **one**, delete its PNG (for example `fig_species_tiers.png`) and run again. To refresh **everything**, set `force_rebuild <- TRUE`.
- **Observations** are cached in `observations_filtered.csv`. Set `use_cached_data <- FALSE` to fetch fresh data from iNaturalist.
- **Satellite tiles and OSM layers** cache under `base_map_cache/` and the `osm_*.gpkg` files, and are reused even during a full figure rebuild. Set `force_refetch_maps <- TRUE` for one run when the map area or the OSM data has actually changed.
- **Photos** (species, observer and award) cache under `slides/`. Set `force_refetch_photos <- TRUE` to re-download them.

The species tiers figure is worth remembering here: if you adjust its photo-grid layout and the slide looks unchanged, delete `fig_species_tiers.png` before re-rendering so the new layout is picked up. The same applies to award podiums (`award_*.png`) and close-ups (`fig_zoom_*.png`).

---

## Performance

The slowest steps are the base map, the OSM layers, the photo downloads and the interpolation. To speed a run up:

- Lower `base_map_zoom` to 12 or 13, and reduce `buffer_km`, for fewer and smaller map tiles.
- Keep `force_refetch_maps` and `force_refetch_photos` at FALSE so tiles and photos are reused.
- Set `use_interpolation <- FALSE` to skip the smooth richness surface.
- Reduce `n_permutations` (try 50) for faster rarefaction, at the cost of slightly rougher confidence bands.
- Raise `grid_cell_size_m` (try 750 or 1000) so the heatmaps have fewer cells to compute.
- Set `include_awards <- FALSE`, or trim `award_ids`, to skip building award podiums.
- Keep `use_cached_data <- TRUE` after the first run so data is not re-fetched.

---

## Troubleshooting

### The run stops with a `bioblitz_style.R` not found error

Put `bioblitz_style.R` in the same folder as the script, and run from that folder so the relative `source()` resolves.

### A figure did not update after a change

Figures are cached. Delete the specific PNG (for example `fig_species_tiers.png`, `award_most_obs.png`, or `fig_zoom_1.png`) or set `force_rebuild <- TRUE`, then run again.

### Rendering fails

Install Quarto (https://quarto.org/) and the `quarto` R package (`install.packages("quarto")`). You can render the deck by hand:

```bash
quarto render outputs/<project>_data_dive/slides/data_dive_presentation.qmd
```

Add `--to pptx` for the PowerPoint.

### The map or photos look stale after new observations arrive

The tiles, OSM layers and photos are cached and reused across figure rebuilds. Set `force_refetch_maps <- TRUE` and `force_refetch_photos <- TRUE` for one run, then set them back to FALSE.

### No award slides appeared

Confirm `include_awards <- TRUE`, and that enough observers cleared `award_min_obs`. Any category with no qualifying data is skipped silently. If you edited `award_ids`, check the ones you want are still listed.

### No hotspot close-ups appeared

The console prints "No qualifying hotspot windows" when nothing meets the thresholds. Lower `zoom_min_obs`, or reduce `zoom_min_sep_m`, in the Figure 1C block. Sparse events may simply not have dense enough clusters.

### The PowerPoint is not navy full-bleed

The restyle needs Python 3 and `python-pptx` (`pip install python-pptx`). The console notes when it is skipped. The deck still renders correctly without it.

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
- **Pick your awards.** Run once with all categories, then trim `award_ids` to the ones that tell the best story for your event.
- **HTML for viewing, PowerPoint for editing.** Present from the HTML deck; enable the PowerPoint when you want to add slides or tweak wording by hand.
- **Keep the caches.** They cut reruns from half an hour to a few minutes. Only clear them, or set the `force_refetch_*` flags, for a deliberate refresh.
- **Match the two decks.** Because both the Data Dive and the photo Slideshow load the same `bioblitz_style.R`, editing the palette once updates both.

---

## Companion: the photo Slideshow deck

This Data Dive pairs with the [iNaturalist Bioblitz Slideshow Generator](https://github.com/ollybolly/iNaturalist_Bioblitz_photo_presentations), which builds a photo-and-map slideshow from the same project and shares the same style file.

| | Data Dive | Photo Slideshow |
|---|---|---|
| Purpose | Analysis and reporting | Visual celebration |
| Output | Charts, maps, statistics, awards | Photo slideshow |
| Format | HTML and PowerPoint | HTML |
| Best for | Wrap-up reports, insights | Event displays, outreach |

Use both: the slideshow for public display, the data dive for the numbers behind it.

---

**Happy analysing.** 📊🔬🌿

---

*Version 4*
