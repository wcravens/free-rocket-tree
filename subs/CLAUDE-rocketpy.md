# RocketPy (vendored submodule)

A primer on the RocketPy source vendored at `subs/rocketpy` — environment, package layout, domain
model, and conventions. That tree is read-only here; see `subs/CLAUDE.md`.

Pinned at **v1.13.0**. Upstream ships its own agent instructions at `.agents/AGENTS.md` (plus
scoped skills under `.agents/skills/`) — read that file when the question is "how would upstream
want this written"; this document covers "how does this code work".

## Project Overview

RocketPy is a pure-Python 6-DOF trajectory simulation library for high-power rocketry. Requires
**Python ≥ 3.10** (CI tests 3.10 and 3.14 on Linux/macOS/Windows). Licensed MIT — note the contrast
with OpenRocket's GPLv3, which matters for any code we lift or link.

It is a *library*, not an application: no GUI, and no file format of its own beyond a JSON save
(`.rpy`). Rockets are defined in Python.

## Common Commands

Everything routes through the `Makefile`, which is OS-agnostic and the source of truth:

```bash
make install          # requirements{,-optional,-tests}.txt, then an editable install
make pytest           # python -m pytest tests
make pytest-slow      # includes @pytest.mark.slow tests (skipped by default)
make coverage         # pytest --cov=rocketpy tests
make coverage-report  # same, HTML report
make format           # ruff check --select I --fix + ruff format  (rocketpy/ tests/ docs/)
make lint             # ruff-lint + pylint, each writing a report file
make build-docs       # Sphinx HTML under docs/
```

CI (`.github/workflows/`) enforces `ruff check`, `ruff format --check`, and `pylint` over
`rocketpy/ tests/ docs/`, then runs four test stages separately:

```bash
pytest tests/unit
pytest rocketpy --doctest-modules     # docstring examples are executable tests
pytest tests/integration
pytest tests/acceptance
```

**Docstring examples are run as tests.** A `>>>` block that does not evaluate exactly as written
fails CI.

Optional-dependency extras gate real features: `env-analysis`, `monte-carlo`, `animation`, and
`all`. Code reaches for them lazily through `tools.import_optional_dependency`.

### Tooling drift

`docs/development/style_guide.rst` still describes Black and Flake8, and the `tests` extra in
`pyproject.toml` still lists them. The Makefile and CI use **ruff** (line length 88, double quotes,
numpy docstring convention — all configured in `pyproject.toml`). Upstream's `AGENTS.md` resolves
this explicitly: prefer `Makefile` and `pyproject.toml` over the prose docs.

## Architecture

A flat `rocketpy/` package — setuptools only, no plugin layer. Composition runs in one direction:
`Environment` plus `Rocket` (which owns a `Motor` and its aerodynamic surfaces) are handed to a
`Flight`, which integrates. There is no central document object and no event bus.

```
rocketpy/
  mathutils/     Function, Vector/Matrix, interpolation kernels (_calc/)
  environment/   Environment, EnvironmentAnalysis, weather fetchers
  motors/        Motor ABC + Solid/Liquid/Hybrid/Generic/RingCluster/PointMass, Tank, TankGeometry
  rocket/        Rocket, PointMassRocket, aero_surface/, parachute, components
  sensors/       Sensor ABC, Accelerometer, Gyroscope, Barometer, GnssReceiver
  control/       _Controller
  simulation/    Flight, MonteCarlo, MultivariateRejectionSampler, flight data import/export
  stochastic/    Stochastic* mirrors of the domain classes
  sensitivity/   SensitivityModel
  plots/ prints/ one module per domain class, mirroring it
```

`rocketpy/__init__.py` is the public API surface, and upstream treats its exports as a stability
contract.

### `Function` — the core abstraction

`mathutils/function.py` (~4.4k lines) defines `Function`, which wraps a callable, a scalar, an
ndarray, a CSV path, or another `Function` into an object supporting interpolation, extrapolation,
arithmetic, calculus, and plotting. Nearly every physical quantity in the library is a `Function`
rather than a float — thrust curves, drag coefficients, mass over time, and every `Flight` output
(`flight.z`, `flight.vx`, …) as a function of time.

