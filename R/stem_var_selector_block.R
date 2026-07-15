#' STEM Variable Selector block
#'
#' A blockr transform block that lists the categorical (factor / character)
#' variables of an upstream data frame in a searchable table showing each
#' variable's name, its label (`attr(x, "label")`) and its number of categories.
#' Clicking a row selects that variable; the block outputs the single selected
#' column (its label preserved), ready to feed a [new_stem_chart_block()] for
#' plotting - and a [new_theme_stem_block()] after that for styling.
#'
#' The table and the plot live in separate blocks that can be moved around
#' independently, so the chart's advanced settings and a downstream theme block
#' stay fully accessible. Compose it as Selector -> [new_stem_chart_block()] ->
#' [new_theme_stem_block()].
#'
#' @param var Name of the variable to select. When empty, the first categorical
#'   variable is used. Normally set by clicking a table row.
#' @param weight Optional name of a numeric column of survey weights to carry
#'   forward. Empty (the default) means unweighted. When set, the block outputs
#'   the weight column alongside the selected variable and tags it so a
#'   downstream [new_stem_chart_block()] / [new_stem_visualize_block()] weights
#'   the plot automatically.
#' @param group Optional name of a categorical column to break the plot down by.
#'   Empty (the default) means no grouping. When set, a downstream bar plot draws
#'   one stacked bar per category of this grouping variable (on the axis) and
#'   shows the *selected* variable as the coloured fill series - so the number of
#'   colours is the selected variable's category count. Grouping is only applied
#'   to `stem_barplot()`, not `stem_inline()`.
#' @param ... Forwarded to [blockr.core::new_transform_block()].
#'
#' @return A transform block object of class `stem_var_selector_block`.
#'
#' @examples
#' new_stem_var_selector_block()
#'
#' @importFrom blockr.core new_transform_block
#' @import shiny
#' @export
new_stem_var_selector_block <- function(var = character(), weight = character(),
                                        group = character(), ...) {
  new_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        cat_vars <- reactive(stem_cat_vars(data()))
        r_var <- reactiveVal(var)
        r_weight <- reactiveVal(weight)
        r_group <- reactiveVal(group)

        output$vars <- DT::renderDT(
          {
            tbl <- cat_vars()
            preselect <- if (nrow(tbl) > 0) 1L else NULL
            DT::datatable(
              tbl,
              rownames = FALSE,
              filter = "top",
              selection = list(mode = "single", selected = preselect),
              options = list(
                pageLength = 10,
                scrollY = "320px",
                scrollCollapse = TRUE
              )
            )
          },
          server = TRUE
        )

        observeEvent(input$vars_rows_selected, {
          tbl <- cat_vars()
          i <- input$vars_rows_selected
          if (length(i) == 1L && i >= 1L && i <= nrow(tbl)) {
            r_var(tbl$Variable[i])
          }
        })

        observeEvent(input$weight, r_weight(input$weight), ignoreNULL = FALSE)
        observeEvent(input$group, r_group(input$group), ignoreNULL = FALSE)

        # Refresh the weight (numeric) and group (categorical) pickers from the
        # upstream data.
        observeEvent(data(), {
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
          g_choices <- stem_group_choices(data())
          updateSelectInput(
            session, "group",
            choices = g_choices,
            selected = if (isTruthy(r_group()) && r_group() %in% g_choices) {
              r_group()
            } else {
              ""
            }
          )
        })

        list(
          expr = reactive({
            tbl <- cat_vars()
            req(nrow(tbl) > 0)

            col <- r_var()
            if (!isTruthy(col) || !col %in% tbl$Variable) {
              col <- tbl$Variable[1]
            }

            # Output the selected column (label attribute kept). When a weight
            # and/or group is chosen, also carry those columns, tagged via
            # `stem_weight` / `stem_group`.
            stem_select_expr(var = col, weight = r_weight(), group = r_group())
          }),
          state = list(var = r_var, weight = r_weight, group = r_group)
        )
      })
    },
    function(id) {
      tagList(
        selectInput(
          NS(id, "group"), "Grouping variable (optional)",
          choices = c("(none)" = "", stats::setNames(group, group)),
          selected = group
        ),
        selectInput(
          NS(id, "weight"), "Survey weight (optional)",
          choices = c("(none)" = "", stats::setNames(weight, weight)),
          selected = weight
        ),
        tags$p(
          class = "text-muted",
          style = "margin: 4px 0;",
          "Search and click a variable to select it for plotting."
        ),
        DT::DTOutput(NS(id, "vars"))
      )
    },
    class = "stem_var_selector_block",
    # `var` (falls back to first categorical variable), `weight` and `group`
    # (both optional) read as empty, so they must be allowed empty.
    allow_empty_state = c("var", "weight", "group"),
    expr_type = "bquoted",
    ...
  )
}

#' @description
#' The block's output panel shows the selected variable's (weighted) frequency
#' distribution rather than the raw responses. The block's *value* passed to
#' downstream blocks is still the underlying data, so a STEM Chart can plot it.
#'
#' @param x,result,session Passed by blockr when rendering the block output.
#' @rdname new_stem_var_selector_block
#' @exportS3Method blockr.core::block_output
block_output.stem_var_selector_block <- function(x, result, session) {
  var <- names(result)[1L]
  weight <- attr(result, "stem_weight", exact = TRUE)
  group <- attr(result, "stem_group", exact = TRUE)
  DT::renderDT(
    stem_freq_table(result, var, weight, group),
    server = TRUE,
    rownames = FALSE,
    options = list(dom = "ti", pageLength = 50, ordering = FALSE)
  )
}
