# Module Ideas and Existing Solutions

An index of the platform modules under consideration for the Free Rocket Tree, with the
intent and open questions for each, and links to the deep-dive surveys of existing
solutions in [`docs/research/`](research/).

## Platform modules

### Motor Inventory

Track motor data (certified specs, thrust curves) and a flyer's personal inventory
(motors on hand, burn status, storage).

- Research: [Rocket Motor Data Sources and Motor Inventory Management](research/motor-data-and-inventory.md)

### Parts / Components / Materials Manager

A canonical library of components (tubes, nose cones, fins, hardware) and materials
(with density and other physical properties) that design and simulation tools draw
from, plus per-user part inventory.

- Research: [Rocket Parts, Components, and Materials Data Management](research/parts-components-materials.md)

### Rocket Design / CAD

A design editor whose output feeds simulation directly.

- **Forked designs** — first-class sharing, forking, and versioning of designs.
- **Parametric / event-driven CAD** — designs defined by parameters and rebuilt on
  change, rather than hand-placed geometry.
- **As-built records** — capture the vehicle as actually constructed (measured mass,
  actual CG, finish) distinct from the nominal design.
- **Simulation-oriented** — no cosmetic bling; discourage the modeling hacks users
  employ to trick simulators into matching reality.
- Research: [Rocket Design and CAD Tooling](research/rocket-design-and-cad.md)

### Simulation Engine

A shared, validated flight-simulation core that other modules (design, flight log)
consume rather than each reimplementing.

- **Scientific priority** — don't pretend to account for things that are
  unproven or inaccurate (e.g. pods); report model validity limits instead of
  silently extrapolating.
- **Open question:** should we bother handling spin (e.g. canted fins)?
- Research: [Rocket Simulation Software: Models, Inputs, and Portability](research/rocket-open-simulation-designs.md)

### Flight Log

Record what actually flew and how it performed, linked back to the design.

- **Separate flight-sim configuration** — e.g. mass and CG overrides after the model
  is prepped for flight, so the as-flown record reflects the real vehicle rather than
  the nominal design.
- Research: [Flight Logging and As-Flown Data](research/flight-logging.md)

## Development practices

Topics for how the consortium itself works, rather than platform modules. No research
docs yet.

- Git workflow
- AI-driven development memory management
- Knowledge graph / context management