Its own docstring flags it as a class to maintain carefully "as it may impact all the rest of the
project". Treat it as load-bearing.

**Cache invalidation is the sharp edge.** `funcify_method` (same file, near the bottom) turns a
method into a cached `Function` property stored in the instance `__dict__` and tagged `__cached__`.
Mutating a domain object after those properties are built leaves stale results behind. Two recovery
paths:

- `reset_funcified_methods(instance)` drops every `__cached__` entry so they rebuild on next access.
- `del instance.attr` drops one.

Plain `@cached_property` is also used (e.g. `Flight.effective_1rl`) with the same hazard. This is
RocketPy's analogue of OpenRocket's `ComponentChangeEvent`/`ModID` scheme — but it is manual and
local rather than event-driven, so a mutator that forgets to reset is silently wrong. The domain
classes compensate by re-evaluating eagerly: `Rocket.add_surfaces` re-runs
`evaluate_center_of_pressure`, `evaluate_stability_margin`, and `evaluate_static_margin` before
returning.

### Coordinate systems

The most error-prone part of the user-facing API, and the reason positions get their own doc page
(`docs/user/positions.rst`).

- `Rocket(coordinate_system_orientation=...)` is `"tail_to_nose"` (default) or `"nose_to_tail"`,
  stored as `Rocket._csys = +1 / -1` and multiplied through every position calculation.
- `Motor(coordinate_system_orientation=...)` is `"nozzle_to_combustion_chamber"` (default) or
  `"combustion_chamber_to_nozzle"`, with its own `_csys`. The two systems are independent; their
  product is the sign factor applied to every motor-derived position in `Rocket.add_motor`.
- The origin may sit anywhere on the axis of symmetry, and every `position=` argument is relative
  to it.
- Each aerodynamic surface additionally has a *local* frame documented in its class docstring
  (fins: origin at the top of the root chord, Z along the axis positive downwards).
- `add_surfaces` accepts either a bare axial coordinate or a full `(x, y, z)` tuple, and the
  reference point differs per surface type — nose cone tip, fin root-chord leading edge before any
  cant offset, the tail's highest point, the lower rail button.

Flight results use a separate inertial frame: X east, Y north, Z up, with attitude carried as Euler
parameters (quaternions) `e0..e3` and body rates `w1, w2, w3`.

### Units

All internal values are SI (m, kg, K, rad, Pa), as in OpenRocket. `rocketpy/units.py` is a thin
conversion helper (`convert_units`, `convert_temperature`, `conversion_factor`) applied at the edges,
mainly to weather data and display. Angles in the user-facing API are mixed and documented
per-argument: `inclination`/`heading` are degrees, `angle_of_attack` internals are radians.
Latitude/longitude are degrees.

### `Flight` — the simulator

`simulation/flight.py` (~4.6k lines) is where the integration lives. **Constructing a `Flight` runs
the simulation** — `__init__` calls `__simulate` unconditionally, and results are then read off as
attributes. There is no deferred mode.

- **State vector** `u` is 13 elements: `[x, y, z, vx, vy, vz, e0, e1, e2, e3, w1, w2, w3]`, with
  time carried alongside it in each `solution` row. Initial attitude comes from 3-1-3 Euler angles
  (`heading`, `inclination`) via `euler313_to_quaternions`.
- **Phases, not one integration.** `Flight.FlightPhases` holds a list of phases, each with its own
  derivative function and its own solver instance; `Flight.TimeNodes` subdivides a phase for
  discrete events. `__simulate` loops phases → time nodes → solver steps.
