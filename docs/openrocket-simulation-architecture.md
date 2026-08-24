# OpenRocket Simulation Architecture — Working Notes

> Temporary working document for discussion. Not part of the official docs.
> Focus: (1) what the simulation actually takes as input, (2) how it ticks through
> time-slices until completion. All paths are relative to
> `core/src/main/java/info/openrocket/core/`.

## 1. The object pipeline

```
Simulation (document/Simulation.java)          — what the user edits/runs
  └── SimulationOptions                        — mutable, GUI-facing parameters
        └── .toSimulationConditions()          — snapshot + model selection
              └── SimulationConditions         — immutable-ish bundle handed to the engine
                    └── BasicEventSimulationEngine.simulate(conditions)
                          └── SimulationStatus — the mutable per-tick state
                          └── FlightData / FlightDataBranch — recorded output
```

Two important things happen in `SimulationOptions.toSimulationConditions()`
(`simulation/SimulationOptions.java:565`):

1. Scalar parameters are copied over.
2. **The physics models are chosen — and currently hardcoded**: `BarrowmanCalculator`
   (aerodynamics), `MassCalculator` (mass properties), `WGSGravityModel` (gravity),
   plus the user-selected wind and atmosphere models. Swapping calculators is only
   possible by building `SimulationConditions` yourself.

At engine start the rocket's `FlightConfiguration` is **cloned**
(`BasicEventSimulationEngine.simulate()`), so the simulation never mutates the design.

## 2. Input parameters

### 2.1 Direct scalar parameters (`SimulationOptions` → `SimulationConditions`)

All SI units, angles in radians.

| Parameter | Default | Used for |
|---|---|---|
| `launchRodLength` | 1 m (pref) | Guided-flight phase: acceleration is projected onto the rod direction until the rocket travels this far |
| `launchRodAngle`, `launchRodDirection` | 0 (vertical), π/2 | Initial orientation / rod direction vector |
| `launchIntoWind` | true | GUI convenience: sets rod direction against average wind |
| `launchLatitude`, `launchLongitude`, `launchAltitude` | prefs | Launch site `WorldCoordinate`: gravity, Coriolis, atmosphere lookup by altitude |
| `geodeticComputation` | `SPHERICAL` | Strategy for world-coordinate updates and Coriolis acceleration |
| `useISA` / `launchTemperature`, `launchPressure` | ISA | Atmosphere model construction |
| wind model (`AVERAGE` pink-noise or multi-level) | pink noise | Sampled every tick → wind velocity vector |
| `timeStep` | **0.05 s** (`RK4SimulationStepper.RECOMMENDED_TIME_STEP`) | *Upper bound* on the RK4 step — see §4.2, the real step is adaptive |
| `maxSimulationTime` | **1200 s** | Hard cutoff; hitting it emits `SIMULATION_END` |
| `maximumAngle` | 3° (`RECOMMENDED_ANGLE_STEP`) | Adaptive-step limit: max pitch rotation allowed per step |
| `randomSeed` | random | Seeds turbulence (pink-noise wind) and small aero coefficient jitter (`PITCH_YAW_RANDOM = ±0.0005`) |

### 2.2 The "rocket" composite, decomposed

The engine does **not** consume the component tree directly. Each tick, the physics
reduces the tree to a handful of aggregate quantities (`RK4SimulationStepper.computeAcceleration()`,
`RK4SimulationStepper.java:332`):

**Notation used in the formulas below:**

| Symbol | Meaning |
|---|---|
| *q* | **Dynamic pressure**, q = ½ρv² [N/m²] — ρ is air density, v is airspeed (velocity relative to wind). Converts every dimensionless aero coefficient into a real force (C·q·A_ref) or moment (C·q·A_ref·L_ref). Computed each evaluation at `RK4SimulationStepper.java:351` |
| *L_ref* | Reference length [m] — the reference diameter of the design. By default the nose cone base diameter (`ReferenceType.NOSECONE`); can be the maximum body diameter or a custom value |
| *A_ref* | Reference area [m²] — always π·(L_ref/2)², the circular area of the reference diameter (`FlightConditions.java:106`) |

**Mass side — `MassCalculator` → `RigidBody` (masscalc/).** Total = structure +
**time-varying motor mass** (propellant burns off). Note: **both** parts are fully
recomputed from the component tree on *every* evaluation (4× per RK4 step) — there
is no caching, although vestigial cache fields sit commented-out in
`MassCalculator.java:23`. Structure mass only actually changes at stage separation:

