# Changelog

## blockr.stem 0.1.3

- **STEM Visualize** — new chart title options under “Chart options”,
  all off / at the stemtools defaults so existing charts are unchanged.
  Requires `stemtools (>= 0.1.2)`.

  - **Show title** (`title_show`) draws the plotted variable’s label as
    the chart title (rendered bold and left-aligned by `theme_stem()`).
  - **Add title quotes** (`title_quote`) wraps the title in typographic
    quotation marks.
  - **Title wrap** (`title_wrap`) sets the maximum characters per title
    line so long titles wrap instead of overflowing. Affects the PNG/SVG
    (ggsave) exports only; the native PowerPoint chart is unaffected.

- **STEM Export** — the title now carries through to every export
  format. PNG/SVG render it automatically; the native PowerPoint chart
  reconstructs the title (including its bold face) and left-aligns it to
  match `theme_stem()`, by editing the chart OOXML in the written
  `.pptx`.

- **STEM Import** — SPSS files (`.sav`/`.zsav`/`.por`) are now read with
  [`haven::read_spss()`](https://haven.tidyverse.org/reference/read_spss.html)
  wrapped in
  [`haven::as_factor()`](https://forcats.tidyverse.org/reference/as_factor.html),
  so labelled numeric columns arrive as proper factors (with their value
  labels) rather than the bare numeric codes
  [`rio::import()`](http://gesistsa.github.io/rio/reference/import.md)
  left behind — which is what the downstream survey blocks expect.

## blockr.stem 0.1.1

- **STEM Export** — the PowerPoint chart preview now renders its text at
  the same size as the exported native chart. The preview is scaled to
  match the chart’s data labels (`1 / stem_pptx_label_scale`), so it no
  longer shows oversized fonts relative to the downloaded `.pptx`.

- **STEM Export** — fixed the category (y-axis) order of the exported
  PowerPoint chart, which came out reversed relative to the preview and
  the PNG/SVG exports. The reversal accounts for mschart ordering the
  category axis by row order for single-series bar charts and by factor
  levels for grouped/stacked charts.

## blockr.stem 0.1.0

First release.

- **STEM Import**
  ([`new_stem_import_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_import_block.md))
  — root data block that imports a data set from a file chosen with a
  point-and-click file browser (`shinyFiles`). Delimited text is read
  with `readr`, spreadsheets with `readxl`, and everything else (`.rds`,
  `.sav`, `.dta`, `.parquet`, …) with
  [`rio::import()`](http://gesistsa.github.io/rio/reference/import.md).
  Format-specific options are exposed via a gear popover.

- **STEM Variable Selector**
  ([`new_stem_var_selector_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_var_selector_block.md))
  — a searchable table of the categorical variables (name, label,
  category count); click a row to output that single column for
  plotting. Optional survey-weight and grouping selections are carried
  downstream to the plot blocks. The output panel shows the selected
  variable’s (weighted) frequency distribution.

- **STEM Chart**
  ([`new_stem_chart_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_chart_block.md))
  — plots a single variable with a `stemtools` chart: a bar plot
  (`stem_barplot()`) or an inline plot (`stem_inline()`), with palette,
  label, weight and grouping options.

- **STEM Visualize**
  ([`new_stem_visualize_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_visualize_block.md))
  — plots a variable *and* applies the Stem theme in one block,
  combining every STEM Chart and Theme STEM setting to produce the
  final, styled chart.

- **Theme STEM**
  ([`new_theme_stem_block()`](https://stem-cz.github.io/blockr.stem/reference/new_theme_stem_block.md))
  — applies the Stem ggplot2 theme
  ([`stemtools::theme_stem()`](https://stem-cz.github.io/stemtools/reference/theme_stem.html))
  to an upstream plot, controlling ink, paper, accent and font family.

- **STEM Export**
  ([`new_stem_export_block()`](https://stem-cz.github.io/blockr.stem/reference/new_stem_export_block.md))
  — previews an upstream plot and downloads it as PNG or SVG at a chosen
  size in centimetres, or as a native, editable PowerPoint chart
  (`.pptx`) via
  [`stem_write_pptx_chart()`](https://stem-cz.github.io/blockr.stem/reference/stem_write_pptx_chart.md).