- **Derivative functions** select the physics: `udot_rail1` (constrained to the rail), `u_dot`
  (6-DOF, `equations_of_motion="solid_propulsion"`), `u_dot_generalized` (6-DOF, default),
  `u_dot_generalized_3dof` (3-DOF), and `u_dot_parachute` (descent under canopy).
  `__init_equations_of_motion` picks between them from `simulation_mode` (`"3 DOF"` / `"6 DOF"`) and
  force-downgrades to 3-DOF when a `PointMassRocket` or `PointMassMotor` is detected.
- **ODE solver** is scipy, LSODA by default, selectable via `ode_solver` — a key of
  `ODE_SOLVER_MAP` (`RK23`, `RK45`, `DOP853`, `Radau`, `BDF`, `LSODA`) or a custom
  `scipy.integrate.OdeSolver` subclass. LSODA needs a private-attribute poke at each node boundary
  to honour the new `t_bound`; see the `__is_lsoda` branch in `__simulate`.
- **Events** — rail departure, apogee, impact, parachute deployment — are handled by dedicated
  `__handle_*` / `__check_*` methods that append new phases mid-run, rather than by an event bus.
- **`time_overshoot`** decouples the ODE step from parachute/controller sampling: the solver may step
  past a trigger evaluation point, and the trigger inputs are interpolated back. A large speed-up,
  and the reason the overshoot bookkeeping (`__process_overshootable_nodes`) exists.
- Outputs are lazily-built `Function`s over the recorded solution array — position, velocity,
  acceleration, aerodynamic forces and moments (`R1..R3`, `M1..M3`), atmospheric conditions,
  body-frame variants, stability margin, and so on.

Parachute triggers are duck-typed on arity: a callable taking 3, 4, or 5 arguments (pressure, AGL
height, state vector, then optionally `sensors` and/or `u_dot`), or a float deployment altitude, or
the string `"apogee"`.

### Environment

`Environment` holds launch site, elevation, gravity, Earth geometry, and the atmosphere.
`set_atmospheric_model(type=...)` selects among `standard_atmosphere`, `custom_atmosphere`,
`wyoming_sounding`, `windy`, `forecast`, `reanalysis`, and `ensemble` — most of which fetch live
data over the network (GFS, NAM, RAP, HRRR, HIRESW, AIGFS, GEFS, ECMWF/ICON via Windy) or read
netCDF4 locally. Anything touching those paths in a test is an integration test by definition.
`EnvironmentAnalysis` is a separate statistical tool over historical data, behind the `env-analysis`
extra.

### Motors and tanks

`Motor` is an ABC; `SolidMotor`, `LiquidMotor`, `HybridMotor`, `GenericMotor`, `RingClusterMotor`,
`PointMassMotor`, and `EmptyMotor` derive from it. Liquid and hybrid motors compose `Tank` objects
(`MassFlowRateBasedTank`, `UllageBasedTank`, `LevelBasedTank`, `MassBasedTank`) over a
`TankGeometry` (`CylindricalTank`, `SphericalTank`) plus `Fluid` definitions — so propellant mass,
CG, and inertia evolve from tank geometry rather than from a lumped curve. One motor per rocket:
`add_motor` warns and overwrites if called twice.

### Monte Carlo and stochastic models

`stochastic/` mirrors the domain classes (`StochasticRocket`, `StochasticEnvironment`,
`StochasticFlight`, `StochasticSolidMotor`, `StochasticNoseCone`, …). Each wraps a nominal object
plus per-argument distributions; `StochasticModel` validates inputs and generates randomized kwargs.
`MonteCarlo(filename, environment, rocket, flight)` iterates them, serially or across processes
(`multiprocess`), streaming inputs, outputs, and errors to files. `simulate_convergence` runs
adaptively against a convergence criterion. `MultivariateRejectionSampler` re-weights an existing
run to a new input distribution without re-simulating.

### Output layers

`plots/` and `prints/` hold one module per domain class, and each domain object instantiates its own
(`self.prints = _RocketPrints(self)`, `self.plots = _RocketPlots(self)`), exposed as `obj.info()`
and `obj.all_info()`. Presentation is deliberately kept out of the domain classes — worth preserving
if we extract anything.

