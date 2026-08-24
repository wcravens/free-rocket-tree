# Cambridge Rocketry Simulator (vendored submodule)

A primer on the CRS source vendored at `subs/camrocsim` — build, the three-language pipeline,
simulation core, and conventions. That tree is read-only here; see `subs/CLAUDE.md`.

Pinned at `8191db9` on `master` (2017-01-13), upstream's final commit. Commit `3ed1513`
(2016-10-13) is byte-identical to the released `camrocsim_3.1_src.tar.gz`. **Archived, not
maintained** — no activity since January 2017, 63 commits total.

## Project Overview

The Cambridge Rocketry Simulator is the GPL six-degree-of-freedom simulator by Simon Box and
Willem Eerland. It is the **CRS** that `docs/research/` surveys and that the RocketPy paper
benchmarks Valetudo against. Its simulation model is peer-reviewed — Box, Bishop, and Hunt,
*"Stochastic Six-Degree-of-Freedom Flight Simulator for Passively Controlled High-Power Rockets,"*
Journal of Aerospace Engineering (ASCE) 24(1), 2011; the README links a free copy at
<http://eprints.soton.ac.uk/73938/>.

It handles single- and two-stage rockets, parachute descent, and stochastic launches producing
splash-down dispersion plots.

The structural thing to understand before reading any of it: **CRS is not one program but three,
wired together by XML files on disk.**

## Architecture

```
Java GUI  ──writes──>  Data/SimulationInput.xml
                              │
                              ▼
                       simulator/rocketc          (C++ binary, forked as a subprocess)
                              │
                              ▼
                       SimulationOutput.xml  ──read by──>  Plotter/*.py  (matplotlib figures)
```

Each stage is independently usable — `rocketc SimulationInput.xml` runs headless, and the plotter
is a plain CLI over the output XML. That decoupling is the most reusable idea in the tree, and the
reason CRS shows up in cross-simulator comparisons: you can drive the physics core without touching
the GUI.

The handoff is `Runtime.getRuntime().exec(...)` in `panelCamRockSim.runProgram()`, with the command
assembled per-platform by `SystemInfo.getRunCommand()`. Progress is reported by the GUI **parsing
the binary's stdout** for `(current,total)` and the literal string `"Simulation Complete."`.

### `cpp/` — the simulation core

About 4.6k lines of C++ depending on **Boost** (`property_tree` for XML, `random`, `numeric::ublas`
for matrices). `main.cpp` is 38 lines: it takes an input path (default `./SimulationInput.xml`) and
hands it to `HandleInputFile`, which parses the XML and dispatches to one of four runs —
`OneStageFlight`, `TwoStageFlight`, `OneStageMonte`, `TwoStageMonte`.

- **`RocketFlight.{h,cpp}`** (762 lines, the largest) — orchestration. Holds up to three `INTAB`
  input tables (first stage, booster, upper stage), initial conditions, rail length, azimuth,
  declination, separation and ignition-delay timings. It sequences phases and carries state across
  boundaries via `StateTransferRocket` / `StateTransferParachute` / `TimeTransfer`.
- **`ascentcalc.{h,cpp}`** — despite the name, **all rocket-body dynamics**, powered and coasting.
  The comment in the header says so outright: "while this class is called ascent, it actually holds
  the rocket dynamics, and descent is for the parachute dynamics."
- **`descentcalc.{h,cpp}`** — parachute dynamics only, a reduced point-mass model (`EqMotionData2`
  carries position, velocity, acceleration, force, wind — no attitude).
- **`RKF45.{h,cpp}`** — a hand-rolled adaptive Runge–Kutta–Fehlberg 4(5) integrator. Defaults:
  `Retol=1e-3`, `Abtol=1e-6`, `h_init=0.01`, `max_step=10.0`, `max_it=1000`. Integration is driven
  through an abstract `integrator` interface with `step()` and `stop_flag()`; `blastoff` and
  `floatdown` are the two concrete implementations, each inheriting from `integrator`, `RKF`, and
  the relevant dynamics class.
- **`MonteFy.{h,cpp}`** — the stochastic layer (see below).
- Support: `vmaths` (quaternions, 3×3 matrices, `vector3`), `vectorops`, `vectorbearing`,
  `interpolation`, `intabread` (input tables), `FlightData` (output records).

**The state vector is 13 elements and momentum-based** — this is the notable modelling choice:

```
z[0..2]   position          (x, y, z)
z[3]      quaternion scalar
z[4..6]   quaternion vector
z[7..9]   translational momentum  (Px, Py, Pz)
z[10..12] rotational momentum     (Ltheta, Lphi, Lpsi)
```

