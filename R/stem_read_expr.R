#' Build a read expression for the STEM Import block
#'
#' Helpers that turn a picked file path plus format-specific options into an
#' unevaluated read call, mirroring the reader dispatch of blockr.io's
#' `read_block`: delimited text is read with \pkg{readr}, spreadsheets with
#' \pkg{readxl}, SPSS files (`.sav`/`.zsav`/`.por`) with [haven::read_spss()]
#' wrapped in [haven::as_factor()] (so labelled numeric columns become factors),
#' and everything else (`.rds`, `.dta`, `.parquet`, ...) with [rio::import()].
#'
#' @param path File path (length-1 character).
#' @param args Named list of format options collected from the gear popover
#'   (`sep`, `quote`, `encoding`, `skip`, `n_max`, `col_names` for CSV; `sheet`,
#'   `range`, `skip`, `n_max`, `col_names` for Excel). Missing entries fall back
#'   to sensible defaults.
#'
#' @return An unevaluated call (language object).
#'
#' @keywords internal
#' @noRd
stem_file_category <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("csv", "tsv", "txt", "dat", "tab")) {
    return("csv")
  }
  if (ext %in% c("xls", "xlsx", "xlsm", "xlsb")) {
    return("excel")
  }
  # SPSS files (read by rio via haven) carry variable/value labels on numeric
  # columns; we convert those to proper factors downstream.
  if (ext %in% c("sav", "zsav", "por")) {
    return("spss")
  }
  "other"
}

#' @rdname stem_file_category
#' @noRd
stem_read_expr <- function(path, args = list()) {
  path <- unname(path)
  switch(stem_file_category(path),
    csv = stem_read_expr_csv(path, args),
    excel = stem_read_expr_excel(path, args),
    spss = stem_read_expr_spss(path, args),
    bquote(rio::import(file = .(p)), list(p = path))
  )
}

#' @rdname stem_file_category
#' @noRd
stem_read_expr_spss <- function(path, args = list()) {
  # Read SPSS with haven directly (not rio::import, which drops the value labels
  # on the way out, leaving bare numeric codes). `haven::read_spss()` keeps them
  # as `haven_labelled` columns; `haven::as_factor()` then turns every labelled
  # column into a factor using its value labels, which is what downstream STEM
  # survey blocks expect.
  bquote(
    haven::as_factor(haven::read_spss(file = .(p))),
    list(p = path)
  )
}

#' @rdname stem_file_category
#' @noRd
stem_read_expr_csv <- function(path, args = list()) {
  sep <- args$sep %||% ","
  col_names <- args$col_names %||% TRUE
  skip <- args$skip %||% 0
  n_max <- args$n_max %||% Inf
  quote <- args$quote %||% "\""
  encoding <- args$encoding %||% "UTF-8"

  if (sep == ",") {
    bquote(
      readr::read_csv(
        file = .(path), col_names = .(col_names), skip = .(skip),
        n_max = .(n_max), quote = .(quote),
        locale = readr::locale(encoding = .(encoding)),
        show_col_types = FALSE
      ),
      list(
        path = path, col_names = col_names, skip = skip, n_max = n_max,
        quote = quote, encoding = encoding
      )
    )
  } else if (sep == "\t") {
    bquote(
      readr::read_tsv(
        file = .(path), col_names = .(col_names), skip = .(skip),
        n_max = .(n_max), quote = .(quote),
        locale = readr::locale(encoding = .(encoding)),
        show_col_types = FALSE
      ),
      list(
        path = path, col_names = col_names, skip = skip, n_max = n_max,
        quote = quote, encoding = encoding
      )
    )
  } else {
    bquote(
      readr::read_delim(
        file = .(path), delim = .(sep), col_names = .(col_names),
        skip = .(skip), n_max = .(n_max), quote = .(quote),
        locale = readr::locale(encoding = .(encoding)),
        show_col_types = FALSE
      ),
      list(
        path = path, sep = sep, col_names = col_names, skip = skip,
        n_max = n_max, quote = quote, encoding = encoding
      )
    )
  }
}

#' @rdname stem_file_category
#' @noRd
stem_read_expr_excel <- function(path, args = list()) {
  sheet <- args$sheet
  range <- args$range
  col_names <- args$col_names %||% TRUE
  skip <- args$skip %||% 0
  n_max <- args$n_max %||% Inf

  bquote(
    readxl::read_excel(
      path = .(path), sheet = .(sheet), range = .(range),
      col_names = .(col_names), skip = .(skip), n_max = .(n_max)
    ),
    list(
      path = path, sheet = sheet, range = range, col_names = col_names,
      skip = skip, n_max = n_max
    )
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x
