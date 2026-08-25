# OpenTsiolkovsky (vendored submodule)

A primer on the OpenTsiolkovsky source vendored at `subs/opentsiolkovsky` — the Rust solver, the
legacy C++ tree, the web front end, and the gap between what the README advertises and what the
current engine integrates. That tree is read-only here; see `subs/CLAUDE.md`.

Pinned at **`a699805`** (2025-09-28), the tip of `master`.

Upstream ships its own agent instructions at `CLAUDE.md` and `AGENTS.md` in the repo root — read those
for "how would upstream want this written"; this document covers "how does this code work".

## Project Overview

A rocket flight simulator from **Interstellar Technologies Inc.** (インターステラテクノロジズ), the
Hokkaido launch company that flies the MOMO sounding rocket and is developing ZERO. Licensed **MIT**
(`subs/opentsiolkovsky/LICENSE`, "Copyright (c) 2016 Interstellar Technologies Inc.").

**It is the only simulator in `docs/research/` maintained by an organization that actually launches
rockets**, and the tree shows it: `examples/` holds `param_momo.json` (Interstellar's own vehicle) and
`SS-520-4/` (the JAXA sounding rocket flown as the smallest orbital launcher ever). These are flight
configurations for real hardware, not tutorial cases.

Named for Konstantin Tsiolkovsky. Three implementations coexist:

- **Rust** (`src/`, ~5.5k lines) — the current engine, CLI and WASM.
- **Legacy C++** (`legacy_cpp/`, ~31k lines incl. a vendored Boost) — the original, kept as reference.
- **React/TypeScript front end** (`frontend/`) — Vite + Bun, 3-D trajectory viewer, driven by the WASM
  build.

```bash
cargo run --bin openTsiolkovsky-cli -- --config examples/param_sample_01.json --verbose
cd frontend && bun install && bun run dev     # http://localhost:5173
./scripts/wasm_build.sh                        # WASM package for the front end
```

## The DOF question — the most important thing in this file

The README's first feature bullet reads:

> **Rocket Simulation**: Three-degree-of-freedom and six-degree-of-freedom flight simulation with
> attitude control (TVC)

**The Rust engine does not integrate rotational dynamics.** Its ODE state is seven elements —
`[mass, x, y, z, vx, vy, vz]` in ECI (`src/simulator.rs:745-750`) — and `SimulationState`
(`src/simulator.rs:13-33`) carries no quaternion, no angular velocity, and no moments. Attitude is
**prescribed**, from an attitude CSV or a constant elevation/azimuth pair, and used to orient thrust
and resolve angle of attack. That is 3-DOF with commanded attitude.

The 6-DOF is in the **legacy C++**, whose ODE state is fourteen elements
(`legacy_cpp/src/rocket.hpp:37`) and which defines the modes the JSON integers actually name
(`legacy_cpp/src/rocket.hpp:50-55`):

```cpp
enum EPower_flight_mode { _3DoF = 0, _3DoF_with_delay = 1, _6DoF = 2, _6DoF_aerodynamic_stable = 3 };
enum EFree_flight_mode  { aerodynamic_stable = 0, _3DoF_defined = 1, ballistic_flight = 2 };
```

The Rust `StageConfig` still parses `power flight mode(int)` and `free flight mode(int)`
(`src/rocket.rs:292-296`) because the input schema was inherited wholesale — but **`power_flight_mode`
is never read by the Rust simulator**; the only mode branch is `free_flight_mode == 2`, the
ballistic-coefficient coast model (`src/simulator.rs:1177`). Likewise `SixDofConfig`
(`src/rocket.rs:459-464`) declares CG/CP/controller-position and moment-of-inertia file names that
nothing in `src/` consumes.

### The techdoc says 6-DOF and derives 3-DOF

`docs/OpenTsiolkovsky_techdoc.pdf` (with `.tex` source) — *OpenTsiolkovsky テクニカルドキュメント*,
by Takahiro Inagawa (稲川貴大) of Interstellar Technologies, in Japanese — is the project's only
derivation document, and it repeats the README's claim in the introduction: 「OpenTsiolkovskyでは
6自由度で計算しています」, *OpenTsiolkovsky computes with six degrees of freedom*.

**Its equations do not.** §運動方程式 derives translation only —

- `dr/dt = V_I` and `dV_I/dt = (1/m)(F_TI + F_AI + F_gI)`, integrated in ECI;
- 外力 (external forces) enumerated as exactly three: thrust `F_TB`, aerodynamic force `F_AA`,
  gravity `g_H` — forces, no moments;
- 座標変換行列 listing three DCMs (`BODY→ECI`, `AIR→BODY`, `NED→ECI`) whose job is to orient
  body-frame thrust and resolve angle of attack.

There is no rotational equation of motion, no moment, no inertia tensor and no quaternion anywhere
in its 332 lines; the single `\omega` is Earth's rotation rate in the ECI→ECEF transform. That is
the prescribed-attitude model the Rust engine implements, written down.

So the techdoc **corroborates the Rust tree and contradicts its own abstract** — useful, because it
is the document a skeptical reader reaches for after distrusting the README. Cite its §運動方程式
and §外力 for the model as implemented; do not cite its introduction. Nothing in the tree documents
the legacy C++ 6-DOF derivation.

**So: cite the pinned Rust tree as a 3-DOF solver with prescribed attitude, and the legacy C++ as the
6-DOF one — and do not describe the legacy tree as the live one.** The README describes the union of
both, and the techdoc's introduction inherits the same overstatement.

## Layout

```
src/                    Rust — the current engine
  main.rs      (270)    CLI
  lib.rs        (32)    crate root
  simulator.rs (1476)   integration loop, staging, events, forces
  rocket.rs    (1265)   config structs (serde), coefficient tables, wind
  physics.rs    (906)   atmosphere, WGS84 geodesy, coordinate transforms, gravity
  math.rs       (551)   vectors, DCMs, Dormand-Prince solver
  io.rs         (858)   JSON in, CSV/JSON out
  wasm.rs       (156)   browser bindings
  tests.rs       (25)
tests/                  Rust integration tests
examples/               param_sample_01.json, param_momo.json, SS-520-4/
frontend/               React + TypeScript + Vite, bun.lock
legacy_cpp/             original C++ (src/, boost/, test/, Makefile, Xcode project)
scripts/                wasm_build.sh, vercel-build.sh
docs/                   OpenTsiolkovsky_techdoc.{tex,pdf} — the derivations (see above);
                        quick-start, development, wasm, configuration
```

`vercel.json` at the root — the front end is deployed as a hosted web app.

## Domain Model (Rust)

### Integration

`IntegrationMode` (`src/simulator.rs:94-98`) offers two schemes, selectable from config:

- **`Rk4`** — fixed step, defaulting to half the output step, floor 1e-6 (`:187-198`).
- **`Rk45`** — `DormandPrince54` with tolerances `(1e-9, 1e-9)`, initial step 1e-6, max 10.0
  (`:184-186`).

Unlike ForRocket, the scheme *is* a config choice.

### Environment

- **Gravity**: `GravityModel` (`src/physics.rs:665-694`) implements **WGS84/EGM96 with the J2
  perturbation**, carrying the normalized coefficient `bar_c20 = -0.484165371736e-3` and returning an
  acceleration vector in ECI. This is a genuine oblateness model — the most capable Earth gravity in
  the survey alongside MAPLEAF's `WGS84` setting, and strictly better than ForRocket's scalar
  inverse-square.
- **Geodesy**: WGS84 ellipsoid with iterative ECEF→LLH conversion (`src/physics.rs:378-415`), full
  ECI/ECEF/NED transforms with Earth rotation.
- **Atmosphere**: `AtmosphereModel` (`src/physics.rs:9-69`), with
  `conditions_with_variation` (`:136`) applying a **±100% density variation ratio** — a first-class
  dispersion knob, driven either by a scalar percentage or an altitude-varying file.
- **Wind**: altitude-interpolated speed and direction from file (`rocket.wind_at_altitude`).

### Vehicle and forces

Per stage: initial mass; a **thrust model** with vacuum Isp and vacuum thrust (each constant or file,
each with a multiplier), throat diameter, nozzle expansion ratio and exhaust pressure — so thrust is
pressure-corrected for altitude rather than lumped; burn start/end and a forced cutoff time.

**Aerodynamics are tables or constants only**, as in ForRocket: `body diameter`, plus normal (`CN`)
and axial (`CA`) coefficients each constant-or-file with a multiplier, plus a ballistic coefficient.
`src/simulator.rs:1168-1195` shows the two branches — in free flight with `free_flight_mode == 2` the
force is `q/BC` along the airflow; otherwise `CA` and `CN` are looked up against **Mach × |angle|**,
with pitch and yaw normal forces resolved separately from α and β. **No geometry model.**

Attitude config carries constant elevation/azimuth, pitch/yaw/roll offsets, and **gyro biases in
deg/h** — an IMU-error model, again a launch-operations concern.

`dumping product` models a jettisoned mass (separation time, mass, its own ballistic coefficient, and
an added ΔV) — fairings and spent hardware tracked as separate falling objects.

### Staging

Up to **three stages** (`Stage1/2/3 Config File List` in ForRocket's sibling schema; here nested
`stage1`/`stage2`/`stage3` blocks with `following stage exist?` and `separation time[s]`).
`build_stage_runtime` (`src/simulator.rs:100-130`) accumulates **stack mass** from the top stage down,
so each stage's initial mass is the mass of everything above it — the standard launch-vehicle
convention. Events are time-scheduled, as in ForRocket.

## Input and output

One JSON file per vehicle (`examples/param_sample_01.json` is the reference), with serde field names
matching the original C++ strings verbatim, punctuation and all — `"air density variation
file exist?(bool)"`, `"time(UTC)[y,m,d,h,min,sec]"`. The schema is
**launch-vehicle shaped**: launch LLH and UTC datetime, per-stage thrust/aero/attitude/dumping blocks,
end time and output step.

Output is **CSV and JSON**. The front end consumes the same results through WASM for 3-D trajectory
and performance plots.

## Conventions

- Rust 2021, `nalgebra` for `Vector3`/`Matrix3`, `serde` for config with explicit
  `#[serde(rename = "...")]` on nearly every field — the rename strings are the public schema and must
  not be changed casually.
- Doc comments (`///`) on public items, with units in brackets.
- SI internally; degrees at the config boundary.
- The front end is Bun-managed (`bun.lock`, not `package-lock.json`).
- `legacy_cpp/` vendors its own Boost, so the C++ tree builds standalone.

## What is stale or absent

- **`power flight mode` and `SixDofConfig` are parsed and ignored** by the Rust engine, as above. The
  schema promises more than the current solver delivers.
- **The legacy C++ tree is reference only** — not built by CI, not the path the CLI or WASM uses.
- **No design or geometry model**, so no fin/nose-cone reasoning.
- **No hobby-rocketry conventions**: no `.ork`/`.rkt`/`.eng` import, no motor database, no rail-button
  or recovery-device modelling of the kind OpenRocket carries. Its parachute equivalent is the
  ballistic-coefficient coast.
- Dispersion exists only as the air-density variation ratio; there is **no Monte Carlo driver**.
