# Minimal blockr.stem demo app
# -----------------------------
# STEM Variable Selector -> STEM Visualize -> STEM Export, seeded by a
# blockr.core static block holding a small synthetic, *labelled* survey data set
# (the variable labels are what the Visualize block's "Show title" option and the
# PowerPoint chart title display).
#
# The interactive UI is provided by blockr.dock (the docking layout). Serving a
# plain blockr.core::new_board() renders an unstyled page - the app must be a
# blockr.dock::new_dock_board() handed to serve().
#
# IMPORTANT: run against the WORKING-TREE code (the installed blockr.stem may be
# an older version without the new title options). From the package root, start
# an interactive R session and source this file - the serve() call returns a
# shinyApp object that then auto-launches:
#
#   R
#   > devtools::load_all(".")            # load the working tree (NOT library())
#   > source("inst/examples/stem_demo_app.R")
#
# (devtools::load_all() also re-registers the STEM blocks and their S3 UI/output
# methods, so the board renders them with the current code.)

library(blockr.core)
library(blockr.dock)
library(blockr.stem)

labelled <- function(x, label) {
  attr(x, "label") <- label
  x
}

set.seed(42)
n <- 400
survey <- data.frame(
  satisfaction = labelled(
    factor(
      sample(
        c(
          "Very dissatisfied",
          "Dissatisfied",
          "Neutral",
          "Satisfied",
          "Very satisfied"
        ),
        n,
        replace = TRUE,
        prob = c(0.05, 0.1, 0.2, 0.4, 0.25)
      ),
      levels = c(
        "Very dissatisfied",
        "Dissatisfied",
        "Neutral",
        "Satisfied",
        "Very satisfied"
      )
    ),
    "How satisfied are you with our service?"
  ),
  recommend = labelled(
    factor(
      sample(
        c("No", "Maybe", "Yes"),
        n,
        replace = TRUE,
        prob = c(0.2, 0.3, 0.5)
      ),
      levels = c("No", "Maybe", "Yes")
    ),
    "Would you recommend us to a friend?"
  ),
  region = labelled(
    factor(sample(c("North", "South", "East", "West"), n, replace = TRUE)),
    "Region"
  ),
  weight = round(stats::runif(n, 0.5, 2), 2),
  stringsAsFactors = FALSE
)

# The modern blockr UI is the docking layout from blockr.dock: build a
# new_dock_board() (NOT blockr.core::new_board(), which serves an unstyled page)
# and hand it to serve(). Blocks are named; links connect them via the "data"
# input port; the edit-board extension adds the toolbar for editing links/blocks;
# `views` lists the panels shown in the single view (the extension plus the four
# blocks).
serve(
  new_dock_board(
    blocks = c(
      survey = new_static_block(survey),
      select = new_stem_var_selector_block(var = "satisfaction"),
      viz = new_stem_visualize_block(var = "satisfaction", title_show = TRUE),
      export = new_stem_export_block(format = "pptx")
    ),
    links = c(
      l1 = new_link("survey", "select", "data"),
      l2 = new_link("select", "viz", "data"),
      l3 = new_link("viz", "export", "data")
    ),
    extensions = list(edit = new_edit_board_extension()),
    views = list(c("edit", "survey", "select", "viz", "export"))
  ),
  "my_board"
)
