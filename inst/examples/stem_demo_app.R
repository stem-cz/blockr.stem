# Minimal blockr.stem demo app
# -----------------------------
# Chains seeded by one blockr.core static block holding a small synthetic,
# *labelled* survey data set (the variable labels are what the Visualize block's
# "Show title" option and the PowerPoint chart title display):
#   1. STEM Variable Selector -> STEM Visualize --\
#                                                  >--> STEM Export (chart/battery)
#   2. STEM Visualize battery --------------------/
#      A single two-input export block: the STEM Visualize chart feeds its `plot`
#      input and the STEM Visualize battery (agree1..agree4, all sharing one
#      5-point agreement scale) feeds its `battery` input. Flip the "Export"
#      toggle to switch which one is previewed / downloaded (PNG, SVG or native
#      PowerPoint chart) - or wire just one and it is used regardless.
#   3. STEM Excel Export - tabulates every categorical variable of the survey
#      into a downloadable Excel spreadsheet (here grouped by region, weighted)
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

# A battery of Likert items that all share ONE 5-point agreement scale - the
# input the STEM Visualize battery block expects (it only plots items with
# identical response categories). Same levels, different label per item.
agree_levels <- c(
  "Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"
)
agree_item <- function(label, prob) {
  labelled(
    factor(sample(agree_levels, n, replace = TRUE, prob = prob), levels = agree_levels),
    label
  )
}

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
  agree1 = agree_item(
    "The staff were friendly and helpful", c(0.05, 0.1, 0.15, 0.4, 0.3)
  ),
  agree2 = agree_item(
    "The service was good value for money", c(0.1, 0.2, 0.25, 0.3, 0.15)
  ),
  agree3 = agree_item(
    "I found what I was looking for quickly", c(0.15, 0.25, 0.2, 0.25, 0.15)
  ),
  agree4 = agree_item(
    "I would use this service again", c(0.05, 0.1, 0.2, 0.35, 0.3)
  ),
  weight = round(stats::runif(n, 0.5, 2), 2),
  stringsAsFactors = FALSE
)

# The modern blockr UI is the docking layout from blockr.dock: build a
# new_dock_board() (NOT blockr.core::new_board(), which serves an unstyled page)
# and hand it to serve(). Blocks are named; links connect them via named input
# ports (most take "data"; the two-input export block takes "plot" / "battery");
# the edit-board extension adds the toolbar for editing links/blocks; `views`
# lists the panels shown in the single view (the extension plus the blocks).
serve(
  new_dock_board(
    blocks = c(
      survey = new_static_block(survey),
      select = new_stem_var_selector_block(var = "satisfaction"),
      viz = new_stem_visualize_block(var = "satisfaction", title_show = TRUE),
      # The battery block reads a set of same-scale items straight from the data,
      # so it connects directly to the static survey block (not via the selector).
      battery = new_stem_visualize_battery_block(
        items = c("agree1", "agree2", "agree3", "agree4"),
        order_by = c("Strongly agree", "Agree")
      ),
      # One two-input STEM Export block fed by BOTH the chart (viz -> `plot`) and
      # the battery (battery -> `battery`); the "Export" toggle picks which one to
      # preview / download. PNG works for either; the native PowerPoint chart is
      # reconstructable from the single-variable chart (the battery exports as an
      # image).
      export = new_stem_export_plot_battery_block(target = "plot", format = "png"),
      # The Excel export reads its categorical variables straight from the data,
      # so it too connects directly to the static survey block. Here it groups
      # the frequency tables by region and weights them by the `weight` column.
      xlsx_export = new_stem_spreadsheet_export_block(
        group = "region", weight = "weight"
      )
    ),
    links = c(
      l1 = new_link("survey", "select", "data"),
      l2 = new_link("select", "viz", "data"),
      l3 = new_link("survey", "battery", "data"),
      # Both plots feed the single export block on its two named input ports.
      l4 = new_link("viz", "export", "plot"),
      l5 = new_link("battery", "export", "battery"),
      l6 = new_link("survey", "xlsx_export", "data")
    ),
    extensions = list(edit = new_edit_board_extension()),
    views = list(c(
      "edit", "survey", "select", "viz", "battery", "export", "xlsx_export"
    ))
  ),
  "my_board"
)
