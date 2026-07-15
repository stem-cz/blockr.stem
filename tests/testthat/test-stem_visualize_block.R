test_that("new_stem_visualize_block constructs a ggplot transform block", {
  blk <- new_stem_visualize_block(var = "Species")
  expect_s3_class(blk, "stem_visualize_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("new_stem_visualize_block validates the type argument", {
  expect_error(new_stem_visualize_block(type = "pie"))
})

test_that("expression combines a stemtools chart with theme_stem", {
  blk <- new_stem_visualize_block()
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "Species", type = "barplot", accent = "#FF0000")
      code <- paste(deparse(session$returned$expr()), collapse = " ")

      # chart part (with the default label size) ...
      expect_match(code, "stemtools::stem_barplot")
      expect_match(code, "set_label_size")
      # ... composed with the theme part.
      expect_match(code, "stemtools::theme_stem")
      expect_match(code, "accent = \"#FF0000\"")

      ready <- blockr.core:::state_ready_reactive(
        "x", blk, session$returned$state, session
      )
      expect_true(ready())
    }
  )
})

test_that("weight and base font size flow into the combined expression", {
  blk <- new_stem_visualize_block()
  df <- data.frame(g = factor(c("a", "b", "a")), w = c(1, 2, 1.5))
  data_input <- reactive(df)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "g", weight = "w", font_size = "16")
      code <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code, "weight = w")
      expect_match(code, "element_text\\(size = 16\\)")
    }
  )
})

test_that("combined expression evaluates to a themed ggplot", {
  blk <- new_stem_visualize_block()
  df <- data.frame(g = factor(rep(c("a", "b", "c"), 4)), w = runif(12, 1, 3))
  data_input <- reactive(df)

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "g", weight = "w", accent = "#FF0000", font_size = "16")
      session$flushReact()
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_s3_class(out, "ggplot")
})
