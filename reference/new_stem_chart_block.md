# STEM Chart block

A blockr transform block that plots a single variable from an upstream
data frame using one of the stemtools plotting functions. The user picks
a variable and chooses between a bar plot
([`stemtools::stem_barplot()`](https://stem-cz.github.io/stemtools/reference/stem_barplot.html))
and an inline plot
([`stemtools::stem_inline()`](https://stem-cz.github.io/stemtools/reference/stem_inline.html)).
Styling arguments (label size, palette, label options) are tucked under
an "Advanced options" disclosure.

## Usage

``` r
new_stem_chart_block(
  var = character(),
  type = c("barplot", "inline"),
  weight = character(),
  label_size = 14,
  palette = "div1",
  direction = 1,
  labels = TRUE,
  label_accuracy = 1,
  ...
)
```

## Arguments

- var:

  Name of the variable (column) to plot. When empty, the first column of
  the upstream data is used.

- type:

  Chart type, one of `"barplot"` or `"inline"`.

- weight:

  Optional name of a numeric column of survey weights to pass to the
  stemtools function. Empty (the default) plots unweighted counts.

- label_size:

  Size in points of the inner data labels (the percentage labels drawn
  on the bars). Defaults to `14`; use `NA` to keep the stemtools default
  sizing instead. To restyle the axis/legend text, use
  [`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md)
  downstream instead.

- palette:

  Name of a Stem palette passed to the plotting function, e.g. `"div1"`.
  See
  [`stemtools::stem_palette()`](https://stem-cz.github.io/stemtools/reference/stem_palette.html).

- direction:

  Palette direction: `1` (default) or `-1` to reverse.

- labels:

  If `TRUE`, print a percentage label on each bar.

- label_accuracy:

  Rounding accuracy of labels; `1` gives whole numbers, `0.1` one
  decimal place.

- ...:

  Forwarded to
  [`blockr.ggplot::new_ggplot_transform_block()`](https://bristolmyerssquibb.github.io/blockr.ggplot/reference/new_ggplot_transform_block.html).

## Value

A ggplot transform block object of class `stem_chart_block`.

## Examples

``` r
new_stem_chart_block(var = "Species", type = "barplot", label_size = 5)
#> <stem_chart_block<ggplot_transform_block<block>>>
#> Name: "Stem chart"
#> Data inputs: "data"
#> Initial block state:
#>  $ var           : chr "Species"
#>  $ type          : chr "barplot"
#>  $ weight        : chr(0)
#>  $ label_size    : num 5
#>  $ palette       : chr "div1"
#>  $ direction     : num 1
#>  $ labels        : logi TRUE
#>  $ label_accuracy: num 1
#> Constructor: blockr.stem::new_stem_chart_block()
```