| Quantity | Accessor | Units | Role in the physics |
|---|---|---|---|
| Total mass *m* | `RigidBody.getMass()` | kg | Divides all forces: linear acceleration = F/m; abort if ≈ 0 |
| CG position | `RigidBody.getCM()` | `Coordinate` [m], rocket coords | A **3-D point**, not a distance: x is axial (aft from the nose tip), y/z radial, and `MassCalculation` really does compose y/z through each component's instance offsets and transforms. The steppers consume only `.x` — moment arm for shifting the aero moments to the CG, and the CG-vs-CP stability check (see the axisymmetry note below) |
| Longitudinal moment of inertia | `RigidBody.getLongitudinalInertia()` | kg·m² | Divides **both** the pitch and the yaw moment → angular acceleration. `RigidBody` holds a diagonal `(Ixx, Iyy, Izz)` only, and every construction site passes the same `It` for Iyy and Izz, so `Izz` is never independently used |
| Rotational (roll) moment of inertia | `RigidBody.getRotationalInertia()` | kg·m² | Divides the roll moment → roll acceleration |

**Aerodynamics side — `BarrowmanCalculator.getAerodynamicForces(config, flightConditions)`
→ `AerodynamicForces` (aerodynamics/).** Recomputed from component geometry every
evaluation as a function of the current `FlightConditions`:

| Quantity | Accessor | Units | Role in the physics |
|---|---|---|---|
| CP location | `AerodynamicForces.getCP()` | `Coordinate` [m], rocket coords | Also a 3-D point of which only `.x` is consumed; its `weight` field carries the CN used for the CP-averaging and ≈ 0 aborts the sim ("no CP"). With CG: stability margin, stall/tumble decision |
| Normal force coefficient | `getCN()` | – | Lateral force f_N = CN·q·A_ref (pitch plane) |
| Side force coefficient | `getCside()` | – | Lateral force f_side = Cside·q·A_ref (yaw plane) |
| Axial drag coefficient | `getCDaxial()` | – | Drag force = CDaxial·q·A_ref, opposing thrust along the body axis |
| Pitch moment coefficient | `getCm()` | – | Pitch moment = Cm·q·A_ref·L_ref (after shift to CG) |
| Yaw moment coefficient | `getCyaw()` | – | Yaw moment = Cyaw·q·A_ref·L_ref (after shift to CG) |
| Roll moment coefficient | `getCroll()` | – | Roll moment = Croll·q·A_ref·L_ref (fin cant, roll damping) |

**Axisymmetry assumption.** Four of the quantities above are richer than the
physics consumes, all in the same direction — the ascent stepper treats the rocket
as a body of revolution:

- CG and CP are `Coordinate`s but only `.x` is read (`RK4SimulationStepper.java:399,400,452`).
- The inertia tensor is diagonal, with pitch = yaw by construction; no products of inertia exist.
- Off-centerline motor thrust produces no torque (`TODO: HIGH`, `RK4SimulationStepper.java:295`).

A radially offset CG, an asymmetric mass distribution, and a one-engine-out
cluster are therefore all invisible to the ascent physics, even though the mass
calculator computes the offsets that would express them.

**`FlightConditions` (aerodynamics/FlightConditions.java) — recomputed each tick
from state + environment; the input to the Barrowman calculation:**

| Quantity | Accessor | Units | Role in the physics |
|---|---|---|---|
| Angle of attack | `getAOA()` | rad | Primary input to CN, CP shift; large-AOA warning / stall detection |
| Airspeed | `getVelocity()` | m/s | Dynamic pressure q = ½ρv² (velocity relative to wind) |
| Mach number | `getMach()` | – | Compressibility corrections to the coefficients |
| Roll rate | `getRollRate()` | rad/s | Roll damping; also limits the adaptive time step |
| Reference area | `getRefArea()` | m² | Scales all coefficient → force conversions |
| Reference length | `getRefLength()` | m | Scales all coefficient → moment conversions |
| Air density ρ | `getAtmosphericConditions().getDensity()` | kg/m³ | Dynamic pressure |
| Speed of sound | `getAtmosphericConditions().getMachSpeed()` | m/s | Mach number |

**Thrust and environment — sampled every evaluation:**

