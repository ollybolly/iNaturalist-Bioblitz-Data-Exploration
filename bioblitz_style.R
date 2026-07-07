# ==============================================================================
# bioblitz_style.R  --  shared palette + taxon icons for both bioblitz scripts
# ==============================================================================
# Single source of truth so the Data Dive, the image/map Slideshow, and the
# environmental module all use identical taxon colours and identical silhouette
# icons. Source this near the top of each script, AFTER packages load and AFTER
# out_dir is defined, and REMOVE each script's own palette / icon definitions
# (see the integration notes file).
#
#   source("bioblitz_style.R")
#
# Provides:
#   taxon_cols            named vector: iconic taxon -> hex (Wes Anderson)
#   iconic_cols           alias of taxon_cols  (Data Dive uses this name)
#   taxon_icon_colors     alias of taxon_cols  (Slideshow uses this name)
#   taxon_color(taxon)    colour lookup with fallback
#   ensure_taxon_icon()   cached, recoloured PhyloPic silhouette PNG path
#   recolor_silhouette()  tint helper (shape only)
#   label_with_icon_md()  ggtext markdown labels with silhouettes (Data Dive)
# ==============================================================================

# --- packages this file needs -------------------------------------------------
for (p in c("wesanderson", "magick")) {
  if (!requireNamespace(p, quietly = TRUE))
    install.packages(p, repos = "https://cloud.r-project.org")
}

# ==============================================================================
# 1. TAXON PALETTE  --  Wes Anderson Zissou1, supplemented with Darjeeling
# ==============================================================================
# Zissou1 supplies the five most prominent groups; Darjeeling1/2 fill the rest.
# Pulled from the package (not hardcoded) so it always matches the installed
# palettes. Reorder the assignments below to taste - the only rule is one colour
# per taxon, shared across both decks.
#
# Note: Wes Anderson palettes are built for ~4-5 categories, so squeezing 13
# iconic taxa across three palettes leaves a couple of warm hues fairly close
# (e.g. amber vs gold). In practice each chart only shows the taxa actually
# present at the event (usually 6-9 groups), so collisions rarely bite. If two
# adjacent groups clash in a given chart, swap their entries here.

# Extended Zissou palette (user-supplied). One colour per taxon; reorder freely.
taxon_cols <- c(
  Aves           = "#3B9AB2",  # blue
  Plantae        = "#446455",  # green
  Insecta        = "#EBCC2A",  # yellow
  Mammalia       = "#E1AF00",  # gold
  Actinopterygii = "#78B7C5",  # light blue (fish)
  Amphibia       = "#81A88D",  # sage green
  Reptilia       = "#E58601",  # orange
  Fungi          = "#F21A00",  # red
  Arachnida      = "#9986A5",  # mauve
  Mollusca       = "#E6A0C4",  # pink
  Animalia       = "#FD6467",  # coral
  Chromista      = "#7294D4",  # periwinkle
  Protozoa       = "#9C964A",  # olive
  Unknown        = "#7A7A7A"   # neutral grey, outside the palette
)

# Fallback tint for any taxon not listed above
taxon_icon_color <- "#7A7A7A"

# Back-compatible aliases so existing code keeps working unchanged
iconic_cols       <- taxon_cols   # Data Dive name
taxon_icon_colors <- taxon_cols   # Slideshow name

taxon_color <- function(taxon) {
  if (taxon %in% names(taxon_cols)) taxon_cols[[taxon]] else taxon_icon_color
}

# ==============================================================================
# 2. TAXON ICONS  --  cached, recoloured PhyloPic silhouettes (ex-Slideshow V3)
# ==============================================================================
# Icons are fetched ONCE from PhyloPic, tinted with taxon_cols, and cached to
# taxon_icon_dir (project root, shared between both scripts). After fetching,
# runs are offline. Drop-in PNGs named <taxon>.png in that folder are used as-is.
# Change the palette? set force_rebuild_icons <- TRUE once to re-tint the cache.

