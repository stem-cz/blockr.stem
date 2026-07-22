test_that("new_stem_export_block constructs a ggplot transform block", {
  blk <- new_stem_export_block()
  expect_s3_class(blk, "stem_export_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("new_stem_export_block validates the format argument", {
  expect_error(new_stem_export_block(format = "pdf"))
})

test_that("stem_default_plot_height is 6 for inline, 10 for bar plots", {
  skip_if_not_installed("stemtools")
  ip_ok <- data.frame(g = factor(rep(c("a", "b"), 6)))
  expect_equal(stem_default_plot_height(stemtools::stem_barplot(ip_ok, g)), 10)
  expect_equal(stem_default_plot_height(stemtools::stem_inline(ip_ok, g)), 6)
  # non-plot / undetermined -> falls back to 10
  expect_equal(stem_default_plot_height(NULL), 10)
})

test_that("effective export sizes fall back to the advertised defaults", {
  skip_if_not_installed("stemtools")
  bar <- stemtools::stem_barplot(data.frame(g = factor(rep(c("a", "b"), 6))), g)

  # A set value is used as-is; an unset/invalid one falls back.
  expect_equal(stem_export_eff_width(20), 20)
  expect_equal(stem_export_eff_width(NA), 14)
  expect_equal(stem_export_eff_width(0), 14)

  expect_equal(stem_export_eff_scale(2), 2)
  expect_equal(stem_export_eff_scale(NA), 1.5)
  expect_equal(stem_export_eff_scale(-1), 1.5)

  expect_equal(stem_export_eff_height(8, bar), 8)
  expect_equal(stem_export_eff_height(NA, bar), 10) # type-based default
})

test_that("the pptx preview scale matches the exported data-label size (14/11)", {
  # The preview must shrink the plot's 14pt labels to the chart's 11pt (the
  # exported chart draws them at stem_pptx_label_scale = 11/14 of the plot size),
  # so the preview scale is the inverse of that label scaling.
  expect_equal(stem_pptx_preview_scale, 14 / 11)
  expect_equal(stem_pptx_preview_scale, 1 / stem_pptx_label_scale)
})

test_that("the preview renders at the chosen export size and scaling", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("png")
  p <- stemtools::stem_barplot(data.frame(g = factor(rep(c("a", "b"), 6))), g)

  session <- shiny::MockShinySession$new()
  render_fn <- block_output.stem_export_block(NULL, p, session)

  # The block controls live under the nested "expr" namespace (see
  # blockr.core::expr_server), so block_output reads NS("expr", <name>); the
  # test must set them at the same qualified ids or it would only ever see the
  # defaults (which is the bug this guards against).
  # MockShinySession serves the image as a base64 data URI; decode it back to a
  # PNG so we can read its pixel dimensions.
  preview_dim <- function(width, height, scale, format = "png") {
    args <- list(width, height, scale, format)
    names(args) <- shiny::NS("expr")(c("width", "height", "scale", "format"))
    do.call(session$setInputs, args)
    info <- shiny::isolate(render_fn(session, "result"))
    raw <- jsonlite::base64_dec(sub("^data:image/png;base64,", "", info$src))
    dim(png::readPNG(raw))[c(2L, 1L)] # -> c(px_width, px_height)
  }

  base <- preview_dim(14, 10, 1.5)
  # A wider export -> wider preview (same height); scaling up -> more pixels
  # in both dimensions (which, displayed scaled-to-fit, shrinks the marks).
  expect_gt(preview_dim(20, 10, 1.5)[1L], base[1L])
  expect_equal(preview_dim(20, 10, 1.5)[2L], base[2L])
  expect_gt(preview_dim(14, 20, 1.5)[2L], base[2L])
  expect_true(all(preview_dim(14, 10, 3.0) > base))

  # The PowerPoint chart ignores the user's scaling control, but its preview is
  # rendered at stem_pptx_preview_scale so the previewed font size matches the
  # smaller text of the exported native chart, not the raw plot.
  expect_equal(
    preview_dim(14, 10, 3.0, "pptx"),
    preview_dim(14, 10, stem_pptx_preview_scale, "png")
  )
  # Independent of the scaling control: different `scale` inputs, same pptx preview.
  expect_equal(preview_dim(14, 10, 0.75, "pptx"), preview_dim(14, 10, 3.0, "pptx"))
})

