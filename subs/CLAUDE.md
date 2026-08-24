# Submodules

This directory holds source for related projects, vendored as pinned git submodules.

**These trees are read-only.** They are here to be read and cited, not changed — pinned so that
the paths and line numbers we quote in `docs/` stay accurate. For genuine submodule maintenance
(updating or re-pinning), run the git commands yourself with the `!` prefix.

## OpenRocket

`./openrocket` is a submodule of the [OpenRocket source](https://github.com/openrocket/openrocket) —
the Java desktop model-rocket design and flight-simulation application at [openrocket.info](https://openrocket.info).

Read `./CLAUDE-openrocket.md` before working in that tree; it covers the build, module layout,
domain model, and conventions.

## RocketPy

`./rocketpy` is a submodule of [RocketPy](https://github.com/RocketPy-Team/RocketPy) — the Python
six-degrees-of-freedom rocket flight simulation library from the RocketPy Team.

Read `./CLAUDE-rocketpy.md` before working in that tree; it covers the environment, package layout,
domain model, and conventions.

## CamPyRoS

`./campyros` is a submodule of [CamPyRoS](https://github.com/cuspaceflight/CamPyRoS) — the Cambridge
Python Rocketry Simulator, a GPLv3 Python 6-DOF trajectory package from CU Spaceflight. It adds
aerodynamic heating, live wind data, and Monte Carlo stochastic analysis on top of the usual
trajectory model.

Not to be confused with the **Cambridge Rocketry Simulator** vendored at `./camrocsim` — a
separate C++/Java project by Box and Eerland, and the one `docs/research/` surveys as CRS.

Read `./CLAUDE-campyros.md` before working in that tree; it covers the package layout, domain
model, coordinate frames, and the parts of the tree that do not actually run.

Pinned at the tip of `main` (2021-04-30); upstream has been dormant since. There is also a `v1.0`
tag if an exact release point is ever needed.

## Cambridge Rocketry Simulator

`./camrocsim` is a submodule of the [Cambridge Rocketry Simulator](https://sourceforge.net/projects/camrocsim/)
— the GPL six-degree-of-freedom simulator by Simon Box and Willem Eerland, and the **CRS** that
`docs/research/` surveys and that the RocketPy paper benchmarks against. Three languages in one
tree: a C++ simulation core, a Java GUI, and a Python plotter.

Its `gui/` is a fork of **OpenRocket** (`net.sf.openrocket`), which we also vendor at
`./openrocket` — so that subtree is a 2016-era snapshot of a project whose current source is
already here. Read across the two rather than treating `camrocsim/gui` as its own thing.

Read `./CLAUDE-camrocsim.md` before working in that tree; it covers the build, the three-language
pipeline, the simulation core, and conventions.

Pinned at the tip of `master` (2017-01-13), upstream's final commit; the project has been dormant
since. Commit `3ed1513` (2016-10-13) is byte-identical to the released `camrocsim_3.1_src.tar.gz`,
if a pin that matches the published 3.1 download is ever needed.

## MAPLEAF

`./mapleaf` is a submodule of [MAPLEAF](https://github.com/henrystoldt/MAPLEAF) — the Modular
Aerospace Prediction Lab for Engines and Aero Forces, an MIT-licensed Python/Cython 6-DOF framework
from the University of Calgary, described in Stoldt et al., AIAA 2021-3267.

Its distinguishing features are a pluggable aerodynamic-coefficient interface, selectable Earth
models (`Flat`/`Round`/`WGS84`+J2) that change the integration frame to match, nine in-tree
Runge-Kutta schemes, built-in design optimization, and a V&V case suite that ships its own reference
data.

Read `./CLAUDE-mapleaf.md` before working in that tree; it covers the package layout, the `.mapleaf`
simulation-definition schema that is its real interface, the domain model, and what no longer runs.

Pinned at the tip of `master` (`af970d3`, 2021-12-11). Upstream has been dormant since; the later
"last push" date GitHub reports belongs to unmerged student capstone branches.

## ForRocket

`./forrocket` is a submodule of [ForRocket](https://github.com/sus304/ForRocket) — an MIT-licensed
C++ 6-DOF trajectory solver by Susumu Tanaka, built on Boost.odeint, Eigen, and nlohmann/json.

Deliberately scope-limited: the README states it will "Prvide only trajectory solver." JSON in, CSV
out, no GUI, and aerodynamics supplied entirely as constants or tables — there is no geometry model
in the tree.

Read `./CLAUDE-forrocket.md` before working in that tree; it covers the layout, the four dynamics
phases, the JSON input tree, and the event model.

Pinned at the tip of `master` (`10fdcd0`, **2020-04-11**). Note the trap: GitHub reports a 2026 last
push, but that is the unmerged `dev_minor-update` branch (2026-07-08); `develop` sits at 2025-04-28.
**`master` — what is pinned here — has not moved since April 2020.**

## OpenTsiolkovsky

`./opentsiolkovsky` is a submodule of
[OpenTsiolkovsky](https://github.com/istellartech/OpenTsiolkovsky) — an MIT-licensed simulator from
**Interstellar Technologies Inc.**, the Japanese launch company that flies MOMO. The only simulator
in `docs/research/` with an institutional operator, and its `examples/` carry real vehicle
configurations (`param_momo.json`, `SS-520-4/`).

Three implementations coexist: a Rust engine (`src/`, the live one, with CLI and WASM), a legacy C++
reference tree (`legacy_cpp/`), and a React/TypeScript front end (`frontend/`).

Read `./CLAUDE-opentsiolkovsky.md` before working in that tree. **Read it before citing the project's
DOF in particular:** the README advertises 6-DOF, but the Rust solver integrates a seven-element
translational state with prescribed attitude — the 6-DOF is in the legacy C++ tree. Upstream also
ships its own `CLAUDE.md` and `AGENTS.md` at its repo root.

Pinned at the tip of `master` (`a699805`, 2025-09-28).

## Adding a submodule

The read-only rule is enforced in two places, and only one of them generalizes:

- `.claude/hooks/protect-subs.sh` reads the submodule paths from `.gitmodules` on every invocation,
  so a new submodule is protected the moment it is registered. Nothing to do.
- `.claude/settings.json` names each submodule path explicitly in its `deny` rules. **Add the new
  path there by hand.** A wildcard such as `subs/*/**` does not work: the permission layer matches a
  rule by its leading literal directory, so that pattern denies all of `subs/` — including this file.
