test_that("new_stem_spreadsheet_export_block constructs a transform block", {
  blk <- new_stem_spreadsheet_export_block()
  expect_s3_class(blk, "stem_spreadsheet_export_block")
  expect_s3_class(blk, "transform_block")
})

test_that("stem_spread_cat_choices labels each variable with its category count", {
  df <- data.frame(
    f = factor(c("a", "b", "a", "c")),
    ch = c("x", "y", "x", "z"),
    n = 1:4,
    stringsAsFactors = FALSE
  )

  # Default: factors only, label is "<name> (<n unique>)".
  choices <- stem_spread_cat_choices(df)
  expect_equal(unname(choices), "f")
  expect_equal(names(choices), "f (3)")

  # include_char = TRUE also offers character columns (but never numerics).
  choices2 <- stem_spread_cat_choices(df, include_char = TRUE)
  expect_setequal(unname(choices2), c("f", "ch"))
  expect_true("ch (3)" %in% names(choices2))
  expect_false("n" %in% unname(choices2))
})

test_that("stem_spread_cat_choices tolerates NULL / empty data", {
  # Upstream data is NULL until a source block produces it (e.g. STEM Import
  # before a file is chosen); the block's startup observer calls this on data(),
  # so it must return no choices rather than erroring on setNames(NULL, ...)
  # ("attempt to set an attribute on NULL"). Mirrors stem_weight_choices().
  expect_identical(stem_spread_cat_choices(NULL), character())
  expect_identical(stem_spread_cat_choices(NULL, include_char = TRUE), character())
  expect_identical(stem_spread_cat_choices(data.frame()), character())
})

test_that("the block's picker observer runs with NULL upstream data", {
  blk <- new_stem_spreadsheet_export_block()

  # Wiring the block to a source that has not produced data yet (data() is NULL,
  # e.g. STEM Import before a file is chosen) must not crash the startup observer
  # that refreshes the exclude/group/weight pickers from data(). Regression for
  # the "attempt to set an attribute on NULL" crash.
  expect_no_error(
    testServer(
      function(id) blockr.core::expr_server(blk, list(data = reactive(NULL))),
      {
        session$flushReact()
      }
    )
  )
})

test_that("the block tracks its settings in state", {
  blk <- new_stem_spreadsheet_export_block()
  df <- data.frame(
    g = factor(rep(c("a", "b"), 6)),
    reg = factor(rep(letters[1:3], 4)),
    w = runif(12)
  )

  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(df))),
    {
      session$setInputs(
        include_char = TRUE, exclude = "reg", group = "g", weight = "w",
        percent = FALSE, na_rm = FALSE
      )
      st <- session$returned$state
      expect_true(st$include_char())
      expect_equal(st$exclude(), "reg")
      expect_equal(st$group(), "g")
      expect_equal(st$weight(), "w")
      expect_false(st$percent())
      expect_false(st$na_rm())
    }
  )
})

test_that("the block passes the data through unchanged", {
  blk <- new_stem_spreadsheet_export_block()
  df <- data.frame(g = factor(rep(c("a", "b"), 6)))

  eval_impl <- getFromNamespace("eval_impl", "blockr.core")
  exprs_to_lang <- getFromNamespace("exprs_to_lang", "blockr.core")

  e <- NULL
  testServer(
    function(id) blockr.core::expr_server(blk, list(data = reactive(df))),
    {
      e <<- exprs_to_lang(session$returned$expr())
    }
  )

  out <- eval_impl(blk, e, list(data = df))
  expect_identical(out, df)
})

test_that("stem_write_spreadsheet writes a non-empty xlsx with the chosen vars", {
  skip_if_not_installed("spreadview")
  df <- data.frame(
    g = factor(rep(c("Yes", "No"), 6)),
    reg = factor(rep(letters[1:3], 4)),
    ch = rep(c("p", "q"), 6),
    w = runif(12, 0.5, 1.5),
    stringsAsFactors = FALSE
  )

  # Factors only, excluding one; a weighted, grouped, percentage spreadsheet.
  # spreadview's own informational warnings/messages are suppressed by the
  # helper (they are noise in a blockr app), so none should escape here.
  f <- withr::local_tempfile(fileext = ".xlsx")
  out <- expect_no_warning(
    stem_write_spreadsheet(df, f, exclude = "reg", group = "g", weight = "w")
  )
  expect_equal(out, f)
  expect_true(file.exists(f) && file.info(f)$size > 0)

  # include_char pulls character columns in too (coerced to factor, since
  # compose_spreadsheet() only accepts factors); empty exclude/group/weight are
  # tolerated (become NULL) without error.
  f2 <- withr::local_tempfile(fileext = ".xlsx")
  stem_write_spreadsheet(
    df, f2,
    include_char = TRUE, exclude = character(), group = character(),
    weight = character()
  )
  expect_true(file.exists(f2) && file.info(f2)$size > 0)
})
