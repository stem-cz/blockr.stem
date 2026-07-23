#' STEM Excel Export block
#'
#' A blockr block that exports the upstream data set as a **readable MS Excel
#' spreadsheet** of frequency tables, built with
#' [spreadview::compose_spreadsheet()]. The variables to tabulate are picked
#' automatically with [spreadview::get_categorical_vars()] - every factor column
#' (plus character columns when `include_char` is on), minus any the user chooses
#' to `exclude`. Optional grouping variables and a survey weight are forwarded to
#' `compose_spreadsheet()`.
#'
#' The block passes its input data through unchanged, so it can sit anywhere in a
#' pipeline; its output panel previews the data being exported and the *Download*
#' button writes the `.xlsx` file.
#'
#' Excel export requires the \pkg{spreadview} package (GitHub only). If it is not
#' installed the download reports an error explaining how to install it.
#'
#' @param include_char When `TRUE`, character columns are tabulated alongside
#'   factor columns; when `FALSE` (the default) only factors are, matching
#'   [spreadview::get_categorical_vars()]'s default.
#' @param exclude Character vector of variable names to drop from the automatic
#'   categorical selection (passed to `get_categorical_vars()`'s `exclude`).
#'   Empty (the default) excludes nothing.
#' @param group Optional character vector of categorical variables to break the
#'   frequency tables down by (passed to `compose_spreadsheet()`'s `group`).
#'   Empty (the default) means no grouping.
#' @param weight Optional name of a numeric column of survey weights (passed to
#'   `compose_spreadsheet()`'s `weight`). Empty (the default) means unweighted.
#' @param percent When `TRUE` (the default) cells are formatted as percentages,
#'   otherwise as plain counts (`compose_spreadsheet()`'s `percent`).
#' @param na_rm When `TRUE` (the default) missing values are dropped from the
#'   tables (`compose_spreadsheet()`'s `na.rm`).
#' @param ... Forwarded to [blockr.core::new_transform_block()].
#'
#' @return A transform block object of class `stem_spreadsheet_export_block`.
#'
#' @examples
#' new_stem_spreadsheet_export_block()
#'
#' @importFrom blockr.core new_transform_block
#' @import shiny
#' @export
new_stem_spreadsheet_export_block <- function(include_char = FALSE,
                                              exclude = character(),
                                              group = character(),
                                              weight = character(),
                                              percent = TRUE, na_rm = TRUE,
                                              ...) {
  new_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        r_include_char <- reactiveVal(include_char)
        r_exclude <- reactiveVal(exclude)
        r_group <- reactiveVal(group)
        r_weight <- reactiveVal(weight)
        r_percent <- reactiveVal(percent)
        r_na_rm <- reactiveVal(na_rm)

        observeEvent(input$include_char, r_include_char(input$include_char))
        observeEvent(input$exclude, r_exclude(input$exclude), ignoreNULL = FALSE)
        observeEvent(input$group, r_group(input$group), ignoreNULL = FALSE)
        observeEvent(input$weight, r_weight(input$weight), ignoreNULL = FALSE)
        observeEvent(input$percent, r_percent(input$percent))
        observeEvent(input$na_rm, r_na_rm(input$na_rm))

        # Refresh the pickers from the upstream data. The exclude list mirrors
        # get_categorical_vars()'s own selection, so it depends on include_char
        # (factors only, or factors + characters); the group list offers any
        # categorical column (only categoricals can be a grouping variable) and
        # the weight list the numeric columns. Each label carries the variable's
        # number of unique categories, e.g. "reg (13)".
        observeEvent(list(data(), r_include_char()), {
          ex_choices <- stem_spread_cat_choices(data(), r_include_char())
          updateSelectInput(
            session, "exclude",
            choices = ex_choices,
            selected = intersect(r_exclude(), ex_choices)
          )
          g_choices <- stem_spread_cat_choices(data(), include_char = TRUE)
          updateSelectInput(
            session, "group",
            choices = g_choices,
            selected = intersect(r_group(), g_choices)
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

        output$download <- downloadHandler(
          filename = function() "stem-spreadsheet.xlsx",
          content = function(file) {
            stem_write_spreadsheet(
              data = data(),
              file = file,
              exclude = r_exclude(),
              include_char = r_include_char(),
              group = r_group(),
              weight = r_weight(),
              percent = r_percent(),
              na.rm = r_na_rm()
            )
          }
        )

        list(
          # Pass the data through unchanged so downstream blocks (and the output
          # preview) see the exported data set.
          expr = reactive(quote(.(data))),
          state = list(
            include_char = r_include_char, exclude = r_exclude, group = r_group,
            weight = r_weight, percent = r_percent, na_rm = r_na_rm
          )
        )
      })
    },
    function(id) {
      tagList(
        checkboxInput(
          NS(id, "include_char"),
          "Include character variables (not only factors)",
          value = include_char
        ),
        selectInput(
          NS(id, "exclude"), "Exclude variables (optional)",
          choices = stats::setNames(exclude, exclude), selected = exclude,
          multiple = TRUE
        ),
        selectInput(
          NS(id, "group"), "Grouping variables (optional)",
          choices = stats::setNames(group, group), selected = group,
          multiple = TRUE
        ),
        selectInput(
          NS(id, "weight"), "Survey weight (optional)",
          choices = c("(none)" = "", stats::setNames(weight, weight)),
          selected = weight
        ),
        tags$details(
          tags$summary("More options"),
          checkboxInput(
            NS(id, "percent"), "Format cells as percentages", value = percent
          ),
          checkboxInput(
            NS(id, "na_rm"), "Drop missing values", value = na_rm
          )
        ),
        tags$p(
          class = "text-muted",
          style = "margin: 4px 0;",
          "All factor variables (add character variables above) are tabulated, ",
          "except any you exclude. The label after each name is its number of ",
          "unique categories."
        ),
        downloadButton(
          NS(id, "download"), "Download Excel", class = "btn-primary"
        )
      )
    },
    class = "stem_spreadsheet_export_block",
    # Every control may legitimately read as empty/falsy: the two checkboxes can
    # be FALSE, and exclude / group / weight can be unset. Listing them all keeps
    # the block from gating on "waiting for inputs" (it always renders, since it
    # just passes the data through).
    allow_empty_state = c(
      "include_char", "exclude", "group", "weight", "percent", "na_rm"
    ),
    expr_type = "bquoted",
    ...
  )
}

