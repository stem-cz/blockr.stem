test_that("stem_freq_table returns readable (weighted) percentages", {
  df <- data.frame(g = factor(rep(c("a", "b"), c(3, 1))), w = c(1, 1, 1, 5))

  unweighted <- stem_freq_table(df["g"], "g")
  expect_identical(names(unweighted), c("Category", "Percent", "CI low", "CI high"))
  expect_identical(unweighted$Category, c("a", "b"))
  expect_equal(unweighted$Percent, c(75, 25))

  weighted <- stem_freq_table(df, "g", "w")
  # 'b' has weight 5, so its weighted share is larger than the raw 25%.
  expect_gt(weighted$Percent[weighted$Category == "b"], 25)
})

test_that("block_output renders a frequency table, not the raw rows", {
  blk <- new_stem_var_selector_block()
  result <- data.frame(g = factor(rep(c("a", "b"), 5)))
  out <- block_output.stem_var_selector_block(blk, result, session = NULL)
  expect_s3_class(out, "shiny.render.function")
})

test_that("new_stem_var_selector_block constructs a transform block", {
  blk <- new_stem_var_selector_block()
  expect_s3_class(blk, "stem_var_selector_block")
  expect_s3_class(blk, "transform_block")
})

test_that("selector outputs the chosen single column, default first cat var", {
  blk <- new_stem_var_selector_block()
  data_input <- reactive(iris) # only 'Species' is categorical

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      # No row selected yet -> first categorical variable (Species).
      code0 <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code0, "\\[\"Species\"\\]")

      ready <- blockr.core:::state_ready_reactive(
        "x", blk, session$returned$state, session
      )
      expect_true(ready())
    }
  )
})

test_that("selecting a weight adds the weight column tagged with stem_weight", {
  blk <- new_stem_var_selector_block()
  df <- data.frame(g = factor(c("a", "b", "a")), w = c(1, 2, 1.5))
  attr(df$g, "label") <- "Group"
  data_input <- reactive(df)

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(vars_rows_selected = 1L, weight = "w")
      session$flushReact()
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_identical(names(out), c("g", "w"))
  expect_identical(attr(out, "stem_weight", exact = TRUE), "w")
  expect_identical(attr(out$g, "label", exact = TRUE), "Group")
})

test_that("downstream chart weights automatically from the selector's tag", {
  # Emulate a selector output: g + w, tagged with stem_weight.
  df <- data.frame(g = factor(rep(c("a", "b"), 6)), w = runif(12, 1, 3))
  tagged <- structure(df, stem_weight = "w")

  blk <- new_stem_chart_block()
  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(tagged))),
    {
      session$setInputs(var = "g") # user does NOT touch the weight control
      session$flushReact()
      code <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_match(code, "weight = w") # picked up from the attribute
      e <<- exprs_to_lang(session$returned$expr())
    }
  )
  expect_s3_class(eval_impl(blk, e, list(data = tagged)), "ggplot")
})

test_that("selecting a group carries the column tagged with stem_group", {
  blk <- new_stem_var_selector_block()
  df <- data.frame(
    g = factor(c("a", "b", "a", "b")),
    grp = factor(c("x", "x", "y", "y")),
    w = c(1, 2, 1, 2)
  )
  data_input <- reactive(df)

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$setInputs(vars_rows_selected = 1L, group = "grp", weight = "w")
      session$flushReact()
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_true(all(c("g", "grp", "w") %in% names(out)))
  expect_identical(attr(out, "stem_group", exact = TRUE), "grp")
})

test_that("grouped barplot maps selected var to fill via group =; inline ignores group", {
  df <- data.frame(g = factor(rep(c("a", "b"), 6)), grp = factor(rep(c("x", "y"), each = 6)))
  tagged <- structure(df, stem_group = "grp")
  blk <- new_stem_chart_block()

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(tagged))),
    {
      session$setInputs(var = "g", type = "barplot")
      bar <- gsub("\\s+", " ", paste(deparse(session$returned$expr()), collapse = " "))
      # selected variable is the item (fill), grouping variable goes to group =
      # (stemtools 0.1.1 puts the group on the axis, item on the fill)
      expect_match(bar, "stem_barplot\\(.\\(data\\), g, group = grp[,)]")

      # stem_inline() has no group argument, so it must be omitted.
      session$setInputs(type = "inline")
      inl <- paste(deparse(session$returned$expr()), collapse = " ")
      expect_no_match(inl, "group")
    }
  )
})

test_that("stem_freq_table adds a Series column when grouping", {
  df <- data.frame(g = factor(rep(c("a", "b"), 4)), grp = factor(rep(c("x", "y"), each = 4)))
  out <- stem_freq_table(df, "g", group = "grp")
  expect_true("Series" %in% names(out))
  # grouping variable is the row category, selected variable is the series
  expect_setequal(unique(out$Category), c("x", "y"))
  expect_setequal(unique(out$Series), c("a", "b"))
})

test_that("selector expression evaluates to the single labelled column", {
  blk <- new_stem_var_selector_block()
  df <- data.frame(n = 1:3, g = factor(c("a", "b", "a")))
  attr(df$g, "label") <- "Group"
  data_input <- reactive(df)

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = data_input)),
    {
      session$flushReact()
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_s3_class(out, "data.frame")
  expect_identical(names(out), "g")
  expect_identical(attr(out$g, "label", exact = TRUE), "Group")
})
