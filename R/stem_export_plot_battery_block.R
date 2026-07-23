#' STEM Export (chart or battery) block
#'
#' A two-input variant of [new_stem_export_block()]: it accepts a plot from a
#' **STEM Visualize** block *and* a plot from a **STEM Visualize battery** block
#' and lets the user pick which one to export with a toggle. Everything else -
#' the PNG / SVG / native PowerPoint export, the size / scaling controls and the
#' live preview - works exactly as in [new_stem_export_block()] (the two blocks
#' share the same export helpers and preview renderer).
#'
#' Both inputs are **optional**, so the block works with just one wired up: the
#' toggle chooses the export target when both are connected, but falls back to
#' whichever input *is* connected when the chosen one is missing. When neither is
#' connected the block waits (blank preview) rather than erroring.
#'
#' @param target Which upstream input to export by default, `"plot"` (the STEM
#'   Visualize input) or `"battery"` (the STEM Visualize battery input).
#' @inheritParams new_stem_export_block
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class
#'   `stem_export_plot_battery_block`.
#'
#' @examples
#' new_stem_export_plot_battery_block(target = "battery", format = "png")
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_stem_export_plot_battery_block <- function(target = c("plot", "battery"),
                                               format = c("png", "svg", "pptx"),
                                               width = 14, height = NA_real_,
                                               scale = 1.5, ...) {
  target <- match.arg(target)
  format <- match.arg(format)

  new_ggplot_transform_block(
    # Two input ports (`plot`, `battery`) - blockr derives a block's inputs from
    # the server's formal arguments after `id`. Both are declared optional (see
    # allow_empty_state below) so the block renders with just one wired up.
    function(id, plot, battery) {
      moduleServer(id, function(input, output, session) {
        r_target <- reactiveVal(target)
        r_format <- reactiveVal(format)
        r_width <- reactiveVal(width)
        r_height <- reactiveVal(height)
        r_scale <- reactiveVal(scale)

        observeEvent(input$target, r_target(input$target))
        observeEvent(input$format, r_format(input$format))
        observeEvent(input$width, r_width(input$width), ignoreNULL = FALSE)
        observeEvent(input$height, r_height(input$height), ignoreNULL = FALSE)
        observeEvent(input$scale, r_scale(input$scale), ignoreNULL = FALSE)

        # The port the export acts on: the toggle's choice, but fall back to the
        # other input when the chosen one isn't connected, so wiring up just one
        # upstream block works without having to match the toggle. An unconnected
        # optional input reads as NULL (blockr binds it to NULL). Returns the
        # port *name* ("plot" / "battery"), or NULL when neither is connected.
        active_port <- reactive({
          have_plot <- !is.null(plot())
          have_battery <- !is.null(battery())
          if (identical(r_target(), "battery")) {
            if (have_battery) "battery" else if (have_plot) "plot" else NULL
          } else {
            if (have_plot) "plot" else if (have_battery) "battery" else NULL
          }
        })

        # The actual plot object behind active_port(), or NULL when neither input
        # is connected. Used by the download handler (the preview reads the passed
        # -through `result` instead).
        active <- reactive({
          switch(active_port() %||% "",
            plot = plot(),
            battery = battery(),
            NULL
          )
        })

        # When height is unset, fill the field with the type-based default so the
        # user sees it (and can override). Keyed on the active plot so switching
        # the toggle (or wiring an input) refreshes it.
        observeEvent(active(), {
          if (length(r_height()) != 1L || is.na(r_height())) {
            updateNumericInput(
              session, "height",
              value = stem_default_plot_height(active())
            )
          }
        })

        # Height actually used: the field value, else the type-based default.
        eff_height <- reactive(stem_export_eff_height(r_height(), active()))
        eff_width <- reactive(stem_export_eff_width(r_width()))
        eff_scale <- reactive(stem_export_eff_scale(r_scale()))

        output$download <- downloadHandler(
          filename = function() paste0("stem-plot.", r_format()),
          content = function(file) {
            plt <- active()
            if (is.null(plt)) {
              stop(
                "Nothing to export: connect a STEM Visualize (chart) and/or a ",
                "STEM Visualize battery block upstream."
              )
            }
            if (identical(r_format(), "pptx")) {
              # Native, editable Office chart - not an image (see
              # stem_write_pptx_chart()). Sized to the same cm width/height as
              # the image formats (the chart is centred on the slide and can
              # still be resized by hand in PowerPoint).
              stem_write_pptx_chart(
                plot = plt,
                file = file,
                width = eff_width(),
                height = eff_height()
              )
              return(invisible(file))
            }
            if (identical(r_format(), "svg") &&
              !requireNamespace("svglite", quietly = TRUE)) {
              stop(
                "SVG export requires the 'svglite' package. ",
                "Install it, or export as PNG instead."
              )
            }
            ggplot2::ggsave(
              filename = file,
              plot = plt,
              device = r_format(),
              width = eff_width(),
              height = eff_height(),
              units = "cm",
              scale = eff_scale()
            )
          }
        )

        list(
          # Pass the selected plot through unchanged so it renders as a preview
          # (and downstream sees it). Emit only the chosen input's marker, and
          # req() it so the block waits - rather than erroring - when neither
          # input is connected yet.
          expr = reactive({
            port <- active_port()
            req(port)
            if (identical(port, "battery")) quote(.(battery)) else quote(.(plot))
          }),
          state = list(
            target = r_target, format = r_format, width = r_width,
            height = r_height, scale = r_scale
          )
        )
      })
    },
    function(id) {
      tagList(
        radioButtons(
          NS(id, "target"), "Export",
          choices = c(
            "Chart (STEM Visualize)" = "plot",
            "Battery (STEM Visualize battery)" = "battery"
          ),
          selected = target, inline = TRUE
        ),
        tags$p(
          class = "text-muted",
          style = "margin: 2px 0 8px;",
          "Pick which upstream plot to export. Wire the STEM Visualize block to ",
          "the ", tags$em("plot"), " input and the STEM Visualize battery block ",
          "to the ", tags$em("battery"), " input; if only one is connected it is ",
          "used regardless of this toggle."
        ),
        radioButtons(
          NS(id, "format"), "Format",
          choices = c("PNG" = "png", "SVG" = "svg", "PowerPoint chart" = "pptx"),
          selected = format, inline = TRUE
        ),
        numericInput(
          NS(id, "width"), "Width (cm)",
          value = width, min = 1, step = 0.5
        ),
        numericInput(
          NS(id, "height"), "Height (cm)",
          value = if (is.na(height)) NULL else height, min = 1, step = 0.5
        ),
        numericInput(
          NS(id, "scale"), "Scaling",
          value = scale, min = 0.1, step = 0.1
        ),
        tags$p(
          class = "text-warning",
          style = "margin: 2px 0 4px;",
          tags$strong("Note:"),
          " a higher scaling number makes the text and marks ", tags$em("smaller"),
          " (and a lower number makes them larger)."
        ),
        tags$p(
          class = "text-muted",
          style = "margin: 2px 0 8px;",
          "Width/height set the export size in cm (height defaults to the plot ",
          "type: 6 cm inline, 10 cm bar). Scaling (ggsave's `scale`) applies to ",
          "PNG/SVG only. The PowerPoint chart is centred on the slide at that ",
          "size, ignores scaling, and can still be resized in PowerPoint."
        ),
        downloadButton(NS(id, "download"), "Download plot", class = "btn-primary")
      )
    },
    class = "stem_export_plot_battery_block",
    # `height` is NA until a default/value is set, so it must be allowed empty
    # (the `input` slot). The `data` slot marks both input ports optional, so the
    # block renders with just one (or neither) connected instead of gating on
    # "waiting for both inputs" - the fallback in active_port() then picks the
    # one that is present.
    allow_empty_state = list(
      input = "height",
      data = c("plot", "battery")
    ),
    expr_type = "bquoted",
    ...
  )
}

#' @description
#' The block's output panel shows the same live preview as [new_stem_export_block()]
#' - the selected plot rendered by the very [ggplot2::ggsave()] call used for the
#' download - via the shared preview renderer.
#'
#' @param id Passed by blockr when rendering the block UI.
#' @param x,result,session Passed by blockr when rendering the block UI/output.
#' @rdname new_stem_export_plot_battery_block
#' @exportS3Method blockr.core::block_ui
block_ui.stem_export_plot_battery_block <- function(id, x, ...) {
  tagList(
    imageOutput(NS(id, "result"), width = "100%", height = "auto")
  )
}

#' @rdname new_stem_export_plot_battery_block
#' @exportS3Method blockr.core::block_output
block_output.stem_export_plot_battery_block <- function(x, result, session) {
  stem_export_preview_image(result, session)
}
