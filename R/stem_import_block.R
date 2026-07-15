#' STEM Import block
#'
#' A blockr data block that imports a data set from a file - like the
#' "Import Data" block (`read_block`) from **blockr.io**, but the file is chosen
#' with a graphical point-and-click file browser (via \pkg{shinyFiles}) instead
#' of by typing a path. It is a root node in an analysis graph: it takes no data
#' input and provides data to down-stream blocks.
#'
#' The selected file is read with the reader that matches its format, mirroring
#' `read_block`: delimited text (`.csv`/`.tsv`/`.txt`/...) with [readr::read_csv()]
#' and friends, spreadsheets (`.xlsx`/`.xls`/...) with [readxl::read_excel()], and
#' everything else (`.rds`, `.sav`, `.dta`, `.parquet`, ...) with [rio::import()].
#' A gear popover next to the file button exposes the format-specific options
#' (CSV delimiter/quote/encoding/skip/rows/header; Excel sheet/range/skip/rows/
#' header), shown only for the matching file type - just like `read_block`.
#'
#' This exists because `blockr.core`'s `filebrowser_block` builds its output
#' expression as the bare file path (`bquote(.(file), ...)`) rather than a call
#' that reads the file, so picking a `.rds` file yields the path string instead
#' of the data. This block wraps the picked path in a real read call.
#'
#' @param file_path Initial file path. Normally left empty and set by picking a
#'   file in the browser.
#' @param args Named list of format-specific reader options (see Details).
#'   Normally left empty and set via the gear popover.
#' @param volumes Named character vector of root directories the file browser may
#'   navigate, passed to [shinyFiles::shinyFileChoose()]. Defaults to
#'   [stem_import_volumes()] (Home and the filesystem root).
#' @param ... Forwarded to [blockr.core::new_block()].
#'
#' @return A data block object of class `stem_import_block`.
#'
#' @examples
#' new_stem_import_block()
#'
#' @importFrom blockr.core new_file_block
#' @import shiny
#' @export
new_stem_import_block <- function(file_path = character(), args = list(),
                                  volumes = stem_import_volumes(), ...) {
  new_file_block(
    function(id) {
      moduleServer(id, function(input, output, session) {
        r_path <- reactiveVal(file_path)
        r_args <- reactiveVal(args)
        detected_type <- reactiveVal(
          if (length(file_path) > 0 && nzchar(file_path[[1]])) {
            stem_file_category(file_path[[1]])
          } else {
            "unknown"
          }
        )

        shinyFiles::shinyFileChoose(input, "file", roots = volumes)

        observeEvent(input$file, {
          sel <- shinyFiles::parseFilePaths(volumes, input$file)$datapath
          if (length(sel) > 0 && nzchar(sel)) {
            r_path(unname(sel))
            detected_type(stem_file_category(sel))
          }
        })

        # Collect CSV options into r_args.
        observeEvent(input$csv_sep, {
          a <- r_args()
          a$sep <- input$csv_sep
          r_args(a)
        })
        observeEvent(input$csv_quote, {
          a <- r_args()
          a$quote <- input$csv_quote
          r_args(a)
        })
        observeEvent(input$csv_encoding, {
          a <- r_args()
          a$encoding <- input$csv_encoding
          r_args(a)
        })
        observeEvent(input$csv_skip, {
          a <- r_args()
          a$skip <- if (input$csv_skip == "") 0 else as.numeric(input$csv_skip)
          r_args(a)
        })
        observeEvent(input$csv_n_max, {
          a <- r_args()
          a$n_max <- if (input$csv_n_max == "") Inf else as.numeric(input$csv_n_max)
          r_args(a)
        })
        observeEvent(input$csv_col_names, {
          a <- r_args()
          a$col_names <- input$csv_col_names
          r_args(a)
        })

        # Collect Excel options into r_args.
        observeEvent(input$excel_sheet, {
          a <- r_args()
          a$sheet <- if (input$excel_sheet == "") NULL else input$excel_sheet
          r_args(a)
        })
        observeEvent(input$excel_range, {
          a <- r_args()
          a$range <- if (input$excel_range == "") NULL else input$excel_range
          r_args(a)
        })
        observeEvent(input$excel_skip, {
          a <- r_args()
          a$skip <- if (input$excel_skip == "") 0 else as.numeric(input$excel_skip)
          r_args(a)
        })
        observeEvent(input$excel_n_max, {
          a <- r_args()
          a$n_max <- if (input$excel_n_max == "") Inf else as.numeric(input$excel_n_max)
          r_args(a)
        })
        observeEvent(input$excel_col_names, {
          a <- r_args()
          a$col_names <- input$excel_col_names
          r_args(a)
        })

        output$selected <- renderText({
          p <- r_path()
          if (length(p) == 0 || !nzchar(p)) {
            "No file selected yet."
          } else {
            paste0("Selected: ", basename(p))
          }
        })

        # Drive the conditionalPanels in the gear popover.
        output$show_csv_options <- reactive(identical(detected_type(), "csv"))
        output$show_excel_options <- reactive(identical(detected_type(), "excel"))
        output$show_no_options <- reactive({
          !identical(detected_type(), "csv") &&
            !identical(detected_type(), "excel")
        })
        outputOptions(output, "show_csv_options", suspendWhenHidden = FALSE)
        outputOptions(output, "show_excel_options", suspendWhenHidden = FALSE)
        outputOptions(output, "show_no_options", suspendWhenHidden = FALSE)

        list(
          expr = reactive({
            p <- r_path()
            req(length(p) > 0, nzchar(p))
            stem_read_expr(p, r_args())
          }),
          # `volumes` is a constructor argument, so blockr requires it in the
          # state as well (it is static config, kept as-is rather than reactive).
          state = list(file_path = r_path, args = r_args, volumes = volumes)
        )
      })
    },
    function(id) {
      gear_id <- NS(id, "gear_btn")
      popover_id <- NS(id, "gear_popover")
      tagList(
        stem_import_css(),
        div(
          class = "block-container",
          div(
            class = "blockr-stem-import-header",
            shinyFiles::shinyFilesButton(
              NS(id, "file"),
              label = "Choose file\u2026",
              title = "Select a data file to import",
              multiple = FALSE,
              class = "btn-primary"
            ),
            div(
              class = "blockr-gear-host",
              tags$button(
                type = "button", id = gear_id, class = "blockr-gear-btn",
                title = "Format options", `aria-label` = "Format options",
                `aria-controls` = popover_id, `aria-expanded` = "false",
                onclick = sprintf(
                  "window.blockrStemGearToggle && window.blockrStemGearToggle('%s','%s');",
                  gear_id, popover_id
                ),
                HTML(stem_gear_icon_svg())
              ),
              div(
                id = popover_id, class = "blockr-popover", style = "display: none;",
                role = "dialog", `aria-label` = "Format options",
                tags$h4("Format-Specific Options"),
                conditionalPanel(
                  condition = "output['show_no_options']", ns = NS(id),
                  tags$p(
                    class = "blockr-popover-hint",
                    "No options for this file type - read as-is."
                  )
                ),
                conditionalPanel(
                  condition = "output['show_csv_options']", ns = NS(id),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Delimiter"),
                    selectizeInput(
                      NS(id, "csv_sep"), NULL,
                      choices = c(
                        `Comma (,)` = ",", `Semicolon (;)` = ";",
                        `Tab (\\t)` = "\t", `Pipe (|)` = "|"
                      ),
                      selected = args$sep %||% ",",
                      options = list(create = TRUE), width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Quote character"),
                    textInput(
                      NS(id, "csv_quote"), NULL,
                      value = args$quote %||% "\"",
                      placeholder = "default: \"", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Encoding"),
                    selectInput(
                      NS(id, "csv_encoding"), NULL,
                      choices = c("UTF-8", "Latin-1", "Windows-1252", "ISO-8859-1"),
                      selected = args$encoding %||% "UTF-8", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Skip rows"),
                    textInput(
                      NS(id, "csv_skip"), NULL,
                      value = if (!is.null(args$skip)) as.character(args$skip) else "",
                      placeholder = "default: 0", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Max rows to read"),
                    textInput(
                      NS(id, "csv_n_max"), NULL,
                      value = if (!is.null(args$n_max) && !is.infinite(args$n_max)) {
                        as.character(args$n_max)
                      } else {
                        ""
                      },
                      placeholder = "default: all rows", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    checkboxInput(
                      NS(id, "csv_col_names"), "First row is header",
                      value = args$col_names %||% TRUE
                    )
                  )
                ),
                conditionalPanel(
                  condition = "output['show_excel_options']", ns = NS(id),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Sheet name or number"),
                    textInput(
                      NS(id, "excel_sheet"), NULL,
                      value = args$sheet %||% "",
                      placeholder = "default: first sheet", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Cell range"),
                    textInput(
                      NS(id, "excel_range"), NULL,
                      value = args$range %||% "",
                      placeholder = "e.g. A1:D100", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Skip rows"),
                    textInput(
                      NS(id, "excel_skip"), NULL,
                      value = if (!is.null(args$skip)) as.character(args$skip) else "",
                      placeholder = "default: 0", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    tags$label(class = "blockr-popover-label", "Max rows to read"),
                    textInput(
                      NS(id, "excel_n_max"), NULL,
                      value = if (!is.null(args$n_max) && !is.infinite(args$n_max)) {
                        as.character(args$n_max)
                      } else {
                        ""
                      },
                      placeholder = "default: all rows", width = "100%"
                    )
                  ),
                  div(
                    class = "blockr-popover-row",
                    checkboxInput(
                      NS(id, "excel_col_names"), "First row is header",
                      value = args$col_names %||% TRUE
                    )
                  )
                )
              )
            )
          ),
          tags$p(
            class = "text-muted", style = "margin: 8px 0 0;",
            textOutput(NS(id, "selected"), inline = TRUE)
          )
        )
      )
    },
    class = "stem_import_block",
    # `args` reads as an empty list until options are set, so it must be allowed
    # to be empty; `file_path` is intentionally NOT allowed empty, so the block
    # waits until a file has been picked before it renders.
    allow_empty_state = "args",
    ...
  )
}

#' @description
#' `stem_import_volumes()` returns the default set of root directories offered by
#' the file browser: the user's home directory and the filesystem root.
#'
#' @rdname new_stem_import_block
#' @export
stem_import_volumes <- function() {
  c(Home = path.expand("~"), Root = "/")
}

# Self-contained gear-popover styling + toggle (a trimmed port of blockr.io's
# read_block popover, kept internal so blockr.stem needs no blockr.io internals).
stem_import_css <- function() {
  tagList(
    tags$style(HTML("
      .blockr-stem-import-header {
        display: flex; align-items: center; gap: 8px;
      }
      .blockr-gear-host { position: relative; }
      .blockr-gear-btn {
        display: inline-flex; align-items: center; justify-content: center;
        width: 32px; height: 32px; color: #9ca3af; background: transparent;
        border: 1px solid #e5e7eb; border-radius: 4px; cursor: pointer;
        transition: color .15s ease, border-color .15s ease, background .15s ease;
      }
      .blockr-gear-btn:hover, .blockr-gear-btn.blockr-gear-active {
        color: #2563eb; border-color: rgba(37,99,235,.3);
        background: rgba(37,99,235,.06);
      }
      .blockr-popover {
        position: absolute; right: 0; top: calc(100% + 4px); z-index: 1000;
        background: #fff; border: 1px solid #e5e7eb; border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,.1); padding: 12px 14px;
        min-width: 320px; max-width: 380px; max-height: 70vh; overflow-y: auto;
      }
      .blockr-popover-row { margin-bottom: 10px; }
      .blockr-popover-row:last-child { margin-bottom: 0; }
      .blockr-popover-label {
        display: block; font-size: .75rem; font-weight: 500; color: #6b7280;
        margin-bottom: .25rem;
      }
      .blockr-popover-hint { font-size: .8125rem; color: #6b7280; margin: 0; }
      .blockr-popover h4 {
        font-size: .8125rem; font-weight: 600; color: #374151; margin: 0 0 8px;
      }
      .blockr-popover .form-group, .blockr-popover .shiny-input-container {
        margin-bottom: 0; width: 100% !important;
      }
      .blockr-popover .selectize-control { width: 100% !important; margin-bottom: 0; }
    ")),
    tags$script(HTML("
      (function() {
        if (window.blockrStemGearToggle) return;
        window.blockrStemGearToggle = function(gearId, popId) {
          var gear = document.getElementById(gearId);
          var pop  = document.getElementById(popId);
          if (!gear || !pop) return;
          var open = pop.style.display !== 'none';
          pop.style.display = open ? 'none' : 'block';
          gear.classList.toggle('blockr-gear-active', !open);
          gear.setAttribute('aria-expanded', open ? 'false' : 'true');
        };
        document.addEventListener('click', function(e) {
          document.querySelectorAll('.blockr-gear-host .blockr-popover').forEach(function(pop) {
            if (pop.style.display === 'none') return;
            var host = pop.closest('.blockr-gear-host');
            if (!host || host.contains(e.target)) return;
            pop.style.display = 'none';
            var gear = host.querySelector('.blockr-gear-btn');
            if (gear) {
              gear.classList.remove('blockr-gear-active');
              gear.setAttribute('aria-expanded', 'false');
            }
          });
        });
      })();
    "))
  )
}

stem_gear_icon_svg <- function() {
  paste0(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\" ",
    "fill=\"currentColor\" viewBox=\"0 0 16 16\"><path d=\"M9.405 1.05c-.413-1.4-2.397-1.4-2.81 0l-.1.34a1.464 ",
    "1.464 0 0 1-2.105.872l-.31-.17c-1.283-.698-2.686.705-1.987 1.987l.169.311c.446.82",
    ".023 1.841-.872 2.105l-.34.1c-1.4.413-1.4 2.397 0 2.81l.34.1a1.464 1.464 0 0 1 ",
    ".872 2.105l-.17.31c-.698 1.283.705 2.686 1.987 1.987l.311-.169a1.464 1.464 0 0 1 ",
    "2.105.872l.1.34c.413 1.4 2.397 1.4 2.81 0l.1-.34a1.464 1.464 0 0 1 2.105-.872l.31",
    ".17c1.283.698 2.686-.705 1.987-1.987l-.169-.311a1.464 1.464 0 0 1 .872-2.105l.34-",
    ".1c1.4-.413 1.4-2.397 0-2.81l-.34-.1a1.464 1.464 0 0 1-.872-2.105l.17-.31c.698-",
    "1.283-.705-2.686-1.987-1.987l-.311.169a1.464 1.464 0 0 1-2.105-.872zM8 10.93a2.929 ",
    "2.929 0 1 1 0-5.86 2.929 2.929 0 0 1 0 5.858z\"/></svg>"
  )
}
