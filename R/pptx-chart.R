#' Export a STEM plot as a native, editable PowerPoint chart
#'
#' Writes a `.pptx` file containing a **native Microsoft Office chart** - a real
#' `c:chart` object backed by an embedded Excel worksheet - rather than a picture
#' of the plot. The recipient can open the deck and use *Chart Design > Edit Data*
#' to change the numbers by hand in Excel, restyle the chart, etc.
#'
#' Because a native Office chart is built from *data* (not pixels), this only
#' works for the STEM bar / inline plots, whose summarised data and aesthetic
#' mapping are recovered from the ggplot object ([stemtools::stem_barplot()],
#' [stemtools::stem_inline()]). The category axis, the (optional) coloured series
#' and the values are read back from the plot; the Stem palette colours are
#' carried over to the chart's series so it looks right out of the box. Any other
#' ggplot raises an error - export those as PNG or SVG instead.
#'
#' The chart inherits the plot's Stem theme (font family and ink colour from
#' [stemtools::theme_stem()], legend on top) so it matches the on-screen plot.
#' Being a native chart it can be freely resized in PowerPoint, so it is placed
#' filling the slide by default rather than at a fixed centimetre size.
#'
#' Requires the \pkg{mschart} and \pkg{officer} packages.
#'
#' @param plot A ggplot object produced by a STEM chart / visualize block.
#' @param file Path of the `.pptx` file to write.
#' @param width,height Size of the chart on the slide, in centimetres. Default
#'   `NA` fills the slide (leaving a small margin); pass explicit values to place
#'   a fixed-size, centred chart instead.
#'
#' @return `file`, invisibly.
#' @export
stem_write_pptx_chart <- function(plot, file, width = NA_real_, height = NA_real_) {
  if (!requireNamespace("mschart", quietly = TRUE) ||
    !requireNamespace("officer", quietly = TRUE)) {
    stop(
      "PowerPoint chart export requires the 'mschart' and 'officer' packages. ",
      "Install them, or export as PNG/SVG instead."
    )
  }

  chart <- stem_pptx_chart(plot)

  doc <- officer::read_pptx()
  doc <- officer::add_slide(doc, layout = "Title and Content", master = "Office Theme")
  doc <- officer::ph_with(
    doc, value = chart, location = stem_pptx_location(width, height)
  )
  print(doc, target = file)
  # theme_stem() left-aligns the plot title, but mschart emits the chart title
  # centred with no API to change it; patch the written OOXML to match (only when
  # there is a title to align).
  if (!is.null(stem_pptx_title(plot))) {
    stem_pptx_leftalign_title(file)
  }
  invisible(file)
}

