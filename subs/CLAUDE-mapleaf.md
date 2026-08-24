# MAPLEAF (vendored submodule)

A primer on the MAPLEAF source vendored at `subs/mapleaf` — package layout, the simulation-definition
schema that is its real interface, the domain model, and the parts that no longer run. That tree is
read-only here; see `subs/CLAUDE.md`.

Pinned at **`af970d3`** (2021-12-11), the tip of `master`. Upstream ships no agent instructions;
`README_Dev.md` and `CodingStyle.md` are the closest equivalents.

## Project Overview

**M**odular **A**erospace **P**rediction **L**ab for **E**ngines **A**nd **A**ero **F**orces — a
6-DOF rocket flight simulation framework from the University of Calgary, described in Stoldt, Quinn,
Kavanagh & Johansen, *MAPLEAF: Modular Aerospace Prediction Lab for Engines and Aero Forces*,
AIAA 2021-3267 (AIAA Propulsion and Energy 2021 Forum).

Licensed **MIT** (`subs/mapleaf/LICENSE`, "Copyright (c) 2020 Henry Stoldt, AERO-CORE, and other
contributors") — the same permissive footing as RocketPy, and the contrast with OpenRocket's GPLv3
and CamPyRoS's GPLv3 is why it matters to `docs/research/`.

Python **3.6+** with Cython hot paths (`setup.py:70,72`). It is both a CLI application and an
importable library, but unlike RocketPy its primary interface is neither — it is a **declarative text
file**, the `.mapleaf` simulation definition. Rockets are configured, not constructed in code.

```bash
mapleaf path/to/SimDefinitionFile.mapleaf   # single simulation
mapleaf NASATwoStageOrbitalRocket           # a bundled example, by bare case name
mapleaf-batch                               # the regression/V&V suite
python -m unittest -v                       # unit tests
```

## Dormancy — read this before trusting anything below

`master` has not moved since **2021-12-11**. GitHub reports a later "last push" (2023-12-27) because
eight side branches exist — `ENMECapstone20212022`, `Capstone_TVC`, `TabulatedInputs` and others,
student capstone work that was never merged. **The default branch is the 2021 tree, and that is what
is pinned here.** Any claim about "current MAPLEAF" that rests on the push badge is wrong.

The practical consequence is in `requirements.txt`: **`matplotlib==3.2.2` is a hard pin**, not a
floor, and that release predates wheels for modern CPython. Combined with `ext_modules=cythonize(...)`
in `setup.py`, a `pip install` on a current interpreter has to build both matplotlib and the Cython
extensions from source. **Whether it still installs is untested here and must be stated as unverified
in `docs/` — this plan reads the tree, it does not run it.**

## Package Layout

```
MAPLEAF/
  ENV/                 environment.py, EarthModelling.py, AtmosphereModelling.py,
                       MeanWindModelling.py, TurbulenceModelling.py, launchRail.py
  Motion/              Integration.py, RigidBodies.py, RigidBodyStates.py, AeroParameters.py,
                       Interpolation.py, forceMomentSystem.py, inertia.py,
                       Cython{Vector,Quaternion,AngularVelocity}.pyx
  Rocket/              rocket.py, stage.py, RocketComponents.py, RocketComponentFactory.py,
                       AeroFunctions.py, noseCone.py, bodyTube.py, Fins.py, boatTail.py,
                       Propulsion.py, Recovery.py, simEventDetector.py
  GNC/                 ControlSystems.py, MomentControllers.py, Actuators.py, PID.py, Navigation.py
  SimulationRunners/   SingleSimulations.py, Batch.py, MonteCarlo.py, Optimization.py, Convergence.py
  IO/                  simDefinition.py, subDictReader.py, Logging.py, Plotting.py, rocketFlight.py
  Examples/            Simulations/, BatchSims/, V&V/, Wind/, TabulatedData/
  Main.py              CLI entry point
```

The split that matters: **`SimulationRunners/` is a layer above `Rocket`**, not beside it. A single
simulation, a batch, a Monte Carlo sweep, an optimization, and a grid-convergence study are five
runners over the same rocket/environment model. That is the seam to look at when asking how the
model could be reused headlessly.

## The `.mapleaf` schema — the actual interface

`SimDefinitionTemplate.mapleaf` at the repo root is the authoritative reference and doubles as the
documentation; it is worth reading before any source file. Format is brace-delimited, arbitrarily
nested key-value, one pair per line, key and value split on first whitespace, no multiline values.

Two features of the reader (`IO/simDefinition.py`) are architecturally interesting:

- **Derived dictionaries.** A dictionary can be defined as a modification of a previously defined one
  (`!create X from Y{ ... }`, `!removeKeysContaining`), so V&V case files express a family of
  configurations as diffs. `SooyAP98DC97Cases.mapleaf:233,256` uses this.
- **`_stdDev` on any key.** `simDefinition.py:200,474-487`: if `key_stdDev` exists alongside `key`,
  reads of `key` return a sample from a normal distribution with `key` as mean. This is implemented
  **in the dictionary reader**, not in a Monte Carlo module — which is why *any* scalar or `Vector`
  parameter in the entire definition is stochastic-capable with no per-parameter support code. It is
  the cleanest idea in the tree. Normal distributions only.

## Domain Model

### Motion and integration

`Motion/RigidBodies.py` has three classes: `RigidBody_3DoF` (line 12), `RigidBody` (line 65, the
6-DOF subclass), and `StatefulRigidBody` (line 117), which integrates arbitrary named extra state
variables alongside the rigid-body state — the hook actuators and control systems use.

**DOF is phase-dependent, not user-selected.** Ascent is 6-DOF; `Rocket._switchTo3DoF`
(`Rocket/rocket.py:700`) swaps the integrator to `RigidBody_3DoF` when a recovery system deploys,
since orientation under canopy is not modelled. There is no `simulation_mode` switch as in RocketPy.

`Motion/Integration.py` — `integratorFactory` (line 56) dispatches by name over two families:

- **Fixed step** (`ClassicalIntegrator`, line 144): `Euler` (193), `RK2Midpoint` (154), `RK2Heun`
  (160), `RK4` (166), and `RK4_3/8` (174).
- **Adaptive** (`AdaptiveIntegrator`, line 238): `RK12Adaptive` (251), `RK23Adaptive` (258, Bogacki-Shampine),
  `RK45Adaptive` (267, Dormand-Prince RK5(4)7FM, the default), `RK78Adaptive` (279, Dormand-Prince
  RK8(7)13M).

Note the count: the template advertises eight methods (`SimDefinitionTemplate.mapleaf:228`), but
source implements **nine** — `RK4_3/8` is undocumented there. Adaptive methods take a Butcher tableau
in a documented text format (`Integration.py:11-25`), so adding a scheme is data, not code.

Step-size control is its own sub-model (`SimDefinitionTemplate.mapleaf:230-247`): `constant`,
`elementary` (safety-factor), or **`PID`** control on a `targetError` that blends position, velocity
and — in 6-DOF — angular-orientation error. Steps estimated at >100× target error are discarded and
recomputed. Crucially, **adaptive stepping is deliberately overridden near events**: the step shrinks
toward a configured value approaching a `simEventDetector` trigger, because altitude-triggered events
resolve only to step boundaries. Time-deterministic events are resolved exactly.

### Aerodynamics — the provider interface

This is MAPLEAF's most transferable idea and the one `docs/research/` §3 argues for in the abstract.
Aerodynamic force sources are **components in the same list as physical parts**, registered in
`Rocket/RocketComponentFactory.py:27` and interchangeable within one rocket:

| Provider | Where | What it does |
|---|---|---|
| Geometry build-up | `noseCone.py`, `bodyTube.py`, `Fins.py`, `boatTail.py` over `AeroFunctions.py` | Barrowman-class `CN`/`CP` (`AeroFunctions.py:273,284`) plus skin-friction (71,138), base drag (170), blunt-body and cross-flow terms (177,191) |
| `AeroForce` | `RocketComponents.py:206` | Constant `Cd`, `Cl`, and three moment coefficients at a position |
| `AeroDamping` | `RocketComponents.py:233` | Constant damping derivatives; moments only, redimensionalized by `Lref/(2·airspeed)` |
| `TabulatedAeroForce` | `RocketComponents.py:263` | CSV interpolation, key columns → value columns |

`TabulatedAeroForce._loadCoefficients` (`RocketComponents.py:279`) parses the CSV header itself: key
columns must come first and be named from `AeroParameters.stringToAeroFunctionMap`
(`Motion/AeroParameters.py:110-121`) — **`Mach`, `Altitude`, `UnitReynolds`, `TotalAOA`, `RollAngle`,
`AOA`, `AOSS`** — and value columns from `CD, CL, CMx, CMy, CMz`. Dimensionality is whatever the file
provides; >1 key column builds an N-dimensional interpolator. The same map drives gain scheduling for
control systems, so "what can a table be indexed by" is answered once for the whole codebase.

**Correction to carry forward:** an *expression-defined* provider is described in the template as
`CalculatedAeroForce` (`SimDefinitionTemplate.mapleaf:677`), intended to accept Python expressions of
Mach/Altitude/UnitRe/AOA/RollAngle/angular rates in the style of Grauer & Morelli's generic global
aerodynamic model. It is marked **`# TODO: Still needs to be implemented`** and its `class` key points
at `TabulatedAeroForce`. It does not exist. Earlier drafts of `docs/research/` claimed three
interchangeable providers including expression-defined coefficients; source supports **build-up,
constant, damping, and tabulated** — the interface is real and pluggable, the expression provider is
not.

### Environment

`ENV/environment.py` composes four independently selectable sub-models. The `EarthModel` choice
changes the frame motion is integrated in (`SimDefinitionTemplate.mapleaf:24-31,272-284`):

| `EarthModel` | Gravity / shape | Global inertial frame |
|---|---|---|
| `None` | no gravity | Launch tower |
| `Flat` (default) | inverse-square, flat ground | Launch tower |
| `Round` | rotating sphere, uniform inverse-square | Earth-Centered Inertial |
| `WGS84` | rotating ellipsoid, **J2** | Earth-Centered Inertial |

Documented neglects for `WGS84`: polar wobble, third-body gravity, tides, solar radiation pressure,
and Earth's own orbital acceleration (ECI treated as inertial). `sphericalHarmonicGravityCoeffs.txt`
ships in `ENV/`.

- **Atmosphere** (`AtmosphericPropertiesModel`, line 289): `USStandardAtmosphere` (computed exactly),
  `Constant`, or `TabulatedAtmosphere` reading `h/T/P/rho/mu` columns.
- **Mean wind** (`MeanWindModel`, line 306): `Constant`, `SampledGroundWindData` (weighted sampling
  across named wind-rose sites by launch month), `SampledRadioSondeData` (same, over sounding
  profiles, with ASL→AGL correction), `Hellman` (power-law shear over a ground model), or
  `CustomWindProfile` from file. Sampling takes an explicit `randomSeed` for repeatability.
- **Turbulence** (`TurbulenceModel`, line 341): `None`, `PinkNoise1D/2D/3D` (seeded per axis, strength
  set by turbulence intensity or velocity σ), or `customSineGust` (NASA HDBK-1001-shaped layer).
  `turbulenceOffWhenUnderChute` defaults on, purely to allow larger descent time steps.

**No live-weather ingestion.** Every wind source is a bundled or user-supplied file — the contrast
with RocketPy's forecast/reanalysis fetchers and CamPyRoS's live data.

### Rocket, stages, events

Stages carry `separationTriggerType` ∈ `apogee`, `ascendingThroughAltitude`,
`descendingThroughAltitude`, `motorBurnout`, `timeReached` (`SimDefinitionTemplate.mapleaf:700`).
`Rocket/simEventDetector.py` evaluates these and drives the time-step shrinking described above.
Recovery systems support an arbitrary number of stages (`:489`). Component positions are hierarchical
— relative to stage tip, with CG and MOI relative to the component — and constant mass/CG/MOI
overrides can replace component build-up per stage.

### GNC

`GNC/` provides a `ControlSystem` with a `MomentController` of type `ConstantGainPIDRocket` or
**`ScheduledGainPIDRocket`**, whose gain table is scheduled by the same `stringToAeroFunctionMap` keys
(`SimDefinitionTemplate.mapleaf:421-448`). A fixed `updateRate` caps the time step; if adaptive
stepping is requested alongside a fixed control rate, MAPLEAF substitutes constant RK4 for ascent and
restores adaptive stepping for the uncontrolled descent.

### Runners

- `SingleSimulations.py` — one flight.
- `Batch.py` — case files under `Examples/BatchSims/`, with parameter sweeps, expected values, and
  plot specifications including overlaid reference data. This is the V&V harness.
- `MonteCarlo.py` — repeated runs over the `_stdDev` sampling described above.
- `Optimization.py` — `optimizationRunnerFactory` (line 317) picks **particle swarm** via pyswarms
  (`PSORunner`, line 339) or **`scipy.optimize.minimize <method>`** (line 334). Cost functions are
  Python expressions over log columns (`Utilities.evalExpression`), and `_createNestedOptimization`
  (line 216) allows an inner optimization inside every outer cost evaluation. **No other package in
  `docs/research/` has built-in design optimization at all.**
- `Convergence.py` — grid/time-step convergence studies.

## The V&V suite

`MAPLEAF/Examples/BatchSims/` holds eight case files: `NASAVerificationCases`, `OpenRocketCases`,
`SparrowCases`, `StaticStabilityCases`, `ParametricFinBodyCases`, `SooyAP98DC97Cases`,
`CanardOptimizationTest`, and `regressionTests`. `mapleaf-batch` runs them.

`SooyAP98DC97Cases.mapleaf` is the one worth citing. It replicates configurations from Sooy &
Schmidt's published comparison of Missile DATCOM (97) and Aeroprediction 98, sweeping angle of attack
at fixed Mach and unit Reynolds number, and plotting MAPLEAF's `CN`, `Cm`, and `CP` against
**digitized reference data that ships in the tree** under `MAPLEAF/Examples/V&V/` — `SooyConventional/`
carries AP98, DC97, FLU3M and TLNS (CFD), and USER3D curves; `SooyBodyAlone/` carries AP98, DC97, and
**wind-tunnel** (`WT*.csv`) curves. Four cases build up by derived dictionary: body alone → body+flare
→ finned body → conventional rocket.

That is a concrete answer to "a published validation suite, runnable in CI" — the comparison targets
are in-repo rather than described in prose.

## Conventions

- `CodingStyle.md` is the source of truth. Classes `PascalCase`, functions/variables `camelCase`
  (**not** PEP 8 `snake_case` — MAPLEAF is consistently camelCase, unlike RocketPy).
- Module names are inconsistent by design-drift: `Rocket/rocket.py` and `Rocket/stage.py` are
  lowercase, `Rocket/RocketComponents.py` and `Motion/Integration.py` are PascalCase. Follow the
  neighbouring file, not a global rule.
- Leading `_` marks internal methods; `try*` prefixes a lookup with a default
  (`tryGetVector("rotationAxis", defaultValue=None)`).
- Docstrings are the doc site (pdoc3, published to GitHub Pages). Units are stated in comments in the
  template rather than in signatures.
- Cython sources are `.pyx`/`.pxd` under `Motion/` (`CythonVector`, `CythonQuaternion`,
  `CythonAngularVelocity`), `Rocket/CythonFinFunctions.pyx`, and `IO/CythonLog.pyx`. `setup.py:34`
  globs them; they are compiled at install time, so **the tree as vendored is not runnable without a
  build step**.
- Optional dependencies `mayavi` (3-D renders) and `ray` (parallelism) are deliberately excluded from
  `requirements.txt` and installed by `installOptionalPackages.py`.

## What does not run, or is stale

- **The Cython extensions are not built** in this checkout, and nothing here builds them.
- **`matplotlib==3.2.2`** (`requirements.txt`) is a hard pin from 2020. Installability on a current
  Python is **unverified** — do not assert either way in `docs/`.
- **`CalculatedAeroForce` is unimplemented**, per the TODO quoted above.
- **`rocket.py:278`** carries a TODO for asking components whether they want extra integrated state,
  so `StatefulRigidBody` selection is partly hand-wired (`_switchToStatefulRigidBodyIfRequired`,
  line 363).
- **Eight unmerged branches** hold the newer capstone work (TVC, tabulated inputs). None of it is in
  the pinned tree.
- **`asv.conf.json`** and `benchmarks/` set up airspeed-velocity benchmarking that has not been run
  against a recent baseline.

## Reading Alongside RocketPy

Both are MIT-licensed Python 6-DOF packages, which makes the divergences the interesting part:

| | RocketPy | MAPLEAF |
|---|---|---|
| Primary interface | Python objects | `.mapleaf` declarative text file |
| Aero coefficients | Geometry build-up, or `Function` from CSV/callable | Component-level providers: build-up, constant, damping, tabulated |
| Earth model | fixed | `None`/`Flat`/`Round`/`WGS84`+J2, frame follows |
| Integrator | scipy `ODE_SOLVER_MAP`, LSODA default | Nine in-tree RK schemes, `RK45Adaptive` default, PID step control |
| Event handling | phases appended mid-run | `simEventDetector` + deliberate step shrinking |
| DOF | `simulation_mode` selectable | 6-DOF ascent, automatic 3-DOF under chute |
| Uncertainty | `stochastic/` mirror classes | `_stdDev` on any key, in the config reader |
| Optimization | none | PSO + `scipy.optimize.minimize`, nestable |
| Weather | live fetchers (GFS, Windy, …) | files only |
| Status | active | dormant since 2021-12 |