| Quantity | Source | Units | Role in the physics |
|---|---|---|---|
| Thrust *T* | Σ `MotorClusterState.getThrust(t)`, interpolated from `ThrustCurveMotor` points | N | Axial force: forceZ = T − drag. Off-center motor moments are currently ignored (TODO, `RK4SimulationStepper.java:295`) |
| Gravity g(alt) | `WGSGravityModel` | m/s² | Subtracted from vertical acceleration (world frame) |
| Coriolis acceleration | `GeodeticComputationStrategy.getCoriolisAcceleration()` | m/s² | Added to linear acceleration (world frame) |
| Wind velocity | wind model sample (pink-noise turbulence, seeded) | m/s | Combined with rocket velocity → airspeed and AOA |

**Configuration & event-driving data (not physics, but inputs):**
- `FlightConfiguration`: which stages are active, which motors are mounted where
- per-stage `StageSeparationConfiguration` (when to separate, delay)
- per-recovery-device `DeploymentConfiguration` (activation event, delay, altitude)
- motor ignition specs (ignition event + delay, ejection-charge delay)

**Extension hooks:**
- `SimulationConditions.getSimulationListenerList()` — listeners are cloned in and
  can *override* nearly every quantity above (see §5).

### 2.3 What comes from the model vs. what the sim computes

The `.ork` design stores **geometry, materials, and configuration choices — never
physics results**. None of the quantities in the §2.2 tables (mass, CG, CP,
coefficients, inertia) are stored in the model; all are derived at runtime.

**Model-supplied inputs (stored in the design / flight configuration):**

| Category | Values from the model | Where it lives |
|---|---|---|
| Component geometry | Lengths, diameters, wall thicknesses, nose/transition shape parameters, fin planform + count + cant angle, component positions in the tree | each `RocketComponent` subclass |
| Materials | Material choice per component → density (bulk/surface/line) | `Material` on each component |
| Surface finish | Roughness height per external component (rough … polished, 500 µm–2 µm) — feeds friction drag | `ExternalComponent.Finish` |
| Manual overrides | Per-component **mass**, **CG**, and **CD** overrides (optionally cascading to subcomponents) — these *replace* calculated values | `RocketComponent.getOverrideMass()/CG()/CD()` |
| Reference convention | `ReferenceType` (nose cone / maximum / custom) → L_ref, A_ref | `Rocket` |
| Motor selection | Which motor in which mount; the motor's **thrust-curve sample points**, propellant/total mass over burn, and motor CG (from the motor database, referenced by the design) | `MotorConfiguration` / `ThrustCurveMotor` |
| Motor sequencing | Ignition event + ignition delay, ejection-charge delay | `MotorConfiguration` |
| Stage separation | Separation event + delay per stage | `StageSeparationConfiguration` |
| Recovery | Parachute/streamer size and **CD (auto-computed from size, or manually set)**, packed dimensions, deployment event + delay + altitude | `RecoveryDevice`, `DeploymentConfiguration` |
| Stage/motor activeness | Which stages and motors participate in this flight configuration | `FlightConfiguration` |

**Computed by the sim (never stored in the model):**

| Derived quantity | Computed from | When |
|---|---|---|
| Component & total mass, CG, moments of inertia | geometry × material density (unless overridden) | every evaluation (motor part varies with burn) |
| CP and all aero coefficients (CN, CDaxial, Cm, …) | geometry + finish + current AOA/Mach/roll rate | every evaluation |
| Thrust T(t) | interpolation of the stored thrust-curve points | every evaluation |
| Dynamic pressure, AOA, Mach, airspeed | evolving state + atmosphere/wind models | every evaluation |
| Position, velocity, orientation, spin | integration (§4) | continuously |

Rule of thumb: **the model stores what you could measure with calipers and a scale
plus your choices** (motors, events, delays, overrides); everything with physics
in it is recomputed each tick. The manual overrides and the recovery-device CD are
the only places where a number that *would* be calculated can instead be injected
directly from the model.

### 2.4 Parameter cadence: what is static between events

The 6-DOF equations of motion consume a fixed set of quantities (see §2.2):
m, CG, I_long, I_rot, T, the six aero coefficients, q (= ½ρv²), A_ref, L_ref, g,
Coriolis, and — during the guided phase — the rod direction vector. Classified by
*when they can actually change*:

**Run-constant (fixed when `SimulationConditions` is built):**

| Parameter | Notes |
|---|---|
| Launch site (lat/lon/alt), geodetic strategy | Feed gravity/Coriolis formulas; the formulas' *parameters* never change |
| Launch rod length, direction vector | Rod direction computed once in `RK4SimulationStepper.initialize()` |
| Gravity / atmosphere / wind **model choice + parameters** | The models are fixed; only their *outputs* vary with altitude/time |
| Integrator limits: `timeStep`, `maximumAngleStep`, `maxSimulationTime` | Ceiling/limits only |
| Random seed | Fixes the turbulence and jitter sequences |

