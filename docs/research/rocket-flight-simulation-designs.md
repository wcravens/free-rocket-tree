# Rocket Simulation Software: Models, Inputs, and Portability

A survey of five rocket flight simulation packages: **OpenRocket**, **RASAero II**,
**RocketPy**, the **Cambridge Rocketry Simulator**, and **CamPyRoS**. For each, this
report describes the physical and mathematical models used, the simulation input
parameters the user supplies, the file formats involved, and the practical portability
of the simulation for re-use or as a component in other systems.

*Research date: 2026-08-22; revised 2026-08-24 against vendored source. Facts verified
against primary sources (project documentation, source repositories, journal papers)
where possible; unverified items are flagged inline.*

**Four of the five are vendored as pinned submodules under [`subs/`](../../subs/CLAUDE.md)**,
so claims about them can be checked against the exact source they were drawn from. Each
section names its pinned commit and links the corresponding primer. RASAero II is the
exception and cannot be vendored: it is closed source, which is the subject of the special
focus at the end of this report.

A companion catalog, *[Simulation Components and Subcomponent
Libraries](simulation-components-and-libraries.md)*, covers what falls outside this
report's five packages: other open-source flight simulators (notably **MAPLEAF**, an
MIT-licensed 6-DOF framework that meets this survey's inclusion bar), and library-level
implementations of the individual pieces the *common simulation core* section below
calls for — Barrowman implementations, chemical-equilibrium solvers, atmosphere and
wind models, geodesy, and format readers.

---

## 1. OpenRocket

**What it is.** Free, open-source (GPL v3) model rocket design and flight simulation
software written in Java. Originated as Sampo Niskanen's 2009 Master's thesis at
Helsinki University of Technology; now maintained by the OpenRocket organization on
GitHub. Current stable version **24.12** (released 2025). It couples a CAD-like design
editor with an integrated simulator, recomputing CG/CP/stability continuously as the
design changes.

- Website: <https://openrocket.info/> · Repo: <https://github.com/openrocket/openrocket>
- Technical documentation (v13.05, still the canonical model description):
  <https://openrocket.sourceforge.net/techdoc.pdf>
- Vendored at [`subs/openrocket`](../../subs/CLAUDE-openrocket.md), pinned at `e0dc0cd`
  (2025-11-08; `core/src/main/resources/build.properties` reads `build.version=24.12`).

### Models

