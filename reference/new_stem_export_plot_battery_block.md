# STEM Export (chart or battery) block

A two-input variant of
[`new_stem_export_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_export_block.md):
it accepts a plot from a **STEM Visualize** block *and* a plot from a
**STEM Visualize battery** block and lets the user pick which one to
export with a toggle. Everything else - the PNG / SVG / native
PowerPoint export, the size / scaling controls and the live preview -
works exactly as in
[`new_stem_export_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_export_block.md)
(the two blocks share the same export helpers and preview renderer).

The block's output panel shows the same live preview as
[`new_stem_export_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_export_block.md)

- the selected plot rendered by the very
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
  call used for the download - via the shared preview renderer.

## Usage

``` r
new_stem_export_plot_battery_block(
  target = c("plot", "battery"),
  format = c("png", "svg", "pptx"),
  width = 14,
  height = NA_real_,
  scale = 1.5,
  ...
)

# S3 method for class 'stem_export_plot_battery_block'
block_ui(id, x, ...)

# S3 method for class 'stem_export_plot_battery_block'
block_output(x, result, session)
```

## Arguments

- target:

  Which upstream input to export by default, `"plot"` (the STEM
  Visualize input) or `"battery"` (the STEM Visualize battery input).

- format:

  Export format, one of `"png"`, `"svg"` or `"pptx"`.

- width:

  Export width in centimetres (default `14`).

- height:

  Export height in centimetres. `NA` (the default) picks a height from
  the plot type (6 cm inline, 10 cm bar plot).

- scale:

  Multiplicative scaling factor passed to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)'s
  `scale` argument for the PNG/SVG image formats (default `1.5`).
  Because the output size is fixed, a **higher** number makes the plot's
  text and marks appear **smaller** (and a lower number makes them
  larger). Ignored by the PowerPoint chart export, which is not
  rasterised.

- ...:

  Forwarded to
  [`blockr.ggplot::new_ggplot_transform_block()`](https://bristolmyerssquibb.github.io/blockr.ggplot/reference/new_ggplot_transform_block.html).

- id:

  Passed by blockr when rendering the block UI.

- x, result, session:

  Passed by blockr when rendering the block UI/output.

## Value

A ggplot transform block object of class
`stem_export_plot_battery_block`.

## Details

Both inputs are **optional**, so the block works with just one wired up:
the toggle chooses the export target when both are connected, but falls
back to whichever input *is* connected when the chosen one is missing.
When neither is connected the block waits (blank preview) rather than
erroring.

## Examples

``` r
new_stem_export_plot_battery_block(target = "battery", format = "png")
#> <stem_export_plot_battery_block<ggplot_transform_block<block>>>
#> Name: "Stem export plot battery"
#> Data inputs: "plot" and "battery"
#> Initial block state:
#>  $ target: chr "battery"
#>  $ format: chr "png"
#>  $ width : num 14
#>  $ height: num NA
#>  $ scale : num 1.5
#> Constructor: blockr.stem::new_stem_export_plot_battery_block()
```
