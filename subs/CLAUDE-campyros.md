# CamPyRoS (vendored submodule)

A primer on the CamPyRoS source vendored at `subs/campyros` — environment, package layout, domain
model, and conventions. That tree is read-only here; see `subs/CLAUDE.md`.

Pinned at `1dba140` on `main` (2021-04-30), which is upstream's final commit; a `v1.0` tag also
exists. **Treat this as an archived research codebase, not a maintained library.** It is the
smallest and least finished of the three simulators we vendor, and the notes below flag the parts
that do not actually run.

Not the Cambridge Rocketry Simulator (`camrocsim`) that `docs/research/` surveys as CRS — that is a
separate C++/Java project by Box and Eerland, not vendored here.

## Project Overview

CamPyRoS (Cambridge Python Rocketry Simulator) is a GPLv3 Python 6-DOF trajectory package from CU
Spaceflight, written for the team's Martlet vehicles. Roughly 6k lines across 15 modules.

Three things distinguish it from RocketPy and OpenRocket, and they are the reason it is worth
keeping around:

- **A rotating, oblate Earth.** Position and velocity are integrated in an Earth-centred inertial
  frame with WGS84 flattening and Earth's angular velocity as first-class constants, so Coriolis
  and centrifugal effects fall out of the frame rather than being bolted on.
- **An aerodynamic heating model** (`heating.py`, the largest module at ~1.8k lines) — tangent-ogive
  nose geometry, oblique/normal shock relations, Prandtl–Meyer expansion, and a transient
  skin-temperature solve. Neither of the other two simulators models heating at all.
- **Live GFS wind** fetched per query through `getgfs`, rather than from a bundled or
  pre-downloaded atmosphere.

## Common Commands

There is no Makefile, no lint config, and no test runner wired up. What exists:

```bash
pip install .                       # setuptools, declares version 1.1
pip install -r requirements.txt     # the same runtime deps, unpinned
pip install ray                     # optional; without it the stats model is single-threaded
python example.py                   # Martlet 4 trajectory
python stats_example.py             # stochastic run, driven by stats_settings.json
```

`environment.yml` is a fully-pinned conda export from a 2021 macOS machine (Python 3.8, `numpy
1.19.3`, `ray 1.1.0`). It is a record of what once worked, not a portable environment — expect to
resolve dependencies yourself.

CI is two GitHub Actions workflows: `black.yml` runs `black --check .`, and `testcase.yml` invokes
a third-party action (`onichandame/python-test-action`) with no configuration.

## Architecture

Composition mirrors the other simulators: build the physical models, hand them to a `Rocket`, call
`run()`. There is no document object and no event bus.

```
campyros/
  main.py         Rocket (the integrator), LaunchSite, Parachute, from_json
  mass.py         MassModel + component models (HollowCylinder, LiquidTank, SolidFuel, DryMass)
  motor.py        Motor, load_motor
  aero.py         AeroData (interpolated coefficient grids), pitch_damping_coefficient
  wind.py         Wind — live GFS lookups via getgfs
  transforms.py   coordinate conversions between inertial / launch / body / lat-lon-alt
  constants.py    WGS84 Earth constants
  heating.py      AeroHeatingAnalysis, TangentOgive, compressible-flow relations
  statistical.py  StatisticalModel — Monte Carlo over perturbed inputs
  plot.py         trajectory, aero, mass, orientation, and dispersion plots
  post.py         ypr_i — attitude post-processing
  slosh.py        CylindricalFuelTank — propellant slosh
  ray_alt.py      no-op stand-in for ray when it is not installed
  gui.py          Tkinter GUI (broken — see Gotchas)
```

`__init__.py` does `from .main import *` plus `mass`, `plot`, `aero`, and `motor`. Note what is
*not* re-exported: `wind`, `statistical`, and `heating` must be imported explicitly
(`from campyros import statistical as stats`), which is what the examples do.

### Coordinate frames

Four frames, with conversions in `transforms.py`:

- **`i` — inertial**: Earth-centred, non-rotating. The frame the ODE is integrated in.
- **`l` — launch site**: origin at the launch site at altitude 0, rotating with the Earth.
- **`b` — body**: fixed to the rocket, x along the body axis.
- **lat/lon/alt**: via `i2lla` / `lla2i`, using the WGS84 constants in `constants.py`.

