# Export a STEM plot as a native, editable PowerPoint chart

Writes a `.pptx` file containing a **native Microsoft Office chart** - a
real `c:chart` object backed by an embedded Excel worksheet - rather
than a picture of the plot. The recipient can open the deck and use
*Chart Design \> Edit Data* to change the numbers by hand in Excel,
restyle the chart, etc.

## Usage

``` r
stem_write_pptx_chart(plot, file, width = NA_real_, height = NA_real_)
```

## Arguments

- plot:

  A ggplot object produced by a STEM chart / visualize block.

- file:

  Path of the `.pptx` file to write.

- width, height:

  Size of the chart on the slide, in centimetres. Default `NA` fills the
  slide (leaving a small margin); pass explicit values to place a
  fixed-size, centred chart instead.

## Value

`file`, invisibly.

## Details

Because a native Office chart is built from *data* (not pixels), this
only works for the STEM bar / inline plots, whose summarised data and
aesthetic mapping are recovered from the ggplot object
([`stemtools::stem_barplot()`](https://stem-cz.github.io/stemtools/reference/stem_barplot.html),
[`stemtools::stem_inline()`](https://stem-cz.github.io/stemtools/reference/stem_inline.html)).
The category axis, the (optional) coloured series and the values are
read back from the plot; the Stem palette colours are carried over to
the chart's series so it looks right out of the box. Any other ggplot
raises an error - export those as PNG or SVG instead.

The chart inherits the plot's Stem theme (font family and ink colour
from
[`stemtools::theme_stem()`](https://stem-cz.github.io/stemtools/reference/theme_stem.html),
legend on top) so it matches the on-screen plot. Being a native chart it
can be freely resized in PowerPoint, so it is placed filling the slide
by default rather than at a fixed centimetre size.

Requires the mschart and officer packages.
