test_that("new_stem_export_plot_battery_block constructs a ggplot transform block", {
  blk <- new_stem_export_plot_battery_block()
  expect_s3_class(blk, "stem_export_plot_battery_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("new_stem_export_plot_battery_block validates its arguments", {
  expect_error(new_stem_export_plot_battery_block(target = "nope"))
  expect_error(new_stem_export_plot_battery_block(format = "pdf"))
})

test_that("the block exposes two optional input ports (plot, battery)", {
  blk <- new_stem_export_plot_battery_block()

  # Inputs are derived from the server's formal args after `id`; both are marked
  # optional (via allow_empty_state's `data` slot) so the block renders with only
  # one wired up.
  block_inputs <- getFromNamespace("block_inputs", "blockr.core")
  block_optional_inputs <- getFromNamespace("block_optional_inputs", "blockr.core")
  expect_setequal(block_inputs(blk), c("plot", "battery"))
  expect_setequal(block_optional_inputs(blk), c("plot", "battery"))
})

test_that("the block tracks its settings in state", {
  blk <- new_stem_export_plot_battery_block()
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()

  testServer(
    function(id) {
      blockr.core::expr_server(
        blk, list(plot = reactive(p), battery = reactive(NULL))
      )
    },
    {
      session$setInputs(
        target = "plot", format = "svg", width = 20, height = 8, scale = 0.75
      )
      st <- session$returned$state
      expect_identical(st$target(), "plot")
      expect_identical(st$format(), "svg")
      expect_equal(st$width(), 20)
      expect_equal(st$height(), 8)
      expect_equal(st$scale(), 0.75)
    }
  )
})

test_that("the toggle selects which input is passed through", {
  blk <- new_stem_export_plot_battery_block()
  chart <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  battery <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_line()

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  emitted <- function(target) {
    e <- NULL
    testServer(
      function(id) {
        blockr.core::expr_server(
          blk, list(plot = reactive(chart), battery = reactive(battery))
        )
      },
      {
        session$setInputs(target = target)
        e <<- exprs_to_lang(session$returned$expr())
      }
    )
    e
  }

  # target = plot  -> emits the plot input; target = battery -> the battery one.
  out_plot <- eval_impl(blk, emitted("plot"), list(plot = chart, battery = battery))
  expect_identical(out_plot, chart)
  out_battery <- eval_impl(
    blk, emitted("battery"), list(plot = chart, battery = battery)
  )
  expect_identical(out_battery, battery)
})

test_that("the export target falls back to whichever input is connected", {
  blk <- new_stem_export_plot_battery_block()
  battery <- ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) + ggplot2::geom_line()

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  # Toggle says "plot" but only the battery input is wired: the block should fall
  # back to the battery rather than waiting on the missing plot input.
  e <- NULL
  testServer(
    function(id) {
      blockr.core::expr_server(
        blk, list(plot = reactive(NULL), battery = reactive(battery))
      )
    },
    {
      session$setInputs(target = "plot")
      e <<- exprs_to_lang(session$returned$expr())
    }
  )
  out <- eval_impl(blk, e, list(battery = battery))
  expect_identical(out, battery)
})

test_that("the block waits (no expr) when neither input is connected", {
  blk <- new_stem_export_plot_battery_block()

  # With both optional inputs NULL, active_port() is NULL and the expr req()s it,
  # so the block yields no runnable expression (a silent "wait") rather than
  # emitting a pass-through of NULL.
  testServer(
    function(id) {
      blockr.core::expr_server(
        blk, list(plot = reactive(NULL), battery = reactive(NULL))
      )
    },
    {
      session$setInputs(target = "plot")
      expect_error(session$returned$expr(), class = "shiny.silent.error")
    }
  )
})

test_that("both export blocks share one preview renderer", {
  skip_if_not_installed("stemtools")
  skip_if_not_installed("png")
  p <- stemtools::stem_barplot(data.frame(g = factor(rep(c("a", "b"), 6))), g)

  session <- shiny::MockShinySession$new()
  render_fn <- block_output.stem_export_plot_battery_block(NULL, p, session)

  # The two-input block reuses stem_export_preview_image(), so its preview honours
  # the same NS("expr", <name>) controls as the single-input block: a wider export
  # yields a wider preview image.
  preview_dim <- function(width, height, scale) {
    args <- list(width, height, scale, "png")
    names(args) <- shiny::NS("expr")(c("width", "height", "scale", "format"))
    do.call(session$setInputs, args)
    info <- shiny::isolate(render_fn(session, "result"))
    raw <- jsonlite::base64_dec(sub("^data:image/png;base64,", "", info$src))
    dim(png::readPNG(raw))[c(2L, 1L)] # -> c(px_width, px_height)
  }

  base <- preview_dim(14, 10, 1.5)
  expect_gt(preview_dim(20, 10, 1.5)[1L], base[1L])
})