# Left-align the native chart's title inside a written `.pptx`. mschart hardcodes
# the title paragraph as a bare `<a:pPr>` (which PowerPoint renders centred) and
# neither chart_labels() nor mschart_theme() exposes its alignment, so we edit the
# OOXML directly: unzip, inject `algn="l"` into the first `<a:pPr>` of each chart's
# `<c:title>` block, and rezip. Best-effort - on any error (or if mschart's
# template changes so the pattern no longer matches) the file is left exactly as
# officer wrote it, i.e. with a centred title, rather than failing the export.
stem_pptx_leftalign_title <- function(file) {
  # Rezipping the patched archive needs zip::zip() (base R can unzip but not
  # write a zip). Without it, skip the whole rewrite and leave the centred title.
  if (!requireNamespace("zip", quietly = TRUE)) {
    return(invisible(file))
  }
  tryCatch(
    {
      ex <- tempfile()
      dir.create(ex)
      on.exit(unlink(ex, recursive = TRUE), add = TRUE)
      utils::unzip(file, exdir = ex)

      charts <- list.files(
        file.path(ex, "ppt", "charts"),
        pattern = "^chart.*\\.xml$", full.names = TRUE
      )
      patched <- FALSE
      for (cf in charts) {
        x <- paste(readLines(cf, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
        # First `<a:pPr>` inside the `<c:title>` block (dotall + lazy so it spans
        # the pretty-printed lines and stops at the title's own paragraph). A
        # no-op when the chart has no title.
        x2 <- sub("(?s)(<c:title[ >].*?)<a:pPr>", "\\1<a:pPr algn=\"l\">", x, perl = TRUE)
        if (!identical(x, x2)) {
          writeLines(x2, cf, useBytes = TRUE)
          patched <- TRUE
        }
      }

      if (patched) {
        files <- list.files(ex, recursive = TRUE, all.files = TRUE, no.. = TRUE)
        # Repackage to a temp file first, then swap it in, so a failure mid-zip
        # can't corrupt the file officer already wrote.
        newzip <- tempfile(fileext = ".pptx")
        zip::zip(
          zipfile = newzip, files = files, root = ex, include_directories = FALSE
        )
        file.copy(newzip, file, overwrite = TRUE)
        unlink(newzip)
      }
    },
    error = function(e) NULL
  )
  invisible(file)
}

# Placement of the chart on a standard 10 x 7.5 inch slide. With no explicit
# size (NA) the chart fills the slide leaving a ~0.4 inch margin; with a size in
# cm it is centred at that exact size. Native charts resize freely in PowerPoint,
# so a large default is the sensible starting point.
stem_pptx_location <- function(width = NA_real_, height = NA_real_) {
  slide_w <- 10
  slide_h <- 7.5
  has <- function(x) length(x) == 1L && !is.na(x) && x > 0
  if (has(width) && has(height)) {
    w <- width / 2.54
    h <- height / 2.54
  } else {
    margin <- 0.4
    w <- slide_w - 2 * margin
    h <- slide_h - 2 * margin
  }
  w <- min(w, slide_w)
  h <- min(h, slide_h)
  officer::ph_location(
    left = (slide_w - w) / 2, top = (slide_h - h) / 2,
    width = w, height = h
  )
}

# Build the mschart object for a STEM plot. Grouped bar plots and inline plots
# become 100%-stacked horizontal bar charts (one bar per axis category, the
# selected variable as the coloured series); an ungrouped bar plot becomes a
# plain horizontal bar chart (one bar per category). Errors if `plot` isn't a
# reconstructable STEM plot.
stem_pptx_chart <- function(plot) {
  df <- stem_pptx_chart_data(plot)
  if (is.null(df)) {
    stop(
      "This plot cannot be exported as a native PowerPoint chart. Native chart ",
      "export supports STEM bar / inline plots; export other plots as PNG or SVG."
    )
  }
  grouped <- !is.null(df$series)
  style <- stem_pptx_style(plot)
  # `gap_width` 30 (vs mschart's default 150) draws thick bars like the plot.
  gap <- 30

  if (grouped) {
    # Grouped / inline: one 100%-stacked bar per axis category.
    chart <- mschart::ms_barchart(
      df, x = "category", y = "value", group = "series", labels = "stem_label"
    )
    chart <- mschart::chart_settings(
      chart,
      grouping = "percentStacked", dir = "horizontal", overlap = 100, gap_width = gap
    )
    fills <- stem_pptx_series_fills(plot, df, "series")
    if (!is.null(fills)) chart <- mschart::chart_data_fill(chart, values = fills)
    # A stacked chart needs its legend to read the series; put it on top like
    # theme_stem() does. A single-series (ungrouped) chart has no useful legend.
    legend_pos <- style$legend
    # Each bar sums to 100%: pin the value axis to 0-100% in 25% steps like the
    # plot, and centre the labels inside the segments.
    label_pos <- "ctr"
    chart <- mschart::chart_ax_y(
      chart,
      num_fmt = "0%", limit_min = 0, limit_max = 1, major_unit = 0.25
    )
  } else {
    chart <- mschart::ms_barchart(df, x = "category", y = "value", labels = "stem_label")
    chart <- mschart::chart_settings(
      chart,
      grouping = "clustered", dir = "horizontal", gap_width = gap
    )
    fills <- stem_pptx_series_fills(plot, df, "category")
    if (!is.null(fills)) chart <- mschart::chart_data_fill(chart, values = unname(fills[1]))
    legend_pos <- "n"
    label_pos <- "outEnd"
    # Category proportions (data-driven max); 10% steps like the plot.
    chart <- mschart::chart_ax_y(
      chart,
      num_fmt = "0%", limit_min = 0, major_unit = 0.1
    )
  }

  chart <- mschart::set_theme(chart, stem_pptx_theme(style, legend_pos))

  # theme_stem() draws no axis titles - drop mschart's default ones (the column
  # names "category" / "value"). Carry over the plot's title (the variable label
  # stemtools draws when title_show is on) so the native chart shows it too; it
  # is rendered bold via the theme's main_title (see stem_pptx_theme()). NULL
  # when the plot has no title, which leaves the chart untitled.
  chart <- mschart::chart_labels(
    chart, title = stem_pptx_title(plot), xlab = NULL, ylab = NULL
  )

  # Show the plot's own labels verbatim (the `stem_label` integers, no "%"
  # suffix, blank on segments the plot hides) via mschart's labels-from-cells,
  # rather than re-deriving and reformatting the value (which added a "%").
  chart <- mschart::chart_data_labels(chart, show_val = FALSE, position = label_pos)
  # Match the plot's label sizing and its bicolour scheme (white on the dark
  # extreme segments, black elsewhere). The label size is scaled to the chart's
  # own axis-text size (see stem_pptx_label_scale).
  label_size <- round(2 * stem_pptx_label_size(plot) * stem_pptx_label_scale) / 2
  chart <- mschart::chart_labels_text(
    chart,
    stem_pptx_label_text(plot, df, style, label_size)
  )
  chart
}

# The plot's title (the variable label stemtools draws when title_show is on),
# read off `plot$labels$title`, or NULL when the plot carries no title. Passed to
# mschart::chart_labels() so the native chart shows the same title, rendered bold
# via the theme's main_title (see stem_pptx_theme()).
stem_pptx_title <- function(plot) {
  ttl <- plot$labels$title
  if (is.character(ttl) && length(ttl) == 1L && nzchar(ttl)) ttl else NULL
}

# The native chart's axis / legend text point size (see stem_pptx_theme()). Also
# the reference the label and preview scaling are expressed against.
stem_pptx_axis_size <- 11

# stemtools sizes the plot's data labels for its own axis text (theme_stem()'s
# axis text is ~14.4pt). The native chart uses smaller 11pt axis/legend text, so
# the raw label size looks oversized against it; scale the labels by 11/14 (the
# chart's base font over the plot's label reference) to keep the same
# label-to-axis proportion the plot has. Applied to the exported label font only.
stem_pptx_label_scale <- stem_pptx_axis_size / 14

# Preview-only `scale` for the pptx format. The pptx preview is a raster of the
# raw ggplot; the exported native chart is smaller-texted. We match the *data
# labels* - the chart's prominent text (the percentage numbers on the bars) -
# rather than the axis text: the export draws them at stem_pptx_label_scale of
# the plot's label size, so ggsave's `scale` (which shrinks apparent text as it
# grows) must preview at the inverse ratio to reproduce the exported label size.
# This reduces to 14/11 for the default 14pt labels and, because the chart
# scales whatever label size the plot has, keeps the previewed labels matching
# the export at any label size (and independent of the base font size, which the
# labels don't follow). Axis text then lands within ~3%, secondary to the labels.
stem_pptx_preview_scale <- 1 / stem_pptx_label_scale

# Point size of the plot's data labels, read off the geom_text / geom_label
# layer. When set_label_size() has pinned a size we use it (e.g. 14); when the
# label size is left on "auto" the layer carries no explicit size, so we fall
# back to the geom's own default (stemtools renders that at ~11pt) rather than a
# fixed guess - otherwise "auto" labels came out oversized in the chart. ggplot
# renders text at `size * .pt` points (size.unit "mm", as stemtools uses).
stem_pptx_label_size <- function(plot) {
  for (ly in plot$layers) {
    if (!inherits(ly$geom, "GeomText") && !inherits(ly$geom, "GeomLabel")) {
      next
    }
    sz <- ly$aes_params$size
    if (length(sz) == 1L && !is.na(sz)) {
      return(sz * ggplot2::.pt)
    }
    default <- tryCatch(
      as.numeric(rlang::eval_tidy(ly$geom$default_aes$size)),
      error = function(e) NA_real_
    )
    if (length(default) == 1L && !is.na(default)) {
      return(default * ggplot2::.pt)
    }
  }
  11
}

# Data-label font(s) for chart_labels_text(): a per-series named list carrying
# the plot's bicolour scheme (the `.label_color` stemtools assigns each item
# category - white on the dark extreme segments, black elsewhere) for grouped /
# inline plots, or a single ink-coloured font when there is no series.
stem_pptx_label_text <- function(plot, df, style, size) {
  mk <- function(col) {
    officer::fp_text(font.family = style$family, color = col, font.size = size)
  }
  if (is.null(df$series) || !".label_color" %in% names(plot$data)) {
    return(mk(style$ink))
  }
  fillvals <- as.character(rlang::eval_tidy(plot$mapping$fill, plot$data))
  lc <- as.character(plot$data$.label_color)
  lvls <- levels(df$series)
  cols <- vapply(
    lvls,
    function(l) {
      v <- lc[fillvals == l]
      if (length(v) && !is.na(v[1]) && nzchar(v[1])) v[1] else style$ink
    },
    character(1)
  )
  stats::setNames(lapply(cols, mk), lvls)
}

# Read the Stem look off the (themed) plot: font family and ink colour from
# theme_stem(), and the legend position, with theme_stem()'s defaults as the
# fallback for an unthemed plot.
stem_pptx_style <- function(plot) {
  th <- plot$theme
  family <- th$text$family %||% "Calibri"
  if (!is.character(family) || !nzchar(family)) family <- "Calibri"
  ink <- th$text$colour %||% "black"
  if (!is.character(ink) || !nzchar(ink)) ink <- "black"
  pos <- if (is.character(th$legend.position)) th$legend.position else "top"
  legend <- switch(pos,
    top = "t", bottom = "b", left = "l", right = "r", none = "n",
    "t"
  )
  list(family = family, ink = ink, legend = legend)
}

# An mschart theme mirroring theme_stem(): the plot's font family / ink colour,
# a clean panel with no gridlines or tick borders, and the given legend position.
stem_pptx_theme <- function(style, legend_pos) {
  txt <- function(size, bold = FALSE) {
    officer::fp_text(
      font.family = style$family, color = style$ink, font.size = size, bold = bold
    )
  }
  none <- officer::fp_border(width = 0)
  mschart::mschart_theme(
    axis_text = txt(stem_pptx_axis_size),
    axis_title = txt(12),
    main_title = txt(14, bold = TRUE),
    legend_text = txt(stem_pptx_axis_size),
    grid_major_line = none,
    grid_minor_line = none,
    axis_ticks = none,
    legend_position = legend_pos
  )
}

# Recover a tidy data frame (category, value, and optionally series) from a STEM
# plot's summarised data (`plot$data`) and aesthetic mapping. `x` is the value
# (freq), `y` the axis category, `fill` the coloured series. Returns NULL when
# the plot doesn't carry the expected data/mapping (i.e. isn't a STEM plot), so
# callers can fall back with a clear error.
stem_pptx_chart_data <- function(plot) {
  m <- plot$mapping
  dat <- plot$data
  if (is.null(dat) || !NROW(dat) || is.null(m$x)) {
    return(NULL)
  }
  # Only STEM summary plots can be turned into a meaningful native chart: their
  # data carries the summarised proportion (`freq`) and its label (`stem_label`).
  # Bail on any other ggplot so we error rather than emit a nonsensical chart.
  if (!all(c("freq", "stem_label") %in% names(dat))) {
    return(NULL)
  }

  value <- suppressWarnings(as.numeric(rlang::eval_tidy(m$x, dat)))
  if (all(is.na(value))) {
    return(NULL)
  }
  axis <- if (!is.null(m$y)) as.character(rlang::eval_tidy(m$y, dat)) else ""
  axis <- rep(axis, length.out = NROW(dat))
  series <- if (!is.null(m$fill)) as.character(rlang::eval_tidy(m$fill, dat)) else NULL

  df <- data.frame(
    category = factor(axis, levels = unique(axis)),
    value = value,
    # The plot's own printed label: an integer percentage, blank where the plot
    # hides a small segment. Shown verbatim as the chart's data labels.
    stem_label = as.character(dat$stem_label),
    stringsAsFactors = FALSE
  )
  if (!is.null(series)) {
    df$series <- factor(series, levels = unique(series))
  }

  # Ad-hoc axis-order fix: ggplot draws the first category at the BOTTOM of the
  # (horizontal) y axis, but a native mschart chart comes out with the categories
  # in the reverse order - so without this the exported bars are upside down
  # relative to the plot and the PNG/SVG exports. mschart orders the category
  # axis differently for the two chart shapes we emit (both verified against the
  # written OOXML), so the reversal differs:
  if (is.null(df$series)) {
    # Single-series (plain bar): the category axis follows *row* order. Reverse
    # the rows. The bars are one colour, so the fill pairing in
    # stem_pptx_series_fills (which is positional against the plot) is unaffected.
    df[rev(seq_len(nrow(df))), , drop = FALSE]
  } else {
    # Grouped / inline (stacked): the category axis follows the category factor's
    # *levels*. Reverse those, leaving the row order - and thus the per-series
    # colour pairing and the stacked-series order - untouched.
    df$category <- factor(df$category, levels = rev(levels(df$category)))
    df
  }
}

# Map each level of `df[[key]]` to the fill colour stemtools drew it with, so the
# native chart reuses the Stem palette. The built layer data carries one resolved
# `fill` per row in the same order as `plot$data`, so we pair them by row.
# Returns a named character vector, or NULL if colours can't be recovered.
stem_pptx_series_fills <- function(plot, df, key) {
  bd <- tryCatch(ggplot2::ggplot_build(plot)$data[[1L]], error = function(e) NULL)
  if (is.null(bd) || is.null(bd$fill) || nrow(bd) != nrow(df)) {
    return(NULL)
  }
  lv <- levels(df[[key]])
  cols <- bd$fill[match(lv, as.character(df[[key]]))]
  if (anyNA(cols)) {
    return(NULL)
  }
  stats::setNames(cols, lv)
}