#' @description
#' The block's output panel previews the (pass-through) data set that will be
#' exported as a table.
#'
#' @param x,result,session Passed by blockr when rendering the block output.
#' @rdname new_stem_spreadsheet_export_block
#' @exportS3Method blockr.core::block_output
block_output.stem_spreadsheet_export_block <- function(x, result, session) {
  DT::renderDT(
    result,
    server = TRUE,
    rownames = FALSE,
    options = list(pageLength = 10, scrollX = TRUE)
  )
}

# Named choices "<col> (<n categories>)" => "<col>" for the Excel export block's
# exclude / group pickers. `include_char` mirrors get_categorical_vars(): FALSE
# offers only factor columns, TRUE factor and character columns.
stem_spread_cat_choices <- function(data, include_char = FALSE) {
  # Upstream data is NULL until a source block produces it (e.g. STEM Import
  # before a file is chosen); return no choices rather than erroring on the
  # `setNames(NULL, ...)` below.
  if (is.null(data) || !length(data)) {
    return(character())
  }
  is_cat <- vapply(
    data,
    function(x) is.factor(x) || (isTRUE(include_char) && is.character(x)),
    logical(1)
  )
  cols <- names(data)[is_cat]
  n <- vapply(
    cols, function(nm) length(unique(data[[nm]])), integer(1), USE.NAMES = FALSE
  )
  stats::setNames(cols, sprintf("%s (%d)", cols, n))
}

# Write `data` to an Excel file at `file` with spreadview::compose_spreadsheet().
# The tabulated `vars` are chosen with spreadview::get_categorical_vars() (all
# factor columns, plus character columns when include_char is TRUE) minus
# `exclude`; empty exclude / group / weight selections become NULL. Errors
# clearly when the GitHub-only spreadview package is missing.
stem_write_spreadsheet <- function(data, file, exclude = NULL,
                                   include_char = FALSE, group = NULL,
                                   weight = NULL, percent = TRUE, na.rm = TRUE) {
  if (!requireNamespace("spreadview", quietly = TRUE)) {
    stop(
      "Excel export requires the 'spreadview' package. Install it with ",
      "remotes::install_github(\"alesvomacka/spreadview\")."
    )
  }
  exclude <- exclude[nzchar(exclude)]
  group <- group[nzchar(group)]
  group <- if (length(group)) group else NULL
  vars <- spreadview::get_categorical_vars(
    data,
    exclude = if (length(exclude)) exclude else NULL,
    include_char = isTRUE(include_char)
  )
  # compose_spreadsheet() requires every tabulated var and grouping column to be
  # a factor, but get_categorical_vars(include_char = TRUE) can return character
  # columns (and a character grouping var is otherwise valid) - coerce those to
  # factor, keeping any variable label so the output headings stay readable.
  for (nm in intersect(c(vars, group), names(data))) {
    col <- data[[nm]]
    if (is.character(col)) {
      lab <- attr(col, "label", exact = TRUE)
      col <- factor(col)
      if (!is.null(lab)) attr(col, "label") <- lab
      data[[nm]] <- col
    }
  }
  # compose_spreadsheet() emits informational warnings/messages (e.g. about
  # weighting) that are noise in a blockr app's console - the block surfaces
  # errors through the download instead, so quiet the chatter here.
  suppressMessages(suppressWarnings(
    spreadview::compose_spreadsheet(
      data = data,
      vars = vars,
      group = group,
      weight = if (has_col(weight)) weight else NULL,
      file = file,
      na.rm = isTRUE(na.rm),
      percent = isTRUE(percent)
    )
  ))
  invisible(file)
}
