# OpenRocket (vendored submodule)

A primer on the OpenRocket source vendored at `subs/openrocket` — build, module layout, domain
model, and conventions. That tree is read-only here; see `subs/CLAUDE.md`.

## Project Overview

OpenRocket is a Java (Swing) model-rocket design and flight-simulation desktop application. Requires **JDK 17** (the build targets Java 17 via JPMS modules). Licensed GPLv3.

After cloning, initialize the component-database submodule or resource loading will be incomplete:

```bash
git submodule init && git submodule update
```

## Documentation

OpenRocket began as a Master's thesis, and the derivations behind the models ship in the tree rather
than living only on the web:

- **`doc/thesis.pdf`** — Niskanen, S., *Development of an Open Source model rocket simulation
  software*, M.Sc. thesis, Helsinki University of Technology, Espoo, 20.5.2009. The original
  motivating work — the software was written as this thesis project. Licensed CC BY-NC-ND.
- **`doc/techdoc/`** — *OpenRocket technical documentation*: `techdoc.pdf` plus the `.tex` sources it
  builds from. The thesis text extended and updated for later releases (last revision 2013-05-10,
  for OpenRocket 13.05) and relicensed CC BY-SA. **This is the citation target for the models as
  implemented**; reach for `thesis.pdf` only when you specifically want the 2009 original. Chapters
  track the code: `chapter-aerodynamic-properties.tex` derives the extended Barrowman normal-force,
  roll and drag models in `aerodynamics/barrowman` (including the tumbling-body drag the tumble
  stepper needs), and `chapter-flight-simulation.tex` covers the atmosphere/wind models under
  `models`, the mass and moment-of-inertia calculations in `masscalc`, and the quaternion-based RK4
  integration and event handling in `simulation`.
- Both PDFs are also published at <https://openrocket.info/documentation.html>.
- **`doc/design/`** — UMLet diagrams (simulation sequence, optimization classes);
  `doc/properties.txt` documents the `openrocket.*` system properties.
- **`docs/`** — Sphinx source for the *user* guide at <https://openrocket.readthedocs.io/>. Despite
  the near-identical name, unrelated to `doc/`: end-user material, no derivations.

## Common Commands

```bash
./gradlew run                  # Build and launch the application
./gradlew build                # Compile, run tests, build core+swing JARs
./gradlew test                 # Run all tests
./gradlew core:test            # Tests for one module (core or swing)
./gradlew core:test --tests "info.openrocket.core.util.MathUtilTest"   # Single test class
./gradlew check                # Tests + Checkstyle + JaCoCo coverage verification
./gradlew checkstyleMain checkstyleTest   # Checkstyle only (config/checkstyle/checkstyle.xml)
./gradlew dist                 # Fat JAR at build/libs/OpenRocket-<version>.jar (runs check first)
```

Checkstyle is configured with `ignoreFailures = false` and `maxWarnings = 0`, so style violations fail the build. Tests use JUnit 5 (Jupiter) with Mockito.

The build version comes from `core/src/main/resources/build.properties`.

## Architecture

Gradle multi-project build with two JPMS modules (see `settings.gradle`):

- **`core/`** (`info.openrocket.core`) — headless domain layer: rocket design model, simulation engine, aerodynamics, file formats. Reusable without the GUI.
- **`swing/`** (`info.openrocket.swing`) — the Swing GUI, depends on core. Main class: `info.openrocket.swing.startup.OpenRocket`.

Each module declares its exports in `src/main/java/module-info.java` — adding a package or dependency usually means editing it. Non-modularized third-party JARs get synthetic module info via the `extra-java-module-info` plugin in each module's `build.gradle`. Service providers in swing (e.g. `RocketComponentShapeService`) must be registered in **both** `module-info.java` and `swing/src/main/resources/META-INF/services` (gradle-modules-plugin limitation).

### Domain model (`core/src/main/java/info/openrocket/core/`)

