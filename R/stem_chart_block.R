#' STEM Chart block
#'
#' A blockr transform block that plots a single variable from an upstream data
#' frame using one of the \pkg{stemtools} plotting functions. The user picks a
#' variable and chooses between a bar plot ([stemtools::stem_barplot()]) and an
#' inline plot ([stemtools::stem_inline()]). Styling arguments (label size,
#' palette, label options) are tucked under an "Advanced options" disclosure.
#'
#' @param var Name of the variable (column) to plot. When empty, the first
#'   column of the upstream data is used.
#' @param type Chart type, one of `"barplot"` or `"inline"`.
#' @param weight Optional name of a numeric column of survey weights to pass to
#'   the stemtools function. Empty (the default) plots unweighted counts.
#' @param label_size Size in points of the inner data labels (the percentage
#'   labels drawn on the bars). Defaults to `14`; use `NA` to keep the stemtools
#'   default sizing instead. To restyle the axis/legend text, use
#'   [new_theme_stem_block()] downstream instead.
#' @param palette Name of a Stem palette passed to the plotting function, e.g.
#'   `"div1"`. See [stemtools::stem_palette()].
#' @param direction Palette direction: `1` (default) or `-1` to reverse.
#' @param labels If `TRUE`, print a percentage label on each bar.
#' @param label_accuracy Rounding accuracy of labels; `1` gives whole numbers,
#'   `0.1` one decimal place.
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class `stem_chart_block`.
#'
#' @examples
#' new_stem_chart_block(var = "Species", type = "barplot", label_size = 5)
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_stem_chart_block <- function(var = character(), type = c("barplot", "inline"),
                                 weight = character(), label_size = 14,
                                 palette = "div1", direction = 1, labels = TRUE,
                                 label_accuracy = 1, ...) {
  type <- match.arg(type)

  new_ggplot_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        cols <- reactive(colnames(data()))
        r_var <- reactiveVal(var)
        r_type <- reactiveVal(type)
        r_weight <- reactiveVal(weight)
        r_label_size <- reactiveVal(label_size)
        r_palette <- reactiveVal(palette)
        r_direction <- reactiveVal(direction)
        r_labels <- reactiveVal(labels)
        r_label_accuracy <- reactiveVal(label_accuracy)

        observeEvent(input$var, r_var(input$var))
        observeEvent(input$type, r_type(input$type))
        observeEvent(input$weight, r_weight(input$weight), ignoreNULL = FALSE)
        observeEvent(
          input$label_size,
          r_label_size(
            if (identical(input$label_size, "auto")) NA_real_ else as.numeric(input$label_size)
          )
        )
        observeEvent(input$palette, r_palette(input$palette))
        observeEvent(input$direction, r_direction(as.numeric(input$direction)))
        observeEvent(input$labels, r_labels(isTRUE(input$labels)))
        observeEvent(input$label_accuracy, r_label_accuracy(as.numeric(input$label_accuracy)))

        # Populate / refresh the variable and weight pickers from the upstream
        # data; the variable picker shows each column's label (attr(x, "label")).
        observeEvent(cols(), {
          selected <- if (isTruthy(r_var()) && r_var() %in% cols()) {
            r_var()
          } else {
            cols()[1]
          }
          updateSelectInput(
            session, "var",
            choices = stem_var_choices(data()),
            selected = selected
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

        list(
          expr = reactive({
            available <- cols()
            req(length(available) > 0)

            col <- r_var()
            if (!isTruthy(col) || !col %in% available) {
              col <- available[1]
            }

            stem_plot_expr(
              item = as.name(col),
              type = r_type(),
              weight = stem_effective_weight(data(), r_weight()),
              group = stem_effective_group(data()),
              palette = r_palette(),
              direction = r_direction(),
              labels = r_labels(),
              label_accuracy = r_label_accuracy(),
              label_size = r_label_size()
            )
          }),
          state = list(
            var = r_var,
            type = r_type,
            weight = r_weight,
            label_size = r_label_size,
            palette = r_palette,
            direction = r_direction,
            labels = r_labels,
            label_accuracy = r_label_accuracy
          )
        )
      })
    },
    function(id) {
      sizes <- c(8, 9, 10, 11, 12, 14, 16, 18, 20)
      tagList(
        selectInput(
          NS(id, "var"), "Variable",
          choices = var, selected = var
        ),
        radioButtons(
          NS(id, "type"), "Chart type",
          choices = c("Bar plot" = "barplot", "Inline plot" = "inline"),
          selected = type, inline = TRUE
        ),
        tags$details(
          class = "stem-chart-advanced",
          tags$summary(
            style = "cursor: pointer; margin: 6px 0; color: #6c757d;",
            "Advanced options"
          ),
          div(
            style = "padding-top: 8px;",
            selectInput(
              NS(id, "weight"), "Survey weight",
              choices = c("(none)" = "", stats::setNames(weight, weight)),
              selected = weight
            ),
            selectInput(
              NS(id, "label_size"), "Label size",
              choices = c(
                "Auto (stemtools default)" = "auto",
                stats::setNames(as.character(sizes), sizes)
              ),
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
              NS(id, "labels"), "Show value labels",
              value = labels
            ),
            selectInput(
              NS(id, "label_accuracy"), "Label accuracy",
              choices = c("Whole numbers" = "1", "One decimal" = "0.1"),
              selected = as.character(label_accuracy)
            )
          )
        )
      )
    },
    class = "stem_chart_block",
    # `var` (falls back to first column), `weight` (optional) and `label_size`
    # (NA when "auto") all read as empty, so they must be allowed empty or the
    # block gates on "waiting for its inputs to be set".
    allow_empty_state = c("var", "weight", "label_size"),
    expr_type = "bquoted",
    ...
  )
}
