#' STEM Visualize block
#'
#' A single blockr block that plots a variable with a \pkg{stemtools} function
#' *and* applies the Stem theme, so the final, styled chart is produced in one
#' place - combining everything [new_stem_chart_block()] and
#' [new_theme_stem_block()] offer without having to wire (or jump between) two
#' blocks. Chart options and theme options live under separate "Advanced"
#' disclosures.
#'
#' @param var Name of the variable (column) to plot. When empty, the first
#'   column of the upstream data is used.
#' @param type Chart type, one of `"barplot"` or `"inline"`.
#' @param weight Optional name of a numeric column of survey weights. Empty (the
#'   default) plots unweighted counts.
#' @param label_size Size in points of the inner data labels. Defaults to `14`;
#'   `NA` keeps the stemtools default.
#' @param palette,direction,labels,label_accuracy Chart styling passed to the
#'   stemtools function (see [new_stem_chart_block()]).
#' @param ink,paper,accent,family Stem theme arguments (see
#'   [new_theme_stem_block()] and [stemtools::theme_stem()]).
#' @param font_size Base text size in points for the axis/legend/title text.
#'   `NA` (the default) keeps the theme's own sizing.
#' @param padding Padding in millimetres added to the plot margin so the extreme
#'   axis labels (e.g. "0 %" / "100 %") are not clipped. Defaults to 8 mm.
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class `stem_visualize_block`.
#'
#' @examples
#' new_stem_visualize_block(var = "Species", accent = "#35978F")
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_stem_visualize_block <- function(var = character(),
                                     type = c("barplot", "inline"),
                                     weight = character(), label_size = 14,
                                     palette = "div1", direction = 1,
                                     labels = TRUE, label_accuracy = 1,
                                     ink = "black", paper = "white",
                                     accent = "#35978F", family = "Calibri",
                                     font_size = NA_real_,
                                     padding = stem_default_padding, ...) {
  type <- match.arg(type)

  new_ggplot_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        cols <- reactive(colnames(data()))

        # chart state
        r_var <- reactiveVal(var)
        r_type <- reactiveVal(type)
        r_weight <- reactiveVal(weight)
        r_label_size <- reactiveVal(label_size)
        r_palette <- reactiveVal(palette)
        r_direction <- reactiveVal(direction)
        r_labels <- reactiveVal(labels)
        r_label_accuracy <- reactiveVal(label_accuracy)
        # theme state
        r_ink <- reactiveVal(ink)
        r_paper <- reactiveVal(paper)
        r_accent <- reactiveVal(accent)
        r_family <- reactiveVal(family)
        r_font_size <- reactiveVal(font_size)
        r_padding <- reactiveVal(padding)

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

        observeEvent(cols(), {
          selected <- if (isTruthy(r_var()) && r_var() %in% cols()) {
            r_var()
          } else {
            cols()[1]
          }
          updateSelectInput(
            session, "var",
            choices = stem_var_choices(data()), selected = selected
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

            plot <- stem_plot_expr(
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
            var = r_var,
            type = r_type,
            weight = r_weight,
            label_size = r_label_size,
            palette = r_palette,
            direction = r_direction,
            labels = r_labels,
            label_accuracy = r_label_accuracy,
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
        selectInput(NS(id, "var"), "Variable", choices = var, selected = var),
        radioButtons(
          NS(id, "type"), "Chart type",
          choices = c("Bar plot" = "barplot", "Inline plot" = "inline"),
          selected = type, inline = TRUE
        ),
        tags$details(
          tags$summary(
            style = "cursor: pointer; margin: 6px 0; color: #6c757d;",
            "Chart options"
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
            checkboxInput(NS(id, "labels"), "Show value labels", value = labels),
            selectInput(
              NS(id, "label_accuracy"), "Label accuracy",
              choices = c("Whole numbers" = "1", "One decimal" = "0.1"),
              selected = as.character(label_accuracy)
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
    class = "stem_visualize_block",
    # Optional/NA-able fields must be allowed empty or the block gates on
    # "waiting for its inputs to be set".
    allow_empty_state = c("var", "weight", "label_size", "family", "font_size", "padding"),
    expr_type = "bquoted",
    ...
  )
}