- A rocket design is a tree of `RocketComponent` subclasses (`rocketcomponent` package) rooted at `Rocket` — `BodyTube`, `NoseCone`, `FinSet` variants, `AxialStage`, `PodSet`, etc. Mass/CG calculations live on the components themselves; cross-cutting behavior via interfaces like `MotorMount`, `Instanceable`, `FlightConfigurableComponent`.
- Per-flight-configuration state (motors, deployment, stage separation) lives in `FlightConfiguration` / `FlightConfigurationId`, not on the components directly.
- `document/OpenRocketDocument` wraps a `Rocket` plus its `Simulation`s and attachments, and implements snapshot-based undo (`addUndoPosition(...)`, 50 levels).
- **Change events drive cache invalidation:** components fire `ComponentChangeEvent` with bit-flag types (`MASS_CHANGE`, `AERODYNAMIC_CHANGE`, `TREE_CHANGE`, ...), and consumers cache against monotonic `ModID`s (`Rocket.getModID()`, `getMassModID()`, ...). A new mutator that doesn't fire the right event type leaves stale aerodynamic/mass results behind. `Rocket.freeze()/thaw()` batches events.

### Simulation

- `BasicEventSimulationEngine` runs a flight: mutable state in `SimulationStatus`, immutable setup in `SimulationConditions`, results in `FlightData`/`FlightDataBranch`. The engine swaps `SimulationStepper`s (`RK4SimulationStepper` for powered/coast flight, landing/tumble/ground steppers) in response to `FlightEvent`s.
- Physics inputs: `aerodynamics/BarrowmanCalculator` (per-component calcs in `aerodynamics/barrowman`) and `masscalc/MassCalculator`; environment models under `models` (atmosphere/gravity/wind).
- Extension points: `SimulationListener` (base class `AbstractSimulationListener`; OpenRocket's own listeners in `simulation/listeners/system`) and user-facing `SimulationExtension` (`simulation/extension`, examples included).

### Startup and dependency injection

- Guice 7. `core/startup/Application` is a static service locator over the injector (`Application.getTranslator()`, `getPreferences()`, ...).
- GUI boot: `swing/startup/OpenRocket.main` → `SwingStartup` creates the injector from `GuiModule` + `PluginModule`, calls `Application.setInjector(...)`, and only then `guiModule.startLoader()` — that ordering is a constraint. Headless/embedded use goes through `core/startup/OpenRocketCore.initialize()`.
- Component-preset and motor databases load asynchronously in the background (`database/AsynchronousDatabaseLoader` subclasses) behind blocking Guice providers — first access blocks until loaded.

### File formats

- Loading: `file/GeneralRocketLoader` sniffs magic bytes and delegates to the `.ork` loader (`file/openrocket/importt`), RockSim `.rkt` (`file/rocksim/importt`), or RASAero (`file/rasaero/importt`). Shared SAX infrastructure in `file/simplesax`.
- Saving/export: `file/openrocket/OpenRocketSaver` (per-component savers alongside), RockSim and RASAero exporters, Wavefront OBJ (`file/wavefrontobj/export`), SVG, CSV.

### Localization

Strings come from `Translator` (`l10n` package) backed by `core/src/main/resources/l10n/messages*.properties` (translations managed via Crowdin). Convention: `private static final Translator trans = Application.getTranslator();` with keys of the form `ClassName.key`. Only English (`messages.properties`) is edited in this repo.

### Units

All internal values are pure SI (meters, kg, Kelvin, radians for angles). Conversion to user-preferred units happens only at display time via `info.openrocket.core.unit` (`Unit`, `UnitGroup`). The file format stores angles in degrees; latitude/longitude are degrees everywhere.

## Testing Notes

- Tests live in `core/src/test/java` and `swing/src/test/java`, named `*Test`; fixtures under `core/src/test/resources`.
- Extend `BaseTestCase` (one exists in each module) whenever code under test touches `Application` services — its `@BeforeAll` builds a Guice injector from `ServicesForTesting` plus a `DebugTranslator` and calls `Application.setInjector(...)`. Without it, `Application.getTranslator()`/`getPreferences()` NPE.
- Under `DebugTranslator`, `trans.get("key")` returns `"[key]"` rather than the translated string, so assert on bracketed keys, not English text.

## Conventions

- Branching: `unstable` is the upstream development branch; `master` tracks releases. PRs to the upstream project target `unstable`.
- Commits: atomic (one logical change per commit), present tense, referencing issues as `[#123] Short subject`.
- Style: 4-space indentation, lines ≤ ~120 chars, Javadoc on public classes/methods, no wildcard imports.