### Serialization

`_encoders.py` provides `RocketPyEncoder` / `RocketPyDecoder`, JSON codecs that record a class
signature per object and reconstruct through per-class `to_dict` / `from_dict` methods.
`utilities.save_to_rpy(flight, filename)` writes a `.rpy` (JSON) file stamped with the RocketPy
version; `load_from_rpy` warns when the file was written by a newer version. `Function` sources that
are callables get hex-encoded (`to_hex_encode` / `from_hex_decode`) rather than truly serialized.

### Logging and errors

Standard-library `logging` throughout (`logger = logging.getLogger(__name__)` per module), with
`utilities.enable_logging(level)` as the user-facing switch. Custom exceptions live in
`rocketpy/exceptions.py` (`InvalidInertiaError`, `InvalidParameterError`, `UnstableRocketWarning`),
though much of the codebase still raises `ValueError` and warns via `warnings.warn`.

## Testing Notes

Four tiers under `tests/`:

- `tests/unit/` — mandatory for new behavior. May use real collaborators ("sociable"), but must stay
  fast and method-focused.
- `tests/integration/` — I/O-heavy or broad across many methods, including the `all_info()` cases.
- `tests/acceptance/` — realistic flights, sometimes compared against known flight data.
- `tests/fixtures/` — every fixture module is registered in `tests/conftest.py` via `pytest_plugins`.
  **Adding a fixture module means editing that list**, or it will not be collected.

Other conventions:

- `@pytest.mark.slow` tests are skipped unless `--runslow` is passed (`make pytest-slow`); wired up
  in `conftest.py` through `pytest_addoption` and `pytest_collection_modifyitems`.
- `conftest.py` forces the `Agg` matplotlib backend, so plotting tests run headless.
- `pytest.approx` for float comparisons; AAA structure and descriptive test names.
- `numericalunits` is used (via the `m` / `kg` fixtures) for dimensional-correctness checks.
- Doctests in `rocketpy/` are part of the suite — see Common Commands.

## Conventions

- Branching: `develop` is the integration branch and the default PR target; `master` is stable.
  Branches are `type/description`, with `type` in `bug|doc|enh|mnt|rel|tst`, lowercase and
  dash-separated.
- Commits: `ACRONYM: subject`, where the acronym is one of
  `BLD BUG DEP DEV DOC ENH MNT REV STY TST REL`; lines ≤ 72 chars; issues referenced as
  `Closes #1234`. PR *titles* drop the acronym — a workflow labels them and populates `CHANGELOG.md`.
- Style: `snake_case` for everything but classes (`PascalCase`) and constants
  (`UPPER_SNAKE_CASE`); descriptive names over terse ones (`angle_of_attack`, not `a`). The library
  was `camelCase` before v1.0.0 — those names are gone, but old notebooks and forum posts still
  show them.
- Docstrings: NumPy style, on every public class/method/function, **stating units**.
- Deprecations go through the `@deprecated` decorator in `rocketpy/tools.py`.
- `CHANGELOG.md` is maintained per PR under `[Unreleased]`, newest on top.

## Reading Alongside OpenRocket

Both trees model the same physics, and the contrasts are the interesting part for `docs/`:

| | OpenRocket | RocketPy |
|---|---|---|
| License | GPLv3 | MIT |
| Shape | Desktop app + core library | Library only |
| Design input | `.ork` XML, GUI tree of `RocketComponent` | Python objects |
| Simulation | `BasicEventSimulationEngine`, swappable `SimulationStepper`s | `Flight` phases with swappable `u_dot*` derivatives |
| DOF | 6-DOF | 6-DOF and 3-DOF |
| Cache invalidation | `ComponentChangeEvent` + `ModID` | `funcify_method` caches, reset manually |
| Extension points | `SimulationListener`, `SimulationExtension` | `_Controller`, sensors, custom `OdeSolver`, parachute triggers |
| Uncertainty | none built in | `stochastic/` + `MonteCarlo` |
