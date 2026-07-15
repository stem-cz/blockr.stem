# Changelog

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
