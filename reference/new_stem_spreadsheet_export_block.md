# STEM Excel Export block

A blockr block that exports the upstream data set as a **readable MS
Excel spreadsheet** of frequency tables, built with
[`spreadview::compose_spreadsheet()`](https://rdrr.io/pkg/spreadview/man/compose_spreadsheet.html).
The variables to tabulate are picked automatically with
[`spreadview::get_categorical_vars()`](https://rdrr.io/pkg/spreadview/man/get_categorical_vars.html) -
every factor column (plus character columns when `include_char` is on),
minus any the user chooses to `exclude`. Optional grouping variables and
a survey weight are forwarded to `compose_spreadsheet()`.

The block's output panel previews the (pass-through) data set that will
be exported as a table.

## Usage

``` r
new_stem_spreadsheet_export_block(
  include_char = FALSE,
  exclude = character(),
  group = character(),
  weight = character(),
  percent = TRUE,
  na_rm = TRUE,
  ...
)

# S3 method for class 'stem_spreadsheet_export_block'
block_output(x, result, session)
```

## Arguments

- include_char:

  When `TRUE`, character columns are tabulated alongside factor columns;
  when `FALSE` (the default) only factors are, matching
  [`spreadview::get_categorical_vars()`](https://rdrr.io/pkg/spreadview/man/get_categorical_vars.html)'s
  default.

- exclude:

  Character vector of variable names to drop from the automatic
  categorical selection (passed to `get_categorical_vars()`'s
  `exclude`). Empty (the default) excludes nothing.

- group:

  Optional character vector of categorical variables to break the
  frequency tables down by (passed to `compose_spreadsheet()`'s
  `group`). Empty (the default) means no grouping.

- weight:

  Optional name of a numeric column of survey weights (passed to
  `compose_spreadsheet()`'s `weight`). Empty (the default) means
  unweighted.

- percent:

  When `TRUE` (the default) cells are formatted as percentages,
  otherwise as plain counts (`compose_spreadsheet()`'s `percent`).

- na_rm:

  When `TRUE` (the default) missing values are dropped from the tables
  (`compose_spreadsheet()`'s `na.rm`).

- ...:

  Forwarded to
  [`blockr.core::new_transform_block()`](https://bristolmyerssquibb.github.io/blockr.core/reference/new_transform_block.html).

- x, result, session:

  Passed by blockr when rendering the block output.

## Value

A transform block object of class `stem_spreadsheet_export_block`.

## Details

The block passes its input data through unchanged, so it can sit
anywhere in a pipeline; its output panel previews the data being
exported and the *Download* button writes the `.xlsx` file.

Excel export requires the spreadview package (GitHub only). If it is not
installed the download reports an error explaining how to install it.

## Examples

``` r
new_stem_spreadsheet_export_block()
#> <stem_spreadsheet_export_block<transform_block<block>>>
#> Name: "Stem spreadsheet export"
#> Data inputs: "data"
#> Initial block state:
#>  $ include_char: logi FALSE
#>  $ exclude     : chr(0)
#>  $ group       : chr(0)
#>  $ weight      : chr(0)
#>  $ percent     : logi TRUE
#>  $ na_rm       : logi TRUE
#> Constructor: blockr.stem::new_stem_spreadsheet_export_block()
```
