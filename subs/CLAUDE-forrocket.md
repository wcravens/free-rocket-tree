# ForRocket (vendored submodule)

A primer on the ForRocket source vendored at `subs/forrocket` — layout, domain model, the JSON input
schema, and what the pinned tree does and does not contain. That tree is read-only here; see
`subs/CLAUDE.md`.

Pinned at **`10fdcd0`** (2020-04-11), the tip of `master`.

## Project Overview

A **6-DOF rocket trajectory solver** in C++ by Susumu Tanaka, licensed **MIT**
(`subs/forrocket/LICENSE`, "Copyright (c) 2020- Susumu Tanaka"). The README's scope statement is
unusually explicit and worth quoting, because it is the whole design thesis:

> Prvide only trajectory solver. Satisfy extend tool.

There is no GUI, no design editor, no geometry model, and no plotting. It reads JSON, integrates, and
writes CSV. Everything else is someone else's job. That deliberate narrowness is why the tree is
vendored here.

Stated features: 6-DOF trajectory; liquid, solid and hybrid engines with "no fixed type of rocket
engine"; a configurable event sequence (cutoff, separation, despin, jettison); JSON in, CSV out.
Listed under "Testing Feature" — i.e. present but less exercised — are attitude-control flight and
multi-stage flight.

Dependencies: **Boost** (`odeint` for integration), **Eigen** (linear algebra), **nlohmann/json**
(input parsing), **Google Test**. Built with a plain `makefile` (`make release`), not CMake.

```bash
make release
ForRocket sample_solver_config.json
```

## Branch state — read this first

**`master` has not been committed to since 2020-04-11**, and that is what is pinned here. GitHub
reports a 2026 "last push" date, which describes side branches that have never been merged:

| Branch | Tip | Date |
|---|---|---|
| `master` (pinned) | `10fdcd0` | **2020-04-11** |
| `develop` | `d9d9212` | 2025-04-28 |
| `dev_minor-update` | `e17d555` | 2026-07-08 |

Anyone reading the repository badge will conclude ForRocket is actively maintained. The default
branch says otherwise, and every claim in `docs/research/` is about the pinned `master`.

## Layout

```
src/
  ForRocket.cpp              entry point
  commandline_option.*       CLI parsing
  json_control.*  fileio.*   nlohmann/json wrapper, CSV output
  interpolate.*              1-D table interpolation
  solver/
    trajectory_solver.*      top-level run: stages in sequence
    rocket_stage.*           per-stage integration, event sequencing
  dynamics/
    dynamics_base.*                shared state/derivative interface
    dynamics_3dof_onlauncher.*     constrained rail phase
    dynamics_6dof_aero.*           free 6-DOF flight, aerodynamically resolved
    dynamics_6dof_programrate.*    6-DOF with commanded body rates
    dynamics_3dof_parachute.*      descent under canopy
    noniterative_iip.*             instantaneous impact point (range safety)
  rocket/
    engine.*                       thrust, Isp, gimbal
    flight_data_recorder.*         output columns
    parameter/                     mass, position, velocity, attitude,
                                   acceleration, force, moment, interpolate_parameter
  environment/
    wgs84.* coordinate.*           ellipsoid constants, ECI/ECEF/NED/body chain
    gravity.* satmo1976.*          gravity, US Standard Atmosphere 1976
    wind.* vincenty.* datetime.*   wind table, geodesics, epoch handling
    sequence_clock.*               event clock
  factory/                   rocket_factory, rocket_stage_factory, engine_factory
docs/
  ProgramDocument/           00_introduction, 01_installation, 02_input_style, 03_output_style
  TechnicalDocument/         tech_doc.tex + tech_doc.pdf — the model derivations
test/                        GoogleTest: clock, interpolate, interpolateparameter
bin/                         sample_*.json inputs
```

**`docs/TechnicalDocument/tech_doc.tex`** is the model documentation — the closest thing ForRocket
has to a paper, and the right citation target for its formulations.

## Domain Model

### Dynamics — four phases, not one

`dynamics/` holds four derivative implementations over a shared `DynamicsBase`, and `rocket_stage.cpp`
switches between them as the flight proceeds:

| Phase | Class | DOF |
|---|---|---|
| On the rail | `Dynamics3dofOnLauncher` | 3-DOF, direction constrained |
| Free flight | `Dynamics6dofAero` | 6-DOF, attitude from aerodynamics |
| Commanded | `Dynamics6dofProgramRate` | 6-DOF, prescribed body rates |
| Under chute | `Dynamics3dofParachute` | 3-DOF |

Integration is **Boost odeint**, `runge_kutta_dopri5` wrapped as the base stepper
(`solver/rocket_stage.cpp:55`), driven by `integrate_const` (`:82,95,112`) so output lands on a fixed
grid. `runge_kutta4` (`:52`) and `runge_kutta_fehlberg78` (`:59`) sit commented out alongside — the
scheme is a source edit, not a config option.

`noniterative_iip.*` computes the **instantaneous impact point**, a range-safety product that no
hobby-oriented package in the survey carries. It is a launch-operations concern.

### Environment