Every conversion takes `time` as an argument, because the launch frame rotates away from the
inertial frame as the simulation runs. `pos_i2alt(pos_i, time)` is the altitude accessor and appears
throughout the integration loop.

Body-to-inertial rotation is carried as a `scipy.spatial.transform.Rotation` (`rocket.b2i`, with
`rocket.i2b` its inverse).

### `Rocket` — the simulator

`Rocket.run()` in `main.py` is the whole simulator. Construction takes `mass_model`, `motor`,
`aero`, and `launch_site`; `run(max_time=1000)` integrates and returns a **pandas DataFrame** with
`time`, `pos_i`, `vel_i`, `b2imat`, `w_b`, and `events` columns.

- **State vector** is 18 elements: `[pos_i(3), vel_i(3), w_b(3), xb(3), yb(3), zb(3)]` — position,
  velocity, body angular rates, then the three body-axis direction vectors expressed in inertial
  coordinates. That last part is the notable choice: orientation is carried as a **full rotation
  matrix integrated component-wise**, where RocketPy uses four quaternion parameters. Nothing
  re-orthonormalizes the matrix between steps, so drift accumulates over long integrations.
- **Integrator** is `scipy.integrate.DOP853`, stepped manually in a `while` loop rather than run to
  completion, with a fixed step available via `variable=False`. Defaults are `rtol=1e-7`,
  `atol=1e-14`.
- **Phases** are handled by `check_phase()`, called once per step, which returns a list of event
  strings. It covers exactly two transitions: **rail departure** (by distance travelled from the
  launch site) and **parachute deployment**. Compare RocketPy, which appends whole new phases with
  their own derivative functions and solvers.
- **Parachute descent is not a separate derivative.** Once `parachute_deployed` is set, `run()`
  stops integrating attitude and instead *constructs* `b2imat` each step by pointing the body x-axis
  into the relative wind, and zeroes `w_b`. The rocket is assumed to weathercock instantly.
- **Deployment trigger** is apogee detection by polling: every `alt_poll_interval` seconds (default
  1 s) it compares altitude against the previous poll and deploys when altitude first decreases.
  There is no altitude-triggered or callable trigger, so a 1-second granularity is baked in.
- The loop terminates on ground impact (`pos_i2alt(...) < 0`) or `max_time`.

`fdot(time, fn)` is the derivative: it unpacks the state, builds the rotation, accumulates forces
and moments separately in body and inertial frames, and returns the 18-element rate.

### Mass model

`MassModel` holds two lists, `constants` and `variables`, and sums over them at each query —
`mass(time)`, `cog(time)`, `ixx/iyy/izz(time)`. Components are `HollowCylinder`, `DryMass`,
`LiquidTank`, `SolidFuel`, and `CylindricalApproximation`. It assumes all centres of mass lie on
the body x-axis and that the vehicle is axially symmetric, so the parallel-axis theorem is applied
only to the transverse moments.

### Aerodynamics

`AeroData` wraps interpolated coefficient grids — `CA` (axial), `CN` (normal), and `COP` — over
Mach and angle of attack, via `scipy.interpolate.interp2d`. There is **no built-in geometry-to-drag
model**: coefficients come from outside, either `AeroData.from_lists(...)` or
`AeroData.from_rasaero(...)`, which parses a RASAero II CSV export. `data/Martlet4RasAeroII.CSV`
is the worked example. The `CA_func`/`CN_func`/`COP_func` attributes can be overridden with custom
callables, in which case the grids are ignored.

Pitch and roll damping are scalar coefficients defined as `moment = C · ρ · ω²`; the helper
`pitch_damping_coefficient(length, radius, fin_number, area_per_fin)` estimates the pitch one.

### Wind

`Wind` queries NOAA GFS through `getgfs` at 0.25° / 1-hour resolution, snapping requested lat/lon
onto the forecast grid, and can cache interpolated profiles (`cache=True`) — worth doing for Monte
Carlo, where the download dominates runtime. It defaults to a datetime two days in the past, and
historic forecasts are explicitly unsupported. `variable=False` falls back to a constant vector.

**This means most of the library needs network access to run**, and results are not reproducible
across days.