**Event-static (piecewise constant; changes only when a flight event fires):**

| Parameter | Valid until | Invalidating events |
|---|---|---|
| Active stage set (`FlightConfiguration`) | separation | `STAGE_SEPARATION` |
| Structure mass, structure CG, structure inertia | separation | `STAGE_SEPARATION` (jettisons components) |
| Aero geometry → per-component calc objects (`calcMap`), and the coefficient *functions* they define | separation | `STAGE_SEPARATION` (aero/tree ModID bump) |
| A_ref, L_ref | separation | `STAGE_SEPARATION` (cached per configuration, `FlightConfiguration.java:534`) |
| Set of burning motors | ignition/burnout | `IGNITION`, `BURNOUT` (between them, thrust *value* varies continuously) |
| Spent-motor mass | burnout | `BURNOUT` (constant after burn ends) |
| Deployed recovery devices (parachute CD·A) | deployment | `RECOVERY_DEVICE_DEPLOYMENT` |
| Guided-flight constraint (acceleration projected onto rod) | rod clearance | `LIFTOFF` / `LAUNCHROD` |
| **The equations themselves** (which stepper integrates) | state change | `RECOVERY_DEVICE_DEPLOYMENT` → landing, `TUMBLE` → tumble, `GROUND_HIT` → ground |

**Per-tick (genuinely continuous — the real state and flow variables):**

| Parameter | Driven by |
|---|---|
| Position, velocity, orientation quaternion, angular velocity | the integration itself |
| Thrust T(t) | thrust-curve interpolation while any motor burns |
| Motor mass + motor CG | propellant consumption during burn |
| ρ, speed of sound | altitude (atmosphere model) |
| g, Coriolis | world position / velocity (weakly varying) |
| Wind velocity | stochastic pink-noise sample each tick |
| AOA, Mach, airspeed, roll rate → all six coefficient *values*, q | state + wind |

**Implementation vs. logic:** the middle table is the interesting one — those values
are *logically* event-static, but the code treats them differently: the aero side
honors this (calcMap and A_ref/L_ref are cached and invalidated by ModID/event),
while the mass side does not (structure mass is recomputed every evaluation despite
being event-static — see §2.2 note). Event-static parameters are exactly the ones
a cache keyed on flight events could hold.

## 3. Engine outer loop: branches

`BasicEventSimulationEngine.simulate()` keeps a `Deque<SimulationStatus> toSimulate`.
It starts with one branch (the sustainer). When a `STAGE_SEPARATION` event fires,
the current `SimulationStatus` is cloned into a **booster branch** and pushed onto
the deque; the loop pops and simulates each branch to completion, each producing its
own `FlightDataBranch`. So "one simulation" = one flight per separated body.

Sanity checks before the first tick: no active stages / no motors → abort;
no recovery device → warning only.

## 4. The tick loop (`simulateLoop`, `BasicEventSimulationEngine.java:149`)

### 4.1 Stepper selection

The engine holds four steppers and swaps `currentStepper` on state changes:

| State | Stepper | Physics |
|---|---|---|
| default flight | `RK4SimulationStepper` | full 6-DOF RK4 integration |
| recovery device deployed | `BasicLandingStepper` | 3-DOF drag descent |
| tumbling (unstable, no thrust) | `BasicTumbleStepper` | tumble drag model |
| landed | `GroundStepper` | inert |

### 4.2 One iteration

```
while (handleEvents()):                  # returns false => branch done
    firePreStep(listeners)               # listener may skip the step
    maxStepTime = time until next queued event   (never past an event)
    currentStepper.step(status, maxStepTime)
    firePostStep(listeners)
    checkNaN()
    # then, from the new state, enqueue detected events:
    ALTITUDE (every step), LIFTOFF (z > 2 cm), LAUNCHROD (rod cleared),
    APOGEE (z fell below maxAlt), GROUND_HIT (z <= 0 after liftoff),
    TUMBLE (stall margin < 0 and CG aft of CP),
    SIMULATION_END (landed and event queue empty)
```

**Inside `RK4SimulationStepper.step()`** the *actual* dt is adaptive — the minimum of
(`RK4SimulationStepper.java:124`):

