#' Plot a battery of same-scale items, with level validation
#'
#' Runtime helper behind [new_stem_visualize_battery_block()]: validates that the
#' chosen `items` are categorical and **share identical response categories**
#' (factor levels / character values) and then draws them with
#' [stemtools::stem_battery()] - one stacked horizontal bar per item. Splitting
#' the check out (rather than calling `stem_battery()` directly from the block's
#' emitted expression) lets a mismatched selection - items from *different*
#' scales that cannot sensibly share one axis - fail with an informative error
#' the block can show, instead of `stem_battery()`'s internal reshape silently
#' unioning the levels into a nonsense chart.
#'
#' @param data Data frame holding the item (and weight) columns.
#' @param items Character vector of column names to plot as the battery.
#' @param weight Optional name of a numeric survey-weight column (`NULL`/`""` for
#'   unweighted).
#' @param order_by Optional character vector of response categories used to order
#'   the items (see [stemtools::stem_battery()]).
#' @param item_label,palette,direction,labels,label_accuracy,label_hide Passed
#'   straight through to [stemtools::stem_battery()].
#' @param reverse_levels If `TRUE`, reverse each item's response categories
#'   (factor levels) before plotting, flipping the orientation of the response
#'   scale along the bars. Defaults to `FALSE`.
#'
#' @return A ggplot2 object from [stemtools::stem_battery()].
#' @export
#'
#' @examples
#' if (requireNamespace("stemtools", quietly = TRUE)) {
#'   df <- data.frame(
#'     q1 = factor(c("Agree", "Disagree"), levels = c("Disagree", "Agree")),
#'     q2 = factor(c("Disagree", "Agree"), levels = c("Disagree", "Agree"))
#'   )
#'   stem_battery_plot(df, items = c("q1", "q2"))
#' }
stem_battery_plot <- function(data, items, weight = NULL, order_by = NULL,
                              item_label = TRUE, palette = "div1", direction = 1,
                              labels = TRUE, label_accuracy = 1,
                              label_hide = 0.05, reverse_levels = FALSE) {
  items <- items[nzchar(items)]
  if (length(items) < 1L) {
    stop(
      "STEM Visualize battery: select at least one variable to plot.",
      call. = FALSE
    )
  }
  missing <- setdiff(items, names(data))
  if (length(missing)) {
    stop(
      "STEM Visualize battery: variable(s) not found in the data: ",
      paste(missing, collapse = ", "), ".",
      call. = FALSE
    )
  }

  is_cat <- vapply(
    data[items], function(x) is.factor(x) || is.character(x), logical(1)
  )
  if (!all(is_cat)) {
    stop(
      "STEM Visualize battery: all items must be categorical ",
      "(factor / character). These are not: ",
      paste(items[!is_cat], collapse = ", "), ".",
      call. = FALSE
    )
  }

  # The core constraint: every item must have the *same* response categories, so
  # they can share a single stacked-bar axis (the point of a battery).
  levels_by_item <- lapply(data[items], stem_col_levels)
  reference <- levels_by_item[[1L]]
  same <- vapply(levels_by_item, function(x) identical(x, reference), logical(1))
  if (!all(same)) {
    stop(
      "STEM Visualize battery requires all selected variables to share the ",
      "same response categories (identical factor levels). These differ from ",
      "\"", items[[1L]], "\": ", paste(items[!same], collapse = ", "), ". ",
      "Pick items from the same battery (e.g. Likert items with one shared scale).",
      call. = FALSE
    )
  }

  if (length(label_hide) != 1L || is.na(label_hide)) label_hide <- 0.05

  # Flip the response scale by reversing every item's categories. Done here (on
  # the data) rather than via a stem_battery() argument because it has none;
  # applied uniformly, so the items still share one scale. Character items are
  # first made factors on their sorted-unique order (stem_col_levels), the same
  # order stem_battery() would otherwise use, so only the direction changes. The
  # "label" attribute is re-attached because factor() drops it - stem_battery()
  # needs it for the item labels when item_label = TRUE.
  if (isTRUE(reverse_levels)) {
    data[items] <- lapply(data[items], function(x) {
      out <- factor(x, levels = rev(stem_col_levels(x)))
      attr(out, "label") <- attr(x, "label", exact = TRUE)
      out
    })
  }

  # Build and evaluate the stem_battery() call. stem_battery() takes `items` (and
  # `weight`) via tidyselect / NSE, so we pass them as bare symbols resolved
  # against the data's columns - `data` is bound in the eval env, matching how
  # blockr binds `.(data)` for the other blocks' emitted calls.
  call_args <- list(
    quote(data),
    items = as.call(c(list(quote(c)), lapply(items, as.name)))
  )
  if (has_col(weight)) call_args[["weight"]] <- as.name(weight)
  if (length(order_by) && any(nzchar(order_by))) {
    call_args[["order_by"]] <- order_by[nzchar(order_by)]
  }
  call_args[["item_label"]] <- isTRUE(item_label)
  call_args[["palette"]] <- palette
  call_args[["direction"]] <- direction
  call_args[["labels"]] <- labels
  call_args[["label_accuracy"]] <- label_accuracy
  call_args[["label_hide"]] <- label_hide

  battery_call <- as.call(c(list(quote(stemtools::stem_battery)), call_args))
  eval(battery_call, envir = list(data = data), enclos = parent.frame())
}