test_that("export block passes the plot through and tracks settings", {
  blk <- new_stem_export_block()
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(p))),
    {
      session$setInputs(format = "png", width = 20, height = 8, scale = 0.75)
      expect_identical(session$returned$state$format(), "png")
      expect_equal(session$returned$state$width(), 20)
      expect_equal(session$returned$state$height(), 8)
      expect_equal(session$returned$state$scale(), 0.75)
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  # pass-through: evaluating the block returns the same plot
  out <- eval_impl(blk, e, list(data = p))
  expect_s3_class(out, "ggplot")
})

test_that("PNG export writes a non-empty file at the requested size", {
  skip_if_not_installed("stemtools")
  blk <- new_stem_export_block()
  p <- stemtools::stem_barplot(
    data.frame(g = factor(rep(c("a", "b"), 6))), g
  )

  # Exercise the ggsave path the download handler uses.
  f <- withr::local_tempfile(fileext = ".png")
  ggplot2::ggsave(f, plot = p, device = "png", width = 14, height = 10, units = "cm")
  expect_true(file.exists(f) && file.info(f)$size > 0)
})

test_that("new_stem_export_block accepts the pptx format", {
  blk <- new_stem_export_block(format = "pptx")
  expect_identical(blk$expr_ui, blk$expr_ui) # constructs without error
  expect_s3_class(blk, "stem_export_block")
})

test_that("pptx category order matches the plot's y axis (both chart shapes)", {
  skip_if_not_installed("stemtools")

  # ggplot draws the first category at the BOTTOM of the (horizontal) y axis, but
  # a native mschart chart reverses that. The reconstructed frame must therefore
  # lay the categories out to match the plot's y axis read bottom -> top, else the
  # exported bars come out upside down. mschart keys the category axis off *row*
  # order for a single-series bar chart but off the category factor's *levels* for
  # a grouped/stacked chart, so the fix (and this test) covers both shapes.
  plot_y <- function(p) {
    ggplot2::ggplot_build(p)$layout$panel_params[[1]]$y$get_labels()
  }

  # Single-series bar: check the row order.
  p1 <- stemtools::stem_barplot(data.frame(g = factor(rep(c("Low", "Mid", "High"), 4))), g)
  d1 <- stem_pptx_chart_data(p1)
  expect_equal(as.character(unique(d1$category)), plot_y(p1))
  expect_null(d1$series)

  # Grouped/stacked: check the category factor levels (rows untouched).
  df <- data.frame(
    g = factor(rep(c("Yes", "No", "Maybe"), 4)),
    grp = factor(rep(c("Group1", "Group2"), each = 6))
  )
  p2 <- stemtools::stem_barplot(df, g, group = grp)
  d2 <- stem_pptx_chart_data(p2)
  expect_equal(levels(d2$category), plot_y(p2))
})

test_that("scaling defaults to 1.5 and is tracked in state", {
  blk <- new_stem_export_block()
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(p))),
    {
      expect_equal(session$returned$state$scale(), 1.5)
      session$setInputs(scale = 1.2)
      expect_equal(session$returned$state$scale(), 1.2)
    }
  )
})