- **Earth**: WGS84 ellipsoid constants (`environment/wgs84.hpp:17-22` — `a = 6378137.0`,
  `inv_f = 298.257223563`, `omega = 7292115e-11`) with the full **ECI ↔ ECEF ↔ NED ↔ body** DCM chain
  in `coordinate.hpp:20-27` and an explicit Earth-rotation tensor built from `omega` (`:34-35`). So the
  Earth is **rotating and ellipsoidal for geodesy and frames**.
- **Gravity**, however, is scalar inverse-square: `gravity.hpp:17-23` returns `wgs84.GM / r²` off the
  geocentric height. **No J2 term.** This is the precise characterization to carry into `docs/` —
  "WGS84" describes the shape and frames here, not the gravity field.
- **Atmosphere**: US Standard Atmosphere 1976 (`satmo1976.*`).
- **Wind**: `EnvironmentWind` is constructed either disabled or from a **CSV path**
  (`wind.hpp:22-25`), interpolated as wind-from-north and wind-from-east against altitude. No live
  data, no wind model.
- **Geodesy**: `vincenty.*` for geodesic distance — downrange over an ellipsoid.

### Aerodynamics — tables only, no geometry

This is the sharpest contrast with OpenRocket and MAPLEAF. A ForRocket vehicle has a diameter, a
length, a mass, and a set of coefficients. There is **no nose cone, no fin, no body-tube component,
and no Barrowman build-up anywhere in the tree.** Every coefficient is either a constant or a CSV
lookup, selected by an `Enable ... File` boolean in `bin/sample_rocket_config.json`:

`CA` (axial force, with a separate burnout table), `CNa` (normal force slope), `Cld` (roll due to fin
cant), `Clp` (roll damping), `Cmq` (pitch damping), `Cnr` (yaw damping) — plus `X-C.P.`, `X-C.G.`, and
the moment-of-inertia tensor, each likewise constant-or-file. Fin cant angle is a scalar input.

The consequence: **ForRocket cannot answer "what happens if I change this fin?"** It answers "given
these coefficients, where does it go?" It is downstream of whatever produced the tables.

### Events — scheduled, not triggered

`bin/sample_sequence_of_event.json` is the model, and it is almost entirely **time-based**:

```
Engine Ignittion Time [s]      Cutoff Time [s]        Stage Separation Time [s]
Despin: Time [s]               Fairing Jettson Time   Parachute Open Time [s]
Secondary Parachute Open Time  Attitude Control Start/End Time    Flight End Time [s]
```

Each gated by an `Enable ...` boolean. The one state-triggered option is
`"Enable Forced Apogee Open"` on the primary parachute. Rail departure is geometric (`Rail Launcher
Length [m]`).

This is a **flight-plan model**, not an event-detection model — the assumption of a vehicle flown to a
sequence rather than one whose events emerge from its state. It is the natural shape for a sounding
rocket or launch vehicle and the wrong shape for "deploy at apogee, whenever that is". Contrast
MAPLEAF's `simEventDetector` and OpenRocket's event bus.

### Input and output

Input is a **tree of JSON files**, one concern per file:

```
solver_config.json          launch datetime, LLH position, azimuth/elevation, wind file,
                            stage count (up to 3), and a per-stage config-list path
  stage_config_list.json    names the three files below, per stage
    sequence_of_event.json  the event schedule above
    rocket_config.json      mass, geometry scalars, CG/CP/MOI, aero coefficients
    engine_config.json      thrust, Isp, gimbal
  + CSV files               time-vs-thrust, Mach-vs-CA, attitude, wind, …
```

Output is CSV, accumulated in `flight_data_recorder.hpp` — parallel `std::vector`s of time, burn
time, thrust, mass flow, burning flag, **gimbal angles on both axes**, propellant and total mass, CG
and CP length, the full **inertia tensor**, the aero coefficients actually used, and the position /
velocity / attitude parameter objects. The gimbal and inertia-tensor columns confirm TVC and 6-DOF are
genuinely modelled, not just configured.

## Conventions

- C++ with `namespace forrocket` throughout; `.cpp`/`.hpp` pairs, one class per pair.
- `snake_case` files and members, `PascalCase` classes.
- Each file carries a banner comment with project name, file name, creation date, and copyright.
- Eigen types (`Eigen::Vector3d`, `Eigen::Matrix3d`) are the vector/matrix vocabulary.
- Factories (`factory/`) build rockets, stages, and engines from parsed JSON — construction is kept
  out of the domain classes.
- Some comments are in Japanese; the identifiers and documents are English.
- `tool/make_src_list.py` regenerates `tool/file_list.txt` for the makefile — source files are listed,
  not globbed, so adding a file means regenerating the list.

## What is thin or absent

- **Tests are minimal**: three GoogleTest files, covering the sequence clock and interpolation only.
  There is no trajectory-level regression or validation suite, and nothing comparable to MAPLEAF's
  V&V cases. **ForRocket ships no validation evidence in-tree.**
- **No geometry or design model**, as above.
- **No Monte Carlo or dispersion driver.** Single deterministic runs only.
- **No atmosphere or wind variability**, beyond supplying a different file.
- **The scheme and tolerances are compile-time.** No integrator selection in JSON.
- **`master` is five years stale**; `develop` and `dev_minor-update` hold unmerged work not present
  in the pinned tree.
