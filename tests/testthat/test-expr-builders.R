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
