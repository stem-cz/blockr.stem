test_that("new_stem_import_block constructs a file/data block", {
  blk <- new_stem_import_block()
  expect_s3_class(blk, "stem_import_block")
  expect_s3_class(blk, "file_block")
})

test_that("stem_import_volumes exposes navigable roots", {
  vols <- stem_import_volumes()
  expect_true(is.character(vols))
  expect_true(all(c("Home", "Root") %in% names(vols)))
  expect_true(dir.exists(vols[["Home"]]))
})

test_that("picking a file emits a rio::import() call that reads it", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"), stringsAsFactors = FALSE)
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(df, path)
  path <- normalizePath(path)

  # Root the file browser at the file's own directory rather than "/". Splitting
  # an absolute path on "/" and rebuilding from "/" is Unix-only: on Windows a
  # normalized path starts with a drive letter (C:\...), so parseFilePaths()
  # would reconstruct a bogus "/C:/..." path that does not exist.
  vols <- c(Test = dirname(path))
  sel <- list(root = "Test", files = list(list(basename(path))))
  # The block stores whatever parseFilePaths() reconstructs (forward slashes on
  # Windows), so compare state against that round-tripped value, not `path`.
  expected <- unname(shinyFiles::parseFilePaths(vols, sel)$datapath)

  blk <- new_stem_import_block(volumes = vols)
  testServer(
    function(id) blockr.core::expr_server(blk, data = list()),
    {
      session$setInputs(file = sel)

      expr <- session$returned$expr()
      code <- paste(deparse(expr), collapse = " ")
      expect_match(code, "rio::import")
      expect_identical(session$returned$state$file_path(), expected)

      # blockr's check_expr_val requires state to return every constructor
      # input (this caught a missing `volumes` that crashed the board).
      expect_true(
        all(
          blockr.core:::block_ctor_inputs(blk) %in%
            names(session$returned$state)
        )
      )

      out <- eval(expr)
      expect_s3_class(out, "data.frame")
      expect_identical(out$b, df$b)
    }
  )
})

test_that("stem_read_expr dispatches on file extension", {
  rds <- stem_read_expr("/a/b.rds")
  expect_match(paste(deparse(rds), collapse = " "), "rio::import")

  csv <- stem_read_expr("/a/b.csv")
  expect_match(paste(deparse(csv), collapse = " "), "readr::read_csv")

  tsv <- stem_read_expr("/a/b.csv", list(sep = "\t"))
  expect_match(paste(deparse(tsv), collapse = " "), "readr::read_tsv")

  xlsx <- stem_read_expr("/a/b.xlsx")
  expect_match(paste(deparse(xlsx), collapse = " "), "readxl::read_excel")

  # SPSS files are read via rio and converted from labelled numerics to factors.
  sav <- stem_read_expr("/a/b.sav")
  sav_code <- paste(deparse(sav), collapse = " ")
  expect_match(sav_code, "haven::read_spss")
  expect_match(sav_code, "haven::as_factor")
})

test_that("SPSS import converts labelled columns to factors", {
  skip_if_not_installed("haven")

  df <- data.frame(q1 = c(1, 2, 1), stringsAsFactors = FALSE)
  df$q1 <- haven::labelled(df$q1, labels = c(No = 1, Yes = 2))
  path <- withr::local_tempfile(fileext = ".sav")
  haven::write_sav(df, path)

  out <- eval(stem_read_expr(normalizePath(path)))
  expect_s3_class(out, "data.frame")
  expect_s3_class(out$q1, "factor")
  expect_identical(as.character(out$q1), c("No", "Yes", "No"))
})

test_that("CSV options flow from the gear popover into the read expression", {
  df <- data.frame(x = 1:2, y = c("p", "q"))
  path <- withr::local_tempfile(fileext = ".csv")
  # Write with a semicolon delimiter and two junk header lines to skip.
  writeLines(c("# junk", "# junk2", "x;y", "1;p", "2;q"), path)
  path <- normalizePath(path)

  # See the rds test above: root the browser at the file's directory so the
  # synthesized selection reconstructs to a real path on Windows too.
  vols <- c(Test = dirname(path))
  sel <- list(root = "Test", files = list(list(basename(path))))

  blk <- new_stem_import_block(volumes = vols)
  testServer(
    function(id) blockr.core::expr_server(blk, data = list()),
    {
      session$setInputs(file = sel)
      session$setInputs(csv_sep = ";", csv_skip = "2")

      expr <- session$returned$expr()
      code <- paste(deparse(expr), collapse = " ")
      expect_match(code, "read_delim")
      expect_match(code, 'delim = ";"')

      out <- eval(expr)
      expect_s3_class(out, "data.frame")
      expect_identical(names(out), c("x", "y"))
      expect_identical(as.character(out$y), c("p", "q"))
    }
  )
})

test_that("block waits (no expr) until a file is chosen", {
  blk <- new_stem_import_block()
  testServer(
    function(id) blockr.core::expr_server(blk, data = list()),
    {
      # No file selected -> the expr reactive is gated by req().
      expect_error(session$returned$expr(), class = "shiny.silent.error")
    }
  )
})
