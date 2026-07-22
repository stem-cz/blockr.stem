test_that("set_label_size resizes text/label layers only", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point() +
    ggplot2::geom_text(ggplot2::aes(label = rownames(mtcars)))

  out <- set_label_size(p, 20)

  is_text <- vapply(
    out$layers,
    function(l) inherits(l$geom, "GeomText") || inherits(l$geom, "GeomLabel"),
    logical(1)
  )

  # The text layer picked up the new size (converted points -> mm) ...
  expect_equal(out$layers[[which(is_text)]]$aes_params$size, 20 / ggplot2::.pt)
  # ... and the point layer was left untouched.
  expect_null(out$layers[[which(!is_text)]]$aes_params$size)
})

test_that("set_label_size is a no-op when there are no text layers", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  out <- set_label_size(p, 20)
  expect_null(out$layers[[1]]$aes_params$size)
})

test_that("stem_plot_expr emits title args only when the title is shown", {
  code <- function(...) paste(deparse(stem_plot_expr(item = as.name("g"), ...)), collapse = " ")

  # Off by default: neither argument is emitted (keeps the call at the stemtools
  # defaults).
  expect_no_match(code(), "title_show")
  expect_no_match(code(), "title_quote")

  # title_show on -> emitted; title_quote stays off unless asked for.
  expect_match(code(title_show = TRUE), "title_show = TRUE")
  expect_no_match(code(title_show = TRUE), "title_quote")
  expect_match(code(title_show = TRUE, title_quote = TRUE), "title_quote = TRUE")

  # title_quote is inert without title_show (no title to quote).
  expect_no_match(code(title_quote = TRUE), "title_quote")
})

test_that("stem_plot_expr emits title_wrap only when non-default and title shown", {
  code <- function(...) paste(deparse(stem_plot_expr(item = as.name("g"), ...)), collapse = " ")

  # Default wrap (80) is never emitted, on or off.
  expect_no_match(code(), "title_wrap")
  expect_no_match(code(title_show = TRUE), "title_wrap")
  expect_no_match(code(title_show = TRUE, title_wrap = 80), "title_wrap")

  # A non-default wrap is emitted only when the title is shown (nothing to wrap
  # otherwise).
  expect_match(code(title_show = TRUE, title_wrap = 40), "title_wrap = 40")
  expect_no_match(code(title_wrap = 40), "title_wrap")

  # Inf disables wrapping and is a non-default, so it is emitted.
  expect_match(code(title_show = TRUE, title_wrap = Inf), "title_wrap = Inf")

  # NA falls back to the stemtools default (not emitted).
  expect_no_match(code(title_show = TRUE, title_wrap = NA_real_), "title_wrap")
})

test_that("stem_battery_expr emits a self-contained stem_battery_plot call", {
  code <- function(...) {
    paste(deparse(stem_battery_expr(...)), collapse = " ")
  }

  # Bare items only: items passed as a character literal, no weight/order_by, no
  # label_size wrapper.
  base <- code(items = c("q1", "q2"))
  expect_match(base, "blockr.stem::stem_battery_plot")
  expect_match(base, "items = c\\(\"q1\", \"q2\"\\)")
  expect_no_match(base, "weight")
  expect_no_match(base, "order_by")
  expect_no_match(base, "set_label_size")

  # Optional args surface only when supplied; label_size wraps the call.
  full <- code(
    items = c("q1", "q2"), weight = "w",
    order_by = c("Agree", "Strongly agree"), label_size = 14
  )
  expect_match(full, "weight = \"w\"")
  expect_match(full, "order_by = c\\(\"Agree\",\\s+\"Strongly agree\"\\)")
  expect_match(full, "blockr.stem::set_label_size")

  # Blank items/order_by entries are dropped.
  expect_no_match(code(items = c("q1", "")), "\"\"")
  expect_no_match(code(items = "q1", order_by = c("", "")), "order_by")

  # reverse_levels is off by default (not emitted) and surfaces only when set.
  expect_no_match(base, "reverse_levels")
  expect_match(code(items = "q1", reverse_levels = TRUE), "reverse_levels = TRUE")
})

test_that("stem_col_levels reports a factor's levels and a character's sorted values", {
  f <- factor(c("b", "a"), levels = c("b", "a"))
  expect_identical(stem_col_levels(f), c("b", "a"))
  expect_identical(stem_col_levels(c("b", "a", "b")), c("a", "b"))
})

test_that("stem_battery_levels returns the first selected item's categories", {
  lv <- c("No", "Yes")
  df <- data.frame(
    q1 = factor(c("Yes", "No"), levels = lv),
    q2 = factor(c("No", "Yes"), levels = lv),
    n = 1:2
  )
  expect_identical(stem_battery_levels(df, c("q1", "q2")), lv)
  # Numeric / unknown columns are ignored.
  expect_identical(stem_battery_levels(df, c("n", "q1")), lv)
  expect_identical(stem_battery_levels(df, character()), character(0))
})

test_that("stem_cat_var_choices keeps only categorical columns", {
  df <- data.frame(a = factor(c("x", "y")), b = 1:2, c = c("p", "q"))
  attr(df$a, "label") <- "Item A"
  ch <- stem_cat_var_choices(df)
  expect_identical(unname(ch), c("a", "c"))
  expect_identical(names(ch)[1], "a - Item A")
})

test_that("stem_var_choices shows labels next to names, name only when absent", {
  df <- data.frame(a = 1:3, b = 4:6, c = 7:9)
  attr(df$a, "label") <- "Age of respondent"
  attr(df$c, "label") <- ""

  ch <- stem_var_choices(df)

  # Values are always the column names.
  expect_identical(unname(ch), c("a", "b", "c"))
  # Display names: labelled -> "name - label"; unlabelled / blank -> name only.
  expect_identical(names(ch), c("a - Age of respondent", "b", "c"))
})