Where RocketPy and CamPyRoS integrate *velocities* and *angular velocities*, CRS integrates
*momenta* and recovers the rates by dividing through the (time-varying) mass and inertia tensor.
For a vehicle losing mass fast, that puts the mass variation on the correct side of the derivative
by construction rather than as an added term. Attitude is quaternions, like RocketPy.

Gravity is inverse-square from Earth's centre (`g = G·M/(6378100+z)²`) but the frame is otherwise
flat and non-rotating — no Coriolis, unlike CamPyRoS.

**Stochastic model.** `MonteFy` perturbs drag coefficient, centre of pressure, normal coefficient,
both parachute drag coefficients, launch declination, and thrust — each a standard deviation in
`Data/Uncertainty.xml`, sampled normally with a truncated variant available. Wind is the
sophisticated part: rather than perturbing a scalar, it draws from a **covariance-matrix
eigendecomposition over an altitude grid** — `Mu`, `HScale` (~120 altitudes to 12 km), `Sigma`,
`Eigenvalues`, `Eigenvectors`, and `PHI` basis functions, all shipped in that XML as a
Karhunen–Loève-style expansion of realistic wind profiles. `Wiggle()` produces a perturbed input
table per Monte Carlo iteration.

### `gui/` — a fork of OpenRocket

113 MB of the 115 MB checkout, and **a fork of OpenRocket at `15.03dev`** (`net.sf.openrocket`,
per `gui/core/resources/build.properties`), with 40 bundled jars. We vendor OpenRocket's current
source at `subs/openrocket` — read across the two rather than treating this as its own codebase.
Most of what's here is upstream OpenRocket; CRS removed features it does not model and added a
bridge.

The CRS-specific parts are worth knowing by name:

- **`net.sf.openrocket.camrocksim`** (`gui/core/src/...`) — note the **`k`**; the package spelling
  differs from the project name. ~17k lines. Contains the XML readers/writers (`RWsiminXML`,
  `RWsimOutXML`, `RWatmosXML`, `RWmotorXML`, `RWuncertainty`, `RWdesignXML`, all over `RWXML`),
  the CRS-side domain model (`RocketDescription`, `StageDescription`, `LaunchData`,
  `AtmosphereData`, `MotorData`, `ParachuteData`, …), and `PlotLauncher` / `SimulatorInterface`.
- **`panelCamRockSim.java`** (`gui/swing/src/.../gui/main/`, 1846 lines) — the Swing panel that
  runs a simulation and launches the plotter.
- **`OpenRocketDocument.java`** carries the conversion: OpenRocket's own document model →
  `RocketDescription` → `SimulationInput.xml`.

Entry point is the stock OpenRocket one, `gui/swing/src/net/sf/openrocket/startup/SwingStartup.java`.

### `Plotter/` — Python figures

~780 lines of Python 2.7-era code. `FlightPlotter.py` is the CLI (`-f` output file, `-x`/`-y` axis
labels); `Decider.py` reads the `<Function>` element from the output XML and dispatches to the
matching plot routine (`OSFProcess`, `TSFProcess`, `OSMProcess`, `TSMProcess` — mirroring the four
C++ run types); `Rdata.py` parses, `PlotBase.py` draws. The README recommends this as the place to
extend analysis, "leaving the Java and c++ code as it is."

### Other directories

- **`Data/`** — 10 example motors (XML), 9 example atmospheres including `no-wind-isa.xml` and
  several named wind profiles, plus `Uncertainty.xml` with the default stochastic conditions.
- **`simulator/`** — empty in the repo; the destination for the compiled `rocketc` binary
  (`make copy`).
- **`doc/`** — `user_guide.pdf` with `.tex` source. The user guide is the reference for the
  stochastic wind parameters.
- **`help_build_files/`** — Debreate (`.deb`) and Advanced Installer (`.aip`) configs plus icons,
  for building releases.

## Common Commands

There is no top-level build. Each language is built separately.

```bash
# C++ core (Linux/macOS) — needs Boost
cd cpp && make              # -> ./rocketc
make copy                   # -> ../simulator/rocketc
make debug                  # unoptimized build with -g
./rocketc path/to/SimulationInput.xml

# C++ tests — googletest 1.8.0 must be unpacked into cpp/ first (see below)
make tests                  # builds ./runtests and runs it

# Java — Ant, from gui/
ant build | ant jar | ant unittest
ant check                   # checktodo + checkascii

# Python plotter
python FlightPlotter.py -f SimulationOutput.xml

# development layout: copies Data/, simulator/, Plotter/ into ~/.camrocsim/
./prepare_linux.sh
```

