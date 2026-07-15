# STEM Export block

A blockr block that previews an upstream ggplot and lets the user
download it as a **PNG** or **SVG** image, or as a **native PowerPoint
chart** (`.pptx`), at a chosen size in centimetres. Width defaults to 14
cm; height defaults to the plot type - 6 cm for an inline plot
([`stemtools::stem_inline()`](https://stem-cz.github.io/stemtools/reference/stem_inline.html))
and 10 cm for a bar plot
([`stemtools::stem_barplot()`](https://stem-cz.github.io/stemtools/reference/stem_barplot.html)) -
and can be overridden.

The block's output panel shows a live preview of the plot *exactly as it
will be exported*: it is produced by the same
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
call as the download, so the chosen width/height (cm) set the aspect
ratio and the scaling factor changes the apparent size of the text and
marks. The preview updates automatically whenever the format, width,
height or scaling inputs change.

## Usage

``` r
new_stem_export_block(
  format = c("png", "svg", "pptx"),
  width = 14,
  height = NA_real_,
  scale = 1.5,
  ...
)

# S3 method for class 'stem_export_block'
block_ui(id, x, ...)

# S3 method for class 'stem_export_block'
block_output(x, result, session)
```

## Arguments

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

A ggplot transform block object of class `stem_export_block`.

## Details

SVG export uses
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)'s
`"svg"` device, which requires the svglite package; if it is not
installed the SVG download reports an error and PNG can be used instead.

PowerPoint export writes a **native, editable Office chart** (not a
picture) via
[`stem_write_pptx_chart()`](https://stem-cz.github.io/blockr.stem/reference/stem_write_pptx_chart.md) -
the recipient can *Edit Data* in Excel and restyle it by hand. It
requires the mschart and officer packages and only works for the STEM
bar / inline plots (see
[`stem_write_pptx_chart()`](https://stem-cz.github.io/blockr.stem/reference/stem_write_pptx_chart.md)).

## Examples

``` r
new_stem_export_block(format = "png", width = 14)
#> <stem_export_block<ggplot_transform_block<block>>>
#> Name: "Stem export"
#> Data inputs: "data"
#> Initial block state:
#>  $ format: chr "png"
#>  $ width : num 14
#>  $ height: num NA
#>  $ scale : num 1.5
#> Constructor: blockr.stem::new_stem_export_block()
```
