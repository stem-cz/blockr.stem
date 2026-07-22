# STEM Import block

A blockr data block that imports a data set from a file - like the
"Import Data" block (`read_block`) from **blockr.io**, but the file is
chosen with a graphical point-and-click file browser (via shinyFiles)
instead of by typing a path. It is a root node in an analysis graph: it
takes no data input and provides data to down-stream blocks.

`stem_import_volumes()` returns the default set of root directories
offered by the file browser: the user's home directory and the
filesystem root.

## Usage

``` r
new_stem_import_block(
  file_path = character(),
  args = list(),
  volumes = stem_import_volumes(),
  ...
)

stem_import_volumes()
```

## Arguments

- file_path:

  Initial file path. Normally left empty and set by picking a file in
  the browser.

- args:

  Named list of format-specific reader options (see Details). Normally
  left empty and set via the gear popover.

- volumes:

  Named character vector of root directories the file browser may
  navigate, passed to
  [`shinyFiles::shinyFileChoose()`](https://rdrr.io/pkg/shinyFiles/man/shinyFiles-observers.html).
  Defaults to `stem_import_volumes()` (Home and the filesystem root).

- ...:

  Forwarded to
  [`blockr.core::new_block()`](https://bristolmyerssquibb.github.io/blockr.core/reference/new_block.html).

## Value

A data block object of class `stem_import_block`.

## Details

The selected file is read with the reader that matches its format,
mirroring `read_block`: delimited text (`.csv`/`.tsv`/`.txt`/...) with
[`readr::read_csv()`](https://readr.tidyverse.org/reference/read_delim.html)
and friends, spreadsheets (`.xlsx`/`.xls`/...) with
[`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html),
and everything else (`.rds`, `.dta`, `.parquet`, ...) with
[`rio::import()`](http://gesistsa.github.io/rio/reference/import.md).
SPSS files (`.sav`/`.zsav`/`.por`) are read with
[`haven::read_spss()`](https://haven.tidyverse.org/reference/read_spss.html)
and then passed through
[`haven::as_factor()`](https://forcats.tidyverse.org/reference/as_factor.html),
so labelled numeric columns arrive as proper factors rather than numeric
codes. A gear popover next to the file button exposes the
format-specific options (CSV delimiter/quote/encoding/skip/rows/header;
Excel sheet/range/skip/rows/ header), shown only for the matching file
type - just like `read_block`.

This exists because `blockr.core`'s `filebrowser_block` builds its
output expression as the bare file path (`bquote(.(file), ...)`) rather
than a call that reads the file, so picking a `.rds` file yields the
path string instead of the data. This block wraps the picked path in a
real read call.

## Examples

``` r
new_stem_import_block()
#> <stem_import_block<file_block<block>>>
#> Name: "Stem import"
#> No data inputs
#> Initial block state:
#>  $ file_path: chr(0)
#>  $ args     : list()
#>  $ volumes  : Named chr [1:2] "/home/runner" "/"
#>   ..- attr(*, "names")= chr [1:2] "Home" "Root"
#> Constructor: blockr.stem::new_stem_import_block()
```
