#' Resize a plot's data labels
#'
#' Adjusts the size of the text drawn by [ggplot2::geom_text()] and
#' [ggplot2::geom_label()] layers of a plot - e.g. the percentage labels inside
#' a [stemtools::stem_barplot()] or [stemtools::stem_inline()] - while leaving
#' axis, legend and title text untouched. Used by [new_stem_chart_block()] to
#' expose an inner-label size control.
#'
#' @param plot A ggplot object.
#' @param size Label size in points.
#'
#' @return `plot`, with the size of its text/label layers updated.
#' @export
#'
#' @examples
#' if (requireNamespace("stemtools", quietly = TRUE)) {
#'   set_label_size(stemtools::stem_barplot(iris, Species), 14)
#' }
set_label_size <- function(plot, size) {
  for (i in seq_along(plot$layers)) {
    geom <- plot$layers[[i]]$geom
    if (inherits(geom, "GeomText") || inherits(geom, "GeomLabel")) {
      plot$layers[[i]]$aes_params$size <- size / ggplot2::.pt
    }
  }
  plot
}

# TRUE when `x` is a usable, non-empty scalar string (a chosen column name).
has_col <- function(x) is.character(x) && length(x) == 1L && nzchar(x)

# Build the expression that plots a single variable with a stemtools function,
# optionally weighting by a column and resizing the inner data labels. `item` is
# a symbol (the bare column name); the upstream data is left as the `.(data)`
# marker for the framework to bind. Returns a plain language object; shared by
# new_stem_chart_block() and new_stem_visualize_block().
stem_plot_expr <- function(item, type = "barplot", weight = NULL, group = NULL,
                           palette = "div1", direction = 1, labels = TRUE,
                           label_accuracy = 1, label_size = NA_real_,
                           title_show = FALSE, title_quote = FALSE,
                           title_wrap = 80) {
  fun <- if (identical(type, "inline")) {
    quote(stemtools::stem_inline)
  } else {
    quote(stemtools::stem_barplot)
  }

  # Grouping is only supported by stem_barplot(), not stem_inline(). When set,
  # stem_barplot() draws one stacked horizontal bar per group category (the
  # grouping variable on the axis) with the *selected* variable (`item`) mapped
  # to the coloured fill - so the number of colours is the selected variable's
  # category count, not the grouping variable's.
  args <- list(quote(.(data)), item)
  if (has_col(group) && !identical(type, "inline")) {
    args[["group"]] <- as.name(group)
  }
  if (has_col(weight)) {
    args[["weight"]] <- as.name(weight)
  }
  args[["palette"]] <- palette
  args[["direction"]] <- direction
  args[["labels"]] <- labels
  args[["label_accuracy"]] <- label_accuracy
  # The title (the variable's label) is drawn by stemtools when title_show is on;
  # title_quote wraps it in typographic quotes. Both default off (the stemtools
  # default), so only emit them when set to keep the generated call tidy.
  # title_wrap sets the max characters per title line (stemtools wraps longer
  # titles onto several lines so they don't overflow); it only affects the
  # ggplot-drawn title, i.e. the PNG/SVG (ggsave) exports - the native
  # PowerPoint chart rebuilds its own title and ignores it. Only meaningful when
  # the title is shown, and only emit when it differs from the stemtools default
  # of 80 to keep the generated call tidy.
  if (isTRUE(title_show)) {
    args[["title_show"]] <- TRUE
    if (isTRUE(title_quote)) args[["title_quote"]] <- TRUE
    if (length(title_wrap) == 1L && !is.na(title_wrap) &&
        !identical(as.numeric(title_wrap), 80)) {
      args[["title_wrap"]] <- title_wrap
    }
  }

  plot_call <- as.call(c(list(fun), args))

  if (length(label_size) == 1L && !is.na(label_size)) {
    plot_call <- as.call(
      list(quote(blockr.stem::set_label_size), plot_call, label_size)
    )
  }
  plot_call
}