use_taxon_icons     <- TRUE
taxon_icon_dir      <- "taxon_icons"   # project-root cache, reused by both decks
fetch_taxon_icons   <- TRUE            # FALSE = only use PNGs already cached
force_rebuild_icons <- TRUE           # TRUE = re-fetch & re-tint even if cached

dir.create(taxon_icon_dir, showWarnings = FALSE, recursive = TRUE)

# PhyloPic search-name overrides per iconic taxon (good local representatives)
taxon_icon_names <- c(
  Plantae        = "Banksia serrata",
  Animalia       = "Mallodon dasystomus",
  Aves           = "Malurus",
  Insecta        = "Tabanus",
  Arachnida      = "Araneidae",
  Amphibia       = "Litoria",
  Reptilia       = "Tiliqua",
  Mammalia       = "Trichosurus",
  Mollusca       = "Bothriembryontidae",
  Fungi          = "Agaricales",
  Actinopterygii = "Lepidogalaxias salamandroides",
  Protozoa       = "Andalucia godoyi",
  Chromista      = "Glaucophyta"
)
# Optional curated PhyloPic UUIDs (override name search). Fill after using
# rphylopic::pick_phylopic(). Leave empty to search by name.
taxon_icon_uuids <- c()

taxon_key <- function(taxon) tolower(gsub("[^A-Za-z]", "", taxon))

# Tint a silhouette to a solid colour, keeping only the SHAPE (not the box).
recolor_silhouette <- function(in_path, out_path, color) {
  sil  <- magick::image_read(in_path)
  info <- magick::image_info(sil)
  flat <- magick::image_composite(magick::image_blank(info$width, info$height, "white"), sil)
  mask <- magick::image_negate(magick::image_convert(flat, colorspace = "gray"))
  tint <- magick::image_blank(info$width, info$height, color = color)
  out  <- magick::image_composite(tint, mask, operator = "CopyOpacity")
  magick::image_write(out, out_path, format = "png")
  file.exists(out_path)
}

# Fetch (once) and cache the raw, untinted silhouette for a taxon. Kept on disk
# so the same shape can be re-tinted to any colour without another API call.
ensure_raw_silhouette <- function(taxon) {
  key     <- taxon_key(taxon)
  raw_png <- file.path(taxon_icon_dir, paste0(key, "_raw.png"))
  if (file.exists(raw_png) && !isTRUE(force_rebuild_icons)) return(raw_png)
  if (!isTRUE(fetch_taxon_icons)) return(NA_character_)
  if (!requireNamespace("rphylopic", quietly = TRUE)) {
    install.packages("rphylopic", repos = "https://cloud.r-project.org")
    if (!requireNamespace("rphylopic", quietly = TRUE)) return(NA_character_)
  }
  if (!requireNamespace("png", quietly = TRUE))
    install.packages("png", repos = "https://cloud.r-project.org")
  if (isTRUE(force_rebuild_icons) && file.exists(raw_png)) unlink(raw_png)
  ok <- tryCatch({
    search_name <- if (taxon %in% names(taxon_icon_names)) taxon_icon_names[[taxon]] else taxon
    uuid <- if (taxon %in% names(taxon_icon_uuids)) taxon_icon_uuids[[taxon]]
            else rphylopic::get_uuid(name = search_name, n = 1)
    if (is.null(uuid) || all(is.na(uuid))) stop("no matching silhouette")
    img   <- rphylopic::get_phylopic(uuid = uuid[1])
    saved <- tryCatch({ png::writePNG(img, raw_png); file.exists(raw_png) },
                      error = function(e) FALSE)
    if (!saved)
      saved <- tryCatch({ rphylopic::save_phylopic(img = img, path = raw_png); file.exists(raw_png) },
                        error = function(e) FALSE)
    if (!saved) stop("could not save silhouette PNG")
    TRUE
  }, error = function(e) {
    cat("    icon fetch failed for", taxon, "-", conditionMessage(e), "\n"); FALSE
  })
  if (isTRUE(ok)) raw_png else NA_character_
}

