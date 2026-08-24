# A Simulation Core for OpenRocket — Exploratory Proposal

> **Speculative design notes — this does NOT describe the current codebase.**
> Companion to `openrocket-simulation-architecture.md`, which documents what
> exists today. Reference convention: **`arch §N`** points into that document;
> a bare **`§N`** points at a section of *this* one.
>
> Thought experiment: extract a *simulation core* that never sees a
> `RocketComponent`. Everything the core consumes is pre-reduced by a
> "characterization" layer that compiles the component tree down to numbers,
> curves, and functions. This document identifies that input set and classifies
> it into logical groups.

## 1. Three kinds of input — the central observation

Not everything can be a scalar. The core's inputs fall into three kinds:

1. **Scalars** — plain run-constant numbers (rod length, launch latitude, time-step
   ceiling).
2. **Functional inputs** — quantities that depend on flight state or time and must
   be supplied as *functions/curves*, not values: the aerodynamic coefficients
   depend on the current flight condition (angle of attack, Mach number, roll
   rate — see §4); motor mass depends on burn time; air density depends on
   altitude. The current `AerodynamicCalculator` / `MassCalculator` / atmosphere /
   wind / gravity objects **are already exactly these functions** — the extraction
   problem is not inventing the interfaces but severing their implementations'
   dependence on the component tree (via precomputation, tabulation, or a
   tree-backed adapter kept outside the core).
3. **The phase table** — per arch §2.4, most "rocket parameters" are only piecewise
   constant: they switch when a flight event fires (separation, burnout,
   deployment). So the core's rocket input is not one bundle but an event-keyed
   *sequence* of bundles.

The descent steppers prove the concept already: tumbling flight reduces the whole
rocket to a single tumble drag coefficient computed from the fin and body
silhouette areas (`BasicTumbleStepper.computeCD()`), and descent under canopy
reduces it to the total drag area — drag coefficient × area, summed over the
deployed parachutes/streamers (`BasicLandingStepper.computeCD()`). The full
six-degrees-of-freedom ascent phase just needs the same treatment with a richer
bundle.

## 2. Launch site & environment (run-constant models)