On Windows the README documents a direct `cl /EHsc` invocation for the core and PyInstaller for the
plotter; the JAR is exported from Eclipse on both platforms.

## Testing Notes

- **C++**: googletest, 8 test files under `cpp/test/` covering `ascentcalc`, `descentcalc`,
  `handleinputfile`, `interpolation`, `montefy`, `vectorbearing`, and `vmath`. The Makefile
  hardcodes `GTEST_DIR=googletest-release-1.8.0` relative to `cpp/`, so you must download and build
  that exact release into that exact path first — the README gives the `wget`/`cmake` recipe.
- **Java**: JUnit via `ant unittest-core` / `unittest-swing`, or Eclipse. CRS added
  `gui/core/test/net/sf/openrocket/camrocsim/` (no `k` here) with `WritingXmlTest` and
  `RocketComponentsTest` — a couple hundred lines checking the XML bridge. The rest is inherited
  OpenRocket tests.
- **Python**: none.
- No CI of any kind.

## Gotchas

- **The package name is spelled two ways.** `net.sf.openrocket.camrocksim` (with `k`) for the main
  source, `net.sf.openrocket.camrocsim` (without) for the tests, and the README mixes "camrocsim"
  and "camrocksim" in prose. Grep for both.
- **An entire earlier standalone GUI is orphaned inside the bridge package.** `MainForm.java` plus
  a full set of NetBeans `*Dialog.java`/`*.form` files (`ConeDialog`, `FinsetDialog`,
  `ParachuteDialog`, `CreateMotorDialog`, `RawAtmosphereDialog`, …) predate the OpenRocket fork.
  `MainForm` is referenced only from within its own package, never from `SwingStartup` — it is dead
  weight relative to the live entry point, but it is also where the pre-fork UI logic lives if you
  need it.
- **`ascentcalc` is not just ascent** — it is all rocket-body dynamics. Only parachute descent lives
  in `descentcalc`. The header comment says so; the filename does not.
- **Python 2 era.** The plotter targets 2.7+ and the Windows build pins a specific PyInstaller
  development commit from 2016.
- **Paths are convention, not configuration.** `SystemInfo` hardcodes `Data`, `simulator`,
  `Plotter`, `SimulationInput.xml`, `SimulationOutput.xml`, `Uncertainty.xml`, and `~/.camrocsim`
  as the per-user install directory. `prepare_linux.sh` exists solely to copy those three folders
  into place, and most of its body is commented-out `/usr/share` alternatives.
- **`simulator/` ships empty**, so the GUI cannot run anything until the C++ core is built and
  copied.
- The C++ carries commented-out includes, a dead `if (tt>0.9){ bool stop_flag=true; }` block in
  `ascentcalc.cpp`, and copyright headers dated 2008 — it is long-lived research code, not a
  polished library.

## Conventions

- **GPL**, per `LICENSE` and the file headers (`Copyright (C) 2008 S.Box`). Keep the headers on
  anything copied. Note this is the most restrictive license of the four trees we vendor, and it
  applies to the OpenRocket-derived GUI as well.
- C++ style is tabs, `using namespace std;` in headers, class-per-file with a matching `.h`, and
  Doxygen-ish `\brief` / `\param` comments — added late (the 2016 "added comments to the cpp code"
  commits), so coverage is uneven.
- Java follows inherited OpenRocket conventions; `ant check` enforces a TODO scan and an ASCII check.
- No branching convention survives — the repo has a single `master` branch and no tags.

## Reading Alongside the Others

| | OpenRocket | RocketPy | CamPyRoS | CRS (this tree) |
|---|---|---|---|---|
| License | GPLv3 | MIT | GPLv3 | GPL |
| Languages | Java | Python | Python | C++ + Java + Python |
| Shape | desktop app + core | library | library | GUI + headless binary + plotter |
| Coupling | in-process | in-process | in-process | XML files on disk |
| Attitude state | quaternions | quaternions | rotation matrix | quaternions |
| Integrated quantity | velocity | velocity | velocity | **momentum** |
| Integrator | custom RK4 | scipy (LSODA default) | scipy DOP853 | hand-rolled RKF45 |
| Descent model | full | reduced | reduced (weathercocked) | reduced (point mass) |
| Stochastic wind | none | forecast ensembles | live GFS | covariance eigenmodes |
| Maintained | yes | yes | no (2021) | no (2017) |
