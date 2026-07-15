# STEM Visualize block

A single blockr block that plots a variable with a stemtools function
*and* applies the Stem theme, so the final, styled chart is produced in
one place - combining everything
[`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)
and
[`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md)
offer without having to wire (or jump between) two blocks. Chart options
and theme options live under separate "Advanced" disclosures.

## Usage

``` r
new_stem_visualize_block(
  var = character(),
  type = c("barplot", "inline"),
  weight = character(),
  label_size = 14,
  palette = "div1",
  direction = 1,
  labels = TRUE,
  label_accuracy = 1,
  ink = "black",
  paper = "white",
  accent = "#35978F",
  family = "Calibri",
  font_size = NA_real_,
  padding = stem_default_padding,
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

  Optional name of a numeric column of survey weights. Empty (the
  default) plots unweighted counts.

- label_size:

  Size in points of the inner data labels. Defaults to `14`; `NA` keeps
  the stemtools default.

- palette, direction, labels, label_accuracy:

  Chart styling passed to the stemtools function (see
  [`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)).

- ink, paper, accent, family:

  Stem theme arguments (see
  [`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md)
  and
  [`stemtools::theme_stem()`](https://stem-cz.github.io/stemtools/reference/theme_stem.html)).

- font_size:

  Base text size in points for the axis/legend/title text. `NA` (the
  default) keeps the theme's own sizing.

- padding:

  Padding in millimetres added to the plot margin so the extreme axis
  labels (e.g. "0 %" / "100 %") are not clipped. Defaults to 8 mm.

- ...:

  Forwarded to
  [`blockr.ggplot::new_ggplot_transform_block()`](https://bristolmyerssquibb.github.io/blockr.ggplot/reference/new_ggplot_transform_block.html).

## Value

A ggplot transform block object of class `stem_visualize_block`.

## Examples

``` r
new_stem_visualize_block(var = "Species", accent = "#35978F")
#> <stem_visualize_block<ggplot_transform_block<block>>>
#> Name: "Stem visualize"
#> Data inputs: "data"
#> Initial block state:
#>  $ var           : chr "Species"
#>  $ type          : chr "barplot"
#>  $ weight        : chr(0)
#>  $ label_size    : num 14
#>  $ palette       : chr "div1"
#>  $ direction     : num 1
#>  $ labels        : logi TRUE
#>  $ label_accuracy: num 1
#>  $ ink           : chr "black"
#>  $ paper         : chr "white"
#>  $ accent        : chr "#35978F"
#>  $ family        : chr "Calibri"
#>  $ font_size     : num NA
#>  $ padding       : num 8
#> Constructor: blockr.stem::new_stem_visualize_block()
```
