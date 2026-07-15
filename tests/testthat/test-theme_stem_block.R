test_that("new_theme_stem_block constructs a ggplot transform block", {
  blk <- new_theme_stem_block(accent = "#FF0000")
  expect_s3_class(blk, "theme_stem_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("theme_stem block tracks inputs and builds a theme_stem() expression", {
  skip_if_not_installed("ggplot2")

  blk <- new_theme_stem_block()
  plot_input <- reactive(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = plot_input)),
    {
      session$setInputs(
        ink = "navy", paper = "white",
        accent = "#FF0000", family = ""
      )

      # State reactives mirror the inputs and match constructor arg names.
      expect_identical(session$returned$state$ink(), "navy")
      expect_identical(session$returned$state$accent(), "#FF0000")

      # The generated expression applies stemtools::theme_stem() with the
      # current control values.
      code <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code, "stemtools::theme_stem")
      expect_match(code, "accent = \"#FF0000\"")
      expect_match(code, "ink = \"navy\"")
    }
  )
})

test_that("base font size appends a theme(text = element_text(size)) layer", {
  blk <- new_theme_stem_block()
  plot_input <- reactive(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = plot_input)),
    {
      # Auto (default): theme_stem() only, no size layer.
      auto <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(auto, "stemtools::theme_stem")
      expect_no_match(auto, "element_text")

      # Setting a base size appends a theme(text = element_text(size = ...)).
      session$setInputs(font_size = "18")
      sized <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(sized, "ggplot2::theme")
      expect_match(sized, "element_text\\(size = 18\\)")
    }
  )
})

test_that("padding adds a plot.margin layer; the control value flows through", {
  norm <- function(x) gsub("[[:space:]]+", " ", paste(deparse(x), collapse = " "))

  # helper always appends a margin (default 8 mm)
  code_default <- norm(stem_theme_expr(quote(.(data))))
  expect_match(code_default, "plot.margin")
  expect_match(code_default, "margin\\(8, 8, 8, 8")

  blk <- new_theme_stem_block()
  plot_input <- reactive(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = plot_input)),
    {
      session$setInputs(padding = 12)
      code <- norm(session$returned$expr())
      expect_match(code, "margin\\(12, 12, 12, 12")
    }
  )
})

test_that("theme block is state-ready with default (auto) font size", {
  blk <- new_theme_stem_block()
  plot_input <- reactive(
    ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  )

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = plot_input)),
    {
      session$flushReact()
      ready <- blockr.core:::state_ready_reactive(
        "x", blk, session$returned$state, session
      )
      expect_true(ready())
    }
  )
})