| Aspect | Model |
|---|---|
| Flight dynamics | Full **6-DOF rigid body** during ascent; orientation stored as a unit quaternion. Drops to **3-DOF** after recovery-device deployment. |
| Aerodynamics | **Extended Barrowman method** (Niskanen's extensions): body normal force with body-lift correction, arbitrary trapezoidal/elliptical/free-form fin planforms, fin–body interference, pitch damping, and roll dynamics (roll forcing/damping for canted fins). |
| Drag | Component build-up: skin friction (laminar/turbulent, surface-roughness dependent), body and fin pressure drag, base drag, parasitic drag (lugs etc.); semi-empirical transonic/supersonic nose-cone wave drag. Most accurate subsonic (~1% altitude error in validation); accuracy degrades supersonic. |
| Atmosphere | International Standard Atmosphere layer model; user overrides for base temperature/pressure. Humidity ignored. |
| Wind | Mean wind plus **pink-noise (1/f^5/3) turbulence** approximating Kaimal/von Kármán spectra. Since 24.12: **multi-level wind** (speed/direction per altitude layer) and CSV wind-profile import. |
| Motor | Tabulated thrust curves, interpolated; motor mass and CG vary through the burn. |
| Recovery | 3-DOF descent; parachute default C_D = 0.8, streamer C_D from empirical wind-tunnel-derived formula. |
| Geodesy/gravity | Selectable: flat Earth, spherical approximation, or WGS84 ellipsoid, including Coriolis effect. `WGSGravityModel` in the vendored source implements the **Somigliana normal-gravity formula** with WGS84 constants (g_e = 9.7803267714, k = 1.93185138639e-3, e² = 6.69437999013e-3), plus an inverse-square altitude correction that assumes a spherical Earth. **This is the same formula RocketPy uses** (§3), the two differing only in the equatorial-gravity constant at the 1e-6 level — so gravity is not a source of divergence between them. |
| Integrator | Fixed-step **4th-order Runge–Kutta** with dynamic step reduction during rapid rotation; default time step 0.05 s. Discrete event system (ignition, burnout, rod cleared, apogee, deployment, touchdown). |
| Mass/inertia | Built up from component geometry × material density; longitudinal and rotational moments of inertia; overrides handled via parallel-axis theorem. |

### Simulation input parameters

- **Geometry/components:** nose cones (conical, ogive, elliptical, parabolic, power
  series, Haack), body tubes, transitions/boattails, four fin types with cant angle,
  launch lugs/rail buttons, inner tubes, couplers, bulkheads, centering rings, mass
  objects, recovery devices, pods, boosters, unlimited stages, motor clusters.
- **Materials & finish:** per-component material/density and surface roughness.
- **Overrides:** per-component or per-stage/whole-rocket overrides of mass, CG, and C_D;
  recent versions accept CSV lookup-table overrides of coefficients from wind-tunnel or
  CFD data. (Directly relevant to the "flight-sim configuration" idea in the consortium
  README.)
- **Motors:** selected per mount per *flight configuration*, with ignition timing and
  ejection delay; bundled database built from thrustcurve.org; user motors as RASP
  `.eng` or RockSim `.rse`.
- **Launch site:** latitude, longitude, altitude; ISA or custom temperature/pressure.
- **Wind:** average speed, standard deviation / turbulence intensity, direction;
  multi-level wind table or CSV import; optional random seed for reproducibility.
- **Launch rod/rail:** length, angle, direction relative to wind.
- **Simulation options:** time step, geodetic method, attachable simulation extensions.
  Output: 50+ recorded flight variables plus user-defined custom expressions.

### File formats

- **Native `.ork`:** a ZIP archive containing `rocket.ork` (XML design document),
  optional preview image and decal textures, and (format v1.11+) embedded thrust curves.
  The XML holds the component tree, simulation conditions, and result summaries; the
  format is versioned and documented
  (<https://openrocket.readthedocs.io/en/latest/dev_guide/file_specification.html>).
- **Import:** `.ork`, RockSim `.rkt`, RASAero II `.CDX1`.
- **Export:** RockSim `.rkt`, RASAero `.CDX1`, OBJ (CAD/3D printing), CSV (simulation
  and component-analysis data), PDF, SVG fin templates.
- **Motors:** RASP `.eng`, RockSim `.rse`.

### Portability / re-use

**High for JVM-based systems — the strongest embedding story of the GUI tools.**

- The simulation core (`core` module) has no GUI dependencies and, since 24.12, is
  **published to Maven Central as `info.openrocket:core`**. An official guide covers
  headless use: initialize via `OpenRocketCore.initialize()` (Guice-based DI), load an
  `.ork` with `GeneralRocketLoader`, and run `Simulation` objects server-side
  (<https://openrocket.readthedocs.io/en/latest/dev_guide/using_openrocket_core.html>).
- **Listener/extension API:** `SimulationListener` /
  `SimulationComputationListener` / `SimulationEventListener` hook every step and event,
  can read the full simulation state, modify flight conditions and aerodynamic data,
  or abort — the sanctioned path for custom control logic and data extraction.
- **Python:** the third-party `orhelper` package bridges via JPype (batch runs, Monte
  Carlo dispersion studies), but it is pinned to OpenRocket 15.03 / JDK 8; modern use
  should target the Maven-published core directly via JPype/Py4J or process isolation.
- **Constraints:** JVM required (no native/C API); **GPL v3 copyleft** applies to
  embedding; no full batch CLI ships (headless use goes through the library API).
- Platforms: Windows/macOS/Linux, x86_64 and ARM64.

---

## 2. RASAero II

**What it is.** Combined aerodynamic analysis and flight simulation package by Charles
E. (Chuck) Rogers and David Cooper (Rogers Aeroscience), aimed at model, high-power,
amateur, and sounding rockets — and at generating aerodynamic coefficients for external
simulation of larger vehicles. **Freeware but closed source**, Windows-only (.NET
Framework 3.5). Current version **1.0.2.0 (May 2019)**, still the latest as of this
research. Its distinguishing strength is aerodynamic prediction across **Mach 0.01–25**.

- Website: <https://rasaero.com/> · Users Manual:
  <https://rasaero.com/dloads/RASAero%20II%20Users%20Manual.pdf>
- **Not vendored, and not vendorable** — closed source, so there is no tree to pin. Every
  claim in this section rests on the Users Manual and the author's own forum posts rather
  than on readable code, which is precisely the gap §"Special focus" addresses.

### Models

| Aspect | Model |
|---|---|
| Aerodynamics | Coefficient prediction across subsonic/transonic/supersonic/hypersonic regimes to Mach 25: CD (zero and non-zero alpha), CL, CN vs alpha, CNα, CP vs Mach and alpha, **power-on vs power-off drag** computed separately. |
| Subsonic CP | Standard Barrowman (TIR-33), or the optional **Rogers Modified Barrowman Method**: adds body-cylinder CNα, body-in-presence-of-fins interference, and body viscous crossflow (Jorgensen), capturing forward CP shift with alpha. |
| High-Mach CP | Models forward CP travel with Mach (by Mach 5 the CP can reach 60–70% of body length) — critical for Mach 3+ fin-stabilized vehicles. (Specific internal theories per regime are not named in the manual; secondary attributions e.g. second-order shock expansion are unverified.) |
| Drag build-up | Body friction, body pressure/wave drag, base drag, fin friction+pressure, fin interference, fin base drag, protuberances, launch lug/rail-guide/launch-shoe drag, boattail wave and supersonic base drag. Power-on base drag reduced using nozzle exit diameter. |
| Skin friction | Laminar-to-turbulent transition (or forced all-turbulent); **equivalent sand roughness** surface-finish model (8 finish grades). Aero recomputed per time step from Mach, alpha, Reynolds number, and power state. |
| Flight dynamics | **2-DOF point mass** (no wind) or **3-DOF with wind**, including dynamic stability, weathercocking, aerodynamic damping derivatives, and **jet damping**. Not 6-DOF. |
| Thrust | RASP curves assumed sea-level; **thrust corrected with altitude** via ambient pressure and nozzle exit area. |
| Atmosphere | 1976 US Standard Atmosphere extended to 1,000,000 ft, anchored to launch-site elevation/pressure and temperature. |
| Recovery | Ballistic or up to two recovery events (apogee + AGL altitude); default parachute C_D = 1.33. |
| Staging | Up to 3 stages incl. nested upper stages and boosted darts; separation and ignition delay inputs. |
| Validation | Author-reported apogee accuracy: average error 3.47%, 80.6% of flights within ±10%; calibrated against NACA/NASA wind-tunnel and free-flight data, ARCAS sounding rocket data, and accelerometer-derived CD. (Author's own figures, largely not independently verified.) |

### Simulation input parameters

- **Geometry (external aerodynamic surface only):** nose cones (conical, tangent ogive,
  Von Kármán, power law, LV-Haack, parabolic, elliptical; optional blunted tip), body
  tubes, transitions, boattails, fin canisters; 3–4 fins with airfoil selection
  (hexagonal, NACA, double/single wedge, biconvex, rounded, square LE); rail guides,
  lugs, launch shoes; user-defined protuberances; surface finish grade.
- **Mass properties:** lift-off weight and CG entered **directly per stage** — RASAero
  does *not* build mass up from components.
- **Motors:** internal database plus RASP `.eng`; **nozzle exit diameter** entered
  separately per stage.
- **Launch site:** elevation, temperature, optional barometric pressure, wind speed
  (its presence selects 3-DOF mode), rail/rod length, launch angle.
- **Events:** two recovery events (device, parachute diameter, C_D); staging delays.

### File formats

- **Native `.CDX1`** (XML-based) design files; legacy `.ALX1` importable.
- **Import:** RockSim `.RKT`. No `.ork` import — but **OpenRocket 23.09+ both imports
  and exports `.CDX1`**, providing a practical bridge.
- **Export:** aerodynamic coefficient tables (CD/CL/CN/CP/CNα vs Mach up to Mach 25,
  power-on and power-off) and flight simulation output to **CSV**; component drag
  breakdown via the Run Test tool. No trajectory export in other formats.

### Portability / re-use

**Low as a component; high as a data source.**

- Closed source, Windows-only GUI, **no API, no CLI, no scripting hooks**. The author
  has declined to release source.
- Programmatic use is limited to **GUI automation**: `pyrasaero`
  (<https://github.com/leedsrocketry/pyrasaero>) drives the app with pywinauto to
  batch-generate designs and export CSVs — workable but fragile, and requires a
  Windows machine/VM.
- The **established interop pattern is data-level**: exported CD-vs-Mach curves
  (power-on/power-off) are consumed directly by other simulators — RocketPy's own
  documented flights use RASAero-generated drag curves. The `.CDX1` XML format is
  effectively documented-by-implementation via OpenRocket's Java importer/exporter.
- No formal license text exists; distribution terms are simply "free," which is itself
  a consideration for any consortium standard that would redistribute or wrap it.

---

## 3. RocketPy

**What it is.** Open-source (**MIT**) Python library for 6-DOF trajectory simulation of
high-power rockets, originated in Projeto Jupiter (University of São Paulo) and now
maintained by the RocketPy Team. Current version **1.13.0 (July 2026)**, Python ≥ 3.10.
Peer-reviewed in Ceotto et al., *"RocketPy: Six Degree-of-Freedom Rocket Trajectory
Simulator,"* ASCE Journal of Aerospace Engineering, 2021
(DOI 10.1061/(ASCE)AS.1943-5525.0001331). It is a **library, not an application** —
there is no GUI or built-in geometry-to-drag CAD; the user scripts everything.

- Repo: <https://github.com/RocketPy-Team/RocketPy> · Docs: <https://docs.rocketpy.org/>
- Vendored at [`subs/rocketpy`](../../subs/CLAUDE-rocketpy.md), pinned at `9bd6ad3`
  (tag `v1.13.0`). The paper's preprint is in the [reference library](../ref/README.md).

### Models

| Aspect | Model |
|---|---|
| Flight dynamics | Full nonlinear **6-DOF rigid body with rigorous variable-mass treatment** (time-varying propellant mass, CM, and inertia tensor propagated through the equations of motion); a 3-DOF mode also available. Orientation via **quaternions**; 13-element state vector. |
| Integrator | `scipy.integrate` solvers — **LSODA default** (adaptive, stiffness-switching); RK23/RK45/DOP853/Radau/BDF selectable; user-set `rtol`/`atol`. |
| Aerodynamics | **Barrowman-based lift coefficients per surface** (nose cones: conical/ogive/Von Kármán/power series; trapezoidal/elliptical/free-form fin *sets*; tails/boattails); since 1.13 also **individual fins** (`Fin`, `TrapezoidalFin`, `EllipticalFin`, `FreeFormFin`) for asymmetric or individually-positioned fins, plus `GenericSurface`/`LinearGenericSurface` for arbitrary user-supplied coefficient sets. Overall drag from **user-supplied power-on/power-off C_D vs Mach curves** (CSV, function, or constant) — typically generated externally (e.g. RASAero, CFD, flight data). Stability margin vs Mach and time. |
| Atmosphere | ISA standard, fully custom profiles, **University of Wyoming soundings, Windy.com API (ECMWF/GFS/ICON/ICONEU), operational forecasts (AIGFS/GFS/NAM/RAP/HRRR/HIRESW), reanalysis (ERA5), and ensembles (GEFS)** — the richest weather integration of the five. |
| Motors | `SolidMotor` (grain geometry with burn regression from the thrust curve), `HybridMotor`, `LiquidMotor` (tank classes: mass-flow/mass/ullage/level-based, with fluid definitions), `GenericMotor`, and since 1.13 `RingClusterMotor` (annular clusters) and `PointMassMotor`; thrust from `.eng`, CSV static-fire data, constants, callables, or the ThrustCurve.org API. |
| Recovery | `Parachute` objects with CdS, **arbitrary Python trigger functions** (pressure/height/full state — enabling altimeter-logic emulation), sampling rate, deployment lag, and sensor noise. |
| Earth/gravity | Latitude-dependent gravity (**Somigliana formula**) or custom; WGS84/SIRGAS2000/NAD83/SAD69 datums; elevation and topography services. |
| Dispersion | First-class **Monte Carlo framework**: stochastic wrappers for environment/rocket/flight, parallel execution, adaptive runs against a convergence criterion, bootstrap confidence intervals, and **impact-dispersion ellipses exported to KML**. Also `MultivariateRejectionSampler`, which **re-weights a completed run to a new input distribution without re-simulating** (the contribution of the 2021 paper), and a separate `SensitivityModel`. |
| Control | **Air brakes with user-supplied controller functions** (closed-loop, receives state history and simulated sensors with noise), with both discrete and continuous controllers since 1.13, and modelled sensors as first-class objects (`Accelerometer`, `Gyroscope`, `Barometer`, `GnssReceiver`, each with noise, quantization, and per-instance seeding) — supports guidance/control prototyping the other tools handle only via listeners or not at all. |
| Validation | Compared against 17+ documented real flights from university teams; project-reported relative errors ~0.45–4.24% on apogee/max velocity (self-reported). |

### Simulation input parameters

Four core classes, each fully parameterized in code:

- **`Environment`:** gravity, date/time, latitude, longitude, elevation, datum,
  timezone, atmosphere source (any of the models above).
- **`Motor`** (solid example): thrust source, dry mass and inertia, nozzle and throat
  radii, grain count/density/geometry, positions of grains/CM/nozzle, burn time,
  coordinate orientation. Liquids/hybrids add tank geometry, fluids, and flow.
- **`Rocket`:** radius, mass (without motor), inertia tensor, CM position, power-on/off
  drag curves; then components with explicit positions: `add_motor`, `add_nose`,
  `add_trapezoidal_fins` (root/tip chord, span, cant angle), `add_elliptical_fins`,
  `add_free_form_fins`, `add_tail`, `set_rail_buttons`, `add_parachute` (CdS, trigger,
  sampling rate, lag, noise), `add_air_brakes`, `add_sensor`.
- **`Flight`:** rail length, inclination, heading, max time, integration tolerances,
  ODE solver, equations-of-motion variant, simulation mode (6-DOF/3-DOF),
  terminate-on-apogee.

Note the modeling philosophy: mass, inertia, and drag are **direct physical inputs**,
not derived from CAD geometry. This matches the consortium README's "separate flight
sim configuration" idea (mass/CG overrides for as-flown vehicles) but means RocketPy
depends on upstream tools (OpenRocket/RASAero/measurement) for those values.

### File formats

- **Consumes:** RASP `.eng`, CSV thrust curves, CSV drag curves, CSV air-brake CD
  tables, netCDF/OPeNDAP weather files, CSV atmosphere/gravity profiles.
- **OpenRocket import:** via the companion **RocketSerializer** package
  (`ork2json`, requires Java) — converts `.ork` designs into RocketPy parameters
  (<https://github.com/RocketPy-Team/RocketSerializer>).
- **Exports:** flight data to CSV; trajectories and Monte Carlo dispersion ellipses to
  KML (Google Earth); Monte Carlo inputs/outputs/errors logs (txt/csv/json).
- **Native save:** `utilities.save_to_rpy()` writes a whole `Flight` to a `.rpy` JSON file
  stamped with the RocketPy version (`load_from_rpy()` warns on a newer one), via per-class
  `to_dict`/`from_dict` codecs. This is a serialization of a *simulation*, not a design
  interchange format — no other tool reads it.

### Portability / re-use

**Highest of the five — it is designed as a component.**

- `pip install rocketpy`; pure Python on numpy/scipy/matplotlib/netCDF4 etc.;
  plotting is separated from simulation, so it runs fully **headless** in scripts,
  servers, notebooks, and CI. Advertised MATLAB interop.
- **MIT license** — no copyleft constraint on embedding, including in closed-source
  systems (unlike OpenRocket and CamRocSim, both GPL v3).
- Clean object-oriented API (Environment → Motor → Rocket → Flight) with results as
  plain numeric attributes/`Function` objects; natural fit as the simulation engine
  inside a larger system.
- Internet access is only needed for live weather sources; everything else is offline.

---

## 4. Cambridge Rocketry Simulator (CamRocSim)

**What it is.** An open-source (GPL v3) simulator for unguided rockets, notable for its
**stochastic (Monte Carlo) 6-DOF** approach producing splash-down zones with confidence
bounds. Created by Simon Box (physics published with C. M. Bishop and Hugh Hunt, ASCE
Journal of Aerospace Engineering, 2011); version 3.x by Willem Eerland with Box and
András Sóbester, published as *"Cambridge Rocketry Simulator – A Stochastic
Six-Degrees-of-Freedom Rocket Flight Simulator,"* **Journal of Open Research Software**,
2017 (DOI 10.5334/jors.137). **Effectively unmaintained:** last release v3.1
(October 2016); the upstream repository's final commit is 2017-01-13, 63 commits in total.
Its ideas live on in successors (CUSF's CamPyRoS — §5 — and RocketPy).

- SourceForge: <https://sourceforge.net/projects/camrocsim/> ·
  Site: <https://cambridgerocket.sourceforge.net/>
- Vendored at [`subs/camrocsim`](../../subs/CLAUDE-camrocsim.md), pinned at `8191db9`
  (tip of `master`). Commit `3ed1513` is byte-identical to the released
  `camrocsim_3.1_src.tar.gz`, so the pinned tree is v3.1 plus three post-release commits.

### Models

| Aspect | Model |
|---|---|
| Flight dynamics | **6-DOF rigid-body ascent** (quaternion orientation) plus **3-DOF point-mass parachute descent**. |
| Integrator | **Runge–Kutta–Fehlberg 4(5)** with adaptive step-size control. |
| Aerodynamics | CN and CP via the **Barrowman equations** (valid α < 10°, Ma < 0.4, slender axisymmetric bodies, 3–4 trapezoidal fins); C_D from a semi-empirical method tabulated as a **2-D function of angle of attack × Reynolds number**; thrust damping torque included. |
| Mass properties | Time-varying mass, CM, and full inertia tensor over the burn, from component build-up + parallel-axis theorem. |
| Atmosphere/wind | Tabulated profiles vs altitude (3-D wind vector, density, temperature); defaults resemble ISA; profiles can be populated from meteorological forecasts. |
| Stochastic engine | The defining feature: per-iteration Gaussian perturbation of C_D (default σ 20%), CP (10%), CN (10%), parachute C_Ds (10%), launch declination (±1°), and thrust scale; **wind modeled as a correlated multivariate-Gaussian profile over altitude** (mean vector, 15×15 covariance matrix, eigen/basis-function decomposition). N runs yield a **splash-down region with 1σ/2σ confidence bounds**. |
| Recovery | Parachute characterized by C_D×A; dual-deploy (drogue + main at a switch altitude); ballistic-failure simulation flag. |
| Staging | Two-stage flights supported (separation time, ignition delay); site claims extensibility to more stages via code changes. |
| Validation | Verified against telemetry from actual flights (2011 paper). |

### Simulation input parameters

All simulation I/O is XML (`SimulationInput.xml` + `Uncertainty.xml`):

- **SimulationSettings:** function (one/two-stage, deterministic/Monte),
  ballistic-failure flag, **number of Monte Carlo iterations**, max time span.
- **LaunchSettings:** eastings/northings/altitude, rail length, azimuth, declination.
- **Per-stage tables (INTAB):** thrust(t), mass(t), inertia tensor(t), CM(t), thrust
  damping(t); C_D matrix over α × Re; CN and CP scalars; altitude profiles of wind,
  density, temperature; rocket length and cross-section area; parachute switch
  altitudes and C_D×A values.
- **Uncertainty:** the σ values and wind covariance structure above (only launch-angle
  and thrust uncertainty exposed in the GUI; the rest hand-edited in XML).
- **GUI design inputs** (the GUI is a fork of **OpenRocket 15.03dev** — `build.version`
  in the vendored tree): nose cone, body tube, transitions, trapezoidal fins, inner tubes,
  bulkheads, mass components, parachutes, motors (with an XML motor library: Cesaroni H–N,
  Aerotech). The bridge to the C++ core lives in the added `net.sf.openrocket.camrocksim`
  package (~17k lines of XML readers/writers and a CRS-side domain model).

### File formats

- **XML throughout:** `SimulationInput.xml` → C++ core → `SimulationOutput.xml`
  (apogee, landing coordinates, event times, full per-run time histories).
- Motors and atmospheres as bespoke XML files (not RASP `.eng`).
- **`.ork` and `.rkt` import is confirmed present** in the vendored source, resolving what
  earlier revisions of this report left open: the fork retains OpenRocket's
  `GeneralRocketLoader` and its `openrocket`/`rocksim` readers, and `BasicFrame`'s open
  dialog offers `.ork`, `.ork.gz`, `.rkt`, and `.rkt.gz` filters. Note the fork predates
  OpenRocket 23.09, so it has **no `.CDX1` support** — the RASAero bridge that current
  OpenRocket provides does not exist here. No KML export found.
- Output visualization via a Python (2.7) matplotlib plotter: trajectories and
  splash-down probability plots.

### Portability / re-use

**Architecturally the cleanest separation; practically the most stale.**

- Deliberate three-part architecture communicating **only via XML**: Java GUI →
  `SimulationInput.xml` → C++ core (`rocketc`) → `SimulationOutput.xml` → Python
  plotter. The authors explicitly designed for component re-use.
- The **C++ core is small (27 files, ~4.6k lines), dependency-light (Boost only) and
  command-line driven** (`./rocketc SimulationInput.xml`), with GoogleTest coverage across
  8 test files — trivially drivable from any language by writing XML, and the authors call
  out `RKF45.cpp` (generic adaptive ODE solver) and `vmaths.cpp` (quaternion 6-DOF math) as
  independently reusable. One naming trap for readers: `ascentcalc` holds *all* rocket-body
  dynamics, powered and coasting; only parachute descent lives in `descentcalc`.
- A MATLAB/Octave toolbox reimplements the same physics without the GUI.
- **Caveats:** GPL v3 copyleft; C++98 code against Boost 1.62 (the version the README's
  Windows build line names), Java 7-era GUI, Python 2.7 plotter; build instructions cover
  Linux and Windows only, though `SystemInfo.getRunCommand()` does carry a macOS branch;
  zero maintenance since January 2017. Re-use today means adopting and modernizing the
  code, or mining it for its stochastic wind/dispersion formulation — which remains its
  most valuable and distinctive contribution.

---

## 5. CamPyRoS

**What it is.** Open-source (**GPL v3**) Python 6-DOF trajectory package from Cambridge
University Spaceflight — the *Cambridge Python Rocketry Simulator* — written for the team's
Martlet vehicles. Roughly 6k lines across 15 modules. Often described as a successor to
CamRocSim (§4), but it is a **wholly separate codebase** sharing no code with the
Box/Eerland simulator; the similar names invite confusion. **Effectively unmaintained:**
final commit 2021-04-30, `setup.py` declaring version 1.1, with a `v1.0` tag.

- Repo: <https://github.com/cuspaceflight/CamPyRoS>
- Vendored at [`subs/campyros`](../../subs/CLAUDE-campyros.md), pinned at `1dba140`
  (tip of `main`).

### Models

| Aspect | Model |
|---|---|
| Flight dynamics | 6-DOF rigid body with an **18-element state vector**: position, velocity, body angular rates, and the three body-axis direction vectors in inertial coordinates. Attitude is therefore a **full rotation matrix integrated component-wise**, not a quaternion — the only tool here that does so. Nothing re-orthonormalizes it between steps, so drift accumulates; a surviving upstream branch is named `stable-matrix-orientation-RK4`. |
| Earth/gravity | **Rotating, oblate Earth (WGS84)** as the integration frame: Earth's angular velocity, semimajor axis, eccentricity, and flattening are first-class constants, so Coriolis and centrifugal effects fall out of the frame rather than being added as terms. Four frames (inertial, launch-site, body, lat/lon/alt) with time-dependent conversions, since the launch frame rotates away from the inertial one during flight. |
| Integrator | `scipy.integrate.DOP853`, stepped manually in a loop rather than run to completion; fixed step optional; defaults `rtol=1e-7`, `atol=1e-14`. |
| Aerodynamics | **No geometry-based model at all.** `AeroData` interpolates user-supplied CA/CN/COP grids over Mach × angle of attack, loaded via `AeroData.from_rasaero()` from a **RASAero II CSV export** or from explicit lists; the coefficient functions can be replaced with arbitrary callables. Scalar pitch and roll damping coefficients (`moment = C·ρ·ω²`). |
| Aerodynamic heating | `AeroHeatingAnalysis` (~1.8k lines, the largest module): tangent-ogive nose geometry, oblique and normal shock relations, Prandtl–Meyer expansion, compressible-flow property ratios, and a transient skin-temperature solve. **No other tool in this survey models heating at all.** |
| Mass properties | `MassModel` sums constant and time-varying components (`HollowCylinder`, `DryMass`, `LiquidTank`, `SolidFuel`), assuming axial symmetry with all centres of mass on the body x-axis. Propellant slosh modelled separately in `slosh.py`. |
| Wind | **Live NOAA GFS** at 0.25°/1-hour resolution via `getgfs`, snapped onto the forecast grid, with optional profile caching; constant-vector fallback. Historic forecasts explicitly unsupported. |
| Recovery | Deployment by **apogee detection through polling** — altitude compared against the previous poll every `alt_poll_interval` (default 1 s), so trigger granularity is baked in; no altitude or callable triggers. Descent is **not separately integrated**: once deployed, attitude is *constructed* each step by pointing the body x-axis into the relative wind and zeroing the angular rates. |
| Dispersion | `StatisticalModel` over a JSON config of `[mean, std_dev]` pairs (launch site, mass model, aero, thrust magnitude and alignment, parachute, and multiplicative gravity/pressure/density/speed-of-sound factors), applied through `error`/`env_vars` dicts. `ray` for parallelism, degrading **silently** to single-threaded when absent. |

### Simulation input parameters and formats

Everything is constructed in Python: `MassModel`, `Motor`, `AeroData`, and `LaunchSite`
are composed into a `Rocket`, whose `run()` integrates and returns a **pandas DataFrame**
(time, `pos_i`, `vel_i`, `b2imat`, `w_b`, events). Aerodynamic input comes from a RASAero II
CSV; the stochastic model reads a JSON settings file; motor data comes from a CSV in the
project's own `novus_sim` format. There is **no design file format and no importer** for
`.ork`, `.rkt`, or `.CDX1` — the RASAero CSV is its only interchange with the wider ecosystem.

### Portability / re-use

**Poor in practice, despite being a library by construction.**

- **No meaningful test suite**: two wind notebooks, plus one `unittest` file that manipulates
  `sys.path` and reads fixtures by paths relative to the repo root, so it runs from exactly
  one working directory. The CI "Test case" workflow invokes a generic third-party action
  with no arguments. A `gui.py` module exists but **cannot import** — it references a
  `RASAeroData` class that is defined nowhere in the package.
- **Most of the library needs network access**, because wind comes from live GFS — so results
  are not reproducible across days without caching.
- `environment.yml` is a fully pinned conda export from a 2021 macOS machine (Python 3.8,
  numpy 1.19.3, ray 1.1.0): a record of what once worked, not a portable environment.
- **GPL v3**, the same copyleft constraint as OpenRocket and CamRocSim.
- What is worth mining: the **rotating-Earth frame and its transforms**, and the
  **aerodynamic heating model** — neither has an equivalent in the other four.

---

## 6. MAPLEAF

**What it is.** Open-source (**MIT**) Python 6-DOF simulation framework from the University
of Calgary — the *Modular Aerospace Prediction Lab for Engines and Aero Forces* — by Henry
Stoldt and colleagues, described in a 2021 AIAA conference paper. Python 3.6+ with Cython
hot paths for vectors, quaternions, fin functions, and logging. Unlike RocketPy it is
neither primarily a library nor an application: its interface is a **declarative `.mapleaf`
text file**, and rockets are configured rather than constructed.

**Dormant, and mis-signalled as active.** Final commit on `master` 2021-12-11. GitHub
reports a later push date, but that traffic is on eight unmerged student capstone branches
(`ENMECapstone20212022`, `Capstone_TVC`, `TabulatedInputs`, …). The default branch — and the
tree pinned here — is the 2021 one.

- Repo: <https://github.com/henrystoldt/MAPLEAF>
- Paper: Stoldt, Quinn, Kavanagh & Johansen, AIAA 2021-3267
- Vendored at [`subs/mapleaf`](../../subs/CLAUDE-mapleaf.md), pinned at `af970d3`
  (tip of `master`, 2021-12-11).

### Models

| Aspect | Model |
|---|---|
| Flight dynamics | 6-DOF rigid body during ascent, with quaternion attitude. **DOF is phase-dependent, not user-selected:** `_switchTo3DoF` swaps the integrator to a 3-DOF body when a recovery system deploys, since orientation under canopy is not modelled. A `StatefulRigidBody` variant integrates arbitrary extra named state alongside the rigid-body state — the hook actuators and control systems use. |
| Earth/gravity | **A single selectable switch**, `EarthModel` ∈ `None` / `Flat` / `Round` / `WGS84`, and the integration frame follows the choice: launch-tower frame for `None` and `Flat`, **Earth-Centered Inertial** for `Round` and `WGS84`. `Round` is a rotating sphere with uniform inverse-square gravity; `WGS84` is a rotating ellipsoid with a **J2** gravity model. Documented neglects for `WGS84`: polar wobble, third-body gravity, tides, and solar radiation pressure. No other tool here exposes the Earth model as one configuration key. |
| Aerodynamics | **A provider interface, not a fixed model** — force sources are components in the same list as physical parts, interchangeable within one vehicle: geometry build-up (Barrowman-class `CN`/`CP`, plus skin friction, base drag, and blunt-body and cross-flow terms) from nose cone, body tube, fin, and boat-tail components; `AeroForce` (constant coefficients); `AeroDamping` (constant damping derivatives, moments only); and `TabulatedAeroForce`, which interpolates a CSV of arbitrary dimensionality keyed on any of **Mach, altitude, unit Reynolds, total AOA, roll angle, AOA, or AOSS**. An expression-defined provider (`CalculatedAeroForce`) is described in the template but is marked *"still needs to be implemented"* and is **not present in the pinned tree**. |
| Integrator | **Nine Runge–Kutta schemes in-tree**, chosen by name: fixed-step `Euler`, `RK2Midpoint`, `RK2Heun`, `RK4`, `RK4_3/8`; adaptive `RK12`, `RK23` (Bogacki–Shampine), `RK45` (Dormand–Prince, the default), `RK78`. Adaptive schemes take a **Butcher tableau in a documented text format**, so adding a scheme is data rather than code. |
| Step-size control | Its own sub-model: `constant`, `elementary` (safety-factor), or a **PID controller** on a target-error metric blending position, velocity, and — in 6-DOF — angular-orientation error. Steps estimated above 100× target error are discarded and recomputed. Crucially, **adaptive stepping is deliberately overridden near events**: the step shrinks toward a configured floor approaching a detected trigger, because altitude-triggered events otherwise resolve only to step boundaries. Time-deterministic events are resolved exactly. |
| Atmosphere | `USStandardAtmosphere` computed exactly, `Constant`, or `TabulatedAtmosphere` reading h/T/P/ρ/μ columns. |
| Wind | Five models: `Constant`; `SampledGroundWindData` (weighted sampling across named **wind-rose** sites by launch month); `SampledRadioSondeData` (the same over **radiosonde** profiles, with ASL→AGL correction); `Hellman` power-law shear over a ground model; and `CustomWindProfile` from file. Sampling takes an explicit random seed for repeatability. **All file-based — no live-weather ingestion.** |
| Turbulence | `PinkNoise1D` / `2D` / `3D`, seeded per axis, strength set by turbulence intensity or velocity σ; or `customSineGust`, a NASA HDBK-1001-shaped gust layer. Turbulence is switched off under canopy by default, purely to permit larger descent steps. |
| Events, staging, recovery | Stage separation triggers on `apogee`, `ascendingThroughAltitude`, `descendingThroughAltitude`, `motorBurnout`, or `timeReached`; a `simEventDetector` evaluates these and drives the step-shrinking above. Recovery systems support an arbitrary number of stages. |
| Control | A `ControlSystem` with a PID moment controller in constant-gain or **gain-scheduled** form, scheduled by the same parameter keys the aero tables use. A fixed control update rate caps the time step; if adaptive stepping is requested alongside it, MAPLEAF substitutes constant RK4 for ascent and restores adaptive stepping for the uncontrolled descent. |
| Dispersion | **Any scalar or vector key in the entire definition** becomes stochastic by adding a `_stdDev` sibling — implemented in the configuration reader, not in a Monte Carlo module, so no per-parameter support code exists anywhere. Normal distributions only. |
| Optimization | **Particle swarm** (pyswarms) or **`scipy.optimize.minimize`**, with cost functions written as Python expressions over log columns, and **nestable inner optimization** running inside every outer cost evaluation. No other package in this survey has design optimization at all. |

### Simulation input parameters

Everything is supplied through one `.mapleaf` file — brace-delimited, arbitrarily nested
key–value, one pair per line, key and value split on the first whitespace, no multiline
values. `SimDefinitionTemplate.mapleaf` at the repo root documents every option and doubles
as the reference manual.

Two reader features shape how the format is used in practice. **Derived dictionaries** let a
dictionary be defined as a modification of a previously defined one, so a family of related
configurations is expressed as diffs rather than copies — the V&V case files rely on it.
And the **`_stdDev` convention** above means the same file describes both a nominal vehicle
and its dispersion, with no separate stochastic configuration.

Rocket geometry is hierarchical: component positions are relative to the stage tip, with CG
and moment of inertia relative to the component, and per-stage constant mass/CG/MOI
overrides available to bypass component build-up entirely.

### File formats

`.mapleaf` in; **CSV** for every table (aerodynamic coefficients, PID gain schedules,
atmosphere profiles, wind profiles); plain-text logs out, at four verbosity levels, the
highest of which post-processes the force log to add force and moment coefficients.

**There is no `.ork`, `.rkt`, `.CDX1`, or `.eng` import.** MAPLEAF shares no design or motor
interchange with the rest of the ecosystem — its coefficient CSVs are its only common
ground, and even those use its own column naming.

### Portability / re-use

**Good by licence and architecture; poor by maintenance.**

- **MIT** — the second permissively licensed complete core in this survey, and the only other
  one besides RocketPy that could be lifted into a GPL-incompatible product.
- **Pip-installable, with a CLI and an importable package.** The runner layer
  (`SingleSimulations`, `Batch`, `MonteCarlo`, `Optimization`, `Convergence`) sits *above* the
  rocket and environment model rather than beside it, so the model is reusable under a
  different driver — the cleanest seam of the five open cores for headless embedding.
- **A published V&V suite that ships its own reference data** — see §9 below.
- Against that: **dormant since 2021**, with a 2021-era dependency set that includes
  `matplotlib==3.2.2` as a **hard pin**, not a floor. Combined with Cython extensions compiled
  at install time, a modern install would have to build both from source. *Unverified:*
  whether MAPLEAF still installs on a current Python — this report reads the pinned tree, it
  does not run it, and no claim either way should be made without testing.
- The Cython sources mean the vendored tree is **not runnable without a build step**, unlike
  RocketPy or CamPyRoS.

---

## 7. Other open cores: ForRocket and OpenTsiolkovsky

Two further complete simulators are vendored here but given compact treatment rather than the
full model-by-model breakdown above. Both are MIT-licensed and both work — the reason for the
shorter profile is that neither is in use anywhere in the hobby ecosystem this report serves,
and neither contributes a model formulation the other six lack.

What they contribute is **architectural evidence**. Two independent teams, in different
countries and different languages, converged on the same shape: a headless solver that reads
a structured input file, integrates, and writes tabular output, with no GUI, no design editor,
and **no geometry-based aerodynamics at all** — coefficients arrive as constants or tables
from somewhere upstream. That is close to the separation of concerns the *common simulation
core* section below argues for, and it is worth knowing that it has been built twice already.

Both also share a limitation worth naming, because it follows from the same choice: neither
can answer *"what happens if I change this fin?"* Both answer only *"given these
coefficients, where does it go?"*

### ForRocket

**What it is.** An MIT-licensed C++ 6-DOF trajectory solver by Susumu Tanaka, built on
Boost.odeint, Eigen, nlohmann/json, and GoogleTest. Its README states the scope in one line —
*"Prvide only trajectory solver"* — and the tree honours it: JSON in, CSV out, no GUI, no
plotting, no geometry.

Four dynamics phases share one derivative interface and are switched between as the flight
proceeds: a 3-DOF rail phase, 6-DOF free flight with attitude resolved aerodynamically, 6-DOF
with commanded body rates, and 3-DOF descent under canopy. Integration is Boost.odeint's
`runge_kutta_dopri5` driven on a fixed output grid; RK4 and Fehlberg 7(8) sit commented out
beside it, so the scheme is a source edit rather than a configuration key. Engines are
type-agnostic — liquid, solid, and hybrid are the same model with different tables — and
gimbal angles and a full inertia tensor appear in the output, so TVC and 6-DOF are genuinely
modelled rather than merely configured. A non-iterative **instantaneous impact point**
calculation is included, a range-safety product no hobby-oriented package here carries.

The Earth is a **rotating WGS84 ellipsoid for frames and geodesy** — the full ECI/ECEF/NED/body
chain, with Vincenty geodesics for downrange — but **gravity is scalar inverse-square with no
J2 term**, so "WGS84" describes the shape here, not the gravity field. Atmosphere is US
Standard 1976; wind is a CSV table or nothing.

Events are **scheduled rather than triggered**: cutoff, separation, despin, fairing jettison,
and both parachutes are specified as times in seconds, each behind an enable flag, with forced
apogee deployment the single state-triggered exception. This is a flight-plan model — the
natural shape for a vehicle flown to a sequence, and the wrong shape for "deploy at apogee,
whenever that turns out to be."

**Status — read carefully, because the obvious signal is wrong.** GitHub reports a last push
of 2026-07-08, and on that basis ForRocket looks like the most actively maintained project in
this survey. It is not. **`master` has not been committed to since 2020-04-11.** The recent
traffic is on `dev_minor-update` (2026-07-08) and `develop` (2025-04-28), neither of which has
ever been merged. A "last push" date reports activity on *any* branch; it says nothing about
the branch users actually get. ForRocket must not be described as actively maintained.

The tree also ships **no validation evidence**: three GoogleTest files covering the sequence
clock and interpolation, and nothing at trajectory level. Its model derivations are in a
LaTeX technical document under `docs/TechnicalDocument/`.

- Repo: <https://github.com/sus304/ForRocket>
- Vendored at [`subs/forrocket`](../../subs/CLAUDE-forrocket.md), pinned at `10fdcd0`
  (tip of `master`, **2020-04-11**).

### OpenTsiolkovsky

**What it is.** An MIT-licensed simulator from **Interstellar Technologies Inc.**, the
Hokkaido launch company that flies the MOMO sounding rocket. **It is the only package in this
survey maintained by an organization that actually launches vehicles**, and the tree shows it:
the bundled examples are flight configurations for MOMO and for **SS-520-4**, the JAXA sounding
rocket flown as the smallest orbital launcher ever built — real hardware, not tutorial cases.

Three implementations coexist: a **Rust** engine (the live one, with a CLI and a WASM build), a
**legacy C++** reference tree, and a **React/TypeScript** browser front end that drives the WASM
build for 3-D trajectory and performance visualization. Deployment configuration for a hosted
web version is in the repository.

Gravity is **WGS84/EGM96 with the J2 perturbation** — a genuine oblateness model, the equal of
MAPLEAF's `WGS84` setting and better than ForRocket's — over a WGS84 ellipsoid with iterative
ECEF→LLH conversion and full ECI/ECEF/NED transforms. The integrator is selectable between
fixed-step RK4 and adaptive Dormand–Prince 5(4). Thrust is modelled from vacuum Isp and vacuum
thrust with throat diameter, nozzle expansion ratio, and exhaust pressure, so it is
**pressure-corrected for altitude** rather than lumped into a single curve. Up to three stages,
with stack mass accumulated from the top stage down in the standard launch-vehicle convention;
jettisoned masses (fairings, spent hardware) are tracked as separate falling bodies with their
own ballistic coefficients. Attitude configuration carries **gyro biases in deg/h** — an IMU
error model — and atmospheric dispersion is available as an air-density variation ratio.
Aerodynamics, as in ForRocket, are constants or tables only: axial and normal coefficients
looked up against Mach × |angle|, or a ballistic-coefficient model during coast.

**A caveat on its advertised DOF, which matters if the project is cited.** The README
describes "three-degree-of-freedom and six-degree-of-freedom flight simulation with attitude
control (TVC)." That is the union of the two implementations, not a description of the current
engine. **The Rust solver integrates a seven-element translational state** — mass, ECI
position, ECI velocity — with **no quaternion, no angular rates, and no moments**; attitude is
prescribed from a table or a constant elevation/azimuth pair. The 6-DOF is in the legacy C++
tree, whose state vector is fourteen elements and which defines the flight-mode enumerations
that the JSON integers still name. The Rust configuration structures continue to parse
`power flight mode` and a `6DoF` block, but the simulator reads neither. Cited precisely: the
**live tree is a 3-DOF solver with prescribed attitude**; the 6-DOF is in the reference
implementation beside it.

The domain caveat is the more general one. This is launch-vehicle software: its input schema
assumes staged vehicles, programmed attitude, orbital insertion, and range safety, and it
carries none of the hobby-rocketry conventions — no motor database, no `.eng`/`.ork` import, no
rail buttons, no recovery-device modelling beyond a ballistic coast.

- Repo: <https://github.com/istellartech/OpenTsiolkovsky>
- Vendored at [`subs/opentsiolkovsky`](../../subs/CLAUDE-opentsiolkovsky.md), pinned at
  `a699805` (tip of `master`, 2025-09-28).

---

## Comparative summary

| | OpenRocket | RASAero II | RocketPy | CamRocSim | CamPyRoS | MAPLEAF | ForRocket | OpenTsiolkovsky |
|---|---|---|---|---|---|---|---|---|
| Vendored at | `subs/openrocket` | — (closed source) | `subs/rocketpy` | `subs/camrocsim` | `subs/campyros` | `subs/mapleaf` | `subs/forrocket` | `subs/opentsiolkovsky` |
| License | GPL v3 | Freeware, closed source | **MIT** | GPL v3 | GPL v3 | **MIT** | **MIT** | **MIT** |
| Language | Java | .NET (closed) | Python ≥ 3.10 | C++ core / Java GUI / Python plots | Python | Python 3.6+ / Cython | C++ (Boost, Eigen) | Rust (+ legacy C++, TS/WASM UI) |
| Status (2026) | Active (24.12) | Static since 2019 | Active (1.13.0) | Unmaintained since Jan 2017 | Unmaintained since Apr 2021 | Dormant since Dec 2021 | **`master` dormant since Apr 2020** (side branches newer) | Quiet — `master` Sep 2025 |
| Ascent DOF | 6-DOF | 2/3-DOF | 6-DOF (3-DOF option) | 6-DOF | 6-DOF | 6-DOF (auto 3-DOF under chute) | 6-DOF | **3-DOF, prescribed attitude** (6-DOF only in legacy C++) |
| Attitude state | Quaternion | n/a (≤3-DOF) | Quaternion | Quaternion | **Rotation matrix** | Quaternion | Quaternion | n/a — attitude prescribed |
| Integrated quantity | Velocity | n/a | Velocity | **Momentum** | Velocity | Velocity | Velocity | Velocity |
| Earth model | Flat / spherical / WGS84 + Coriolis | Flat | Flat + latitude-dependent gravity | Flat, inverse-square gravity | **Rotating oblate WGS84** | **`None`/`Flat`/`Round`/`WGS84`+J2 — selectable, frame follows** | Rotating WGS84 frames, but **inverse-square gravity, no J2** | **WGS84/EGM96 with J2** |
| Aero source | Extended Barrowman, built-in from geometry | Built-in, Mach 0.01–25, power-on/off | Barrowman lift + **user-supplied drag curves** | Barrowman + tabulated C_D(α, Re) | **Imported tables only** (RASAero CSV) | **Provider interface**: build-up + constant + damping + tabulated | **Imported tables/constants only** | **Imported tables/constants only** |
| Mach range strength | Subsonic (best), semi-empirical super | **Subsonic → hypersonic** | Whatever the supplied curves cover | Subsonic (Ma < 0.4 assumptions) | Whatever the supplied curves cover | Build-up is subsonic-class; tables cover whatever is supplied | Whatever the supplied tables cover | Whatever the supplied tables cover |
| Integrator | Fixed-step RK4 | Not published | scipy LSODA (adaptive, selectable) | RKF45 adaptive | scipy DOP853 | **Nine RK schemes**, RK45 adaptive default, PID step control | Boost.odeint Dormand–Prince 5 — **compile-time, not configurable** | RK4 or Dormand–Prince 5(4), selectable |
| Aero heating | No | No | No | No | **Yes** | No | No | No |
| Weather input | ISA + multi-level wind + CSV | Std. atmosphere + scalar wind | ISA/custom/**soundings/forecasts/ERA5/ensembles** | Tabulated XML profiles | **Live GFS** (network-bound) | ISA/constant/tabulated + wind-rose & radiosonde sampling, pink-noise turbulence — **files only** | US Std. 1976 + wind CSV | Std. atmosphere + wind file + **air-density variation ratio** |
| Monte Carlo | Via scripting (orhelper/extensions) | No | **Built-in framework** (parallel, KML ellipses, MRS) | **Built-in, core design goal** | Built-in (`StatisticalModel`, ray) | **Built-in — `_stdDev` on any key** | No | No (density variation only) |
| Design formats | `.ork` (zip+XML); imports/exports `.rkt`, `.CDX1` | `.CDX1` (XML); imports `.rkt` | Code; `.rpy` save; `.ork` via RocketSerializer | Bespoke XML; imports `.ork`/`.rkt` | None — code only | None — `.mapleaf` schema only | None — JSON only | None — JSON only |
| Motor formats | `.eng`, `.rse` (thrustcurve.org DB) | `.eng` | `.eng`, CSV, ThrustCurve API | Bespoke XML | CSV (`novus_sim` format) | None — CSV thrust tables | None — CSV tables | None — CSV thrust/Isp tables |
| Headless use | Yes — Maven-published core + listener API | GUI automation only (pyrasaero) | **Native — it is a library** | Yes — CLI core driven by XML | Native, but network-bound | Native (CLI + library) | **Native — it is only a solver** | Native (CLI + WASM) |
| Embedding suitability | Good (JVM, GPL) | Poor (data exporter only) | **Excellent (MIT, pip)** | Good architecture, stale code | Poor (GPL, untested, dormant) | Good (MIT, clean runner seam); dormant, Cython build, 2021 pins | Fair (MIT, C++); **no validation evidence**, stale master | Fair (MIT, Rust); launch-vehicle assumptions throughout |

## Observations for the consortium

1. **De-facto interchange formats already exist.** RASP `.eng` (motors, via
   thrustcurve.org) is universal except in CamRocSim; RockSim `.rkt` and OpenRocket
   `.ork` are the design-interchange lingua franca, with OpenRocket 23.09+ bridging to
   RASAero `.CDX1` in both directions. Any consortium interoperability standard should
   start from these rather than invent new ones.

2. **The tools compose along a pipeline, not as alternatives.** The community's
   established workflow is: design geometry in **OpenRocket**; generate wide-Mach-range,
   power-on/off drag curves in **RASAero II**; feed both (via RocketSerializer and CSV)
   into **RocketPy** for high-fidelity 6-DOF flight, real weather, dispersion analysis,
   and control prototyping. That pipeline is a ready-made template for a modular
   "Simulation Engine" component.

3. **Separation of design model from flight configuration** — the README's
   mass/CG-override idea — is supported natively by OpenRocket (per-flight-configuration
   overrides) and is structural in RocketPy and RASAero (mass properties are direct
   inputs, decoupled from geometry).

4. **Licensing shapes the architecture.** RocketPy's MIT license permits any embedding;
   OpenRocket's and CamRocSim's GPL v3 requires copyleft-compatible integration (or
   process-level isolation via files/IPC, as CamRocSim's XML pipeline demonstrates);
   RASAero II can only ever be an offline data generator.

5. **CamRocSim's stochastic wind/dispersion formulation** (correlated Gaussian wind
   profiles, confidence-bounded splash-down zones) predates and complements RocketPy's
   Monte Carlo framework and is worth mining even though the codebase itself is stale.

6. **The two dormant projects are worth keeping for what only they have.** CamRocSim
   contributes the correlated-wind formulation above and a momentum-based formulation of
   the equations of motion; CamPyRoS contributes a rotating oblate-Earth integration frame
   and the only aerodynamic heating model in the survey. Neither is a viable dependency —
   both are GPL, unmaintained, and (in CamPyRoS's case) untested — so the value is in the
   physics and the formulations, not the code.

---

## A common simulation core: comprehensive feature set

This section sketches the feature set a single simulation **library** would need in
order to serve, if correctly implemented, as a drop-in replacement for the simulation
cores of all five projects surveyed above. The scope is deliberately the *core only*:
flight physics, environment, events, dispersion, and the programmatic surface around
them. Design editing, CAD, visualization, GUIs, and motor/parts databases are
consumers of such a library, not part of it. Each feature below is a superset drawn
from capabilities at least one of the surveyed tools already provides, so the set is
demonstrably implementable and demonstrably needed.

### 1. Flight dynamics

- **6-DOF rigid-body ascent** with quaternion attitude (all three open cores use
  quaternions to avoid Euler singularities), with selectable reduced-order modes
  (3-DOF point mass, 2-DOF vertical) for fast previews and RASAero-style workflows.
- **Time-varying mass properties as first-class state**: mass, center of mass, and the
  full inertia tensor evolving through the burn (RocketPy's variable-mass treatment;
  CamRocSim's tabulated inertia tensor), including proper thrust-damping / jet-damping
  torques from propellant mass flow (RASAero, CamRocSim).
- **Multi-body phases**: staging with separation dynamics (each separated body — spent
  booster, nose section under drogue — continues as its own simulated object), nested
  upper stages and boosted darts (RASAero), and clustered motor mounts (OpenRocket).
- **Descent modeling** that degrades gracefully: 6-DOF while intact, per-body 3-DOF
  under canopy after separation (OpenRocket/CamRocSim pattern), including tumbling and
  ballistic-failure trajectories (CamRocSim's failure flag).

### 2. Numerical integration

- **Adaptive, selectable integrators** — at minimum an RK4/RKF45-class fixed and
  adaptive pair plus a stiffness-capable solver (RocketPy's LSODA default), with
  user-set tolerances and step limits.
- **Event-exact integration**: discrete flight events (ignition, burnout, rail
  departure, apogee, deployment triggers, altitude crossings, touchdown) located by
  root-finding rather than landing on whichever step is nearest, so event timing does
  not depend on step size.
- **Determinism and reproducibility**: identical inputs plus an explicit random seed
  must reproduce identical trajectories bit-for-bit on a given platform (OpenRocket
  already persists a wind seed in `.ork` files); turbulence generation must be
  independent of integrator step size (as OpenRocket's fixed-frequency pink-noise
  generator is).

### 3. Aerodynamics — a pluggable coefficient interface

The single largest divergence among the five tools is *where aerodynamic coefficients
come from* — spanning fully built-in (OpenRocket, RASAero) to entirely imported
(CamPyRoS, which has no geometry-based model at all). A common core should therefore define aerodynamics as an **interface**
(coefficients as functions of Mach, angle of attack, Reynolds number, power-on/off
state, and control deflections) with multiple interchangeable providers:

- **Analytic geometry-based provider**: extended Barrowman (OpenRocket's formulation —
  body lift, arbitrary fin planforms, fin–body interference, pitch and roll damping,
  canted-fin roll dynamics), so designs simulate from geometry alone.
- **Tabulated provider**: user-supplied lookup tables — C_D vs Mach power-on/off
  (RocketPy's model), C_D over an α × Re grid (CamRocSim's model), or full coefficient
  sets exported from RASAero, CFD, or wind-tunnel data.
- **Wide-Mach empirical provider** (aspirational, the RASAero capability none of the
  open cores has): transonic/supersonic/hypersonic drag and CP travel, nose and fin
  bluntness, airfoil sections, power-on base-drag reduction from nozzle exit geometry.
- **Component drag build-up with attribution**: skin friction with surface-roughness
  classes and laminar/turbulent transition, pressure/wave drag, base drag, and
  parasitic drag (lugs, rail guides, protuberances), reportable per component
  (OpenRocket's component analysis; RASAero's Run Test breakdown).
- **Live stability outputs**: CP, CNα, static margin (calibers and alternative
  measures), and dynamic-stability derivatives, exposed continuously so client
  applications can implement OpenRocket-style real-time design feedback.

### 4. Propulsion

- **Motor abstraction covering solid, hybrid, liquid, and generic** motors (RocketPy's
  class family): thrust from tabulated curves, callables, or constants; solid grain
  regression; tank models with fluid properties and flow for liquids/hybrids.
- **Standard format ingestion**: RASP `.eng` and RockSim `.rse` thrust curves, and CSV
  static-fire data — the existing lingua franca.
- **Altitude-corrected thrust** from ambient pressure and nozzle exit area (RASAero),
  with per-motor ignition timing, ignition/separation delays, and ejection-charge
  delays (OpenRocket flight configurations).

### 5. Environment

- **Atmosphere providers behind one interface**: ISA/US Standard 1976 (to sounding
  altitudes, per RASAero's 1,000,000 ft extension), fully custom profiles, and
  real-weather sources — soundings, forecast models, reanalysis (ERA5), and ensembles
  (RocketPy's roster) — all reducible to the same profile queries.
- **Wind as a layered 3-D field**: multi-level speed/direction profiles (OpenRocket
  24.12), plus a spectral turbulence model (pink-noise Kaimal/von Kármán
  approximation) and support for correlated stochastic wind profiles
  (CamRocSim's multivariate-Gaussian formulation — see §7).
- **Geodesy and gravity**: flat-Earth, spherical, and WGS84 ellipsoid modes with
  Coriolis (OpenRocket), latitude-dependent gravity (RocketPy's Somigliana), datum
  handling, and launch-site elevation/temperature/pressure anchoring. The most complete
  form of this is integrating directly in an Earth-centred rotating frame so that Coriolis
  and centrifugal terms are structural rather than corrections (CamPyRoS) — which matters
  only for long-range or high-apogee vehicles, and can otherwise be reduced away.

### 6. Events, recovery, and control hooks

- **Recovery devices as triggerable objects**: parachutes and streamers characterized
  by C_D·A, with triggers ranging from simple (apogee, AGL altitude, delay — the
  RASAero/CamRocSim model) to **arbitrary user trigger functions receiving simulated
  sensor data with noise and lag** (RocketPy), so real altimeter logic can be
  flown-in-sim.
- **A listener/extension API on the simulation loop** (OpenRocket's
  `SimulationListener` family): observe or modify state, forces, and coefficients at
  every step; veto or inject events; abort runs. This one mechanism subsumes air
  starts, custom telemetry capture, and research instrumentation.
- **Closed-loop control surfaces**: air brakes (or similar actuators) with
  deployment-dependent drag tables and user controller callbacks running at a fixed
  sampling rate against noisy simulated sensors (RocketPy) — the hook that makes the
  core usable for guidance/control development without forking it.
- **Flight-configuration overrides separated from the design model**: per-run
  overrides of mass, CG, and coefficients (OpenRocket), matching the consortium's
  "as-flown configuration" requirement — the core should never need the design tool's
  geometry to accept measured values.

### 7. Stochastic simulation and dispersion

Monte Carlo must be **in the core, not bolted on** (the lesson of orhelper vs.
RocketPy/CamRocSim):

- Distributions attachable to any input parameter — aero coefficients, CP, thrust
  scale, masses, launch angle, parachute C_D (CamRocSim's perturbation set;
  RocketPy's stochastic wrappers).
- **Correlated wind-profile uncertainty** (mean profile + covariance over altitude,
  CamRocSim's distinctive contribution), not just independent per-parameter noise.
- Parallel batch execution, convergence diagnostics and confidence intervals
  (RocketPy), and derived products: landing-dispersion statistics and 1σ/2σ
  splash-down ellipses (CamRocSim, RocketPy).
- Full input/output logging per iteration so any run is individually reproducible.

### 8. Inputs, outputs, and interchange

- **A documented, versioned, declarative input schema** describing a complete
  simulation (vehicle physical model, environment, events, options, seeds) — the role
  CamRocSim's `SimulationInput.xml` plays — so any language or tool can drive the core
  without linking it.
- **Readers for the existing ecosystem formats**: `.ork` design documents (or the
  parameter sets RocketSerializer derives from them), RockSim `.rkt`, RASAero `.CDX1`,
  `.eng`/`.rse` motors, and CSV coefficient/wind tables. Import is a core concern
  because it defines what the replacement can replace.
- **Structured results**: the full state history and derived quantities (50+ variables,
  per OpenRocket) with user-defined expressions, exportable to CSV, KML
  (trajectories and dispersion ellipses), and a stable machine-readable results schema
  mirroring the input schema.

### 9. Library and architecture requirements

These are what make it a *component* rather than another application:

- **Headless by construction**: zero GUI, plotting, or network dependencies in the
  core; weather fetching and visualization live in optional companion layers
  (RocketPy's separation of `info()`/plotting from simulation is the model).
- **Embeddable API + process-level interface**: a clean object API for in-process use
  *and* a CLI driven by the declarative schema (CamRocSim's `rocketc` pattern) for
  language-agnostic, sandbox-friendly integration.
- **Bindings strategy**: a core implemented in a language that binds outward cheaply
  (or a reference implementation plus a C ABI), so JVM, Python, and MATLAB consumers —
  the audiences these projects actually serve — are all first-class.
- **Permissive licensing (MIT/BSD/Apache)**: GPL v3 is what prevents OpenRocket's and
  CamRocSim's cores from being universal components today; RocketPy's MIT license is
  why it embeds everywhere.
- **A published validation suite**: regression cases against the flight data the
  existing projects validated with (OpenRocket's ~1% subsonic altitude error,
  RASAero's flight-comparison set, RocketPy's documented university flights,
  CamRocSim's telemetry checks), runnable in CI, so "correctly implemented" is a
  testable claim rather than an aspiration — and so replacing an existing core can be
  justified with numbers.
- **Scientific honesty switches**, per the consortium README: the core should report
  the validity envelope of the active models (e.g., Barrowman's α and Mach
  assumptions), warn when a trajectory exits it, and refuse to silently extrapolate —
  "don't pretend to take into account things that are unproven."

Taken together: the dynamics and events of OpenRocket, the Mach envelope and drag
attribution of RASAero, the variable-mass propulsion, weather, control hooks, and
Monte Carlo of RocketPy, and the stochastic wind formulation and XML-driven
process architecture of CamRocSim — behind one headless, permissively licensed,
schema-driven API.

---

## Special focus: RASAero II — unique capabilities, closed source, and a replication roadmap

RASAero II occupies a singular position in this survey: it is the only tool whose core
capability — engineering-level aerodynamic prediction from **Mach 0.01 to Mach 25** —
none of the open-source projects can reproduce, and it is also the only tool that is
**closed source**, Windows-bound, static since 2019, maintained by one author, and
distributed with no formal license. For a consortium building a common open simulation
core, that combination is the ecosystem's largest single risk and its clearest gap.
This section records what makes RASAero unique, what its author has actually disclosed
about its methods, and the established open literature from which those capabilities
could be independently re-implemented.

### What is unique about RASAero II

- **Full-envelope coefficient prediction**: CD (power-on and power-off), CL, CN, CNα,
  and CP as functions of Mach and angle of attack from subsonic through hypersonic,
  including the forward CP travel at high Mach (by Mach 5, up to 60–70% of body
  length) that determines fin sizing for Mach 3+ vehicles. OpenRocket and CamRocSim
  are essentially subsonic methods with semi-empirical extensions; RocketPy has no
  geometry-based aero at all and routinely *consumes RASAero's output*.
- **Physically grounded drag build-up**: laminar/transitional/turbulent skin friction
  with an equivalent-sand-roughness surface-finish model; base drag with **power-on
  plume pressurization** driven by nozzle exit diameter (extended in v1.0.2.0 to
  large exit-area ratios for orbital-class vehicles); boattail wave and base drag;
  fin airfoil sections; nose and fin bluntness; launch lug/rail-guide/launch-shoe and
  general protuberance drag validated against Saturn I flight data.
- **Refined subsonic stability**: the optional Rogers Modified Barrowman Method,
  adding body-cylinder normal force, body-in-presence-of-fins interference, and
  viscous crossflow (forward CP shift with angle of attack).
- **A public validation trail**: the program is calibrated against NACA/NASA wind
  tunnel and free-flight data, sounding-rocket datasets (ARCAS, Aerobee 150A), and
  professional missile aero codes, with the comparison documents posted on
  rasaero.com. Author-reported apogee accuracy: 3.47% average error, 80.6% of flights
  within ±10%.

### Risks of the closed-source status

Rogers stated plainly on RocketryForum (Feb 2018): *"The source code for RASAero II is
not available at this time,"* with publication of the underlying methods deferred
indefinitely. There is no methods bibliography in the Users Manual, no API, no batch
mode, and no formal license text — only "free." The practical consequences:

- The hobby ecosystem's only wide-Mach aero capability depends on one closed Windows
  binary that has not been updated since May 2019 and cannot be forked, ported,
  audited, or embedded.
- Interoperability is one-directional and data-level: RASAero exports coefficient
  CSVs that other tools ingest, and OpenRocket reverse-engineered `.CDX1` well enough
  to read and write it — but the *methods* remain a black box, testable only from the
  outside.
- Any consortium standard that treats RASAero as a required pipeline stage inherits
  these risks. The durable alternative is an open re-implementation of the
  capability, not the program.

### What RASAero actually discloses (verified, from the author)

The Users Manual and Rogers' own RocketryForum posts — especially the thread
*"Differences Between the Barrowman Method and the Rogers Modified Barrowman
Method"* — together constitute the only authoritative method disclosure:

| Regime / feature | Disclosed method (Rogers' own statements) |
|---|---|
| Subsonic CP/CNα | Barrowman method per **Centuri TIR-33**; optional Rogers Modified Barrowman = body-cylinder CNα + body-in-presence-of-fins factor K(bf) + **Jorgensen** viscous crossflow, with crossflow drag coefficients from **Missile DATCOM** |
| Supersonic | "a combination of **USAF DATCOM and Missile DATCOM** methods" (direct quote) |
| Hypersonic | "**Modified Newtonian Theory and Missile DATCOM** methods" (direct quote) |
| Skin friction | Laminar → transition (flat-plate Re = 500,000) → turbulent; all-turbulent option; equivalent-sand-roughness finish table |
| Power-on base drag | Base pressurization from exhaust plume via nozzle exit diameter; empirically extended for very large exit-area ratios at supersonic/hypersonic Mach (v1.0.2.0) |
| Protuberance drag | Drag-per-unit-frontal-area scaling of body CD, validated against **NASA TN D-2002** (Saturn I Block I flight data) |
| Known weak spot | Rogers: the supersonic square-leading-edge fin wave drag model "is one of the less refined models in RASAero" |

Negative findings worth recording: no Rogers publications on the *aerodynamic* methods
exist — his High Power Rocketry magazine articles cover solid-motor propulsion (nozzle
performance, erosive burning), not aero prediction — and no AIAA/journal papers by him
were found. The frequently repeated claim that "RASAero is essentially Missile DATCOM"
is a forum oversimplification: the subsonic core is Barrowman-based.

### Open literature for replicating each capability

Every method family Rogers names is documented in publicly available government and
academic literature (NTRS and DTIC hold most of it). A capable open re-implementation
would draw on:

| Capability | Canonical open literature |
|---|---|
| Subsonic CP/CNα | Barrowman & Barrowman, *The Theoretical Prediction of the Center of Pressure* (NARAM-8, 1966); Barrowman's 1967 M.S. thesis; Centuri **TIR-33** |
| Viscous crossflow / high-α body lift | Allen & Perkins, **NACA Report 1048** (1951); Jorgensen, **NASA TR R-474** (1977, on NTRS) |
| Supersonic body wave drag & CP | Syvertson & Dennis second-order shock-expansion, **NACA Report 1328** (1957); Van Dyke second-order theory (NACA TN 2744, 1952) |
| Supersonic fin lift | Busemann second-order airfoil theory (via Bonney, *Engineering Supersonic Aerodynamics*, 1950); linearized supersonic wing theory; Missile DATCOM Vol. I fin-alone methods |
| Hypersonic | Lees modified Newtonian theory (1955); Gentry et al., **Mark IV Supersonic-Hypersonic Arbitrary-Body Program** (AFFDL-TR-73-159, 1973) — the standard catalog of tangent-cone/tangent-wedge/Newtonian local-inclination methods, with a public-domain descendant at pdas.com |
| Compressible skin friction | Van Driest II (1951/1956); Hopkins & Inouye evaluation (AIAA J., 1971); Hopkins charts, NASA TN D-6945 (1972); Nikuradse equivalent sand roughness (NACA TM 1292); Schlichting, *Boundary-Layer Theory* |
| Base drag & power-on plume | Hoerner, *Fluid-Dynamic Drag* (1965); Brazzel & Henderson power-on base drag correlation (AGARD CP-10, 1966 — which breaks down in exactly the high-thrust-ratio regime Rogers says he extended empirically); Moore's AP98/AP02 improved power-on base drag models |
| Transonic drag rise | Whitcomb area rule (NACA Report 1273, 1956); empirical subsonic↔supersonic fairing as documented in Missile DATCOM Vol. I and Moore |
| Complete method catalogs | **Missile DATCOM** documentation — methods and user's manuals are public on DTIC (AFWAL-TR-86-3091 Vols I–II; 1997, 2011, 2014 revisions) even though the code itself is export-controlled; **NSWC Aeroprediction Code** series (AP98: NSWCDD/TR-98/1; AP02: NSWCDD/TR-01/108, both on DTIC); and above all **Moore, *Approximate Methods for Weapon Aerodynamics*** (AIAA, 2000) — the single best open, book-form catalog of engineering methods for slender finned vehicles from Mach 0 to 20 |

Two attribution caveats, kept explicit: Rogers names the DATCOM family, TIR-33,
Jorgensen, and modified Newtonian theory — he has **never** named second-order
shock-expansion, Van Driest II, Busemann, or Brazzel–Henderson specifically. Those are
the standard ingredients *inside* the method families he cites, so they are the right
starting points for a replica, but mapping them to RASAero's internals is inference,
not disclosure. And Missile DATCOM's *code* is export-controlled; only its
documentation is public — an open re-implementation must work from the documented
methods, not the code.

### Replication strategy for an open core

1. **Implement from Moore + Missile DATCOM documentation.** Moore's AIAA book and the
   DTIC-hosted DATCOM method reports cover the same regime RASAero does and are the
   very sources Rogers cites. This is a documented-methods engineering project, not a
   reverse-engineering one.
2. **Validate against the same public data RASAero uses.** RASAero's calibration
   datasets are themselves open NACA/NASA reports (NACA RM A53D02, NASA TR R-100,
   NASA TN D-4013/D-4014 ARCAS wind-tunnel data, NASA TN D-2002 Saturn I). An open
   implementation can be held to the same benchmarks — and compared head-to-head
   against RASAero's own published comparison PDFs.
3. **Use RASAero as a reference for differential testing.** Batch CSV exports (via
   pyrasaero GUI automation) provide dense coefficient tables for comparing an open
   implementation against RASAero across Mach, α, and geometry sweeps.
4. **Slot the result into the common core** as the "wide-Mach empirical provider"
   behind the pluggable aerodynamic-coefficient interface described in the previous
   section — opening the one pipeline stage that is currently closed.

---

## References

All URLs accessed 2026-08-22.

### Vendored source

Four of the five packages are pinned as submodules under `subs/`, each with an
agent-facing primer; claims in this report about their internals were checked against
these exact trees. See [`subs/CLAUDE.md`](../../subs/CLAUDE.md) for the set, and
[`docs/ref/`](../ref/README.md) for local copies of the papers cited below.

| Package | Path | Pinned commit |
|---|---|---|
| OpenRocket | [`subs/openrocket`](../../subs/CLAUDE-openrocket.md) | `e0dc0cd` (2025-11-08, v24.12) |
| RocketPy | [`subs/rocketpy`](../../subs/CLAUDE-rocketpy.md) | `9bd6ad3` (tag `v1.13.0`) |
| CamRocSim | [`subs/camrocsim`](../../subs/CLAUDE-camrocsim.md) | `8191db9` (2017-01-13) |
| CamPyRoS | [`subs/campyros`](../../subs/CLAUDE-campyros.md) | `1dba140` (2021-04-30) |

### Peer-reviewed publications

1. Niskanen, S. (2009). *Development of an Open Source model rocket simulation
   software*. Master's thesis, Helsinki University of Technology.
   <https://openrocket.sourceforge.net/thesis.pdf>
2. Niskanen, S. (2013). *OpenRocket Technical Documentation*, version 13.05.
   <https://openrocket.sourceforge.net/techdoc.pdf>
3. Ceotto, G., et al. (2021). "RocketPy: Six Degree-of-Freedom Rocket Trajectory
   Simulator." *Journal of Aerospace Engineering* (ASCE), 34(6).
   DOI: [10.1061/(ASCE)AS.1943-5525.0001331](https://ascelibrary.org/doi/10.1061/%28ASCE%29AS.1943-5525.0001331)
4. Box, S., Bishop, C. M., & Hunt, H. (2011). "Stochastic Six-Degree-of-Freedom
   Flight Simulator for Passively Controlled High-Power Rockets." *Journal of
   Aerospace Engineering* (ASCE), 24(1), 31–45.
   DOI: [10.1061/(ASCE)AS.1943-5525.0000051](https://ascelibrary.org/doi/10.1061/%28ASCE%29AS.1943-5525.0000051)
5. Eerland, W. J., Box, S., & Sóbester, A. (2017). "Cambridge Rocketry Simulator –
   A Stochastic Six-Degrees-of-Freedom Rocket Flight Simulator." *Journal of Open
   Research Software*, 5(1).
   DOI: [10.5334/jors.137](https://openresearchsoftware.metajnl.com/articles/10.5334/jors.137)
6. Box, S., Bishop, C. M., & Hunt, H. (2009). *Estimating the dynamic and aerodynamic
   parameters of passively controlled high power rockets for flight simulation*.
   Technical report. <https://cambridgerocket.sourceforge.net/AerodynamicCoefficients.pdf>

### Software, documentation, and project sites

**OpenRocket**

7. OpenRocket project. *OpenRocket* [software], version 24.12. GNU GPL v3.
   <https://openrocket.info/> · Source: <https://github.com/openrocket/openrocket>
8. OpenRocket project. *OpenRocket Documentation* (Sphinx site): features, advanced
   flight simulation, simulation extensions.
   <https://openrocket.readthedocs.io/en/latest/>
9. OpenRocket project. "Using OpenRocket Core in External Applications."
   *OpenRocket Development Guide*.
   <https://openrocket.readthedocs.io/en/latest/dev_guide/using_openrocket_core.html>
10. OpenRocket project. "OpenRocket File Format Specification."
    *OpenRocket Development Guide*.
    <https://openrocket.readthedocs.io/en/latest/dev_guide/file_specification.html>
11. OpenRocket project. `info.openrocket:core` [Maven Central artifact], version 24.12.
    <https://central.sonatype.com/artifact/info.openrocket/core>
12. SilentSys. *orhelper* [software]: Python bridge to OpenRocket via JPype.
    <https://github.com/SilentSys/orhelper>

**RASAero II**

13. Rogers, C. E., & Cooper, D. (2019). *RASAero II* [software], version 1.0.2.0.
    Rogers Aeroscience. Freeware. <https://rasaero.com/>
14. Rogers, C. E., & Cooper, D. *RASAero II Users Manual*, version 1.0.2.0.
    Rogers Aeroscience.
    <https://rasaero.com/dloads/RASAero%20II%20Users%20Manual.pdf>
15. Leeds University Rocketry. *pyrasaero* [software]: GUI automation for batch
    RASAero II runs. <https://github.com/leedsrocketry/pyrasaero>

**RocketPy**

16. RocketPy Team. *RocketPy* [software], version 1.13.0. MIT License.
    <https://github.com/RocketPy-Team/RocketPy> ·
    PyPI: <https://pypi.org/project/rocketpy/>
17. RocketPy Team. *RocketPy Documentation*: class references (Environment, Motor,
    Rocket, Flight, MonteCarlo), equations of motion, flight examples.
    <https://docs.rocketpy.org/>
18. RocketPy Team. *RocketSerializer* [software]: OpenRocket `.ork` to RocketPy
    converter. <https://github.com/RocketPy-Team/RocketSerializer>

**Cambridge Rocketry Simulator**

19. Box, S., Eerland, W. J., et al. (2016). *Cambridge Rocketry Simulator* [software],
    version 3.1. GNU GPL v3.
    <https://sourceforge.net/projects/camrocsim/> ·
    Archived: [Zenodo, DOI 10.5281/zenodo.161850](https://doi.org/10.5281/zenodo.161850)
20. Cambridge Rocketry Simulator project site: technical details, user guide,
    MATLAB/Octave toolbox downloads. <https://cambridgerocket.sourceforge.net/>

### Related resources

21. thrustcurve.org — hobby rocket motor data repository (source of OpenRocket's and
    RocketPy's motor data). <https://www.thrustcurve.org/>
22. OpenRocket wiki. "Third-Party Compatibility" — interchange between OpenRocket,
    RockSim, and RASAero II. <https://wiki.openrocket.info/Third-Party_Compatibility>
23. Free Rocket Tree Consortium. *Simulation Components and Subcomponent Libraries*
    (2026-08-24). [`docs/research/simulation-components-and-libraries.md`](simulation-components-and-libraries.md)
    — companion catalog of additional simulators and of library-level building blocks
    for the common simulation core.
24. Cambridge University Spaceflight. *CamPyRoS — Cambridge Python Rocketry Simulator*
    [software], version 1.1 (final commit 2021-04-30). GNU GPL v3. A separate codebase
    from CamRocSim despite the name and shared institution.
    <https://github.com/cuspaceflight/CamPyRoS>

### RASAero method disclosures (primary)

25. Rogers, C. E. (crogers168). "Differences Between the Barrowman Method and the
    Rogers Modified Barrowman Method." RocketryForum thread — the author's most
    explicit method attribution (Barrowman/TIR-33, Jorgensen, USAF DATCOM, Missile
    DATCOM, Modified Newtonian).
    <https://www.rocketryforum.com/threads/differences-between-the-barrowman-method-and-the-rogers-modified-barrowman-method.163535/>
26. Rogers, C. E. (crogers168). RocketryForum threads: "RASAero Source Code?"
    (source-code status, 2018)
    [144646](https://www.rocketryforum.com/threads/rasaero-source-code.144646/);
    "New Version of the Free RASAero II Software (Version 1.0.2.0) Released"
    (power-on base drag extensions)
    [153033](https://www.rocketryforum.com/threads/new-version-of-the-free-rasaero-ii-software-version-1-0-2-0-released.153033/);
    "RASAero II Comparisons with Supersonic CP and CD ARCAS Wind Tunnel Data"
    [130843](https://www.rocketryforum.com/threads/rasaero-ii-comparisons-with-supersonic-cp-and-cd-arcas-wind-tunnel-data.130843/);
    "Streamlined Protuberance Drag, Camera Shroud Drag, and Saturn I Block I Flight
    Data"
    [197641](https://www.rocketryforum.com/threads/streamlined-protuberance-drag-camera-shroud-drag-and-saturn-i-block-i-flight-data.197641/).
27. Rogers Aeroscience technical-report and validation pages: aerodynamic validation
    data, solid-motor articles, flight comparisons.
    <https://www.rasaero.com/comparisons.htm> and the `dl_aerodynamics.htm`,
    `dl_technical_reports.htm` download pages at rasaero.com.

### Aerodynamic methods literature (for replication)

28. Barrowman, J. S., & Barrowman, J. A. (1966). *The Theoretical Prediction of the
    Center of Pressure*. NARAM-8 R&D Project Report.
29. Barrowman, J. S. (1967). *The Practical Calculation of the Aerodynamic
    Characteristics of Slender Finned Vehicles*. M.S. thesis, Catholic University of
    America.
30. Barrowman, J. (1970). *Calculating the Center of Pressure of a Model Rocket*.
    Centuri Engineering Co., Technical Information Report TIR-33.
31. Allen, H. J., & Perkins, E. W. (1951). *A Study of Effects of Viscosity on Flow
    Over Slender Inclined Bodies of Revolution*. NACA Report 1048.
32. Jorgensen, L. H. (1977). *Prediction of Static Aerodynamic Characteristics for
    Slender Bodies Alone and With Lifting Surfaces to Very High Angles of Attack*.
    NASA TR R-474. <https://ntrs.nasa.gov/citations/19770026166>
33. Syvertson, C. A., & Dennis, D. H. (1957). *A Second-Order Shock-Expansion Method
    Applicable to Bodies of Revolution Near Zero Lift*. NACA Report 1328 (supersedes
    NACA TN 3527, on NTRS).
34. Van Dyke, M. D. (1952). *Practical Calculation of Second-Order Supersonic Flow
    Past Nonlifting Bodies of Revolution*. NACA TN 2744.
35. Lees, L. (1955). "Hypersonic Flow." *Proc. Fifth International Aeronautical
    Conference*, Los Angeles, IAS. (Modified Newtonian theory.)
36. Gentry, A. E., Smyth, D. N., & Oliver, W. R. (1973). *The Mark IV
    Supersonic-Hypersonic Arbitrary-Body Program (HABP)*. AFFDL-TR-73-159.
    Public-domain descendant and reference list: <https://www.pdas.com/hyperrefs.html>
37. Van Driest, E. R. (1951). "Turbulent Boundary Layer in Compressible Fluids."
    *J. Aeronautical Sciences*, 18(3), 145–160; and (1956) "The Problem of
    Aerodynamic Heating." *Aeronautical Engineering Review*, 15(10). (Van Driest II.)
38. Hopkins, E. J., & Inouye, M. (1971). "An Evaluation of Theories for Predicting
    Turbulent Skin Friction and Heat Transfer on Flat Plates at Supersonic and
    Hypersonic Mach Numbers." *AIAA Journal*, 9(6), 993–1003.
39. Nikuradse, J. (1933). *Strömungsgesetze in rauhen Rohren*. VDI-Forschungsheft 361;
    English translation: NACA TM 1292 (1950). (Equivalent sand roughness.) See also
    Schlichting, H., *Boundary-Layer Theory*, McGraw-Hill.
40. Hoerner, S. F. (1965). *Fluid-Dynamic Drag*. Hoerner Fluid Dynamics.
41. Brazzel, C. E., & Henderson, J. H. (1966). "An Empirical Technique for Estimating
    Power-On Base Drag of Bodies of Revolution With a Single Jet Exhaust." In *The
    Fluid Dynamic Aspects of Ballistics*, AGARD CP-10.
42. Whitcomb, R. T. (1956). *A Study of the Zero-Lift Drag-Rise Characteristics of
    Wing-Body Combinations Near the Speed of Sound*. NACA Report 1273. (Area rule.)
43. Bonney, E. A. (1950). *Engineering Supersonic Aerodynamics*. McGraw-Hill.
    (Practical treatment of Busemann second-order supersonic airfoil theory.)
44. Vukelich, S. R., et al. (1988). *Missile DATCOM, Volume I — Final Report* and
    *Volume II — User's Manual*. AFWAL-TR-86-3091. DTIC ADA211086 / ADA210128.
    Later revisions: Blake, W. B. (1998), AFRL-VA-WP-TR-1998-3009; Rosema, C., et al.
    (2011), AFRL-RB-WP-TR-2011-3071, DTIC ADA548461; 2014 revision,
    AFRL-RQ-WP-TR-2014-0281, DTIC AD1000581. (Documentation public; code
    export-controlled.)
45. Hoak, D. E., & Finck, R. D. (1978). *USAF Stability and Control DATCOM*.
    AFWAL-TR-83-3048. (Digital Datcom implementation is public domain.)
46. Moore, F. G. (2000). *Approximate Methods for Weapon Aerodynamics*. AIAA Progress
    in Astronautics and Aeronautics, Vol. 186.
47. Moore, F. G., McInville, R. M., & Hymer, T. C. (1998). *The 1998 Version of the
    NSWC Aeroprediction Code: Part I — Summary of New Theoretical Methodology*.
    NSWCDD/TR-98/1. DTIC ADA342842. Also: Moore, F. G., & Hymer, T. C. (2002),
    *The 2002 Version of the Aeroprediction Code*, NSWCDD/TR-01/108, DTIC ADA400445.

### Validation datasets cited by RASAero (all public)

48. James, C. S., & Carros, R. J. (1953). NACA RM A53D02 — fin-stabilized body of
    revolution, fineness ratio 10, Mach 0.6–10.
49. Stoney, W. E. (1961). *Collection of Zero-Lift Drag Data on Bodies of Revolution
    from Free-Flight Investigations*. NASA TR R-100.
50. Ferris, J. C. (1967). NASA TN D-4013, and Babb, C. D., & Fuller, D. E. (1967),
    NASA TN D-4014 — ARCAS sounding rocket wind-tunnel data, Mach 0.60–4.63.
51. Garcia, F. (1964). *An Aerodynamic Analysis of Saturn I Block I Flight Test
    Vehicles*. NASA TN D-2002, NASA MSFC.
