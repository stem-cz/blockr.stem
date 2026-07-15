# Theme STEM block

A blockr transform block that applies the complete Stem ggplot2 theme
([`stemtools::theme_stem()`](https://stem-cz.github.io/stemtools/reference/theme_stem.html))
to an upstream ggplot2 plot. It works like the blockr.ggplot Theme
block, but instead of exposing individual theme elements it applies the
Stem house theme, exposing that theme's own arguments (`ink`, `paper`,
`accent`, `family`) as block controls.

## Usage

``` r
new_theme_stem_block(
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

- ink:

  Foreground colour used for text, titles and axis lines.

- paper:

  Background colour behind the panel, plot, strips and legend keys.

- accent:

  Accent colour (e.g. the fill of
  [`ggplot2::geom_smooth()`](https://ggplot2.tidyverse.org/reference/geom_smooth.html)).
  Defaults to the primary Stem brand colour.

- family:

  Font family for all text. Defaults to `"Calibri"`, the Stem house
  font. A blank string uses the graphics device's default family.

- font_size:

  Base text size in points for the axis, legend and title text. Use `NA`
  (the default) to keep the theme's own sizing. This controls the plot's
  structural text; to resize the inner data labels of a
  [`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md),
  use that block's own label-size control.

- padding:

  Padding in millimetres added to the plot margin so the extreme axis
  labels (e.g. "0 %" / "100 %") are not clipped. Defaults to 8 mm.

- ...:

  Forwarded to
  [`blockr.ggplot::new_ggplot_transform_block()`](https://bristolmyerssquibb.github.io/blockr.ggplot/reference/new_ggplot_transform_block.html).

## Value

A ggplot transform block object of class `theme_stem_block`.

## Examples

``` r
new_theme_stem_block(accent = "#35978F", font_size = 14)
#> <theme_stem_block<ggplot_transform_block<block>>>
#> Name: "Theme stem"
#> Data inputs: "data"
#> Initial block state:
#>  $ ink      : chr "black"
#>  $ paper    : chr "white"
#>  $ accent   : chr "#35978F"
#>  $ family   : chr "Calibri"
#>  $ font_size: num 14
#>  $ padding  : num 8
#> Constructor: blockr.stem::new_theme_stem_block()

if (interactive()) {
  library(blockr.core)
  # The block needs a ggplot input, see app.R for a full board demo.
  serve(new_theme_stem_block())
}
```