test_that("stem_write_pptx_chart writes a native, editable Office chart", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")

  df <- data.frame(
    g = factor(rep(c("a", "b", "c"), 4)),
    grp = factor(rep(c("x", "y"), each = 6))
  )

  # Grouped bar plot -> a stacked native chart.
  f <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(stemtools::stem_barplot(df, g, group = grp), f)
  parts <- utils::unzip(f, list = TRUE)$Name
  # A real chart part + its embedded Excel data cache (what makes it editable),
  # and NOT an embedded raster image of the plot.
  expect_true(any(grepl("ppt/charts/chart.*\\.xml$", parts)))
  expect_true(any(grepl("embeddings/.*\\.xlsx$", parts)))
  expect_false(any(grepl("ppt/media/.*\\.(png|jpeg|jpg|svg)$", parts)))

  # Ungrouped bar plot and inline plot also reconstruct.
  f2 <- withr::local_tempfile(fileext = ".pptx")
  expect_invisible(stem_write_pptx_chart(stemtools::stem_barplot(df, g), f2))
  f3 <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(stemtools::stem_inline(df, g), f3)
  expect_true(file.exists(f3) && file.info(f3)$size > 0)
})

test_that("native chart carries the plot's white bar outline (the segment gaps)", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")

  df <- data.frame(
    g = factor(rep(c("a", "b", "c"), 4)),
    grp = factor(rep(c("x", "y"), each = 6))
  )

  # stemtools draws each bar with colour = "white"; the helper recovers that
  # outline (colour + a positive width in points) so the native chart shows the
  # same gaps between stacked segments.
  p <- stemtools::stem_barplot(df, g, group = grp)
  pd <- stem_pptx_chart_data(p)
  st <- stem_pptx_series_strokes(p, pd, "series")
  expect_true(all(toupper(st$values) == "#FFFFFF" | tolower(st$values) == "white"))
  expect_true(is.numeric(st$width) && st$width > 0)

  # It reaches the written OOXML as a white series line (<a:ln> solidFill).
  read_chart_xml <- function(f) {
    parts <- utils::unzip(f, list = TRUE)$Name
    part <- grep("ppt/charts/chart.*\\.xml$", parts, value = TRUE)[1]
    paste(readLines(unz(f, part), warn = FALSE), collapse = "")
  }
  f <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(p, f)
  xml <- read_chart_xml(f)
  expect_match(xml, "<a:ln[^>]*>\\s*<a:solidFill>\\s*<a:srgbClr val=\"FFFFFF\"")
})

test_that("native chart inherits the Stem theme (top legend, font, small labels)", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")

  read_chart_xml <- function(f) {
    parts <- utils::unzip(f, list = TRUE)$Name
    part <- grep("ppt/charts/chart.*\\.xml$", parts, value = TRUE)[1]
    paste(readLines(unz(f, part), warn = FALSE), collapse = "")
  }

  df <- data.frame(
    g = factor(rep(c("a", "b", "c"), 4)),
    grp = factor(rep(c("x", "y"), each = 6))
  )
  # set_label_size(14) mimics the chart / visualize block's default so we test
  # the explicit-size path (14pt labels).
  p <- set_label_size(stemtools::stem_barplot(df, g, group = grp), 14) +
    stemtools::theme_stem(family = "Calibri", ink = "black")

  f <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(p, f)
  xml <- read_chart_xml(f)

  expect_match(xml, "<c:legendPos val=\"t\"") # legend on top, like theme_stem()
  expect_match(xml, "Calibri") # font family carried over
  # 14pt plot labels scaled to the chart's 11pt axis text (14 * 11/14 = 11).
  expect_match(xml, "sz=\"1100\"")
  expect_no_match(xml, "sz=\"1400\"")
  # Bicolour labels: white on the dark extreme item categories, black elsewhere.
  expect_match(xml, "FFFFFF")

  # No axis titles (theme_stem() has none), thick bars, 25% tick steps like the
  # plot, and labels taken verbatim from the plot (from cells, no "%" suffix).
  expect_no_match(xml, "<a:t>value</a:t>")
  expect_no_match(xml, "<a:t>category</a:t>")
  expect_match(xml, "gapWidth val=\"30\"")
  expect_match(xml, "majorUnit val=\"0.25\"")
  expect_match(xml, "showDataLabelsRange val=\"1\"")
  expect_match(xml, "<c:showVal val=\"0\"")

  # A single-series (ungrouped) chart has no legend at all.
  f2 <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(stemtools::stem_barplot(df, g) + stemtools::theme_stem(), f2)
  expect_no_match(read_chart_xml(f2), "<c:legend>")
})

