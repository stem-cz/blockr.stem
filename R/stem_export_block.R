#' STEM Export block
#'
#' A blockr block that previews an upstream ggplot and lets the user download it
#' as a **PNG** or **SVG** image, or as a **native PowerPoint chart** (`.pptx`),
#' at a chosen size in centimetres. Width defaults to 14 cm; height defaults to
#' the plot type - 6 cm for an inline plot ([stemtools::stem_inline()]) and
#' 10 cm for a bar plot ([stemtools::stem_barplot()]) - and can be overridden.
#'
#' SVG export uses [ggplot2::ggsave()]'s `"svg"` device, which requires the
#' \pkg{svglite} package; if it is not installed the SVG download reports an
#' error and PNG can be used instead.
#'
#' PowerPoint export writes a **native, editable Office chart** (not a picture)
#' via [stem_write_pptx_chart()] - the recipient can *Edit Data* in Excel and
#' restyle it by hand. It requires the \pkg{mschart} and \pkg{officer} packages
#' and only works for the STEM bar / inline plots (see [stem_write_pptx_chart()]).
#'
#' @param format Export format, one of `"png"`, `"svg"` or `"pptx"`.
#' @param width Export width in centimetres (default `14`).
#' @param height Export height in centimetres. `NA` (the default) picks a height
#'   from the plot type (6 cm inline, 10 cm bar plot).
#' @param scale Multiplicative scaling factor passed to [ggplot2::ggsave()]'s
#'   `scale` argument for the PNG/SVG image formats (default `1.5`). Because the
#'   output size is fixed, a **higher** number makes the plot's text and marks
#'   appear **smaller** (and a lower number makes them larger). Ignored by the
#'   PowerPoint chart export, which is not rasterised.
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class `stem_export_block`.
#'
#' @examples
#' new_stem_export_block(format = "png", width = 14)
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_stem_export_block <- function(format = c("png", "svg", "pptx"), width = 14,
                                  height = NA_real_, scale = 1.5, ...) {
  format <- match.arg(format)

  new_ggplot_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        r_format <- reactiveVal(format)
        r_width <- reactiveVal(width)
        r_height <- reactiveVal(height)
        r_scale <- reactiveVal(scale)

        observeEvent(input$format, r_format(input$format))
        observeEvent(input$width, r_width(input$width), ignoreNULL = FALSE)
        observeEvent(input$height, r_height(input$height), ignoreNULL = FALSE)
        observeEvent(input$scale, r_scale(input$scale), ignoreNULL = FALSE)

        # When height is unset, fill the field with the type-based default so the
        # user sees it (and can override).
        observeEvent(data(), {
          if (length(r_height()) != 1L || is.na(r_height())) {
            updateNumericInput(
              session, "height",
              value = stem_default_plot_height(data())
            )
          }
        })

        # Height actually used: the field value, else the type-based default.
        eff_height <- reactive(stem_export_eff_height(r_height(), data()))
        eff_width <- reactive(stem_export_eff_width(r_width()))
        eff_scale <- reactive(stem_export_eff_scale(r_scale()))

        output$download <- downloadHandler(
          filename = function() paste0("stem-plot.", r_format()),
          content = function(file) {
            if (identical(r_format(), "pptx")) {
              # Native, editable Office chart - not an image (see
              # stem_write_pptx_chart()). Sized to the same cm width/height as
              # the image formats (the chart is centred on the slide and can
              # still be resized by hand in PowerPoint).
              stem_write_pptx_chart(
                plot = data(),
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
              plot = data(),
              device = r_format(),
              width = eff_width(),
              height = eff_height(),
              units = "cm",
              scale = eff_scale()
            )
          }
        )

        list(
          # Pass the plot through unchanged so it renders as a preview.
          expr = reactive(quote(.(data))),
          state = list(
            format = r_format, width = r_width, height = r_height, scale = r_scale
          )
        )
      })
    },
    function(id) {
      tagList(
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
    class = "stem_export_block",
    # `height` is NA until a default/value is set, so it must be allowed empty.
    allow_empty_state = "height",
    expr_type = "bquoted",
    ...
  )
}

#' @description
#' The block's output panel shows a live preview of the plot *exactly as it will
#' be exported*: it is produced by the same [ggplot2::ggsave()] call as the
#' download, so the chosen width/height (cm) set the aspect ratio and the scaling
#' factor changes the apparent size of the text and marks. The preview updates
#' automatically whenever the format, width, height or scaling inputs change.
#'
#' @param id,x Passed by blockr when rendering the block UI.
#' @param x,result,session Passed by blockr when rendering the block output.
#' @rdname new_stem_export_block
#' @exportS3Method blockr.core::block_ui
block_ui.stem_export_block <- function(id, x, ...) {
  tagList(
    imageOutput(NS(id, "result"), width = "100%", height = "auto")
  )
}

#' @rdname new_stem_export_block
#' @exportS3Method blockr.core::block_output
block_output.stem_export_block <- function(x, result, session) {
  renderImage(
    {
      # Read the export controls reactively so the preview re-renders whenever
      # the user changes format/width/height/scaling. `session` here is the
      # block's *outer* module session, but blockr.core::expr_server() runs the
      # block server under a nested `"expr"` namespace, so the inputs live at
      # `NS("expr", <name>)` from this session's point of view - reading them
      # unqualified would always yield NULL (and thus the defaults). See
      # blockr.core:::expr_server.block (id = "expr").
      ctrl <- function(name) session$input[[NS("expr", name)]]

      fmt <- ctrl("format")
      if (length(fmt) != 1L) fmt <- "png"

      width <- stem_export_eff_width(ctrl("width"))
      height <- stem_export_eff_height(ctrl("height"), result)
      # The PowerPoint chart is not rasterised and ignores `scale`, so preview
      # it at scale 1 to match; PNG/SVG previews honour the scaling control.
      scale <- if (identical(fmt, "pptx")) 1 else stem_export_eff_scale(ctrl("scale"))

      file <- tempfile(fileext = ".png")
      # Same call as the download handler (raster preview even for SVG/PPTX,
      # which share this visual layout). dpi only affects preview sharpness, not
      # the proportions, so the on-screen look matches the export.
      ggplot2::ggsave(
        filename = file,
        plot = result,
        device = "png",
        width = width,
        height = height,
        units = "cm",
        scale = scale,
        dpi = 150
      )

      list(
        src = file,
        contentType = "image/png",
        # Pin the preview to a constant display *width* (not the image's
        # intrinsic size) so the scaling factor's effect is always visible:
        # `scale` changes the export layout, so a higher scale renders the text
        # and marks smaller relative to the plot. If we let the image show at
        # its intrinsic size (max-width only), a wide panel would just display a
        # bigger image with the same-looking content and the scaling change
        # would be invisible. `width: 100%` up to a fixed cap keeps the on-screen
        # width steady, so only the relative sizing changes; height auto keeps
        # the export aspect ratio.
        style = paste(
          "width: 100%; max-width: 720px; height: auto;",
          "display: block; margin: 0 auto;"
        ),
        alt = "Preview of the exported plot"
      )
    },
    deleteFile = TRUE
  )
}