# Cached silhouette tinted to any colour. color = NULL uses the taxon's palette
# colour (cached as <taxon>.png, back-compatible with the Slideshow and with
# hand-placed drop-in PNGs). Other colours (e.g. white for treemap tiles) are
# cached as <taxon>_<hex>.png.
ensure_taxon_icon_tint <- function(taxon, color = NULL) {
  if (!isTRUE(use_taxon_icons)) return(NA_character_)
  if (is.null(color)) color <- taxon_color(taxon)
  key       <- taxon_key(taxon)
  is_default <- identical(toupper(color), toupper(taxon_color(taxon)))
  final_png <- if (is_default) file.path(taxon_icon_dir, paste0(key, ".png"))
               else file.path(taxon_icon_dir,
                              paste0(key, "_", tolower(gsub("[^0-9a-fA-F]", "", color)), ".png"))
  if (file.exists(final_png) && !isTRUE(force_rebuild_icons)) return(final_png)
  raw <- ensure_raw_silhouette(taxon)
  if (is.na(raw) || !file.exists(raw)) return(NA_character_)
  if (recolor_silhouette(raw, final_png, color)) final_png else NA_character_
}

# Back-compatible: palette-tinted icon (the name both scripts already call).
ensure_taxon_icon <- function(taxon) ensure_taxon_icon_tint(taxon, taxon_color(taxon))

# ==============================================================================
# 3. ICON LABELS FOR GGPLOT  --  replaces the Data Dive's emoji label_with_icon
# ==============================================================================
# Returns markdown <img> labels with the recoloured silhouette beside the taxon
# name. Use as a scale `labels =` function, and render the matching text element
# with ggtext::element_markdown(). Example:
#
#   scale_colour_manual(values = taxon_cols, labels = label_with_icon_md) +
#   theme(legend.text = ggtext::element_markdown())
#
#   scale_x_discrete(labels = label_with_icon_md) +
#   theme(axis.text.x = ggtext::element_markdown())
#
# Falls back to plain text for any taxon without an icon, so it is always safe.
label_with_icon_md <- function(x, height = 72) {
  if (!requireNamespace("ggtext", quietly = TRUE))
    install.packages("ggtext", repos = "https://cloud.r-project.org")
  vapply(as.character(x), function(t) {
    p <- tryCatch(ensure_taxon_icon(t), error = function(e) NA_character_)
    if (is.na(p) || !file.exists(p)) return(t)
    sprintf("<img src='%s' height='%d'/> %s",
            normalizePath(p, winslash = "/"), height, t)
  }, character(1), USE.NAMES = FALSE)
}

cat("bioblitz_style.R loaded: Wes Anderson taxon palette + silhouette icons\n")

# ==============================================================================
# OPTIONAL: match ggplot CHART text to the slide font (Montserrat)
# ------------------------------------------------------------------------------
# Slide titles/body are Montserrat/Open Sans via each deck's CSS. ggplot charts
# render through a graphics device, not the browser, so they do NOT inherit the
# web font. To make chart text Montserrat too, register it with showtext and add
# family = "Montserrat" to your theme text elements. Left OFF by default because
# showtext must be told the output DPI or text comes out mis-sized.
#
# if (requireNamespace("showtext", quietly = TRUE) &&
#     requireNamespace("sysfonts", quietly = TRUE)) {
#   sysfonts::font_add_google("Montserrat", "Montserrat")
#   showtext::showtext_auto()
#   showtext::showtext_opts(dpi = 300)   # match each ggsave(dpi = ...): 300 charts, 150 maps
#   # then add  + ggplot2::theme(text = ggplot2::element_text(family = "Montserrat"))
#   # to theme_bioblitz() and the map / treemap themes.
# }
