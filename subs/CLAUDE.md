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

## Adding a submodule

The read-only rule is enforced in two places, and only one of them generalizes:

- `.claude/hooks/protect-subs.sh` reads the submodule paths from `.gitmodules` on every invocation,
  so a new submodule is protected the moment it is registered. Nothing to do.
- `.claude/settings.json` names each submodule path explicitly in its `deny` rules. **Add the new
  path there by hand.** A wildcard such as `subs/*/**` does not work: the permission layer matches a
  rule by its leading literal directory, so that pattern denies all of `subs/` — including this file.
