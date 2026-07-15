test_that("new_stem_chart_block constructs a ggplot transform block", {
  blk <- new_stem_chart_block(var = "Species", type = "barplot")
  expect_s3_class(blk, "stem_chart_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("new_stem_chart_block validates the type argument", {
  expect_error(new_stem_chart_block(type = "scatter"))
})

test_that("stem chart block builds barplot / inline exprs for the chosen variable", {
  blk <- new_stem_chart_block()
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "Species", type = "barplot")
      expect_identical(session$returned$state$var(), "Species")
      barcode <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(barcode, "stemtools::stem_barplot")
      expect_match(barcode, "Species")

      session$setInputs(type = "inline")
      inlinecode <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(inlinecode, "stemtools::stem_inline")
      expect_match(inlinecode, "Species")
    }
  )
})

test_that("stem chart block falls back to the first column when var is unset", {
  blk <- new_stem_chart_block()
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      # No var selected yet -> expression uses the first column (Sepal.Length).
      code <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code, "Sepal.Length")
    }
  )
})

test_that("block is state-ready when label size is auto (empty)", {
  # Regression: label_size is NA when "auto", which reads as empty. If it is not
  # allowed to be empty, blockr gates the block ("waiting for its inputs to be
  # set") and it never renders until a numeric size is picked.
  blk <- new_stem_chart_block(var = "Species")
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "Species", type = "barplot", label_size = "auto")
      session$flushReact()
      ready <- blockr.core:::state_ready_reactive(
        "x", blk, session$returned$state, session
      )
      expect_true(ready())
    }
  )
})

test_that("survey weight is passed to the stemtools call when set", {
  blk <- new_stem_chart_block()
  df <- data.frame(g = factor(c("a", "b", "a")), w = c(1, 2, 1.5))
  data_input <- reactive(df)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(var = "g", type = "barplot")

      # No weight selected -> no weight argument.
      unweighted <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_no_match(unweighted, "weight")

      session$setInputs(weight = "w")
      weighted <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(weighted, "weight = w")
    }
  )
})

test_that("label size defaults to 14 points", {
  blk <- new_stem_chart_block(var = "Species")
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      # No label_size input set yet -> the constructor default (14) applies.
      code <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code, "blockr.stem::set_label_size")
      expect_match(code, "14")
    }
  )
})

test_that("advanced styling arguments flow into the expression", {
  blk <- new_stem_chart_block()
  data_input <- reactive(iris)

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(
        var = "Species", type = "barplot",
        palette = "seq2", direction = "-1",
        labels = FALSE, label_accuracy = "0.1",
        label_size = "auto"
      )

      # Label size "auto": the plotting call is used bare.
      auto <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(auto, "palette = \"seq2\"")
      expect_match(auto, "direction = -1")
      expect_match(auto, "labels = FALSE")
      expect_match(auto, "label_accuracy = 0.1")
      expect_no_match(auto, "set_label_size")

      # Setting a label size wraps the chart in set_label_size(), which resizes
      # the inner data labels only (no theme() layer).
      session$setInputs(label_size = "16")
      sized <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(sized, "blockr.stem::set_label_size")
      expect_match(sized, "16")
      expect_no_match(sized, "element_text")
    }
  )
})