#' STEM Visualize battery block
#'
#' A single blockr block that plots a **battery of same-scale categorical
#' items** - typically a set of Likert items sharing one response scale - as a
#' stacked-bar chart with [stemtools::stem_battery()] (one horizontal bar per
#' item) *and* applies the Stem theme, so the final, styled chart is produced in
#' one place. The user selects several variables from a list; only variables that
#' share **identical response categories** (factor levels) can be plotted
#' together - a mismatched selection produces an informative error (see
#' [stem_battery_plot()]). The block emits a plain ggplot, so it pipes cleanly
#' into [new_stem_export_block()] for PNG / SVG / PowerPoint download.
#'
#' Chart options and theme options live under separate "Advanced" disclosures,
#' mirroring [new_stem_visualize_block()].
#'
#' @param items Character vector of variable (column) names to plot as the
#'   battery. When empty, the block waits for a selection.
#' @param weight Optional name of a numeric column of survey weights. Empty (the
#'   default) plots unweighted proportions.
#' @param order_by Optional character vector of response categories used to order
#'   the items by their combined share, e.g. `c("Strongly agree", "Agree")`. Its
#'   picker is populated with the selected items' shared categories.
#' @param item_label If `TRUE` (default), label each bar with the variable's
#'   `"label"` attribute instead of its name (falls back to the name if absent).
#' @param label_hide Proportions below this threshold are left unlabelled.
#'   Defaults to `0.05`.
#' @param reverse_levels If `TRUE`, reverse the items' response categories
#'   (factor levels) to flip the orientation of the response scale in the plot.
#'   Defaults to `FALSE`.
#' @param label_size Size in points of the inner data labels. Defaults to `14`;
#'   `NA` keeps the stemtools default.
#' @param palette,direction,labels,label_accuracy Chart styling passed to
#'   [stemtools::stem_battery()] (see [new_stem_chart_block()]).
#' @param ink,paper,accent,family Stem theme arguments (see
#'   [new_theme_stem_block()] and [stemtools::theme_stem()]).
#' @param font_size Base text size in points for the axis/legend/title text.
#'   `NA` (the default) keeps the theme's own sizing.
#' @param padding Padding in millimetres added to the plot margin so the extreme
#'   axis labels are not clipped. Defaults to 8 mm.
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class
#'   `stem_visualize_battery_block`.
#'
#' @examples
#' new_stem_visualize_battery_block(items = c("q1", "q2"), accent = "#35978F")
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_stem_visualize_battery_block <- function(items = character(),
                                             weight = character(),
                                             order_by = character(),
                                             item_label = TRUE,
                                             palette = "div1", direction = 1,
                                             labels = TRUE, label_accuracy = 1,
                                             label_hide = 0.05,
                                             reverse_levels = FALSE,
                                             label_size = 14,
                                             ink = "black", paper = "white",
                                             accent = "#35978F",
                                             family = "Calibri",
                                             font_size = NA_real_,
                                             padding = stem_default_padding, ...) {
  new_ggplot_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        cols <- reactive(colnames(data()))

        # chart state
        r_items <- reactiveVal(items)
        r_weight <- reactiveVal(weight)
        r_order_by <- reactiveVal(order_by)
        r_item_label <- reactiveVal(item_label)
        r_palette <- reactiveVal(palette)
        r_direction <- reactiveVal(direction)
        r_labels <- reactiveVal(labels)
        r_label_accuracy <- reactiveVal(label_accuracy)
        r_label_hide <- reactiveVal(label_hide)
        r_reverse_levels <- reactiveVal(reverse_levels)
        r_label_size <- reactiveVal(label_size)
        # theme state
        r_ink <- reactiveVal(ink)
        r_paper <- reactiveVal(paper)
        r_accent <- reactiveVal(accent)
        r_family <- reactiveVal(family)
        r_font_size <- reactiveVal(font_size)
        r_padding <- reactiveVal(padding)

        # A multi-select with nothing chosen reads as NULL, so keep the empty
        # vector (ignoreNULL = FALSE) rather than the starting value.
        observeEvent(input$items, r_items(input$items %||% character()),
          ignoreNULL = FALSE
        )
        observeEvent(input$order_by, r_order_by(input$order_by %||% character()),
          ignoreNULL = FALSE
        )
        observeEvent(input$weight, r_weight(input$weight), ignoreNULL = FALSE)
        observeEvent(input$item_label, r_item_label(isTRUE(input$item_label)))
        observeEvent(input$palette, r_palette(input$palette))
        observeEvent(input$direction, r_direction(as.numeric(input$direction)))
        observeEvent(input$labels, r_labels(isTRUE(input$labels)))
        observeEvent(input$label_accuracy, r_label_accuracy(as.numeric(input$label_accuracy)))
        observeEvent(input$label_hide, r_label_hide(input$label_hide), ignoreNULL = FALSE)
        observeEvent(input$reverse_levels, r_reverse_levels(isTRUE(input$reverse_levels)))
        observeEvent(
          input$label_size,
          r_label_size(
            if (identical(input$label_size, "auto")) NA_real_ else as.numeric(input$label_size)
          )
        )
        observeEvent(input$ink, r_ink(input$ink %||% "black"), ignoreNULL = FALSE)
        observeEvent(input$paper, r_paper(input$paper %||% "white"), ignoreNULL = FALSE)
        observeEvent(input$accent, r_accent(input$accent %||% "#35978F"), ignoreNULL = FALSE)
        observeEvent(input$family, r_family(input$family %||% ""), ignoreNULL = FALSE)
        observeEvent(
          input$font_size,
          r_font_size(
            if (identical(input$font_size, "auto")) NA_real_ else as.numeric(input$font_size)
          )
        )
        observeEvent(input$padding, r_padding(input$padding), ignoreNULL = FALSE)

        # Refresh the item (categorical only) and weight (numeric) pickers from
        # the upstream data, keeping any still-valid selection.
        observeEvent(cols(), {
          item_choices <- stem_cat_var_choices(data())
          updateSelectInput(
            session, "items",
            choices = item_choices,
            selected = intersect(r_items(), item_choices)
          )
          w_choices <- stem_weight_choices(data())
          updateSelectInput(
            session, "weight",
            choices = w_choices,
            selected = if (isTruthy(r_weight()) && r_weight() %in% w_choices) {
              r_weight()
            } else {
              ""
            }
          )
        })

        # The `order_by` choices are the shared response categories of the
        # currently selected items; refresh them (and drop any now-invalid
        # selection) whenever the selection or data changes.
        observeEvent(list(r_items(), cols()), {
          lv <- stem_battery_levels(data(), r_items())
          updateSelectInput(
            session, "order_by",
            choices = lv,
            selected = intersect(r_order_by(), lv)
          )
        })

        list(
          expr = reactive({
            available <- cols()
            req(length(available) > 0)

            chosen <- intersect(r_items(), available)
            # No usable selection yet: wait rather than emit an invalid call.
            req(length(chosen) >= 1)

            plot <- stem_battery_expr(
              items = chosen,
              weight = stem_effective_weight(data(), r_weight()),
              order_by = r_order_by(),
              item_label = r_item_label(),
              palette = r_palette(),
              direction = r_direction(),
              labels = r_labels(),
              label_accuracy = r_label_accuracy(),
              label_hide = r_label_hide(),
              reverse_levels = r_reverse_levels(),
              label_size = r_label_size()
            )
            stem_theme_expr(
              base = plot,
              ink = r_ink(),
              paper = r_paper(),
              accent = r_accent(),
              family = r_family(),
              font_size = r_font_size(),
              padding = r_padding()
            )
          }),
          state = list(
            items = r_items,
            weight = r_weight,
            order_by = r_order_by,
            item_label = r_item_label,
            palette = r_palette,
            direction = r_direction,
            labels = r_labels,
            label_accuracy = r_label_accuracy,
            label_hide = r_label_hide,
            reverse_levels = r_reverse_levels,
            label_size = r_label_size,
            ink = r_ink,
            paper = r_paper,
            accent = r_accent,
            family = r_family,
            font_size = r_font_size,
            padding = r_padding
          )
        )
      })
    },
    function(id) {
      sizes <- c(8, 9, 10, 11, 12, 14, 16, 18, 20)
      size_choices <- c(
        "Auto (stemtools default)" = "auto",
        stats::setNames(as.character(sizes), sizes)
      )
      tagList(
        selectInput(
          NS(id, "items"), "Variables (same response scale)",
          choices = stats::setNames(items, items), selected = items,
          multiple = TRUE
        ),
        tags$p(
          class = "text-muted",
          style = "margin: 4px 0;",
          "Select several variables that share the same response categories ",
          "(e.g. Likert items from one battery)."
        ),
        tags$details(
          tags$summary(
            style = "cursor: pointer; margin: 6px 0; color: #6c757d;",
            "Chart options"
          ),
          div(
            style = "padding-top: 8px;",
            selectInput(
              NS(id, "order_by"), "Order items by (response categories)",
              choices = stats::setNames(order_by, order_by), selected = order_by,
              multiple = TRUE
            ),
            checkboxInput(
              NS(id, "item_label"), "Use variable labels for items",
              value = item_label
            ),
            selectInput(
              NS(id, "weight"), "Survey weight",
              choices = c("(none)" = "", stats::setNames(weight, weight)),
              selected = weight
            ),
            selectInput(
              NS(id, "label_size"), "Label size",
              choices = size_choices,
              selected = if (is.na(label_size)) "auto" else as.character(label_size)
            ),
            selectInput(
              NS(id, "palette"), "Palette",
              choices = c(
                "nom1", "nom2", "seq1", "seq2", "seq3", "seq4",
                "modern", "div1", "div2", "div3"
              ),
              selected = palette
            ),
            radioButtons(
              NS(id, "direction"), "Palette direction",
              choices = c("Default" = "1", "Reversed" = "-1"),
              selected = as.character(direction), inline = TRUE
            ),
            checkboxInput(
              NS(id, "reverse_levels"), "Reverse response scale order",
              value = reverse_levels
            ),
            checkboxInput(NS(id, "labels"), "Show value labels", value = labels),
            selectInput(
              NS(id, "label_accuracy"), "Label accuracy",
              choices = c("Whole numbers" = "1", "One decimal" = "0.1"),
              selected = as.character(label_accuracy)
            ),
            numericInput(
              NS(id, "label_hide"), "Hide labels below (proportion)",
              value = label_hide, min = 0, max = 1, step = 0.01
            )
          )
        ),
        tags$details(
          tags$summary(
            style = "cursor: pointer; margin: 6px 0; color: #6c757d;",
            "Theme options"
          ),
          div(
            style = "padding-top: 8px;",
            colourpicker::colourInput(NS(id, "ink"), "Ink (text & axes)", value = ink),
            colourpicker::colourInput(NS(id, "paper"), "Paper (background)", value = paper),
            colourpicker::colourInput(NS(id, "accent"), "Accent", value = accent),
            textInput(
              NS(id, "family"), "Font family",
              value = family,
              placeholder = "e.g. Calibri (blank = device default)"
            ),
            selectInput(
              NS(id, "font_size"), "Base font size",
              choices = size_choices,
              selected = if (is.na(font_size)) "auto" else as.character(font_size)
            ),
            numericInput(
              NS(id, "padding"), "Padding (mm)",
              value = padding, min = 0, step = 1
            )
          )
        )
      )
    },
    class = "stem_visualize_battery_block",
    # Optional/NA-able fields must be allowed empty or the block gates on
    # "waiting for its inputs to be set". `items`/`order_by` start empty until the
    # user selects; `weight`/`label_size`/`label_hide`/`family`/`font_size`/
    # `padding` are optional or NA-able.
    allow_empty_state = c(
      "items", "weight", "order_by", "label_size", "label_hide",
      "family", "font_size", "padding"
    ),
    expr_type = "bquoted",
    ...
  )
}
