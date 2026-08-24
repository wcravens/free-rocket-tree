# Simulation Components and Subcomponent Libraries

A companion catalog to *[Rocket Simulation Software: Models, Inputs, and
Portability](rocket-flight-simulation-designs.md)*. That report surveys eight complete
flight-simulation **packages** in depth. This one covers everything around them:

1. **Flight simulators the survey does not cover** — open-source 6-DOF cores that are
   real candidates for the same comparison, plus the closed/commercial tools named for
   completeness.
2. **Subcomponent libraries** — library-level implementations of the individual pieces
   the survey's *[common simulation core](rocket-flight-simulation-designs.md#a-common-simulation-core-comprehensive-feature-set)*
   feature set calls for: aerodynamic methods, propellant thermochemistry, atmosphere
   and wind models, geodesy, integrators, and format readers.

The motive for (2) is the consortium's own thesis: a shared core should *depend on*
well-validated implementations of the hard parts rather than re-derive them. Barrowman's
equations, the US Standard Atmosphere, NRLMSISE-00, and chemical-equilibrium solvers are
all solved problems with maintained implementations. Knowing which are solid, which are
abandoned, and which are unusable on license grounds is a prerequisite for that.

*Research date: 2026-08-24. Repository metadata — license, star count, archive status —
was read from the GitHub API on that date. **Dates are default-branch commit dates, not
the API's `pushed_at` field.** That distinction was not made in this catalog's first pass
and it mattered: `pushed_at` reports activity on *any* branch, and for three projects here
it overstated currency by a year or more — ForRocket by six years. Capability descriptions
come from project READMEs and documentation and are **not** verified against source.
Except where a row says otherwise, nothing in this catalog is vendored under
[`subs/`](../../subs/CLAUDE.md); treat every capability claim here as weaker evidence than
the corresponding claims in the eight-package survey.*

---

## Part 1 — Flight simulators not in the survey

### 1.1 MAPLEAF — promoted into the survey