### Statistical model

`StatisticalModel(run_file)` reads a JSON config (`stats_settings.json` is the template) giving
`[mean, std_dev]` pairs for launch site, mass model, aero, thrust magnitude and alignment,
parachute, and environment multipliers. Perturbations are applied through the `error` /
`env_vars` dicts that `Rocket`, `AeroData`, and the motor accept — multiplicative factors on
gravity, pressure, density, and speed of sound. `analyse(results_path, iterations)` reduces the
runs, and `plot.py` has the dispersion plots (`stats_landing`, `stats_apogee`, `stats_alt`).

Parallelism is `ray`. When it is missing, `ray_alt.remote` stands in — it warns and runs the
function serially, so a stats run silently becomes very slow rather than failing.

## Gotchas

The tree has rough edges that will waste time if you assume it is polished:

- **`gui.py` does not work.** It imports `RASAeroData` from `.aero`, a class that does not exist
  anywhere in the package (the RASAero path is the `AeroData.from_rasaero` static method), and
  imports `Motor` from `.main`, which does not define or import it. Its docstring still refers to
  the package by its old name, `trajectory`. It is not re-exported from `__init__.py`, so importing
  `campyros` still works — but anything touching the GUI is dead on arrival.
- **There is effectively no test suite.** `tests/` at the repo root holds two wind notebooks.
  `campyros/tests/test.py` is a `unittest` file, but it manipulates `sys.path` by hand and reads
  fixtures via paths relative to the repo root (`campyros/tests/testmotor.csv`), so it only runs
  from that one working directory. The "Test case" CI workflow invokes a generic third-party action
  with no arguments.
- **Docstring style is inconsistent** — Google-style `Args:`/`Attributes:` in `main.py`, `aero.py`,
  and `motor.py`; NumPy-style `Parameters`/`Attributes` in `statistical.py` and parts of
  `transforms.py`. Some are unfinished (`alt_poll_interval (int): ???`, `def get_wind: """[summary]`).
- **`legacy/` and `novus_sim_6.1/`** are prior-generation material, not live code —
  `novus_sim_6.1/` is the earlier motor simulation (`motor_sim.py`, `hybrid_functions.py`, propep
  inputs), and `legacy/` holds design documents (`.docx`) on coordinate systems and the variable
  moment-of-inertia model, plus heating test cases. Useful as provenance, but nothing imports them.
- **`data/` mixes fixtures with committed run output**, including a pickled wind cache
  (`w0_0_('20210321', '12', '[1]').pkl`) and `trajectory.json`.

## Conventions

- Formatting is **black**, enforced by CI; that is the only automated style gate.
- Docstrings are meant to be Sphinx-compatible; `CONTRIBUTING.md` asks for a "very specific format"
  without pinning one down, and the code reflects that.
- Branching: PRs go to `main` from a fork. Two other branches survive upstream
  (`Wind-Statistics`, `stable-matrix-orientation-RK4` — the latter's name suggests a known fix for
  the rotation-matrix drift noted above).
- `CONTRIBUTING.md` asks contributors to keep `example.py`, `stats_example.py`, the notebooks, and
  `main.py` in step with any change, since the project has no tests to catch breakage.
- Every module carries a GPLv3 `__copyright__` block; keep it on any file that gets copied.

## Reading Alongside the Others

| | OpenRocket | RocketPy | CamPyRoS |
|---|---|---|---|
| License | GPLv3 | MIT | GPLv3 |
| Earth model | flat | flat, optional spherical/WGS84 geometry | rotating oblate (WGS84) throughout |
| Attitude state | quaternions | quaternions (`e0..e3`) | integrated 3×3 rotation matrix |
| Integrator | custom RK4 stepper | scipy, LSODA default, selectable | scipy DOP853, manually stepped |
| Flight phases | event-driven, swappable steppers | phases with swappable derivatives | two boolean checks per step |
| Aero source | built-in Barrowman | built-in Barrowman + imported curves | imported curves only (RASAero II) |
| Heating | none | none | transient skin-temperature model |
| Uncertainty | none | `stochastic/` + `MonteCarlo` | `StatisticalModel` + `ray` |
| Maintained | yes | yes | no (last commit 2021) |
