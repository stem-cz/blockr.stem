# Handoff: pinning the blockr / dockViewR stack with `rv`

_Last updated 2026-07-22._

## TL;DR

- The blockr stack is pinned with **[`rv`](https://a2-ai.github.io/rv-docs/)**, a
  declarative R package manager. The single source of truth is **`rproject.toml`**;
  the resolved commit shas are frozen in **`rv.lock`**. Both are committed.
- **To reproduce the known-good environment:** `rv sync`. rv installs exactly what
  is in `rv.lock` into the project library (`rv/library/`, git-ignored). Took ~70s
  here (binaries from PPM + cached git builds).
- `.Rprofile` activates the rv library automatically when you start R in this repo,
  so `devtools::load_all()` / `devtools::test()` / the demo app run against the
  pinned library with no extra steps.
- **Do not** `pak::pkg_install()` / update the blockr packages ad hoc. Change the
  pin in `rproject.toml`, run `rv sync`, commit `rproject.toml` + `rv.lock`.
- The linchpin is still **dockViewR 0.3.0** (0.4.0 breaks dock panel placement).
  `rproject.toml` forces it from CRAN/PPM via `prefer_repositories_for`.

## Why rv (what it fixed)

The old setup broke repeatedly because dependencies were silently updated — locally
or on GitHub HEAD — and the pinned set could not be reinstalled cleanly. Three traps,
all now closed:

1. **Silent local / GitHub drift.** rv gives the project its own library and freezes
   every dependency's resolved commit sha in `rv.lock`. `rv sync` reinstalls exactly
   that; nothing installed elsewhere on the machine leaks in, and upstream HEAD churn
   cannot move the pins. `rv sync --locked` fails loudly if `rproject.toml` and
   `rv.lock` ever drift (use it in CI).
2. **pak's solver couldn't install the pinned set.** blockr.dock / dplyr / ggplot / io
   each carry a bare `Remotes: BristolMyersSquibb/blockr.core` (= main HEAD) that
   conflicts with a pinned `blockr.core` sha. rv follows `Remotes` by default **but an
   explicit top-level pin wins**, so listing `blockr.core @ 2492d08` in `dependencies`
   overrides the transitive HEAD. Verified: `rv.lock` froze `blockr.core` at `2492d08`,
   not the HEAD the Remotes point to. The old one-by-one `dependencies = FALSE` recipe
   is gone.
3. **dockViewR 0.4.0.** `prefer_repositories_for = ["dockViewR"]` forces it from the
   repository (0.3.0), so no `Remotes` branch (e.g. cynkra/dockViewR@95-panel-mount-event)
   can pull 0.4.0 in transitively. blockr.dock @ 8bad10e only requires `(>= 0.2.1)`,
   which 0.3.0 satisfies.

## Known-good stack (frozen in `rv.lock`)

| Package        | Version      | Source / commit         |
| -------------- | ------------ | ----------------------- |
| blockr         | 0.1.1        | git `17b7cb5`           |
| blockr.core    | 0.1.4        | git `2492d08`           |
| blockr.dock    | 0.1.3        | git `8bad10e`           |
| blockr.dplyr   | 0.2.0.9004   | git `43d92f5`           |
| blockr.ggplot  | 0.1.1.9001   | git `522d986`           |
| blockr.io      | 0.1.0.9004   | git `d79a65f`           |
| stemtools      | 0.1.2        | git `8b4343c`           |
| spreadview     | 0.3.0        | git `9658eb8`           |
| blockr.dag     | 0.1.2        | PPM (CRAN mirror)       |
| **dockViewR**  | **0.3.0**    | **PPM/CRAN — pinned**   |

## Everyday commands

```sh
rv sync            # make the project library match rv.lock (reproduce the env)
rv plan            # dry run: show what sync would install, no changes
rv add owner/repo  # add a git dep and re-sync (edits rproject.toml)
rv upgrade         # move pins forward (then review + commit rproject.toml + rv.lock)
rv summary         # project status
rv run -e '<R>'    # run R with the project library configured (or just start R here)
```

## Run / verify the demo app

```r
devtools::load_all(".")                 # working-tree code (NOT library())
source("inst/examples/stem_demo_app.R") # serve() returns a shinyApp that launches
```

Confirm: panels place correctly (no black background) and all blocks appear,
including **STEM Excel Export**.

> Automated screenshot verification needs a Chromium-based browser (chromote).
> None is installed on this machine, so the visual check is manual. The functional
> checks (correct versions in the rv library, `devtools::load_all()`, all 9 STEM
> blocks register, `devtools::test()` green) all pass under the pinned stack.

## Moving the pin forward (e.g. when the dockViewR 0.4.x fix stabilizes)

The upstream fix for the blank-panel bug (blockr.dock PR #361 / #367) requires
dockViewR >= 0.4.0 with the `dockview:active-panel` event. When it reaches a tagged
release / CRAN:

1. Edit `rproject.toml`: bump the `blockr.dock` commit, drop or raise the `dockViewR`
   pin (and its `prefer_repositories_for` entry), adjust the others as its Remotes
   require. Best done in a throwaway checkout first.
2. `rv sync`, run the demo app, confirm non-front dock tabs render (no black panels).
3. If solid, commit the new `rproject.toml` + `rv.lock` and update this table.
   Rollback is `git checkout rproject.toml rv.lock && rv sync`.

## CI

CI (`R-CMD-check.yaml`) stays **decoupled** from the pin — it installs the blockr
HEADs and only fails on real errors (not upstream deprecation warnings), acting as
an early-warning canary for upstream breakage. Optionally add a second job that runs
`rv sync --locked` (via `a2-ai/actions/setup-rv` or by installing the `rv` binary)
to prove the pinned stack still builds. The two jobs are independent: one catches
"upstream broke us", the other "our pin no longer installs".

## Files

- `rproject.toml` — the declarative pin (edit this, then `rv sync`).
- `rv.lock` — resolved shas + versions (generated; commit it, don't hand-edit).
- `.Rprofile`, `rv/scripts/` — activation (committed). `rv/library/` — the installed
  library (git-ignored via `rv/.gitignore`; rebuilt by `rv sync`).