| Parameter | Kind | Notes |
|---|---|---|
| Latitude, longitude, altitude | scalar | Launch-site location; feeds the gravity strength, the Coriolis effect (the apparent sideways acceleration caused by Earth's rotation), and the atmosphere lookup |
| Geodetic strategy | choice | How Earth's shape and rotation are modeled when converting flight positions to world coordinates: flat ground / spherical Earth / WGS84 (the standard ellipsoidal Earth model used by GPS) |
| Gravity model | function: position → gravitational acceleration | Today `WGSGravityModel`, already tree-independent |
| Atmosphere model | function: altitude → (air density, speed of sound) | International Standard Atmosphere by default, or built from a launch-site surface temperature/pressure override; already tree-independent |
| Wind model | function: (altitude, time) → wind velocity vector | Includes turbulence intensity; stochastic, consumes the seed |
| Random seed | scalar | Fixes turbulence + aero jitter sequences |

## 3. Launch / initial conditions

| Parameter | Kind | Notes |
|---|---|---|
| Launch rod length | scalar | Guided-phase distance |
| Launch rod angle + direction | scalars → direction vector | Also the initial orientation |
| Initial position, initial velocity | vectors | Already in `SimulationConditions` (`launchPosition`/`launchVelocity`) — this is the air-start hook |

## 4. Aerodynamic characterization (per phase — see §8 below)

The irreducible aerodynamic input is a **response function**, not a set of
numbers. Given the current *flight condition* — how the rocket is moving through
the air right now — it returns a set of dimensionless coefficients that describe
how the airflow pushes and twists the rocket. The flight condition consists of:

- **Angle of attack** — the angle between where the rocket is *pointing* and
  where it is actually *moving* through the air. Zero for a perfectly stable
  rocket flying straight; nonzero whenever wind or wobble tilts the flight path.
- **Mach number** — airspeed divided by the local speed of sound. Captures
  compressibility: the coefficients change substantially approaching and passing
  the speed of sound.
- **Roll rate** — how fast the rocket is spinning about its long axis (affects
  roll damping).
- (Optionally **Reynolds number** — a measure combining airspeed, rocket size,
  and air viscosity that governs skin-friction drag.)

Equivalently: today's `AerodynamicCalculator` contract minus the
`FlightConfiguration` argument.

Each coefficient is dimensionless; the core turns it into a real force or torque
by multiplying with the **dynamic pressure** *q* = ½ · air density · airspeed²
and the reference area (forces) or additionally the reference length (torques):

| Parameter | Code name | Kind | Meaning |
|---|---|---|---|
| Reference area / reference length | `refArea` (A_ref), `refLength` (L_ref) | scalars | Arbitrary-but-fixed scaling quantities that make the coefficients dimensionless: the reference length is the rocket's reference diameter, and the reference area is the circular area of that diameter. Every force is coefficient · q · A_ref; every torque additionally × L_ref |
| Normal force coefficient | `CN` | function of flight condition | The lift-like sideways force in the *pitch* plane, produced when the rocket flies at an angle of attack — mostly generated by the fins and nose |
| Side force coefficient | `Cside` | function of flight condition | The same sideways force, but in the *yaw* plane (left/right) |
| Axial drag coefficient | `CDaxial` | function of flight condition | Air resistance along the body axis, opposing thrust — the coefficient behind "how draggy is this rocket" |
| Pitch moment coefficient | `Cm` | function of flight condition | The torque tending to rotate the nose up or down; includes the damping that resists pitch rotation |
| Yaw moment coefficient | `Cyaw` | function of flight condition | The torque tending to rotate the nose left or right |
| Roll moment coefficient | `Croll` | function of flight condition | The torque spinning the rocket about its long axis — produced by canted fins, resisted by roll damping |
| Center of pressure location | `CP` | function of flight condition | The point along the body where the net aerodynamic side force effectively acts. Its distance *behind* the center of gravity is the **stability margin**: positive = self-correcting flight, negative = the rocket tumbles |

Supply options: (a) a callable model object (what exists today, tree-backed);
(b) precomputed lookup tables over an (angle-of-attack × Mach-number) grid — the
classic "aero deck"[^aero-deck] used by other six-degrees-of-freedom flight
simulators; (c) closed-form fits. The core should define only the interface and
not care.

[^aero-deck]: An "aero deck" (aerodynamic deck) precomputes the coefficients
    once over a grid of flight conditions — every combination of angle of attack
    and Mach number — and the simulator just interpolates at runtime. The name
    is a fossil from when such tables were delivered as decks of punched cards.
    It is the standard input form for missile/aerospace 6-DOF simulators, and
    would let the core accept aerodynamic data from CFD, wind-tunnel tests, or
    other programs instead of only the Barrowman method.

## 5. Mass characterization (per phase)

| Parameter | Code name | Kind | Meaning |
|---|---|---|---|
| Structure mass | `RigidBody.getMass()` (minus motors) | scalar **per phase** | Dry mass of everything except the motors; divides all forces to give linear acceleration. Constant between stage separations (arch §2.4) — the core never needs the tree, just one rigid-body bundle per phase |
| Center of gravity | `RigidBody.getCM()` (CG) | vector per phase | The balance point. Torques act about it, and its axial position relative to the center of pressure (§4) sets the stability margin. **Not a scalar:** it is a full `Coordinate` — x is axial (measured aft from the nose tip), y/z are radial — and the radial components are really computed, since `MassCalculation` composes each component's CM through its 3-D instance offsets and transforms, so pods, asymmetric masses, and off-axis instances shift the balance point sideways. Today's steppers read only `getCM().x` (§10a), so the core interface should carry the vector even if the first implementation ignores y/z |
| Longitudinal moment of inertia | `RigidBody.getLongitudinalInertia()` | scalar per phase | Resistance to rotation in pitch and yaw (nose swinging up/down or left/right); divides those torques to give angular acceleration |
| Roll moment of inertia | `RigidBody.getRotationalInertia()` | scalar per phase | Resistance to spinning about the long axis; divides the roll torque |
| Motor mass + center-of-gravity contribution | — | function of burn time, per motor instance | Propellant burns off, so the motors' mass and balance point shift continuously during the burn. Combined with the structure values via standard rigid-body composition (parallel-axis rules); needs each motor's mounting position |

## 6. Propulsion (per motor instance)

| Parameter | Kind | Notes |
|---|---|---|
| Thrust curve | sampled curve: time since ignition → thrust force (N) | The motor's measured force output over its burn; the simulation interpolates between the sample points, and the sample times also become forced integration nodes |
| Burn duration | scalar | Time from ignition until the propellant is exhausted; defines the `BURNOUT` event |
| Mount position (offset from the rocket's centerline) | vector | Where the motor sits — needed to compute the off-center torque a clustered motor produces. Currently unused for torques (TODO in `RK4SimulationStepper`), but belongs in the core interface |
| Ignition trigger + delay | event spec | What causes this motor to light (launch button, burnout of a lower stage, …) plus a delay; see §8 below |
| Ejection-charge delay | scalar | Motors carry a small pyrotechnic charge that fires a set time *after* burnout, typically to deploy the recovery system; this is that time. Schedules the `EJECTION_CHARGE` event |

## 7. Recovery & descent (per device / per descent mode)

| Parameter | Kind | Notes |
|---|---|---|
| Drag area per recovery device | scalar | Drag coefficient × canopy area (units m²) — the single number that captures a parachute or streamer's braking effect, and the *only* thing the landing stepper needs |
| Deployment trigger (event, delay, altitude) | event spec | See §8 below |
| Tumble drag area | scalar per phase | Same drag-coefficient-×-area idea for an unstable, end-over-end tumbling rocket; derived once from the fin and body silhouette areas |

## 8. Phase & event structure (the "rocket" as the core sees it)

The component tree's real role in the core is replaced by a **phase graph**:

- An ordered set of **phases** (initial stack, post-separation sustainer, each
  booster branch), each referencing one aero package (§4), one structure mass
  bundle (§5), its set of motor instances (§6), and its recovery devices (§7).
- **Transition rules** = today's config-driven event specs: ignition events +
  delays, separation events + delays (which also *spawn a new branch* with its own
  phase bundles), deployment events + delays + altitudes.
- Everything else (`LIFTOFF`, `APOGEE`, `GROUND_HIT`, `TUMBLE`, …) is *detected* by
  the core from state, not supplied.

This is exactly the event-static column of arch §2.4 turned into an explicit input
data structure instead of being re-derived from the tree at each event.

## 9. Integration & control

| Parameter | Kind | Notes |
|---|---|---|
| Time-step ceiling | scalar | Real dt is adaptive (arch §4.2) |
| Maximum angle step | scalar | Adaptive-dt limit |
| Max simulation time | scalar | Hard cutoff |
| Listeners | hooks | Extension mechanism; arguably part of the core's API rather than a parameter |

## 10a. Axisymmetry assumptions inherited from today's steppers

Several of the quantities above are vectors or tensors in principle, but the
current implementation collapses them on an implicit assumption that the rocket
is a body of revolution. A core extraction is the moment to decide whether to
carry the assumption forward or design it out:

| Quantity | Reduced to | Where |
|---|---|---|
| Center of gravity | axial component only, `getCM().x` | `RK4SimulationStepper` moment shift and stability test; `AbstractSimulationStepper` CG logging |
| Center of pressure | axial component only, `getCP().x` | same moment shift |
| Inertia tensor | diagonal `(Ixx, Iyy, Izz)`, with pitch and yaw further forced equal by the two-argument `RigidBody` constructor | `RigidBody` ("implements a simplified, diagonal MOI") |
| Off-centerline motor thrust | no torque at all | `RK4SimulationStepper` — explicit `TODO: HIGH` |

Consequence: a radially offset CG, a genuinely asymmetric mass distribution, and
a clustered motor with one engine out are all invisible to the present ascent
physics. The characterization layer already produces the richer quantities; only
the stepper discards them.

## 10. What deliberately does *not* cross the boundary

Component geometry, materials, finishes, overrides, motor database records,
`FlightConfiguration` — all consumed by the characterization layer to *produce*
§§4–8. The model↔sim rule of arch §2.3 becomes an architectural boundary: calipers
and choices stay outside; only physics-ready quantities enter the core.

