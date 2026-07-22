# A small same-scale battery: three factor items sharing one Likert scale.
battery_df <- function() {
  lv <- c("Strongly disagree", "Disagree", "Agree", "Strongly agree")
  set.seed(1)
  df <- data.frame(
    q1 = factor(sample(lv, 40, TRUE), levels = lv),
    q2 = factor(sample(lv, 40, TRUE), levels = lv),
    q3 = factor(sample(lv, 40, TRUE), levels = lv),
    other = factor(sample(c("Yes", "No"), 40, TRUE)),
    w = runif(40, 0.5, 2)
  )
  attr(df$q1, "label") <- "Trust in police"
  attr(df$q2, "label") <- "Trust in EU"
  attr(df$q3, "label") <- "Trust in government"
  df
}

test_that("new_stem_visualize_battery_block constructs a ggplot transform block", {
  blk <- new_stem_visualize_battery_block(items = c("q1", "q2"))
  expect_s3_class(blk, "stem_visualize_battery_block")
  expect_s3_class(blk, "ggplot_transform_block")
})

test_that("expression combines a stem_battery call with theme_stem", {
  blk <- new_stem_visualize_battery_block()
  data_input <- reactive(battery_df())

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(
        items = c("q1", "q2", "q3"), weight = "w",
        order_by = c("Strongly agree", "Agree"), accent = "#FF0000"
      )
      code <- paste(deparse(session$returned$expr()), collapse = " ")

      expect_match(code, "stem_battery_plot")
      expect_match(code, "set_label_size")
      expect_match(code, "stemtools::theme_stem")
      expect_match(code, "accent = \"#FF0000\"")
      expect_match(code, "weight = \"w\"")
      expect_match(code, "order_by = c\\(\"Strongly agree\",\\s+\"Agree\"\\)")

      ready <- blockr.core:::state_ready_reactive(
        "x", blk, session$returned$state, session
      )
      expect_true(ready())
    }
  )
})

test_that("block waits until at least one item is selected", {
  blk <- new_stem_visualize_battery_block()
  data_input <- reactive(battery_df())

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(items = character())
      # req(length(chosen) >= 1) short-circuits, so nothing is returned.
      expect_error(session$returned$expr())
    }
  )
})

test_that("combined expression evaluates to a themed ggplot", {
  skip_if_not_installed("stemtools")
  blk <- new_stem_visualize_battery_block()
  df <- battery_df()
  data_input <- reactive(df)

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(items = c("q1", "q2", "q3"), weight = "w", accent = "#FF0000")
      session$flushReact()
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_s3_class(out, "ggplot")
})

test_that("stem_battery_plot draws a battery of matching items", {
  skip_if_not_installed("stemtools")
  df <- battery_df()
  p <- stem_battery_plot(df, items = c("q1", "q2", "q3"), weight = "w")
  expect_s3_class(p, "ggplot")
})

test_that("reverse_levels flips the response-scale segment order", {
  skip_if_not_installed("stemtools")
  df <- battery_df()
  # Segment widths of a single item, in spatial (left-to-right) order.
  widths <- function(rev) {
    p <- stem_battery_plot(df, items = c("q1", "q2", "q3"), reverse_levels = rev)
    d <- ggplot2::ggplot_build(p)$data[[1L]]
    d <- d[d$y == d$y[1L], ]
    d <- d[order(d$xmin), ]
    d$xmax - d$xmin
  }
  # Reversing the levels mirrors the stack, so the widths come out reversed.
  expect_equal(widths(TRUE), rev(widths(FALSE)))
})

test_that("stem_battery_plot errors informatively on mismatched levels", {
  skip_if_not_installed("stemtools")
  df <- battery_df()
  expect_error(
    stem_battery_plot(df, items = c("q1", "other")),
    "same response categories"
  )
})

test_that("stem_battery_plot rejects non-categorical and missing items", {
  df <- battery_df()
  expect_error(
    stem_battery_plot(df, items = c("q1", "w")),
    "must be categorical"
  )
  expect_error(
    stem_battery_plot(df, items = c("q1", "nope")),
    "not found"
  )
  expect_error(stem_battery_plot(df, items = character()), "at least one")
})