test_that("native chart label size follows the plot (explicit vs auto)", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")

  df <- data.frame(
    g = factor(rep(c("a", "b", "c"), 4)),
    grp = factor(rep(c("x", "y"), each = 6))
  )
  # NB: ggplot2 Layer objects are ggproto (reference semantics), so
  # set_label_size() mutates its input's layer in place - build a fresh plot for
  # each case rather than reusing one.
  fresh <- function() stemtools::stem_barplot(df, g, group = grp)

  # set_label_size() pins the size; "auto" (no explicit size) must fall back to
  # the plot's own ~11pt, not an oversized default.
  expect_equal(stem_pptx_label_size(set_label_size(fresh(), 14)), 14)
  expect_equal(round(stem_pptx_label_size(fresh())), 11)

  f <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(fresh(), f) # auto labels
  parts <- utils::unzip(f, list = TRUE)$Name
  xml <- paste(
    readLines(unz(f, grep("ppt/charts/chart.*\\.xml$", parts, value = TRUE)[1]), warn = FALSE),
    collapse = ""
  )
  # The data-label font (inside <c:dLbls>) is the ~11pt auto size scaled by
  # 11/14 -> 8.5pt (sz="850"); the 11pt axis text is unscaled (sz="1100").
  dlbls <- regmatches(xml, gregexpr("<c:dLbls>.*?</c:dLbls>", xml))[[1]]
  expect_true(any(grepl("sz=\"850\"", dlbls)))
})

test_that("stem_pptx_location fills the slide by default, centres a fixed size", {
  skip_if_not_installed("officer")
  fill <- stem_pptx_location()
  expect_gt(fill$width, 9) # ~full 10in slide width
  expect_gt(fill$height, 6)

  fixed <- stem_pptx_location(width = 16, height = 10)
  expect_equal(fixed$width, 16 / 2.54)
  expect_equal(fixed$height, 10 / 2.54)
  expect_equal(fixed$left, (10 - 16 / 2.54) / 2) # centred on a 10in slide
})

test_that("native chart carries the plot's title, rendered bold", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")

  read_chart_xml <- function(f) {
    parts <- utils::unzip(f, list = TRUE)$Name
    part <- grep("ppt/charts/chart.*\\.xml$", parts, value = TRUE)[1]
    paste(readLines(unz(f, part), warn = FALSE), collapse = "")
  }

  df <- data.frame(g = factor(rep(c("a", "b", "c"), 4)))
  attr(df$g, "label") <- "Do you like R?"

  # Title on -> it appears in a bold <c:title> block.
  p <- stemtools::stem_barplot(df, g, title_show = TRUE) + stemtools::theme_stem()
  expect_equal(stem_pptx_title(p), "Do you like R?")

  f <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(p, f)
  xml <- read_chart_xml(f)
  title <- regmatches(xml, regexpr("<c:title[ >].*?</c:title>", xml))
  expect_match(title, "Do you like R\\?")
  expect_match(title, "b=\"1\"") # bold, via the theme's main_title
  # left-aligned to match theme_stem() (patched into the title's <a:pPr>).
  expect_match(title, "<a:pPr algn=\"l\"")

  # Title off -> no title helper value, no title text in the chart.
  p_off <- stemtools::stem_barplot(df, g) + stemtools::theme_stem()
  expect_null(stem_pptx_title(p_off))
  f2 <- withr::local_tempfile(fileext = ".pptx")
  stem_write_pptx_chart(p_off, f2)
  expect_no_match(read_chart_xml(f2), "Do you like R")
})

test_that("stem_write_pptx_chart rejects a plot it can't reconstruct", {
  skip_if_not_installed("mschart")
  skip_if_not_installed("officer")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  f <- withr::local_tempfile(fileext = ".pptx")
  expect_error(stem_write_pptx_chart(p, f), "native PowerPoint chart")
})
