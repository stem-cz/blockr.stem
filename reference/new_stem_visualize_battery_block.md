# STEM Visualize battery block

A single blockr block that plots a **battery of same-scale categorical
items** - typically a set of Likert items sharing one response scale -
as a stacked-bar chart with
[`stemtools::stem_battery()`](https://stem-cz.github.io/stemtools/reference/stem_battery.html)
(one horizontal bar per item) *and* applies the Stem theme, so the
final, styled chart is produced in one place. The user selects several
variables from a list; only variables that share **identical response
categories** (factor levels) can be plotted together - a mismatched
selection produces an informative error (see
[`stem_battery_plot()`](https://stem-cz.github.io/blockr.stem/reference/stem_battery_plot.md)).
The block emits a plain ggplot, so it pipes cleanly into
[`new_stem_export_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_export_block.md)
for PNG / SVG / PowerPoint download.

## Usage

``` r
new_stem_visualize_battery_block(
  items = character(),
  weight = character(),
  order_by = character(),
  item_label = TRUE,
  palette = "div1",
  direction = 1,
  labels = TRUE,
  label_accuracy = 1,
  label_hide = 0.05,
  reverse_levels = FALSE,
  label_size = 14,
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

- items:

  Character vector of variable (column) names to plot as the battery.
  When empty, the block waits for a selection.

- weight:

  Optional name of a numeric column of survey weights. Empty (the
  default) plots unweighted proportions.

- order_by:

  Optional character vector of response categories used to order the
  items by their combined share, e.g. `c("Strongly agree", "Agree")`.
  Its picker is populated with the selected items' shared categories.

- item_label:

  If `TRUE` (default), label each bar with the variable's `"label"`
  attribute instead of its name (falls back to the name if absent).

- palette, direction, labels, label_accuracy:

  Chart styling passed to
  [`stemtools::stem_battery()`](https://stem-cz.github.io/stemtools/reference/stem_battery.html)
  (see
  [`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)).

- label_hide:

  Proportions below this threshold are left unlabelled. Defaults to
  `0.05`.

- reverse_levels:

  If `TRUE`, reverse the items' response categories (factor levels) to
  flip the orientation of the response scale in the plot. Defaults to
  `FALSE`.

- label_size:

  Size in points of the inner data labels. Defaults to `14`; `NA` keeps
  the stemtools default.

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
  labels are not clipped. Defaults to 8 mm.

- ...:

  Forwarded to
  [`blockr.ggplot::new_ggplot_transform_block()`](https://bristolmyerssquibb.github.io/blockr.ggplot/reference/new_ggplot_transform_block.html).

## Value

A ggplot transform block object of class `stem_visualize_battery_block`.

## Details

Chart options and theme options live under separate "Advanced"
disclosures, mirroring
[`new_stem_visualize_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_visualize_block.md).

## Examples

``` r
new_stem_visualize_battery_block(items = c("q1", "q2"), accent = "#35978F")
#> <stem_visualize_battery_block<ggplot_transform_block<block>>>
#> Name: "Stem visualize battery"
#> Data inputs: "data"
#> Initial block state:
#>  $ items         : chr [1:2] "q1" "q2"
#>  $ weight        : chr(0)
#>  $ order_by      : chr(0)
#>  $ item_label    : logi TRUE
#>  $ palette       : chr "div1"
#>  $ direction     : num 1
#>  $ labels        : logi TRUE
#>  $ label_accuracy: num 1
#>  $ label_hide    : num 0.05
#>  $ reverse_levels: logi FALSE
#>  $ label_size    : num 14
#>  $ ink           : chr "black"
#>  $ paper         : chr "white"
#>  $ accent        : chr "#35978F"
#>  $ family        : chr "Calibri"
#>  $ font_size     : num NA
#>  $ padding       : num 8
#> Constructor: blockr.stem::new_stem_visualize_battery_block()
```
