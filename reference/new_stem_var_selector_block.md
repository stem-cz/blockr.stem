# STEM Variable Selector block

A blockr transform block that lists the categorical (factor / character)
variables of an upstream data frame in a searchable table showing each
variable's name, its label (`attr(x, "label")`) and its number of
categories. Clicking a row selects that variable; the block outputs the
single selected column (its label preserved), ready to feed a
[`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)
for plotting - and a
[`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md)
after that for styling.

The block's output panel shows the selected variable's (weighted)
frequency distribution rather than the raw responses. The block's
*value* passed to downstream blocks is still the underlying data, so a
STEM Chart can plot it.

## Usage

``` r
new_stem_var_selector_block(
  var = character(),
  weight = character(),
  group = character(),
  ...
)

# S3 method for class 'stem_var_selector_block'
block_output(x, result, session)
```

## Arguments

- var:

  Name of the variable to select. When empty, the first categorical
  variable is used. Normally set by clicking a table row.

- weight:

  Optional name of a numeric column of survey weights to carry forward.
  Empty (the default) means unweighted. When set, the block outputs the
  weight column alongside the selected variable and tags it so a
  downstream
  [`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)
  /
  [`new_stem_visualize_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_visualize_block.md)
  weights the plot automatically.

- group:

  Optional name of a categorical column to break the plot down by. Empty
  (the default) means no grouping. When set, a downstream bar plot draws
  one stacked bar per category of this grouping variable (on the axis)
  and shows the *selected* variable as the coloured fill series - so the
  number of colours is the selected variable's category count. Grouping
  is only applied to `stem_barplot()`, not `stem_inline()`.

- ...:

  Forwarded to
  [`blockr.core::new_transform_block()`](https://bristolmyerssquibb.github.io/blockr.core/reference/new_transform_block.html).

- x, result, session:

  Passed by blockr when rendering the block output.

## Value

A transform block object of class `stem_var_selector_block`.

## Details

The table and the plot live in separate blocks that can be moved around
independently, so the chart's advanced settings and a downstream theme
block stay fully accessible. Compose it as Selector -\>
[`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md)
-\>
[`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md).

## Examples

``` r
new_stem_var_selector_block()
#> <stem_var_selector_block<transform_block<block>>>
#> Name: "Stem var selector"
#> Data inputs: "data"
#> Initial block state:
#>  $ var   : chr(0)
#>  $ weight: chr(0)
#>  $ group : chr(0)
#> Constructor: blockr.stem::new_stem_var_selector_block()
```