# Build the expression that plots a *battery* of same-scale categorical items
# with stemtools::stem_battery() (one stacked horizontal bar per item). Emitted
# via the exported runtime helper blockr.stem::stem_battery_plot(), which
# validates the items share identical response categories before delegating to
# stem_battery() - so a mismatched selection surfaces an informative error in the
# block rather than a cryptic tidy/reshape failure. `items`/`order_by` are
# character vectors and `weight` a column-name string, all emitted as plain
# literals (no bare symbols), keeping the generated call self-contained. Shared
# by new_stem_visualize_battery_block(); optionally wrapped in set_label_size().
stem_battery_expr <- function(items, weight = NULL, order_by = NULL,
                              item_label = TRUE, palette = "div1", direction = 1,
                              labels = TRUE, label_accuracy = 1,
                              label_hide = 0.05, reverse_levels = FALSE,
                              label_size = NA_real_) {
  items <- items[nzchar(items)]

  args <- list(quote(.(data)), items = items)
  if (has_col(weight)) args[["weight"]] <- weight
  order_by <- order_by[nzchar(order_by)]
  if (length(order_by)) args[["order_by"]] <- order_by
  args[["item_label"]] <- isTRUE(item_label)
  args[["palette"]] <- palette
  args[["direction"]] <- direction
  args[["labels"]] <- labels
  args[["label_accuracy"]] <- label_accuracy
  # A cleared field reads as NA; fall back to the stem_battery default so the
  # call stays valid.
  if (length(label_hide) != 1L || is.na(label_hide)) label_hide <- 0.05
  args[["label_hide"]] <- label_hide
  # Off by default (the natural scale order); only emit when set, to keep the
  # generated call tidy.
  if (isTRUE(reverse_levels)) args[["reverse_levels"]] <- TRUE

  plot_call <- as.call(c(list(quote(blockr.stem::stem_battery_plot)), args))

  if (length(label_size) == 1L && !is.na(label_size)) {
    plot_call <- as.call(
      list(quote(blockr.stem::set_label_size), plot_call, label_size)
    )
  }
  plot_call
}

# Expression for the STEM Variable Selector: output the selected column, plus
# the weight and/or group columns tagged with `stem_weight` / `stem_group`
# attributes when chosen. Downstream plot blocks read those attributes.
# `var`/`weight`/`group` are column name strings; upstream data is `.(data)`.
stem_select_expr <- function(var, weight = NULL, group = NULL) {
  keep <- var
  if (has_col(weight)) keep <- c(keep, weight)
  if (has_col(group)) keep <- c(keep, group)
  keep <- unique(keep)

  sub <- as.call(list(as.name("["), quote(.(data)), keep))

  tags <- list()
  if (has_col(weight)) tags$stem_weight <- weight
  if (has_col(group)) tags$stem_group <- group
  if (length(tags)) {
    as.call(c(list(quote(structure), sub), tags))
  } else {
    sub
  }
}

