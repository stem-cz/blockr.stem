# blockr.stem 0.1.5

* **STEM Export (chart/battery)** (`new_stem_export_plot_battery_block()`) — new
  output block: a two-input variant of **STEM Export** that accepts a plot from a
  **STEM Visualize** block *and* a plot from a **STEM Visualize battery** block,
  with a toggle to choose which one to export. Both inputs are optional, so it
  works with just one wired up — the toggle picks the target when both are
  connected and falls back to whichever input *is* connected otherwise. The
  PNG / SVG / native PowerPoint export, the size / scaling controls and the live
  preview are shared with `new_stem_export_block()`, so they behave identically.

* **STEM Excel Export** (`new_stem_spreadsheet_export_block()`) — fixed a crash at
  startup ("attempt to set an attribute on NULL") when the block is wired to an
  upstream source that has not produced data yet (e.g. STEM Import before a file
  is chosen). The picker-refresh helper `stem_spread_cat_choices()` now returns
  no choices for `NULL`/empty data, matching `stem_weight_choices()`.

# blockr.stem 0.1.4

* **STEM Excel Export** (`new_stem_spreadsheet_export_block()`) — new output block
  that exports the upstream data set as a readable Excel spreadsheet of frequency
  tables via `spreadview::compose_spreadsheet()`. The variables to tabulate are
  picked automatically with `spreadview::get_categorical_vars()` — every factor
  column (add character columns with **Include character variables**), minus any
  the user chooses to **Exclude** (each listed with its category count, e.g.
  `region (4)`). Optional **Grouping variables** and a **Survey weight** are
  forwarded to `compose_spreadsheet()`, along with the **percentage** and
  **drop-missing** formatting toggles. The block passes its data through
  unchanged and previews it in the output panel. Requires the GitHub-only
  `spreadview (>= 0.3.0)` package (in Suggests); character selections are coerced
  to factors, which `compose_spreadsheet()` requires. spreadview's own console
  warnings/messages are suppressed as noise in a blockr app.

* **STEM Visualize battery** (`new_stem_visualize_battery_block()`) — new plot
  block that plots a battery of same-scale categorical items (e.g. Likert items
  sharing one response scale) as a stacked-bar chart (`stemtools::stem_battery()`)
  and applies the Stem theme in one block. The items are validated to share
  identical response categories, so a mismatched selection surfaces an
  informative error rather than a cryptic reshape failure.

# blockr.stem 0.1.3

* **STEM Visualize** — new chart title options under "Chart options", all off /
  at the stemtools defaults so existing charts are unchanged. Requires
  `stemtools (>= 0.1.2)`.
  * **Show title** (`title_show`) draws the plotted variable's label as the
    chart title (rendered bold and left-aligned by `theme_stem()`).
  * **Add title quotes** (`title_quote`) wraps the title in typographic
    quotation marks.
  * **Title wrap** (`title_wrap`) sets the maximum characters per title line so
    long titles wrap instead of overflowing. Affects the PNG/SVG (ggsave)
    exports only; the native PowerPoint chart is unaffected.

* **STEM Export** — the title now carries through to every export format. PNG/SVG
  render it automatically; the native PowerPoint chart reconstructs the title
  (including its bold face) and left-aligns it to match `theme_stem()`, by
  editing the chart OOXML in the written `.pptx`.

* **STEM Import** — SPSS files (`.sav`/`.zsav`/`.por`) are now read with
  `haven::read_spss()` wrapped in `haven::as_factor()`, so labelled numeric
  columns arrive as proper factors (with their value labels) rather than the
  bare numeric codes `rio::import()` left behind — which is what the downstream
  survey blocks expect.

# blockr.stem 0.1.1

* **STEM Export** — the PowerPoint chart preview now renders its text at the same
  size as the exported native chart. The preview is scaled to match the chart's
  data labels (`1 / stem_pptx_label_scale`), so it no longer shows oversized
  fonts relative to the downloaded `.pptx`.

* **STEM Export** — fixed the category (y-axis) order of the exported PowerPoint
  chart, which came out reversed relative to the preview and the PNG/SVG exports.
  The reversal accounts for mschart ordering the category axis by row order for
  single-series bar charts and by factor levels for grouped/stacked charts.

# blockr.stem 0.1.0

First release.

* **STEM Import** (`new_stem_import_block()`) — root data block that imports a
  data set from a file chosen with a point-and-click file browser
  (`shinyFiles`). Delimited text is read with `readr`, spreadsheets with
  `readxl`, and everything else (`.rds`, `.sav`, `.dta`, `.parquet`, ...) with
  `rio::import()`. Format-specific options are exposed via a gear popover.

* **STEM Variable Selector** (`new_stem_var_selector_block()`) — a searchable
  table of the categorical variables (name, label, category count); click a row
  to output that single column for plotting. Optional survey-weight and grouping
  selections are carried downstream to the plot blocks. The output panel shows
  the selected variable's (weighted) frequency distribution.

* **STEM Chart** (`new_stem_chart_block()`) — plots a single variable with a
  `stemtools` chart: a bar plot (`stem_barplot()`) or an inline plot
  (`stem_inline()`), with palette, label, weight and grouping options.

* **STEM Visualize** (`new_stem_visualize_block()`) — plots a variable *and*
  applies the Stem theme in one block, combining every STEM Chart and Theme STEM
  setting to produce the final, styled chart.

* **Theme STEM** (`new_theme_stem_block()`) — applies the Stem ggplot2 theme
  (`stemtools::theme_stem()`) to an upstream plot, controlling ink, paper,
  accent and font family.

* **STEM Export** (`new_stem_export_block()`) — previews an upstream plot and
  downloads it as PNG or SVG at a chosen size in centimetres, or as a native,
  editable PowerPoint chart (`.pptx`) via `stem_write_pptx_chart()`.
