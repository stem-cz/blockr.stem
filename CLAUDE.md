# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

`blockr.stem` is an R package that extends the **blockr** low-code
framework (`blockr.core` + `blockr.ggplot`) with STEM-branded blocks for
a data pipeline: import a data set → select/plot a categorical (survey)
variable with
[`stemtools`](https://stem-cz.github.io/blockr.stem/package%20%60stemtools%60)
→ apply the Stem house theme → export as PNG/SVG or a native, editable
PowerPoint chart. All output is oriented around
[`stemtools::stem_barplot()`](https://stem-cz.github.io/stemtools/reference/stem_barplot.html)
/ `stem_inline()` survey charts.

## Common commands

This is a standard R package with roxygen2 docs and testthat (edition
3). There is no build system beyond R/devtools; run these from an R
session at the repo root (e.g. `R -q -e '<expr>'`):

- **Run all tests:**
  [`devtools::test()`](https://devtools.r-lib.org/reference/test.html)
- **Run one test file:** `devtools::test(filter = "expr-builders")`
  (matches `tests/testthat/test-expr-builders.R`; the filter is the name
  after `test-`)
- **Regenerate docs + NAMESPACE after changing roxygen `@` tags or
  exports:**
  [`devtools::document()`](https://devtools.r-lib.org/reference/document.html)
  — the `NAMESPACE` and `man/*.Rd` are generated; never hand-edit them.
- **Full package check:**
  [`devtools::check()`](https://devtools.r-lib.org/reference/check.html)
- **Load for interactive work:**
  [`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)

An MCP server (`r-btw` / `r-mcptools`) is available for driving a live R
session and has dedicated tools (`btw_tool_pkg_test`,
`btw_tool_pkg_document`, `btw_tool_pkg_check`, `btw_tool_pkg_load_all`)
— prefer these when an R session is already running.

## Architecture

### Block registration

`R/zzz.R`’s `.onLoad()` calls
[`blockr.core::register_blocks()`](https://bristolmyerssquibb.github.io/blockr.core/reference/register_block.html)
for each exported `new_*_block()` constructor, assigning a `category`
(`input` / `transform` / `plot` / `output`), an icon and a description.
**Adding a block means adding both its constructor and a
`register_blocks()` entry here.**

### Block constructor pattern

Every block is a `new_*_block()` function that wraps a
blockr.core/blockr.ggplot constructor (`new_file_block`,
`new_transform_block`, `new_ggplot_transform_block`) and passes three
things:

1.  A **server function** `function(id, data) moduleServer(...)`. It
    mirrors each constructor argument into a `reactiveVal` (`r_<name>`),
    wires `observeEvent` to keep those in sync with the inputs, and
    returns a list with:
    - `expr` — a `reactive()` that builds an **unevaluated language
      object** (see below), and
    - `state` — the named list of reactiveVals, one per constructor
      argument.
2.  A **UI function** `function(id)` returning the block’s controls
    (Shiny inputs, `tags$details` disclosures for advanced options).
3.  `class`, `allow_empty_state`, and usually `expr_type = "bquoted"`.

`allow_empty_state` lists every state field that may legitimately read
as empty (optional columns, NA-able sizes, “auto” toggles). **Omitting a
field here makes the block gate on “waiting for its inputs to be set”
and never render** — this is the most common cause of a block that
silently does nothing.

### Expression building (`R/expr-builders.R`, `R/stem_read_expr.R`)

Blocks do not compute results directly; they emit code that blockr
evaluates. The helpers in `expr-builders.R` construct these calls with
`bquote`/`as.call`, using the `.(data)` marker as the placeholder blockr
binds to the upstream data (hence `expr_type = "bquoted"`). Key
builders: - `stem_plot_expr()` — a `stem_barplot()` / `stem_inline()`
call, optionally wrapped in
[`blockr.stem::set_label_size()`](https://stem-cz.github.io/blockr.stem/reference/set_label_size.md).
Shared by the Chart and Visualize blocks. - `stem_theme_expr()` —
appends
[`stemtools::theme_stem()`](https://stem-cz.github.io/stemtools/reference/theme_stem.html) +
margin/font layers to a base plot. Shared by the Theme and Visualize
blocks. - `stem_select_expr()` — subsets to the chosen column(s). -
`stem_read_expr()` — dispatches a picked file path to `readr`
(delimited), `readxl` (spreadsheets) or
[`rio::import()`](http://gesistsa.github.io/rio/reference/import.md)
(everything else).

### Cross-block data flow via attributes

The Variable Selector block tags its output data with `stem_weight` /
`stem_group` attributes (via
[`structure()`](https://rdrr.io/r/base/structure.html) in
`stem_select_expr()`). Downstream plot blocks read them through
`stem_effective_weight()` / `stem_effective_group()`, so a
weight/grouping chosen upstream **overrides** the plot block’s own
control. When touching weighting or grouping, keep the Selector
(authoritative) and the plot block’s fallback in sync.

### The blocks

- **STEM Import** (`stem_import_block.R`) — root data block. Exists
  because blockr.core’s `filebrowser_block` outputs the bare path, not a
  read call; this wraps the shinyFiles-picked path in a real reader.
  Ships a self-contained gear-popover (inline CSS/JS) for format
  options.
- **STEM Variable Selector** (`stem_var_selector_block.R`) — searchable
  DT table of categorical vars; a row click outputs that single column.
  Custom `block_output` shows a
  [`stemtools::stem_summarise_cat()`](https://stem-cz.github.io/stemtools/reference/stem_summarise_cat.html)
  frequency table.
- **STEM Chart** (`stem_chart_block.R`) and **STEM Visualize**
  (`stem_visualize_block.R`) — Chart plots only; Visualize is Chart +
  Theme fused into one block (shares the same
  `stem_plot_expr`/`stem_theme_expr`).
- **Theme STEM** (`theme_stem_block.R`) — applies `theme_stem()` to any
  upstream ggplot.
- **STEM Export** (`stem_export_block.R`, `pptx-chart.R`) — preview +
  download. Its live preview uses the **same `ggsave()` call** as the
  download so what you see matches the file; the preview reads controls
  at `NS("expr", <name>)` because blockr runs the block server under a
  nested `"expr"` namespace. `pptx-chart.R` reconstructs a tidy
  `category/value/series` frame from the ggplot’s `$data`/`$mapping` to
  emit a **native, editable** `mschart` Office chart (only works for
  reconstructable STEM plots; errors otherwise).

## Conventions

- Comments in this codebase are unusually explanatory and explain *why*
  (blockr quirks, ggplot internals, mschart/officer sizing). Match that
  when the reason is non-obvious; don’t add noise where it isn’t.
- `%||%` (null-coalescing) is defined locally in `R/stem_read_expr.R`.
- Optional heavy deps are in `Suggests` and guarded at the call site
  with [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)
  (`mschart`/`officer` for pptx, `svglite` for SVG).