# Readable (weighted) frequency table for a single categorical variable, built
# with stemtools::stem_summarise_cat(). Percentages, rounded, with the 95% CI.
# Used to render the STEM Variable Selector's output panel.
stem_freq_table <- function(data, var, weight = NULL, group = NULL) {
  # Mirror the bar plot: summarise the selected `var` (proportions within each
  # group). When grouping, the grouping variable is the row category (the plot's
  # axis, one bar per category) and the selected `var` is the coloured series
  # (the plot's fill).
  args <- list(quote(data), as.name(var))
  if (has_col(group)) args[["group"]] <- as.name(group)
  if (has_col(weight)) args[["weight"]] <- as.name(weight)
  freq <- eval(as.call(c(list(quote(stemtools::stem_summarise_cat)), args)))

  cat_col <- if (has_col(group)) group else var
  out <- data.frame(
    Category = as.character(freq[[cat_col]]),
    Percent = round(100 * freq$freq, 1),
    `CI low` = round(100 * freq$freq_low, 1),
    `CI high` = round(100 * freq$freq_upp, 1),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  if (has_col(group)) {
    out <- cbind(Series = as.character(freq[[var]]), out, stringsAsFactors = FALSE)
  }
  out
}

# The survey weight a plot block should use: the upstream selection carried on
# the `stem_weight` attribute wins (the Selector is authoritative), otherwise the
# block's own `weight` control value.
stem_effective_weight <- function(data, weight) {
  upstream <- attr(data, "stem_weight", exact = TRUE)
  if (has_col(upstream)) upstream else weight
}

# The grouping variable a plot block should use: carried on the `stem_group`
# attribute by the Selector (NULL when none).
stem_effective_group <- function(data) {
  g <- attr(data, "stem_group", exact = TRUE)
  if (has_col(g)) g else NULL
}

# Sensible default export height (cm) for a stem plot: 6 for an inline plot (a
# single stacked bar has one y row) and 10 for a bar plot. Falls back to 10 if
# the type can't be determined.
stem_default_plot_height <- function(plot) {
  is_inline <- tryCatch(
    length(unique(ggplot2::ggplot_build(plot)$data[[1L]]$y)) == 1L,
    error = function(e) FALSE
  )
  if (isTRUE(is_inline)) 6 else 10
}

# Effective export dimensions, shared by the download handler and the live
# preview so both use identical sizing. An unset/invalid field falls back to the
# same default the UI advertises (width 14 cm, scale 1.5, height by plot type).
stem_export_eff_width <- function(w) {
  if (length(w) != 1L || is.na(w) || w <= 0) 14 else w
}
stem_export_eff_height <- function(h, plot) {
  if (length(h) != 1L || is.na(h)) stem_default_plot_height(plot) else h
}
stem_export_eff_scale <- function(s) {
  if (length(s) != 1L || is.na(s) || s <= 0) 1.5 else s
}

# Default plot padding (mm) applied around the plot so the extreme axis labels
# (e.g. "0 %" / "100 %"), which are centred on the panel edges and overflow by
# roughly half their width (~7 mm at the default size), are not clipped.
stem_default_padding <- 8

# Compose a base plot expression with the Stem theme: optionally a base font
# size for the axis/legend/title text, and a `padding` (mm) added to the plot
# margin so edge axis labels are not cut off. `base` is a language object -
# either the `.(data)` marker (Theme STEM block) or a stem_plot_expr() call
# (STEM Visualize block). Returns a plain language object.
stem_theme_expr <- function(base, ink = "black", paper = "white",
                            accent = "#35978F", family = "Calibri",
                            font_size = NA_real_,
                            padding = stem_default_padding) {
  themed <- as.call(list(
    quote(stemtools::theme_stem),
    ink = ink, paper = paper, accent = accent, family = family
  ))
  out <- call("+", base, themed)

  if (length(font_size) == 1L && !is.na(font_size)) {
    size_layer <- bquote(
      ggplot2::theme(text = ggplot2::element_text(size = .(font_size)))
    )
    out <- call("+", out, size_layer)
  }

  pad <- if (length(padding) == 1L && !is.na(padding) && padding >= 0) {
    padding
  } else {
    stem_default_padding
  }
  margin_layer <- bquote(
    ggplot2::theme(
      plot.margin = ggplot2::margin(.(pad), .(pad), .(pad), .(pad), unit = "mm")
    )
  )
  call("+", out, margin_layer)
}

# Data frame of the categorical (factor / character) variables in `data`, with
# their labels (attr(x, "label")) and category counts - the model behind the
# searchable table in new_stem_var_selector_block().
stem_cat_vars <- function(data) {
  is_cat <- vapply(data, function(x) is.factor(x) || is.character(x), logical(1))
  cols <- names(data)[is_cat]

  label_of <- function(nm) {
    lab <- attr(data[[nm]], "label", exact = TRUE)
    if (is.character(lab) && length(lab) == 1L && nzchar(lab)) lab else NA_character_
  }

  data.frame(
    Variable = cols,
    Label = vapply(cols, label_of, character(1), USE.NAMES = FALSE),
    Categories = vapply(
      cols, function(nm) length(unique(data[[nm]])), integer(1), USE.NAMES = FALSE
    ),
    stringsAsFactors = FALSE
  )
}

# Choices for a survey-weight selectInput: "(none)" plus the numeric columns of
# `data` (survey weights are numeric). Value "" means unweighted.
stem_weight_choices <- function(data) {
  nums <- names(data)[vapply(data, is.numeric, logical(1))]
  c(`(none)` = "", stats::setNames(nums, nums))
}

# Choices for a grouping selectInput: "(none)" plus the categorical (factor /
# character) columns of `data`. Value "" means no grouping.
stem_group_choices <- function(data) {
  cats <- names(data)[vapply(data, function(x) is.factor(x) || is.character(x), logical(1))]
  c(`(none)` = "", stats::setNames(cats, cats))
}

# The response categories of a categorical column: a factor's `levels()` (order
# preserved, as that is the battery's item/segment order), or the sorted unique
# values of a character column. The unit that must match across a battery's items.
stem_col_levels <- function(x) {
  if (is.factor(x)) levels(x) else sort(unique(as.character(x)))
}

# The shared response categories to offer as `order_by` choices for a battery of
# `items` (column-name character vector): the levels of the first selected
# categorical item. Best-effort - when the selected items' levels disagree the
# authoritative check lives in stem_battery_plot(), which errors on export.
stem_battery_levels <- function(data, items) {
  items <- intersect(items[nzchar(items)], names(data))
  is_cat <- vapply(
    data[items], function(x) is.factor(x) || is.character(x), logical(1)
  )
  items <- items[is_cat]
  if (!length(items)) character(0) else stem_col_levels(data[[items[1]]])
}

# Choices for a categorical-variable selectInput: like stem_var_choices() (values
# are the column names, display is "<col> - <label>" when labelled) but limited to
# the factor / character columns - the only variables a battery can plot.
stem_cat_var_choices <- function(data) {
  choices <- stem_var_choices(data)
  is_cat <- vapply(
    data[choices], function(x) is.factor(x) || is.character(x), logical(1)
  )
  choices[is_cat]
}

# Named choices for a variable selectInput: values are the column names, the
# displayed names are "<col> - <label>" when the column carries an
# `attr(x, "label")`, otherwise just the column name.
stem_var_choices <- function(data) {
  cols <- colnames(data)
  display <- vapply(
    cols,
    function(nm) {
      lab <- attr(data[[nm]], "label", exact = TRUE)
      if (is.character(lab) && length(lab) == 1L && nzchar(lab)) {
        paste0(nm, " - ", lab)
      } else {
        nm
      }
    },
    character(1),
    USE.NAMES = FALSE
  )
  stats::setNames(cols, display)
}
