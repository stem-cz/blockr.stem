#' Theme STEM block
#'
#' A blockr transform block that applies the complete Stem ggplot2 theme
#' ([stemtools::theme_stem()]) to an upstream ggplot2 plot. It works like the
#' \pkg{blockr.ggplot} Theme block, but instead of exposing individual theme
#' elements it applies the Stem house theme, exposing that theme's own
#' arguments (`ink`, `paper`, `accent`, `family`) as block controls.
#'
#' @param ink Foreground colour used for text, titles and axis lines.
#' @param paper Background colour behind the panel, plot, strips and legend
#'   keys.
#' @param accent Accent colour (e.g. the fill of [ggplot2::geom_smooth()]).
#'   Defaults to the primary Stem brand colour.
#' @param family Font family for all text. Defaults to `"Calibri"`, the Stem
#'   house font. A blank string uses the graphics device's default family.
#' @param font_size Base text size in points for the axis, legend and title
#'   text. Use `NA` (the default) to keep the theme's own sizing. This controls
#'   the plot's structural text; to resize the inner data labels of a
#'   [new_stem_chart_block()], use that block's own label-size control.
#' @param padding Padding in millimetres added to the plot margin so the extreme
#'   axis labels (e.g. "0 %" / "100 %") are not clipped. Defaults to 8 mm.
#' @param ... Forwarded to [blockr.ggplot::new_ggplot_transform_block()].
#'
#' @return A ggplot transform block object of class `theme_stem_block`.
#'
#' @examples
#' new_theme_stem_block(accent = "#35978F", font_size = 14)
#'
#' if (interactive()) {
#'   library(blockr.core)
#'   # The block needs a ggplot input, see app.R for a full board demo.
#'   serve(new_theme_stem_block())
#' }
#'
#' @importFrom blockr.ggplot new_ggplot_transform_block
#' @import shiny
#' @export
new_theme_stem_block <- function(ink = "black", paper = "white",
                                 accent = "#35978F", family = "Calibri",
                                 font_size = NA_real_,
                                 padding = stem_default_padding, ...) {
  new_ggplot_transform_block(
    function(id, data) {
      moduleServer(id, function(input, output, session) {
        r_ink <- reactiveVal(ink)
        r_paper <- reactiveVal(paper)
        r_accent <- reactiveVal(accent)
        r_family <- reactiveVal(family)
        r_font_size <- reactiveVal(font_size)
        r_padding <- reactiveVal(padding)

        observeEvent(
          input$ink, r_ink(input$ink %||% "black"),
          ignoreNULL = FALSE
        )
        observeEvent(
          input$paper, r_paper(input$paper %||% "white"),
          ignoreNULL = FALSE
        )
        observeEvent(
          input$accent, r_accent(input$accent %||% "#35978F"),
          ignoreNULL = FALSE
        )
        observeEvent(
          input$family, r_family(input$family %||% ""),
          ignoreNULL = FALSE
        )
        observeEvent(
          input$font_size,
          r_font_size(
            if (identical(input$font_size, "auto")) NA_real_ else as.numeric(input$font_size)
          )
        )
        observeEvent(input$padding, r_padding(input$padding), ignoreNULL = FALSE)

        list(
          expr = reactive({
            # Apply the Stem theme to the upstream plot (the `.(data)` marker).
            stem_theme_expr(
              base = quote(.(data)),
              ink = r_ink(),
              paper = r_paper(),
              accent = r_accent(),
              family = r_family(),
              font_size = r_font_size(),
              padding = r_padding()
            )
          }),
          state = list(
            ink = r_ink, paper = r_paper,
            accent = r_accent, family = r_family,
            font_size = r_font_size, padding = r_padding
          )
        )
      })
    },
    function(id) {
      sizes <- c(8, 9, 10, 11, 12, 14, 16, 18, 20)
      tagList(
        colourpicker::colourInput(
          NS(id, "ink"), "Ink (text & axes)",
          value = ink
        ),
        colourpicker::colourInput(
          NS(id, "paper"), "Paper (background)",
          value = paper
        ),
        colourpicker::colourInput(
          NS(id, "accent"), "Accent",
          value = accent
        ),
        textInput(
          NS(id, "family"), "Font family",
          value = family,
          placeholder = "e.g. Calibri (blank = device default)"
        ),
        selectInput(
          NS(id, "font_size"), "Base font size",
          choices = c(
            "Auto (theme default)" = "auto",
            stats::setNames(as.character(sizes), sizes)
          ),
          selected = if (is.na(font_size)) "auto" else as.character(font_size)
        ),
        numericInput(
          NS(id, "padding"), "Padding (mm)",
          value = padding, min = 0, step = 1
        )
      )
    },
    class = "theme_stem_block",
    # `family` may be blank (device default), `font_size` is NA when "auto", and
    # `padding` may be cleared; all read as empty, so allow them.
    allow_empty_state = c("family", "font_size", "padding"),
    expr_type = "bquoted",
    ...
  )
}
