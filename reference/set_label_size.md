# Resize a plot's data labels

Adjusts the size of the text drawn by
[`ggplot2::geom_text()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
and
[`ggplot2::geom_label()`](https://ggplot2.tidyverse.org/reference/geom_text.html)
layers of a plot - e.g. the percentage labels inside a
[`stemtools::stem_barplot()`](https://stem-cz.github.io/stemtools/reference/stem_barplot.html)
or
[`stemtools::stem_inline()`](https://stem-cz.github.io/stemtools/reference/stem_inline.html) -
while leaving axis, legend and title text untouched. Used by
[`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)
to expose an inner-label size control.

## Usage

``` r
set_label_size(plot, size)
```

## Arguments

- plot:

  A ggplot object.

- size:

  Label size in points.

## Value

`plot`, with the size of its text/label layers updated.

## Examples

``` r
if (requireNamespace("stemtools", quietly = TRUE)) {
  set_label_size(stemtools::stem_barplot(iris, Species), 14)
}
```
