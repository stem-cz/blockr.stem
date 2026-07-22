.onLoad <- function(libname, pkgname) {
  blockr.core::register_blocks(
    "new_theme_stem_block",
    name = "Theme STEM",
    description = paste(
      "Apply the Stem ggplot2 theme (theme_stem) to an upstream plot,",
      "controlling ink, paper, accent and font family"
    ),
    category = "plot",
    icon = "palette2",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_chart_block",
    name = "STEM Chart",
    description = paste(
      "Plot a single variable from the upstream data with a stemtools",
      "chart: a bar plot (stem_barplot) or an inline plot (stem_inline)"
    ),
    category = "plot",
    icon = "bar-chart-line",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_visualize_block",
    name = "STEM Visualize",
    description = paste(
      "Plot a variable with a stemtools chart and apply the Stem theme in one",
      "block: all STEM Chart and Theme STEM settings, showing the final chart"
    ),
    category = "plot",
    icon = "easel",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_visualize_battery_block",
    name = "STEM Visualize battery",
    description = paste(
      "Plot a battery of same-scale categorical items (e.g. Likert items) as a",
      "stacked-bar chart (stem_battery) and apply the Stem theme in one block"
    ),
    category = "plot",
    icon = "list-ol",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_export_block",
    name = "STEM Export",
    description = paste(
      "Preview an upstream plot and download it as PNG or SVG at a chosen",
      "size in centimetres (height defaults to the plot type)"
    ),
    category = "output",
    icon = "download",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_spreadsheet_export_block",
    name = "STEM Excel Export",
    description = paste(
      "Export the data as a readable Excel spreadsheet of frequency tables",
      "(spreadview::compose_spreadsheet) over its categorical variables, with",
      "optional grouping variables and a survey weight"
    ),
    category = "output",
    icon = "file-earmark-spreadsheet",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_import_block",
    name = "STEM Import",
    description = paste(
      "Import a data set from a file (rds, csv, xlsx, sav, dta, parquet, ...)",
      "chosen with a graphical point-and-click file browser"
    ),
    category = "input",
    icon = "folder2-open",
    package = pkgname,
    overwrite = TRUE
  )
  blockr.core::register_blocks(
    "new_stem_var_selector_block",
    name = "STEM Variable Selector",
    description = paste(
      "Searchable table of the categorical variables and their labels;",
      "click a row to output that single column for a STEM Chart to plot"
    ),
    category = "transform",
    icon = "list-check",
    package = pkgname,
    overwrite = TRUE
  )
  invisible(NULL)
}