MAPLEAF was catalogued here in the first pass and has since been **promoted into the main
survey**, where it is now [§6](rocket-flight-simulation-designs.md#6-mapleaf) with the same
full treatment the other packages receive. It is a complete flight-simulation package, not a
component, and it is vendored and pinned at
[`subs/mapleaf`](../../subs/CLAUDE-mapleaf.md) so its claims are checkable against source —
the standard this catalog explicitly does not meet.

Read the survey section rather than a summary here. Two of the claims originally made in this
catalog did not survive verification against the pinned tree and are corrected there: its
expression-defined aerodynamic provider is **declared but unimplemented**, and its status is
best described by its **default branch** (`master`, 2021-12-11) rather than the later push date
reported below for other projects.

### 1.2 Other open-source flight simulators

| Project | License | Language | Default branch | Stars | What it is |
|---|---|---|---|---|---|
| [OpenTsiolkovsky](https://github.com/istellartech/OpenTsiolkovsky) | MIT | Rust (+ legacy C++, TS/WASM web UI) | `master` 2025-09-28 | 120 | **Now vendored and profiled in the survey ([§7](rocket-flight-simulation-designs.md#7-other-open-cores-forrocket-and-opentsiolkovsky)).** Launch-vehicle trajectory simulator from Interstellar Technologies (a Japanese launch company). Up to three stages, sub-orbital and LEO insertion, JSON input, CSV/JSON output, CLI plus a browser front end, aerodynamics supplied as tables. Note the correction made there against source: the **Rust solver is 3-DOF with prescribed attitude**; the advertised 6-DOF/TVC lives in the legacy C++ tree. |
| [ForRocket](https://github.com/sus304/ForRocket) | MIT | C++ | **`master` 2020-04-11** | 48 | **Now vendored and profiled in the survey ([§7](rocket-flight-simulation-designs.md#7-other-open-cores-forrocket-and-opentsiolkovsky)).** "Only a trajectory solver," by explicit design — the same core-not-application thesis the survey argues for. 6-DOF, engine-type agnostic (solid/liquid/hybrid), staged event sequencing (cutoff, separation, despin, jettison), controlled-flight support. JSON in, CSV out, built on Boost/Eigen/nlohmann-json/GoogleTest. **Its 2026-07-08 push date is on the unmerged `dev_minor-update` branch; `develop` is at 2025-04-28. `master` has been static since April 2020.** |
| [hpr-sim](https://github.com/rdoddanavar/hpr-sim) | GPL-3.0 | C++ core + Python | `master` 2025-05-16 | 9 | An independent attempt at precisely the architecture §9 recommends: C++ numerics behind PyBind11 Python bindings, YAML declarative input, RASP `.eng` motors, Monte Carlo, multicore, geodetic and wind-turbulence environment models. Self-described as **not yet in a release state**. |
| [AeroVECTOR](https://github.com/GuidodiPasquo/AeroVECTOR) | GPL-3.0 | Python | `master` 2023-07-12 | 185 | **3-DOF**, aimed squarely at active control: TVC, active fin control, and parachute-deployment algorithms, with non-linear actuator dynamics and **software-in-the-loop over serial to an Arduino-class flight computer**. Aerodynamics use OpenRocket's extended Barrowman plus modifications, with fin forces from interpolated wind-tunnel data and **Diederich's semi-empirical method**. |
| [FARS / failure-aware-rocket-simulator](https://github.com/Tuzcuberat1/failure-aware-rocket-simulator) | GPL-3.0 | Java | `main` 2026-08-09 | 5 | Brand new. Does not reimplement physics — it wraps OpenRocket with custom `SimulationListener`s to **inject failures** (ignition failure, early burnout, thrust degradation, recovery-deployment failure, avionics blockage, structural failure) and runs Monte Carlo reliability analysis over real OpenRocket runs. Interesting mainly as a working demonstration that OpenRocket's listener API is a sufficient extension point (survey §6). |
| [rocket-sim](https://github.com/ZenAlexa/rocket-sim) | MIT | Rust | `master` 2026-02-07 | 3 | 6-DOF multi-stage with TVC, gravity-turn guidance, RK4 at 200 Hz, plus an orbital-mechanics toolkit. Created February 2026. Too new and too small to lean on; noted because it is a concrete instance of the from-scratch duplication the consortium README is a response to. |
| [JSBSim](https://github.com/JSBSim-Team/jsbsim) | LGPL-2.1 | C++ | `master` 2026-08-03 | 2211 | Not rocketry-specific, but the most relevant architectural precedent in the catalog: a mature, heavily used, **XML-schema-driven** flight dynamics model with a C++ core and Python/other bindings — twenty-plus years of evidence that the survey's §8/§9 "declarative schema + embeddable core + bindings" shape is sustainable. Has been used for launch-vehicle ascent studies. Requires supplied coefficient tables; no geometry-based rocket aero. |

Also encountered and **not** recommended as dependencies, for a reason worth recording
as a pattern: student-team software-in-the-loop simulators —
[ISS_SILSIM](https://github.com/ISSUIUC/ISS_SILSIM) (Illinois Space Society, C++, last
push 2023-10-18) and [calstar/SIL](https://github.com/calstar/SIL) (C++, last push
2022-10-11) — **carry no license file at all**. They are readable but legally
un-embeddable. This is common enough in team-built rocketry code to be worth a
consortium convention of its own.

### 1.3 Closed and commercial tools, for completeness

The survey covers RASAero II as its closed-source case study. The others in this
category, none of which can be a component:

- **RockSim** (Apogee Components) — the long-standing commercial design/simulation
  program; source of the `.rkt` interchange format that OpenRocket and RASAero both
  read. Offers Barrowman, a "RockSim" method, and a cardboard-cutout method for
  stability.
- **SpaceCAD** — commercial design/simulation; Barrowman stability only, smaller parts
  database.
- **AeroRocket suite** (AeroCFD, AeroDRAG, AeroCP, VisualCFD) and **Aerolab** —
  shareware/freeware Windows aerodynamic tools. Aerolab estimates drag, lift, and
  stability at zero angle of attack from Mach 0–8, which overlaps the RASAero envelope.
  All closed.
- **ASTOS** (commercial) and **POST2** (NASA, restricted distribution) — professional
  launch-vehicle trajectory optimization. Named because they define what
  "industrial-grade" means here, not because they are reachable.

---

## Part 2 — Subcomponent libraries, by core-spec feature

Organized against the numbered sections of the survey's *common simulation core*.

### §2 Numerical integration

Nothing rocketry-specific is needed. The established options — SciPy's `solve_ivp`
(LSODA/DOP853/Radau; RocketPy's choice), SUNDIALS/CVODE, Boost `odeint` (C++), and
Julia's `DifferentialEquations.jl` — all provide adaptive stepping with event
root-finding, which is the survey's actual requirement ("event-exact integration").
The design decision is *which* to depend on, not whether to write one.

### §3 Aerodynamics

This is where "lean on a stronger subcomponent" is hardest, because the good
implementations are either embedded in whole applications or are documentation without
usable code.

| Component | License | Status | Assessment |
|---|---|---|---|
| [open-aerospace/barrowman](https://github.com/open-aerospace/barrowman) | GPL-3.0 | **Dormant** — last push 2016-04-11, 11 stars, 27 commits | The only standalone library named after the method. Pure-Python implementation of the original Barrowman method for slender finned vehicles. README is largely a TODO. Not a credible dependency; useful as a compact reference reading of the equations. |
| OpenRocket's `AerodynamicCalculator` | GPL-3.0 | Active | The best-validated open extended-Barrowman implementation there is — body lift, arbitrary fin planforms, fin–body interference, pitch/roll damping, canted fins. Already vendored at [`subs/openrocket`](../../subs/CLAUDE-openrocket.md). Extractable only into GPL-compatible work. |
| RocketPy's `AeroSurface` classes | **MIT** | Active | Barrowman lift for nose cones, fins, and tails, plus user drag curves. Already vendored at [`subs/rocketpy`](../../subs/CLAUDE-rocketpy.md). The permissively licensed Barrowman implementation the ecosystem actually has. |
| AeroVECTOR's fin model | GPL-3.0 | Dormant | Notable for **Diederich's semi-empirical fin method** and interpolated wind-tunnel fin data — a specific subcomponent absent from the survey's five. |
| [python-datcom](https://github.com/danielenriquez59/python-datcom) | **None** — no LICENSE file, despite a README claim of public domain | Created 2025-10-14, 4 commits, 43 stars | A modernizing translation of **USAF Digital DATCOM** (the aircraft code, not Missile DATCOM) into Python — state dicts replacing COMMON blocks, type hints, NumPy. Exactly the shape of thing the survey's replication roadmap wants, and currently unusable: no license, no releases, no validation results. Worth watching, and worth asking the author to add a license. |
| USAF **Digital DATCOM** (original FORTRAN) | Public domain | Static | The genuinely public-domain aircraft code. Distinct from **Missile DATCOM**, whose *documentation* is public on DTIC but whose *code* is export-controlled — the distinction the survey already draws. |
| [PDAS](https://www.pdas.com/) — Public Domain Aeronautical Software | Public domain | Static, curated | The most directly relevant collection for the RASAero-replication roadmap: **HABP** (the Mark IV Supersonic-Hypersonic Arbitrary-Body Program, with tangent-cone/tangent-wedge/Newtonian local-inclination methods), **PANAIR** (higher-order panel method, subsonic and supersonic), and a **1976 US Standard Atmosphere** implementation to 1000 km with hot/cold/polar/tropical variants. Public-domain FORTRAN source, so no license barrier at all. |
| [OpenVSP](https://github.com/OpenVSP/OpenVSP) + VSPAERO | **NASA Open Source Agreement 1.3** | Very active, 831 stars | NASA parametric geometry plus panel/vortex-lattice solver. Can generate coefficient tables from geometry. NOSA is a non-standard, non-OSI-friendly copyleft — check it carefully before any integration deeper than running it as an offline tool. |
| [SU2](https://github.com/su2code/SU2) | LGPL-2.1 | Very active, 1784 stars | General-purpose compressible CFD. The high-fidelity end of coefficient generation. |
| [OpenFOAM ToolChain for Rocket Aerodynamic Analysis](https://github.com/WyllDuck/OpenFOAM-ToolChain-for-Rocket-Aerodynamic-Analysis) | **None stated** | Last push 2026-04-27, 37 stars | A TUM student project: a documented subsonic/transonic/supersonic OpenFOAM workflow for extracting rocket aerodynamic characteristics. Valuable as *methodology* for producing validation-grade coefficient tables; unlicensed, so not embeddable. |
| [datcom-parser](https://github.com/skyward-er/datcom-parser) | Not asserted | Last push 2023-01-19 | Skyward Experimental Rocketry's parser for Missile DATCOM `for006.dat` output. Relevant only to teams who already have DATCOM access. |

**Recommendation for §3:** the pluggable-provider interface should be designed against
three concrete providers that already exist — RocketPy's MIT Barrowman implementation,
a tabulated reader, and a PDAS-derived local-inclination method for the hypersonic end.
The transonic/supersonic middle remains the genuine gap, exactly as the survey concluded.

### §4 Propulsion

The most consequential finding in this catalog after MAPLEAF:

| Component | License | Status | Assessment |
|---|---|---|---|
| [nasa/cea](https://github.com/nasa/cea) | **Apache-2.0** | Repository created 2025-12-22, actively pushed, 176 stars | NASA's **Chemical Equilibrium with Applications**, re-implemented and released on GitHub under a permissive license. Fortran core with C and Python bindings, 2,000+ species, rocket-performance mode. Historically CEA was distributed as registered executables under restrictive terms; a permissively licensed, binding-friendly CEA changes what a shared propulsion module can do. |
| [RocketCEA](https://rocketcea.readthedocs.io/) | **GPL-3.0** | Active (v1.2.3) | The established Python wrapper around the legacy CEA FORTRAN, with mixture-ratio exploration and optimization tooling. Mature and widely used — but copyleft, where `nasa/cea` is not. That contrast is the whole decision. |
| [Cantera](https://cantera.org/) | BSD-3-Clause | Very active (v3.2.0) | General chemical kinetics, thermodynamics, and transport. The heavier, more general alternative to CEA-style equilibrium. |
| [CoolProp](http://www.coolprop.org/) | MIT | Active (v8.0.0) | Thermophysical fluid properties — the standard dependency for the survey's §4 "tank models with fluid properties" requirement for liquids and hybrids. |
| [openMotor](https://github.com/reilleya/openMotor) | GPL-3.0 | **Active** — last push 2026-07-08, 618 stars | The community-standard open solid-motor internal ballistics simulator, and the effective successor to BurnSim. **Fast Marching Method** grain regression, so arbitrary core geometries work; BATES/Finocyl/Star plus DXF import; nozzle model; **exports `.eng`** and reads/writes BurnSim files. Ballistics per Sutton and Nakka. *Unverified: whether the ballistics core is separable from the PyQt6 GUI* — the README documents no headless API, and that separability is the question that decides whether it can be a component or only a producer of `.eng` files. |
| [OpenBurn](https://github.com/tuxxi/OpenBurn) | GPL-3.0 | **Abandoned** — last push 2018-07-12, 19 commits | Superseded by openMotor. Listed so it is not rediscovered as a live option. |
| [HRAP](https://github.com/rnickel1/HRAP_Source) — Hybrid Rocket Analysis Program | GPL-3.0 | Active — last push 2026-03-11, 41 stars | Thermodynamic-equilibrium simulation of **self-pressurizing hybrid motors** (saturated nitrous oxide): adiabatic oxidizer tank, combustion chamber, isentropic nozzle, semi-empirical efficiency factors. Python and MATLAB versions, with a published theory document. The most credible open hybrid-motor model found. |
| [bamboo](https://github.com/cuspaceflight/bamboo) | **AGPL-3.0** | Last push 2024-09-25, 33 stars | Cambridge University Spaceflight's liquid-engine cooling-system modelling. AGPL makes it effectively unembeddable for most consumers; note the same institution's CamPyRoS licensing pattern. |

### §5 Environment

Well-served by maintained, permissively licensed libraries. There is no reason for a
shared core to hand-roll any of these.

| Need | Library | License | Status |
|---|---|---|---|
| ISA / standard atmosphere | [ambiance](https://github.com/airinnova/ambiance) | Apache-2.0 | Active (2026-04-13), 46 stars. Full ICAO Standard Atmosphere 1993. |
| US Standard Atmosphere 1976 to 1000 km | PDAS `atmosphere` | Public domain | Static; includes hot/cold/polar/tropical non-standard variants. |
| Upper-atmosphere density/temperature | [pymsis](https://github.com/SWxTREC/pymsis) | MIT | Active (2026-07-08), 38 stars. NRL's own MSIS wrapper — MSIS2.0/2.1 and NRLMSISE-00. The best-provenance option. |
| NRLMSISE-00 (alternatives) | [fluids.atmosphere](https://github.com/CalebBell/fluids) (MIT, very active, 450 stars, also bundles HWM93/HWM14 wind); [pynrlmsise00](https://github.com/st-bender/pynrlmsise00) (GPL-2.0, 2024-09-30); [ATMOS/pyatmos](https://github.com/lcx366/ATMOS) (MIT, 2024-11-05, adds COESA76 and JB2008) | mixed | — |
| Horizontal wind (climatological) | HWM14, via `fluids.atmosphere` | MIT | The empirical upper-atmosphere wind counterpart to MSIS. |
| Soundings and forecast weather | [MetPy](https://unidata.github.io/MetPy/) (BSD-3), [siphon](https://github.com/Unidata/siphon) (BSD-3, THREDDS/Wyoming sounding access), [SounderPy](https://github.com/kylejgillett/sounderpy) (MIT, retrieves RAOB/ACARS/model/reanalysis profiles), [Herbie](https://github.com/blaylockbk/Herbie) (MIT, NWP model archive access) | permissive | All active. Collectively they cover the weather sources RocketPy fetches, as a decoupled optional layer — which is precisely the §9 "no network dependencies in the core" separation. |
| Geodesy and datums | [pyproj](https://pyproj4.github.io/pyproj/) (MIT, PROJ bindings), [GeographicLib](https://geographiclib.sourceforge.io/) (MIT, C++/Python/Java/JS) | MIT | Active. Geodesic distance, WGS84 conversions, and local-tangent-plane transforms — the §5 geodesy requirement, solved. |

### §6 Events, recovery, and control

No general-purpose library exists for rocket recovery-event logic; it is inherently
part of the simulation core. What the ecosystem does supply is **prior art on the
software-in-the-loop boundary**: AeroVECTOR's serial bridge to an Arduino-class flight
computer (§1.2), RocketPy's noisy-sensor trigger callbacks, and OpenRocket's
`SimulationListener` family — with FARS as evidence the listener interface is
expressive enough for third parties to build on without forking. For structural limits
adjacent to recovery, [Fin-Flutter-Velocity-Calculator](https://github.com/jkb-git/Fin-Flutter-Velocity-Calculator)
(BSD-2-Clause, active 2026-01-09) implements the standard flutter-velocity criterion as
a small, cleanly licensed component.

### §8 Inputs, outputs, and interchange

| Component | License | Status | Assessment |
|---|---|---|---|
| [thrustcurve.org](https://www.thrustcurve.org/) — [thrustcurve3](https://github.com/JohnCoker/thrustcurve3) | ISC | Active (2026-08-19) | The site itself is open source under a permissive license, with a documented API. The survey names thrustcurve.org as the motor-data source; that its implementation is ISC-licensed matters for anyone building on it. |
| [thrustcurve-db](https://github.com/broofa/thrustcurve-db) | ISC (per npm) | Active (2026-05-20), v4.0.1 | The whole ThrustCurve motor database rebundled as a **single static JSON file**, CDN-served, with thrust samples included. The lowest-friction way for any tool to ship motor data without an API dependency. |
| [openrocket/motor-database](https://github.com/openrocket/motor-database) | GPL-3.0 | **New** — created 2025-12-21, pushed 2026-08-24 | OpenRocket's own motor database, built from thrustcurve.org and other sources, as a separate repository. A new and directly relevant interchange asset that postdates the survey's research. |
| [rasp-parser](https://github.com/gituser12981u2/rasp-parser) | MIT | Created 2025-05, quiet since | Standalone RASP `.eng` parser with validation and cubic-spline integration for impulse. Small and new; the format is simple enough that this is a convenience, not a critical dependency. |
| [rjw57/thrustcurve](https://github.com/rjw57/thrustcurve) | Apache-2.0 | **Dormant** (2015) | Older Python parser for amateur rocketry formats. |
| [RocketSerializer](https://github.com/RocketPy-Team/RocketSerializer) | MIT | Active (2026-08-16) | `.ork` → RocketPy converter; already covered in the survey. |
| [openrocket-python-parser](https://github.com/AIAA-UTD-Comet-Rocketry/openrocket-python-parser) | MIT | Created 2025-10, pushed 2026-08-23, 0 stars | Parses `.ork` XML and simulation data into Python objects and pandas DataFrames. A general-purpose `.ork` reader not tied to RocketPy's object model — closer to what a language-agnostic importer needs. Very new and unproven. |

No JavaScript `.ork` parser was found. RockSim `.rkt` and RASAero `.CDX1` have no
standalone parser libraries either; the only implementations are inside OpenRocket.

---

## Part 3 — Triage

**Lean on these** — maintained, permissively licensed, and doing one thing well:

`nasa/cea` (Apache-2.0) · CoolProp (MIT) · Cantera (BSD) · pymsis (MIT) · ambiance
(Apache-2.0) · `fluids.atmosphere` (MIT) · pyproj / GeographicLib (MIT) · MetPy /
siphon / SounderPy / Herbie (BSD/MIT) · thrustcurve-db (ISC) · SciPy integrators ·
RocketPy's MIT Barrowman surfaces.

**Mine, fork, or evaluate** — real value, but with a condition attached:

- **MAPLEAF** — MIT and architecturally closest to the target. **Now promoted into the
  survey (§6) and vendored**; the open question is unchanged and still the highest-value
  thing to check next: whether a **2021**-era Python/Cython package with a hard
  `matplotlib==3.2.2` pin still builds on a current interpreter.
- **openMotor** — active and community-standard, but its usability as a *library*
  rather than an application is unverified.
- **HRAP** — the credible open hybrid-motor model; GPL-3.0.
- **PDAS** — public-domain source for the hypersonic and panel-method ends of §3.
- **ForRocket** / **hpr-sim** — independent implementations of the "solver only, driven
  by a declarative file" architecture; worth reading as design precedent even if not
  adopted.
- **AeroVECTOR** — for the Diederich fin method and the SIL serial-bridge pattern.

**Reference only** — do not plan to depend on:

- **python-datcom**, **OpenFOAM ToolChain**, **ISS_SILSIM**, **calstar/SIL** — no
  license. Readable, not usable.
- **open-aerospace/barrowman** (2016), **OpenBurn** (2018) — abandoned and superseded.
- **bamboo** — AGPL-3.0.
- **OpenVSP** — NOSA 1.3; fine as an offline tool, needs legal review for anything more.
- **RockSim / SpaceCAD / AeroRocket / Aerolab / ASTOS / POST2** — closed.

---

## Part 4 — What this changes in the survey

1. **The survey's package list had a real omission — now closed.** MAPLEAF met the
   survey's inclusion bar (6-DOF, published, open) and has since been given a full
   section there (§6) and vendored at `subs/mapleaf`, with its claims re-checked against
   source. ForRocket and OpenTsiolkovsky were vendored alongside it and profiled compactly
   (§7). Re-verification changed two things this catalog had asserted from documentation:
   MAPLEAF's expression-defined aero provider is **unimplemented**, and OpenTsiolkovsky's
   **live Rust solver is 3-DOF**, not the 6-DOF its README advertises.

2. **"Permissive core" is no longer a set of one.** The survey's conclusion that
   RocketPy's MIT license is why it embeds everywhere still holds, but MAPLEAF (MIT),
   ForRocket (MIT), and OpenTsiolkovsky (MIT) show the pattern is spreading. The
   copyleft problem is concentrated in the *oldest* projects.

3. **The propulsion licensing barrier has moved.** With NASA's CEA on GitHub under
   Apache-2.0 as of December 2025, a permissively licensed shared core can do
   propellant thermochemistry without inheriting GPL from RocketCEA. This postdates the
   survey's research and is worth an explicit note in §4.

4. **The RASAero replication roadmap gains two concrete assets.** PDAS ships
   public-domain source for the Mark IV HABP local-inclination methods the roadmap
   names — the roadmap currently cites it only as a reference list. And Sooy & Schmidt
   (2005) is a published open benchmark for engineering-method accuracy across exactly
   the Mach range in question, **already implemented as regression cases in MAPLEAF** —
   which, now that MAPLEAF is vendored, ships its digitized AP98, DATCOM-97, wind-tunnel,
   and CFD reference curves directly in this repository. That combination converts
   "replicate from documented methods and validate" from a plan into a set of runnable
   comparisons, and the survey's roadmap now says so.

5. **Unlicensed team software is a systemic ecosystem problem.** Four projects in this
   catalog — two of them substantial — have no license file. This belongs in the
   consortium's "standards of collaboration" work as a concrete, low-cost ask: a
   license file is the difference between code that can be built on and code that
   cannot.

---

## References

All URLs accessed 2026-08-24. Repository metadata from the GitHub REST API, same date.

### Flight simulators

1. Stoldt, H., Quinn, D., Kavanagh, J., & Johansen, C. (2021). "MAPLEAF: A Compact,
   Extensible, Open-Source, 6-Degrees-of-Freedom Rocket Flight Simulation Framework."
   AIAA 2021-3267, *AIAA Propulsion and Energy 2021 Forum*.
   DOI: [10.2514/6.2021-3267](https://arc.aiaa.org/doi/10.2514/6.2021-3267) ·
   Source: <https://github.com/henrystoldt/MAPLEAF> ·
   Docs: <https://henrystoldt.github.io/MAPLEAF/>
2. Interstellar Technologies. *OpenTsiolkovsky* [software]. MIT.
   <https://github.com/istellartech/OpenTsiolkovsky>
3. *ForRocket* [software]. MIT. <https://github.com/sus304/ForRocket>
4. Doddanavar, R. *hpr-sim* [software]. GPL-3.0.
   <https://github.com/rdoddanavar/hpr-sim>
5. di Pasquo, G. *AeroVECTOR* [software]. GPL-3.0.
   <https://github.com/GuidodiPasquo/AeroVECTOR>
6. *FARS — Failure-Aware Rocket Simulator* [software]. GPL-3.0.
   <https://github.com/Tuzcuberat1/failure-aware-rocket-simulator>
7. Berndt, J. S. (2004). "JSBSim: An Open Source Flight Dynamics Model in C++."
   AIAA 2004-4923. DOI: [10.2514/6.2004-4923](https://arc.aiaa.org/doi/10.2514/6.2004-4923) ·
   <https://github.com/JSBSim-Team/jsbsim>
8. Illinois Space Society. *ISS_SILSIM* [software]. No license.
   <https://github.com/ISSUIUC/ISS_SILSIM> · CalSTAR. *SIL* [software]. No license.
   <https://github.com/calstar/SIL>

### Aerodynamic methods and codes

9. Sooy, T. J., & Schmidt, R. Z. (2005). "Aerodynamic Predictions, Comparisons, and
   Validations Using Missile DATCOM (97) and Aeroprediction 98 (AP98)." *Journal of
   Spacecraft and Rockets*, 42(2), 257–265.
   DOI: [10.2514/1.7814](https://arc.aiaa.org/doi/10.2514/1.7814)
10. Public Domain Aeronautical Software. <https://www.pdas.com/> — Hypersonic Arbitrary
    Body Program: <https://www.pdas.com/hyper.html> · PANAIR:
    <https://www.pdas.com/panair.html>
11. Open Aerospace. *barrowman* [software]. GPL-3.0.
    <https://github.com/open-aerospace/barrowman> ·
    Docs: <https://open-aerospace.github.io/barrowman/>
12. *python-datcom* [software]. No license file.
    <https://github.com/danielenriquez59/python-datcom>
13. NASA. *OpenVSP* [software]. NASA Open Source Agreement 1.3.
    <https://github.com/OpenVSP/OpenVSP>
14. SU2 Foundation. *SU2* [software]. LGPL-2.1. <https://github.com/su2code/SU2>
15. *OpenFOAM ToolChain for Rocket Aerodynamic Analysis* [software], TU München. No
    license stated.
    <https://github.com/WyllDuck/OpenFOAM-ToolChain-for-Rocket-Aerodynamic-Analysis>

### Propulsion

16. NASA. *CEA — Chemical Equilibrium with Applications* [software]. Apache-2.0.
    <https://github.com/nasa/cea>
17. Brown, C. *RocketCEA* [software]. GPL-3.0. <https://rocketcea.readthedocs.io/>
18. Cantera Developers. *Cantera* [software]. BSD-3-Clause. <https://cantera.org/>
19. Bell, I. H., et al. *CoolProp* [software]. MIT. <http://www.coolprop.org/>
20. Reilley, A. *openMotor* [software]. GPL-3.0.
    <https://github.com/reilleya/openMotor>
21. Nickel, R. *HRAP — Hybrid Rocket Analysis Program* [software]. GPL-3.0.
    <https://github.com/rnickel1/HRAP_Source>
22. Cambridge University Spaceflight. *bamboo* [software]. AGPL-3.0.
    <https://github.com/cuspaceflight/bamboo>

### Environment

23. Dettmann, A. *Ambiance* [software]. Apache-2.0.
    <https://github.com/airinnova/ambiance>
24. Lucas, G., et al. *pymsis* [software]. MIT. <https://github.com/SWxTREC/pymsis>
25. Bell, C. *fluids* [software] — `fluids.atmosphere` (NRLMSISE-00, HWM93/HWM14). MIT.
    <https://github.com/CalebBell/fluids>
26. Bender, S. *pynrlmsise00* [software]. GPL-2.0.
    <https://github.com/st-bender/pynrlmsise00>
27. *ATMOS / pyatmos* [software]. MIT. <https://github.com/lcx366/ATMOS>
28. May, R. M., et al. (2022). "MetPy: A Meteorological Python Library for Data Analysis
    and Visualization." *BAMS*, 103(10). <https://unidata.github.io/MetPy/> ·
    Siphon: <https://github.com/Unidata/siphon>
29. Gillett, K. *SounderPy* [software]. MIT.
    <https://github.com/kylejgillett/sounderpy>
30. Blaylock, B. *Herbie* [software]. MIT. <https://github.com/blaylockbk/Herbie>
31. *pyproj* [software]. MIT. <https://pyproj4.github.io/pyproj/> ·
    Karney, C. F. F. *GeographicLib*. MIT. <https://geographiclib.sourceforge.io/>

### Interchange and data

32. Coker, J. *ThrustCurve* [software and data]. ISC.
    <https://www.thrustcurve.org/> · <https://github.com/JohnCoker/thrustcurve3>
33. *thrustcurve-db* [software/data]. ISC.
    <https://github.com/broofa/thrustcurve-db>
34. OpenRocket project. *motor-database* [data]. GPL-3.0.
    <https://github.com/openrocket/motor-database>
35. *rasp-parser* [software]. MIT. <https://github.com/gituser12981u2/rasp-parser>
36. *openrocket-python-parser* [software]. MIT.
    <https://github.com/AIAA-UTD-Comet-Rocketry/openrocket-python-parser>
37. *Fin-Flutter-Velocity-Calculator* [software]. BSD-2-Clause.
    <https://github.com/jkb-git/Fin-Flutter-Velocity-Calculator>
38. Skyward Experimental Rocketry. *datcom-parser* [software].
    <https://github.com/skyward-er/datcom-parser>

### Commercial and closed tools

39. Apogee Components. *RockSim*. <https://www.apogeerockets.com/Rocket_Software/RockSim>
40. *SpaceCAD*. <https://www.spacecad.com/>
41. AeroRocket (J. Cipolla). *AeroCFD, AeroDRAG, AeroCP, VisualCFD*.
    <http://www.aerorocket.com/>
42. *Aerolab* — zero-α drag/lift/stability estimation, Mach 0–8. Freeware, closed.