1. user `timeStep` (÷5 while on the launch rod)
2. `maxStepTime` (distance to the next scheduled event)
3. `maximumAngleStep` / current pitch rate
4. max roll step angle / roll rate
5. max roll-rate change / roll acceleration
6. max pitch-yaw change / pitch-yaw acceleration
7. rod length / (10·v) while on the rod
8. 1.5 × previous step (ramp-up limiter)

with a floor of `timeStep/20` (and an absolute `MIN_TIME_STEP = 0.001 s`). Then a
standard RK4: k1–k4 evaluations of `computeAcceleration()` (each one is a full
mass + aero + thrust + gravity + Coriolis evaluation), state update, and
`storeData()` appends one row to the `FlightDataBranch`.

So: the user-visible "time step" is a *ceiling*; near events, on the rod, or during
fast rotation the engine takes smaller slices. Motor thrust-curve sample points are
even queued as events at ignition specifically to force RK4 steps to land on them.

### 4.3 Event handling (`handleEvents`)

Events live in a time-ordered `EventQueue` on `SimulationStatus`. Every iteration,
all events with `time <= now` are drained; each event is also offered to motor
ignition / stage separation / recovery deployment configs, which may enqueue
*derived* events:

- `LAUNCH` → (via ignition configs) `IGNITION`
- `IGNITION` → thrust-curve sample points + `BURNOUT` at burn end
- `BURNOUT` → `EJECTION_CHARGE` after the motor's delay; burnout before liftoff aborts
- `EJECTION_CHARGE` → (via deployment configs) `RECOVERY_DEVICE_DEPLOYMENT`
- `STAGE_SEPARATION` → new booster branch pushed (see §3)
- `RECOVERY_DEVICE_DEPLOYMENT` → switch to landing stepper; abort if still under thrust
- `GROUND_HIT` → one final step to record impact values, switch to ground stepper
- `TUMBLE` → switch to tumble stepper (abort if under thrust)
- `SIM_ABORT`, `SIMULATION_END` → return false, ending the branch loop

Quirk: if no motor has ignited yet, `nextEvent()` *jumps* simulation time forward
to the next event instead of integrating — nothing physical happens before first
ignition.

### 4.4 Termination

A branch ends when any of these occurs:

- `SIMULATION_END` (landed + empty queue — the normal case)
- `SIM_ABORT` (no CP, zero mass, zero length, deploy/tumble under thrust, no ignition…)
- `maxSimulationTime` exceeded
- `SimulationException` (e.g. NaN state) — propagates, ends the whole run

The whole run ends when the branch deque is empty; `FlightData.calculateInterestingValues()`
then computes summary numbers (apogee, max velocity, flight time, …).

## 5. Hook points (listeners)

All hooks receive the mutable `SimulationStatus` and may modify it. Dispatched via
`SimulationListenerHelper`; the reference for exact semantics is
`simulation/listeners/AbstractSimulationListener.java`. The ones in the tick path:

| Hook | Can it override? |
|---|---|
| `startSimulation` / `endSimulation` | — |
| `preStep` | return false → skip the step |
| `postStep` | mutate state after the step |
| `handleFlightEvent` | return false → swallow the event |
| `preThrustCalculation` / `postThrustCalculation` | replace thrust value |
| `preAerodynamicCalculation` / `postAerodynamicCalculation` | replace `AerodynamicForces` |
| `preMassCalculation` / `postMassCalculation` | replace `RigidBody` mass data |
| `preAccelerationCalculation` / `postAccelerationCalculation` | replace the whole `AccelerationData` |
| `motorIgnition`, `recoveryDeviceDeployment` | return false → suppress |

This is how air-start, roll control, etc. are implemented without touching the engine.

## 6. Key files

| File | Role |
|---|---|
| `simulation/SimulationOptions.java` | user-facing parameters + `toSimulationConditions()` |
| `simulation/SimulationConditions.java` | the parameter/model bundle the engine consumes |
| `simulation/BasicEventSimulationEngine.java` | branch loop, tick loop, event handling |
| `simulation/SimulationStatus.java` | per-tick mutable state (position, velocity, quaternion, event queue…) |
| `simulation/AbstractSimulationStepper.java` | shared model evaluation + `DataStore` of per-tick intermediates |
| `simulation/RK4SimulationStepper.java` | 6-DOF RK4 + adaptive dt selection |
| `simulation/FlightEvent.java`, `EventQueue` | event types and ordering |
| `aerodynamics/BarrowmanCalculator.java` | CP + force/moment coefficients |
| `masscalc/MassCalculator.java` | mass / CG / inertia (`RigidBody`) |
| `simulation/FlightData*.java` | recorded output |
