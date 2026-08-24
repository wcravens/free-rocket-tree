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

Not to be confused with the **Cambridge Rocketry Simulator** (`camrocsim`, Box and Eerland) that
`docs/research/` surveys as CRS — that is a separate C++/Java project hosted on SourceForge, and it
is not vendored here.

Read `./CLAUDE-campyros.md` before working in that tree; it covers the package layout, domain
model, coordinate frames, and the parts of the tree that do not actually run.

Pinned at the tip of `main` (2021-04-30); upstream has been dormant since. There is also a `v1.0`
tag if an exact release point is ever needed.

## Adding a submodule

The read-only rule is enforced in two places, and only one of them generalizes:

- `.claude/hooks/protect-subs.sh` reads the submodule paths from `.gitmodules` on every invocation,
  so a new submodule is protected the moment it is registered. Nothing to do.
- `.claude/settings.json` names each submodule path explicitly in its `deny` rules. **Add the new
  path there by hand.** A wildcard such as `subs/*/**` does not work: the permission layer matches a
  rule by its leading literal directory, so that pattern denies all of `subs/` — including this file.
