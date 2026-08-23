# Rocket Design and CAD Tooling: Editors, Formats, Forking, and As-Built Records

A survey of the existing landscape relevant to a consortium **"Rocket Design / CAD"
module**, whose stated ideas are: forked designs, parametric/event-driven CAD, as-built
records, and simulation-oriented modeling (no cosmetic "bling"; discourage the hacks
users employ to trick simulators). This report covers the *design* side of the
ecosystem: rocketry-specific design editors, general parametric CAD as actually used
by flyers, code-first/parametric design concepts, how designs are shared and forked
today, the state of as-built record keeping, and the known simulation-honesty problems
that a design tool either causes or could cure. Simulation engines themselves
(OpenRocket's simulator, RASAero II, RocketPy, CamRocSim) are covered in depth in the
companion report *[Rocket Simulation Software: Models, Inputs, and
Portability](rocket-open-simulation-designs.md)* and are referenced, not repeated,
here.

*Research date: 2026-08-23. Facts verified against primary sources (project sites,
source repositories, official documentation) where possible; unverified or
secondary-source items are flagged inline.*

---

## 1. Rocketry-specific design editors

### 1.1 OpenRocket's design editor

**What it is.** The de-facto standard free design editor for model and high-power
rockets (GPL v3, Java, current stable **24.12**). Its editor and simulator are one
application: the design model is a **component tree**, and CG, CP, and stability
margin are recomputed continuously as the tree is edited. Because OpenRocket is both
the most-used editor and the owner of the most-shared file format, its design model
effectively *defines* what "a rocket design" means in the hobby ecosystem today.

- Website: <https://openrocket.info/> · Repo: <https://github.com/openrocket/openrocket>
- File format specification:
  <https://openrocket.readthedocs.io/en/latest/dev_guide/file_specification.html>

**The component tree model.** A design is a strict hierarchy: rocket → stage(s) →
external components (nose cone, body tube, transition/boattail, fin sets, launch
lugs/rail buttons) → internal components nested inside them (inner tubes, couplers,
centering rings, bulkheads, engine blocks, mass objects, parachutes/streamers,
shock cords). Since v22.02 the tree also supports **pods**, **strap-on/parallel-staged
boosters**, and **tube fins** (tube-fin drag simulation was rewritten during the 22.02
cycle to make those models simulate correctly). Fin sets may be trapezoidal,
elliptical, or free-form; fins carry cant angle and (since format 1.8) fin tabs. Every
component has dimensions, a material (density), a surface finish, and optional
appearance data. Mass, inertia, CG, and CP fall out of the tree automatically — this
is the "parametric" behavior users experience: change a dimension and every derived
quantity updates.

**What it can and cannot represent.**

| Can represent | Cannot represent (or mass-only) |
|---|---|
| Axisymmetric single/multi-stage vehicles, unlimited stages, motor clusters, pods, strap-on boosters | **Ring tails** — can be mocked with an inner tube for mass/CG, but the ring is excluded from aerodynamic (CP) calculation (documented in the wiki's Advanced Rocket Design page) |
| Trapezoidal / elliptical / free-form / tube fins, canted fins | **Grid fins** — no support |
| Nose cones (conical, ogive, elliptical, parabolic, power series, Haack) and transitions/boattails | Non-axisymmetric airframes, lifting bodies, asymmetric fin arrangements (aero model assumes slender axisymmetric body) |
| Per-component material, density, surface finish | Airfoil sections on fins (fin cross-section is limited to square/rounded/airfoiled thickness treatment; no NACA section selection as in RASAero) |
| Motor mounts with per-configuration motor selection, ignition events, ejection delays | External CFD coefficient integration (only via CD overrides / CSV lookup overrides, see §5) |
| Mass/CG/CD overrides at component, assembly, and stage level | Design intent: no user-defined relations between component parameters (see §3) |

**Cosmetics in the design file ("bling").** The `.ork` format stores a full
**appearance system**: paint color, shine, decal textures (with the image files
embedded in the archive), separate inside/outside appearance, and a `<photostudio>`
section holding 3D-render settings. None of it affects simulation — surface *finish*
(roughness class) is a separate, simulated property. This is precisely the
design-file "bling" the consortium module proposes to exclude: in `.ork` it is
entangled with the engineering model in the same file and is the reason the format is
a ZIP archive rather than a plain XML document (see §4).

**The `.ork` format.** A ZIP archive containing `rocket.ork` (XML), an optional
`preview.png` (format v1.11+), optional `textures/` decals, and (v1.11+) embedded
thrust curves. The XML root holds four sections: `<rocket>` (metadata + the
`<subcomponents>` component tree, each component carrying a UUID), `<simulations>`
(conditions and cached results), `<photostudio>`, and `<docprefs>` (document
preferences, custom materials). The format is versioned (semantic major.minor,
1.0 → 1.11) and officially documented, but the specification itself states it is not
exhaustive — developers are directed to the source code for parameters it does not
cover. Flight configurations are stored as `<motorconfiguration>` elements (per-config
motor selection, stage activeness, deployment settings). OpenRocket imports `.ork`,
RockSim `.rkt`, and RASAero `.CDX1`, and exports `.rkt`, `.CDX1`, OBJ (for 3D
printing/CAD), SVG fin templates, and CSV data — making it the ecosystem's format hub
(details in the companion simulation report).

**Programmatic access.** The `core` module is published to Maven Central and designs
can be constructed or modified in Java code; simulation extensions can be written in
Java or **JavaScript** (the built-in "Scripts" extension), and custom expressions add
computed variables per time step. However, all of this targets the *simulation*; there
is **no user-facing scripting of the design geometry** (no "generate this fin can from
these three parameters" inside the GUI).

### 1.2 RockSim (Apogee Components) — v10 and v11

**What it is.** The long-standing commercial design-and-simulation package, originated
by Paul Fossey (PKF Systems) in 1997 and sold by Apogee Components. **RockSim v11
shipped in March 2024** (the first major release since RockSim 10, which dated to
2015-era); current price **$50 single-user** (three personal installs), Windows and
macOS. Closed source.

- Product page: <https://www.apogeerockets.com/index.php?main_page=product_software_info&products_id=3300>
- v11 feature article: Peak of Flight Newsletter #622,
  <https://www.apogeerockets.com/Peak-of-Flight/Newsletter622>

**Editor.** Component-tree design editor of the same family as OpenRocket's (OpenRocket
was consciously modeled on RockSim's design representation). Distinguishing features:

- **The "RockSim method" CP calculation** — Barrowman extended with body lift and
  support for geometries plain Barrowman cannot handle: fins mounted on transitions
  and tailcones, and fin counts other than 3/4/6. (Community-documented in Apogee
  newsletters and forum posts; the method's internals are not published — closed
  source.)
- Native **tube fin and ring tail** aerodynamic support predating OpenRocket's tube-fin
  support. *(Secondary sources; not independently verified against the RockSim
  manual.)*
- v11 additions: **airfoiled fin shapes with 3D-printable export**, automatic motor
  database updates from ThrustCurve.org, ejection-charge (black powder) calculator,
  fin placement guides printed at 100% scale, 2D measurement tools, per-component
  mass shown in the tree.
- Mass/CG overrides per component and whole-rocket, used the same way as OpenRocket's
  (designed vs. measured — see §5).

**The `.rkt` format.** Since the v6–v8 era, `.rkt` is a **plain-text XML file — not a
ZIP archive** — which makes it, ironically, more diff/VCS-friendly than `.ork`. The
format is semi-documented: RockSim installs ship a `RockSim_Xml_Doc.txt`
specification, a community parser/spec project exists
(<https://github.com/PWrInSpace/rkt_format>), and OpenRocket's importer/exporter
constitutes a de-facto open implementation. `.rkt` is the lingua franca of the
legacy design-sharing libraries (§4). Motor files: RockSim's `.rse`/`.eng`.

### 1.3 SpaceCAD

**What it is.** Commercial Windows-only design/simulation package (spacecad.com),
currently **SpaceCAD 7** (rebuilt for Windows 10/11: new visual designer, updated
parts databases, flight-event display, "bumper" staging where the upper stage has no
engine). Markets itself as "the first model rocket software that provides a real
CAD-like experience." Flight prediction covers velocity, acceleration, apogee, and
flight time — a simpler simulator than OpenRocket/RockSim. Notably positioned at the
education market: it is an official tool of **UKROC** (UK schools rocketry
competition), with a £14.99 license offer on the UKROC page (valid to August 2026).
Closed source; native file format and import/export capabilities were not verifiable
from public documentation for this report *(unverified — the site does not publish a
format specification)*. Its practical role in the ecosystem is small compared with
OpenRocket/RockSim.

- Site: <https://www.spacecad.com/> · SpaceCAD 7 announcement:
  <https://www.spacecad.com/posts/spacecad-7-model-rocket-design-software/>

### 1.4 Newer entrants (verified as of 2026-08)

- **RocketForge** (<https://rocketforge.space/>) — the one genuine **web-based
  OpenRocket-like design editor** found. Free, browser-based, in early access; built
  by an individual developer (Jon Wiese); **not open source**. Verified from the site:
  visual design editor with ~11 component types and live SVG preview, ThrustCurve.org
  motor search, a claimed 6-DOF RK4 simulation engine, **`.ork` import and export**,
  cloud auto-save, and **team workspaces with editor/viewer roles** (including
  classroom "class teams") — i.e., it already has primitive multi-user sharing,
  though no forking/version history. The site itself cautions that simulation
  accuracy is "actively being improved" and results are estimates. Worth watching as
  evidence of demand for a web editor, but it is proprietary and single-maintainer —
  exactly the replicate-and-fragment pattern the consortium README warns about.
- **LaunchSim** (<https://github.com/Ret-tree/LaunchSim>) — free browser-based flight
  simulator (MIT) that **imports `.ork`** but has no design editor; oriented at
  launch-day operations (weather, GO/NO-GO, altimeter import, GPS recovery). Very
  early: 3 commits at research time. Not a design tool; listed for completeness.
- **RocketPy web app** — RocketPy's project site advertises browser-based simulation
  with `.ork` conversion; this is a simulation front-end, not a design editor
  *(site claim; app not exercised for this report)*.
- **No browser port of OpenRocket itself** was found (no CheerpJ/WASM build); the
  OpenRocket project's own direction remains the Java desktop app plus the
  Maven-published headless core.

### Editor comparison

| | OpenRocket 24.12 | RockSim v11 | SpaceCAD 7 | RocketForge |
|---|---|---|---|---|
| License / cost | GPL v3, free | Closed, $50 | Closed, ~£15–commercial | Closed, free (early access) |
| Platforms | Win/macOS/Linux (Java) | Win/macOS | Windows | Browser |
| Design model | Component tree | Component tree | Component tree ("CAD-like") | Component tree (subset) |
| CP method | Extended Barrowman | "RockSim method" (unpublished) | Unpublished | Unpublished (claims 6-DOF RK4) |
| Native format | `.ork` (ZIP+XML, spec'd) | `.rkt` (plain XML, semi-spec'd) | Proprietary (unverified) | Cloud + `.ork` in/out |
| Overrides (mass/CG/CD) | Yes, 3 levels | Mass/CG (per docs) | Not documented | Not documented |
| Scripting of design | No (API only) | No | No | No |
| Version control / forking | None | None | None | Team sharing, no history |
| Cosmetic layer in file | Yes (paint/decals/photostudio) | Yes (colors/finish) | Yes | Minimal |

---

## 2. General parametric CAD used for rocketry

Flyers routinely step outside the rocketry editors for anything the component tree
cannot express: 3D-printed fin cans and nose cones, avionics bays and sleds, complex
fin geometry, camera shrouds, and scale detail. The pattern across forum threads and
build logs is consistent: **design the flight article in OpenRocket/RockSim for
stability and altitude; design the manufactured parts in a mechanical CAD package;
keep the two in sync by hand.** That manual synchronization — re-entering masses,
re-measuring CG, approximating printed parts as tubes and mass objects — is the gap a
consortium design module would close.

### 2.1 FreeCAD and the Rocket Workbench

**What it is.** The **FreeCAD Rocket Workbench** by David Carter (davesrocketshop) is
the most serious existing bridge between rocketry design models and real parametric
CAD. Open source (**LGPL v2.1**, with MIT-licensed parts), distributed through
FreeCAD's Addon Manager, requires FreeCAD ≥ 1.0. Actively maintained: **v5.1.3
released August 2026**, with a steady release cadence (v5.0.0 late 2025 introduced
scaling workflows, fin fillets, proxy objects, MultiCFD, and OpenRocket export;
v4.1 added RockSim import and ring-tail support). 1,100+ commits.

- Repo: <https://github.com/davesrocketshop/Rocket> ·
  Releases: <https://github.com/davesrocketshop/Rocket/releases>
- Feature discussion threads:
  <https://www.rocketryforum.com/threads/freecad-rocket-workbench-v5-0-released.194386/>,
  <https://www.rocketryforum.com/threads/recent-freecad-rocket-workbench-feature-updates.195608/>

**Verified capabilities.**

| Area | Capability |
|---|---|
| Components | Rocketry component types (nose cones, transitions, body tubes, fins incl. fillets and tabs, ring tails, launch guides) as real parametric FreeCAD solids |
| Parts database | Curated component database derived from the OpenRocket parts data |
| Import | OpenRocket `.ork`, RockSim `.rkt`, RASAero formats; materials auto-assigned via FreeCAD 1.0's material system |
| Export | **To OpenRocket** (v5.0+), plus everything FreeCAD exports natively (STEP, STL for printing, drawings) |
| Analysis | **Fin flutter analysis** implementing the improved methods from Apogee Peak of Flight #615/#617; **CFD workflows** via the external CfdOF workbench, incl. a MultiCFD object for batch runs of related cases |
| Scaling | Whole-rocket / per-stage / per-part scaling and **upscaling** workflows (match an imported OpenRocket/RockSim design to real part dimensions or a target scale) |

**What it is not.** It is not a flight simulator: no built-in trajectory simulation,
CP/stability display, or motor database — the workflow is design/analyze in FreeCAD,
simulate in OpenRocket (round-tripping via import/export). That import→model→export
round-trip between a full parametric CAD kernel and the `.ork` component model is the
closest thing in existence to the consortium's "CAD and simulation share one design"
idea, and its maintainer has already solved many of the semantic-mapping problems
(materials, component correspondence, scale). A fork of the workbench exists
(DrRocketry/DRS-FreeCAD-Rocket), illustrating both the health and the fragmentation
risk of single-maintainer projects.

### 2.2 Autodesk Fusion 360

Dominant among hobbyists for **3D-printed rocketry parts** because of its free
personal-use license and integrated CAM/print pipeline. Forum threads show it used
for complex fin geometry (compound curves, airfoils), fin cans, avionics bays with
printed-in mounting features and heat-set inserts, and fin marking guides; fully
printed supersonic airframes designed in it have flown. Autodesk also showcases
professional launch-vehicle use (HyImpulse). For rocketry it has **no aerodynamic
awareness whatsoever**: no CP, no stability, no motor concept; mass properties exist
(mass/CG/inertia of solids with materials) but nothing consumes them for flight.
Cloud-resident proprietary format; version history exists in the cloud, but no
rocketry semantics. Closed, subscription-based; personal-use terms have narrowed over
time — a dependency risk the consortium should not build on.

### 2.3 Onshape

Cloud parametric CAD (PTC) with a free public tier used by students and teams. Two
properties make it the most instructive reference for the consortium module:

1. **First-class, Git-style version control is built into the data model** —
   immutable versions, branches as pointers (not file copies), merge of workspaces,
   and a complete per-edit history across all users. This is the only mainstream CAD
   system where "fork the design, diverge, merge back" is a native, documented
   workflow (<https://www.onshape.com/en/features/branch-merge-cad>,
   <https://cad.onshape.com/help/Content/Primer/versions.htm>).
2. **FeatureScript**, its built-in language for writing parametric features, shows
   what scriptable, constraint-carrying parametric design looks like in practice.

Like Fusion, Onshape knows nothing about rockets: no aero model, no CP/CG-vs-thrust
reasoning, no motors. And its public tier makes every free-tier document public —
which teams accept, but which is sharing-by-exposure, not structured forking with
attribution.

**Where general CAD fails for rocketry — summary.** (a) No aerodynamic model: CP,
stability margin, drag do not exist as concepts. (b) No motor/flight semantics:
thrust curves, ignition events, deployment are inexpressible. (c) Mass properties are
computed but disconnected from any flight consumer. (d) The rocketry component
ontology (tube/coupler/centering-ring compatibility, motor-mount conventions) must be
rebuilt per user. The FreeCAD Rocket Workbench is the only project attacking this gap
from the CAD side.

---

## 3. Parametric and event-driven design concepts

**What "parametric" means today, tool by tool.** The word covers three quite
different things in the current landscape:

| Level | What it means | Who has it |
|---|---|---|
| **Dimension-driven components** | Components are defined by parameters (length, diameter, thickness, material); derived quantities (mass, CG, CP, stability) recompute automatically on change. No relations *between* parameters. | OpenRocket, RockSim, SpaceCAD, RocketForge |
| **Feature-history parametric CAD** | A recorded tree of operations with expressions/constraints linking dimensions; edit an upstream feature and the model regenerates. Design intent is expressible ("fin root = 1.5 × body diameter"). | FreeCAD, Fusion 360, Onshape (+ FeatureScript), FreeCAD Rocket Workbench |
| **Code-first / generative** | The design *is* a program; parameters are function arguments; regeneration is re-execution. Inherently diffable, forkable, and CI-able. | OpenSCAD, CadQuery, build123d; rocketry generators below |

The consortium's "parametric/event-driven CAD" idea goes beyond all three as they
exist in rocketry tools: no rocketry editor lets the user express inter-component
relations, and none has an event/reactive model (recompute chains, rule triggers,
validity checks firing on change) beyond the hard-coded CG/CP recalculation.

**Existing code-first rocket design (verified projects).**

- **rockit** (<https://github.com/vishnubob/rockit>) — "Model Rocket Construction
  Kit": JSON rocket specification → OpenSCAD-rendered 3D parts, outputting
  `.scad`/`.stl`/`.dxf`/`.png`. The clearest existing example of a declarative rocket
  spec compiled to printable geometry. Long dormant *(activity status not deeply
  verified)*.
- **SJOC — Space Junk Open Constructor** (<https://github.com/sartakov/SJOC>) —
  OpenSCAD-based model rocket constructor including an `ork_to_sjoc.py` converter
  from OpenRocket files to its OpenSCAD modules. Hobby-scale (28 commits, minimal
  community), but it demonstrates `.ork` ↔ code-CAD conversion is tractable.
- **Universal Parts Generator** (RocketryForum, thread 189881) — parametric OpenSCAD
  generation of nine nose cone types, transitions, airfoiled fin cans, centering
  rings, couplers, clusters, etc. Community-maintained via forum rather than a
  canonical repo.
- **Altimeter Cloud tools** (<https://www.altimetercloud.com/tools/>, Rocketry Ltd,
  closed source, free) — browser-based parametric part generators alongside the
  vendor's flight-log platform: a **laser-cut parts designer** (bulkheads, centering
  rings, fins, exported as DXF/SVG) and a **3D-printable parts tool**, plus ~20
  engineering calculators (altitude prediction, fin flutter, rail exit velocity,
  descent/drift, ejection charges). Parameters-in, geometry-out with no persistent
  design model — but a live demonstration that web-based parametric part generation
  is what a vendor builds when courting flyers.
- Assorted parametric nose-cone/fin-can generators on Thingiverse/Printables
  (Crowell's configurable fin can, thing:3133682; JohnHawley's and
  JebediahKerman314's nose-cone generators implementing the standard haack/power
  series/parabolic profiles).
- **CadQuery**: no notable dedicated rocket-design library was found (the
  awesome-cadquery list contains none); usage is ad-hoc. A gap, not a landscape.
- **OpenRocket as a code target**: designs can be built programmatically against the
  Maven-published core (this is how RocketPy's RocketSerializer and the FreeCAD
  workbench interoperate), but there is no supported user-level DSL.

**Reading for the consortium:** the ingredients all exist separately — declarative
specs (rockit's JSON), code-generated geometry (OpenSCAD generators), spec-to-`.ork`
conversion (SJOC, FreeCAD WB export), and scriptable parametric platforms
(FeatureScript) — but no project combines a *simulation-bearing* design model with a
code-first, relation-carrying representation. That combination is unclaimed
territory.

---

## 4. Design versioning, sharing, and forking

**How designs are shared today.**

| Channel | What it holds | Forking/versioning support |
|---|---|---|
| **rocketreviews.com RockSim Library** (ex-EMRR) | ~3,800 `.rkt`/`.ork` design files, searchable by kit/manufacturer; community uploads (<https://www.rocketreviews.com/rocksim-library.html>) | None — flat file downloads, no history, no provenance |
| **Apogee** | `.rkt` files published per kit; Peak of Flight rocket plans with design files (<https://www.apogeerockets.com/Peak-of-Flight-Rocket-Plans>) | None — vendor-published artifacts |
| **Forum attachment swapping** (RocketryForum et al.) | `.ork`/`.rkt` attached to threads on request ("where do I get .ork files?" threads recur for years) | None; versions exist only as re-posted attachments |
| **ThrustCurve.org saved rockets** | Not designs — simple motor-guide parameter sets (diameter, mass, CD, MMT) saved per account, with an API (`saverockets`/`getrockets`) and public sharing of a user's rockets (<https://www.thrustcurve.org/info/api.html>) | Account-based, API-accessible; but not a design format |
| **GitHub/GitLab team repos** | University/club teams commit `.ork` files alongside code | Git history of an opaque binary (see below) |
| **RocketForge team workspaces** | Cloud designs shared with editor/viewer roles | Sharing yes; no version history or fork graph |
| **Onshape public documents** | Full CAD models of rocketry parts | Real branch/merge — but only for geometry, no rocketry semantics |

**No rocketry tool has first-class version control, diffing, or forking.** The
closest things are RocketForge's role-based sharing (no history) and Onshape's
branch/merge (not a rocketry tool). "Forked designs" as a concept — derive, track
lineage, credit the original, merge improvements — exists nowhere in the ecosystem,
despite being the community's actual social practice (kits get cloned, upscaled,
modified, and re-shared constantly; the FreeCAD workbench even ships an *upscaling
workflow* because deriving from existing designs is that common).

**The text-based diffable format question.** The facts, verified:

- `.ork` is a ZIP archive purely so decal textures can ride along; when a design has
  no graphics the archive wraps a single XML file anyway (maintainer explanation on
  RocketryForum thread 189284). Git therefore sees an opaque, recompressed blob:
  no meaningful diffs, no merges, poor delta storage.
- **Uncompressed `rocket.ork` XML diffs meaningfully** — forum users confirm that
  diffing the extracted XML shows exactly what changed in the design. Workarounds in
  use: manual unzip before commit, git hooks/filters that decompress on commit, and
  ReZipDoc (a Java git-diff plugin for zipped content). An option to save
  uncompressed has been discussed in the community; no released OpenRocket version
  offers it *(no developer commitment found in the thread)*.
- One caveat for diff semantics even on the raw XML: the `<simulations>` section
  embeds cached results and the file carries UI/preference state, so semantically
  identical designs can differ textually. A canonical, results-free serialization
  would be needed for clean diffs — a format-design lesson, not just a compression
  toggle.
- RockSim `.rkt` is already plain XML (single file, no wrapper) and is therefore
  technically diffable today, though nobody has built tooling on that property.

---

## 5. As-built records

**The question:** does any tool distinguish the *designed* artifact from the *as-built*
one — measured masses, actual CG, finish quality, per-airframe identity? Short
answer: **no tool has an as-built concept; OpenRocket's overrides are the partial
support, and they work by destroying the designed value.**

- **OpenRocket overrides** (official docs:
  <https://openrocket.readthedocs.io/en/latest/user_guide/overrides_and_surface_finish.html>)
  allow mass, CG, and CD to be overridden at component, assembly, or stage level. The
  documentation explicitly frames this as the as-built mechanism: "nothing is more
  accurate than putting the actual part on a scale and weighing it"; CG overrides are
  recommended once glue and paint (which the model cannot predict) are on the
  airframe; assembly-level mass overrides "imitate the weight of adhesives." Recent
  versions extend CD override to **CSV lookup tables** of coefficients from
  wind-tunnel/CFD/flight data — i.e., as-flown aerodynamics. But the override is a
  single alternative value with a checkbox: the file records *that* a value is
  overridden, not *why*, *when*, *how it was measured*, or what the designed value's
  provenance was. There is one file, one truth; "designed vs. measured" survives only
  as an unchecked-vs-checked box, and community threads (e.g. "Mass and CG Override —
  when to use it?", threads 135253 and 35852) show persistent user confusion over
  when overriding is legitimate.
- **Flight configurations** (OpenRocket, and equivalents in RockSim) are per-flight
  *intent* — motor selection, ignition/ejection timing, stage activeness — not
  per-airframe *state*. They answer "what will I load," not "what did I build."
- **RockSim** offers the same style of mass/CG overrides (per its documentation and
  long-standing usage); nothing beyond that.
- Nothing anywhere tracks: serialized airframes (the same design built three times
  with three different masses), finish/paint records, repairs and modifications over
  an airframe's life, or reconciliation of simulated vs. flown performance feeding
  back into the record. Flight-computer data lives in altimeter vendor apps and
  spreadsheets, disconnected from the design file (LaunchSim's altimeter import is
  launch-ops, not record keeping).

**Conclusion: as-built record keeping is a genuine gap** — the consortium idea with
the least prior art. The design worth stealing from OpenRocket is that measured
values attach *at the same granularity as the design tree* (component/assembly/stage);
the flaw to fix is that they overwrite rather than accompany the designed values, and
carry no provenance.

---

## 6. Simulation-honesty issues

Because the editors' aerodynamic models have hard limits (§1.1) and no tool separates
"measured correction" from "invented fudge," the community has evolved a folklore of
modeling hacks. All of the following are verified as documented community practice:

| Hack | Mechanism | Why it exists | Risk |
|---|---|---|---|
| **Base-drag phantom cone** | Add a zero-mass conical transition (diameter = aft diameter, length ≈ π·D as a starting point) behind short, fat rockets (L/D well under 10:1) | Barrowman-family CP ignores base drag, which stabilizes stubby rockets; the phantom cone shifts CP aft to realistic values. Originated by Bruce Levison, Apogee Peak of Flight **#154**; widely circulated (RocketryForum thread 169558) | The cone corrupts drag/altitude prediction — users must **remove it before running flight sims** and re-add it to check stability. Two mutually incompatible versions of one design file |
| **Phantom structural components** | Zero-mass couplers/body tubes ("PBT"s) used purely to position other components; zero-density custom materials for placeholder fins | The tree's parent-child rules won't otherwise allow the real arrangement (removable fin cans, odd assemblies) | Design file no longer describes the physical rocket; mass/CG right only by construction |
| **Configurable-mass dummy motor tubes** | 1 mm × 1 mm zero-mass inner tubes at a chosen CG as named mass stand-ins (thread 190232) | Working around the lack of parameterized/optional payload masses per configuration | Fragile, invisible to any consumer of the file |
| **Ring tails as inner tubes** | Model the ring for mass/CG knowing it is aerodynamically ignored (OpenRocket wiki, Advanced Rocket Design) | No native ring-tail aero | CP is silently wrong; the wiki warns, the file doesn't |
| **CD/mass tuning to match altimeters** | Override CD (or inflate finish roughness/mass) until sim apogee matches flown apogee (fiberglass-simulation thread 195437 and others) | Legitimate calibration impulse, no legitimate channel: a tuned CD is indistinguishable in the file from a measured one | "Calibrated" designs shared onward carry hidden fudges that are wrong for any other motor/velocity regime |

**How the tools respond.** They don't, mostly. OpenRocket *documents* the limitations
(wiki pages state outright that ring-tail sims "will not be accurate") and marks
overridden components in the UI, but the file format and the sharing ecosystem
preserve none of that context: a downloaded `.ork` with a phantom cone, zero-density
fins, and a tuned CD looks identical to an honestly modeled design. RockSim's
situation is the same, with the added opacity of unpublished methods. The base-drag
trick is even semi-institutionalized — published in Apogee's own newsletter — because
it corrects a real model deficiency the tools have never absorbed natively.

The honest reading: **most hacks are symptoms of missing model features or missing
as-built/calibration channels**, not user malice. A tool that (a) models base drag
in its CP method, (b) supports optional/positional components properly, and
(c) provides provenance-carrying measured-value records, removes the *need* for most
of them — which is a stronger position than merely "discouraging" hacks.

---

## Comparative summary

| Consortium idea | Best existing prior art | State of the art assessment |
|---|---|---|
| Simulation-oriented design model | OpenRocket component tree + `.ork` | Mature but closed-world: fixed ontology, no relations, cosmetics entangled in the engineering file, documented aero blind spots that breed hacks |
| Parametric / event-driven CAD | FreeCAD Rocket WB (rocketry components in a real feature-history CAD); Onshape FeatureScript (scriptable features); rockit/SJOC (code-first specs) | Ingredients exist in separate projects; no simulation-bearing rocketry model is parametric-with-relations or reactive |
| Forked designs / versioning | Onshape branch-merge (non-rocketry); RocketForge team sharing (no history); rocketreviews' 3,800-file flat library | No rocketry tool has version control, diffing, lineage, or attribution; `.ork`'s ZIP wrapper actively blocks git; `.rkt` is accidentally diffable |
| As-built records | OpenRocket overrides + CSV coefficient overrides; flight configurations | Partial at best: single-value overwrites without provenance; no per-airframe identity; the clearest gap in the ecosystem |
| Simulation honesty | OpenRocket wiki warnings; Peak of Flight literature | Hacks are documented folklore; formats cannot distinguish measurement from fudge; root causes are model gaps and missing calibration channels |

## Observations for the consortium

1. **The `.ork` component tree is the semantic baseline, not the endpoint.** Every
   editor surveyed — commercial, free, and web — converges on the same
   dimension-driven component-tree model, and `.ork` is the interchange hub (RockSim,
   RASAero, FreeCAD WB, RocketForge, RocketPy all read or write it). A consortium
   design format should be losslessly convertible to/from `.ork` from day one, then
   exceed it: inter-component relations, an extensible component ontology, and a
   strict separation of engineering model from appearance (`.ork`'s
   paint/decals/photostudio baggage is the cautionary example — it is why the format
   is an un-diffable ZIP).

2. **"Forked designs" needs a format decision before a platform decision.** The
   community already forks constantly (kit clones, upscales, forum re-shares) with
   zero lineage or credit — the consortium README's attribution concern applies to
   *designs*, not just code. The verified blockers are mechanical: ship a canonical
   **plain-text, results-free, order-stable serialization** (the uncompressed-XML
   demand already exists in the community, thread 189284) and git provides history,
   diff, and forks for free; Onshape's branch/merge model shows what a native UX on
   top of that looks like. Cached simulation results and UI state must live outside
   the diffed artifact.

3. **As-built records are the module's clearest green field.** Nothing distinguishes
   designed from measured values except OpenRocket's overwrite-style overrides. The
   consortium design: measured values (mass, CG, CD tables, finish) attach alongside —
   never replacing — designed values, at component/assembly/stage granularity, each
   with provenance (method, date, instrument, flight); plus per-airframe serials so
   one design maps to many built instances. This also creates the hook the companion
   simulation report's "flight configuration overrides" feature consumes.

4. **Treat simulation hacks as requirements, not sins.** Each folklore hack encodes a
   missing feature: base-drag phantom cones → put base-drag CP correction in the aero
   model (the method is published in the hobby literature); phantom tubes/couplers →
   support optional and position-free components natively; tuned CDs → provide a
   first-class *calibration* record (measured coefficient sets with provenance,
   validity range, and source flight) distinct from design values. A validating tool
   can then flag the remaining true fudges — zero-density materials, phantom
   geometry, out-of-envelope coefficients — mechanically, aligning with the
   companion report's "scientific honesty switches."

5. **Partner with, don't duplicate, the FreeCAD Rocket Workbench.** It is actively
   maintained, permissively-enough licensed (LGPL), already solves `.ork`/`.rkt`/
   RASAero ↔ CAD mapping, and adds analyses (fin flutter, CFD orchestration) no
   rocketry editor has. It is also a single-maintainer project with an existing fork —
   precisely the kind of validated work the consortium exists to consolidate. The
   manufacturing-CAD side of the module (printable fin cans, av-bays) should build on
   it and on the code-CAD generator ecosystem (rockit's JSON-spec approach) rather
   than reinvent geometry kernels.

6. **The web tier is being ceded to closed single-maintainer apps.** RocketForge
   demonstrates real demand for browser-based design with team sharing — and it is
   proprietary, early-access, and one person. An open consortium design model with a
   documented schema and a permissively licensed reference library is what would let
   web front-ends like it (and LaunchSim, and RocketPy's web app) become ecosystem
   participants instead of parallel silos — the README's "why now" argument in
   miniature.

---

## References

All URLs accessed 2026-08-23.

### OpenRocket (design editor and format)

1. OpenRocket project site and features. <https://openrocket.info/> ·
   <https://openrocket.info/features.html>
2. OpenRocket source repository. <https://github.com/openrocket/openrocket>
3. OpenRocket File Format Specification (`.ork`). *OpenRocket Development Guide.*
   <https://openrocket.readthedocs.io/en/latest/dev_guide/file_specification.html>
4. "Overrides and Surface Finish." *OpenRocket User Guide.*
   <https://openrocket.readthedocs.io/en/latest/user_guide/overrides_and_surface_finish.html>
5. "Simulation Extensions" (Java and JavaScript scripting). *OpenRocket User Guide.*
   <https://openrocket.readthedocs.io/en/latest/user_guide/simulation_extensions.html>
6. OpenRocket wiki: "Advanced Rocket Design" (ring tail / grid fin limitations),
   "Custom Expressions," "Overrides and Surface Finish."
   <https://wiki.openrocket.info/Advanced_Rocket_Design> ·
   <https://wiki.openrocket.info/Custom_Expressions>
7. OpenRocket 22.02 release (pods, boosters, tube-fin rework).
   <https://github.com/openrocket/openrocket/releases/tag/release-22.02> ·
   <https://openrocket.info/whats-new/wn-22.02.html>
8. Cook, D. *openrocket-database* — enhanced `.orc` component parts database
   (Apache 2.0; bundled with OpenRocket since 22.02).
   <https://github.com/dbcook/openrocket-database>

### RockSim and Apogee

9. Apogee Components. *RockSim v11 Single User* product page ($50; Win/macOS;
   v11 features). <https://www.apogeerockets.com/index.php?main_page=product_software_info&products_id=3300>
10. Apogee Components. "New Features in RockSim v11." *Peak of Flight Newsletter*
    #622 (v11 release, March 2024).
    <https://www.apogeerockets.com/Peak-of-Flight/Newsletter622>
11. Apogee Components. "RockSim 10 Now Available!" (blog) and RockSim FAQs.
    <https://www.apogeerockets.com/blog/RockSim-10-Now-Available> ·
    <https://www.apogeerockets.com/RockSim/RockSim_FAQs>
12. Fossey, P. L. *RockSim Program Guide* (PKF Systems).
    <https://www.apogeerockets.com/downloads/PDFs/Rocksim.pdf>
13. PWrInSpace. *rkt_format* — RockSim RKT file spec parser.
    <https://github.com/PWrInSpace/rkt_format>
14. RocketryForum: "RockSim CP" and "Center of pressure calculations" (RockSim
    method vs. Barrowman; fins-on-transitions; fin-count limits).
    <https://www.rocketryforum.com/threads/rocksim-cp.188407/> ·
    <https://www.rocketryforum.com/threads/center-of-pressure-calculations.123858/>

### SpaceCAD

15. SpaceCAD site; "Hello, SpaceCAD 7" announcement; UKROC page.
    <https://www.spacecad.com/> ·
    <https://www.spacecad.com/posts/spacecad-7-model-rocket-design-software/> ·
    <https://www.spacecad.com/ukroc/>

### Web-based entrants

16. Wiese, J. *RocketForge* — browser-based rocket design and simulation (early
    access, closed source). <https://rocketforge.space/>
17. Ret-tree. *LaunchSim* — browser-based flight simulator, `.ork` import (MIT).
    <https://github.com/Ret-tree/LaunchSim>
18. RocketPy Team project site (browser simulation claim).
    <https://rocketpy-team.github.io/>

### General CAD and the FreeCAD Rocket Workbench

19. Carter, D. *Rocket* — FreeCAD Rocketry Workbench (LGPL v2.1/MIT).
    <https://github.com/davesrocketshop/Rocket> ·
    Releases: <https://github.com/davesrocketshop/Rocket/releases>
20. RocketryForum: "FreeCAD Rocket Workbench V5.0 released"; "Recent FreeCAD Rocket
    Workbench feature updates" (scaling, fin flutter per Peak of Flight #615/#617).
    <https://www.rocketryforum.com/threads/freecad-rocket-workbench-v5-0-released.194386/> ·
    <https://www.rocketryforum.com/threads/recent-freecad-rocket-workbench-feature-updates.195608/>
21. Hackaday. "FreeCAD Takes Off With A Rocket Design Workbench" (2021).
    <https://hackaday.com/2021/04/02/freecad-takes-off-with-a-rocket-design-workbench/>
22. DrRocketry. *DRS-FreeCAD-Rocket* (fork of the workbench).
    <https://github.com/DrRocketry/DRS-FreeCAD-Rocket>
23. Autodesk. "Efficient rocket development with Fusion 360" (HyImpulse case).
    <https://www.autodesk.com/hyimpulse-technologies>
24. RocketryForum: "Designing Complex Fin Geometry in Fusion360 (and others)";
    "3d printed fin can for high power rockets."
    <https://www.rocketryforum.com/threads/designing-complex-fin-geometry-in-fusion360-and-others.190519/> ·
    <https://www.rocketryforum.com/threads/3d-printed-fin-can-for-high-power-rockets.165727/>
25. "3D-Printed Rockets" build log (fully printed PA-12 supersonic airframe).
    <https://carbonheliumnitrogen.github.io/lad.html>
26. Onshape. "Branch & Merge in CAD Design"; "Git-Style Version Control" (blog);
    "Working with Versions, Branching, and Merging" (help).
    <https://www.onshape.com/en/features/branch-merge-cad> ·
    <https://www.onshape.com/en/blog/git-style-version-control-cad-data-management> ·
    <https://cad.onshape.com/help/Content/Primer/versions.htm>

### Code-first / parametric generators

27. vishnubob. *rockit* — Model Rocket Construction Kit (JSON → OpenSCAD → STL).
    <https://github.com/vishnubob/rockit>
28. sartakov. *SJOC* — Space Junk Open Constructor (OpenSCAD; `ork_to_sjoc.py`).
    <https://github.com/sartakov/SJOC>
29. RocketryForum: "Universal parts generator"; "Yet another parametric model rocket
    generator"; "3D Printable Component Generators"; "Converting OpenRocket files to
    Openscad."
    <https://www.rocketryforum.com/threads/universal-parts-generator.189881/> ·
    <https://www.rocketryforum.com/threads/yet-another-parametric-model-rocket-generator.188236/> ·
    <https://www.rocketryforum.com/threads/3d-printable-component-generators.148308/> ·
    <https://www.rocketryforum.com/threads/converting-openrocket-files-to-openscad.167714/>
30. Crowell, G. "Model Rocketry Configurable Fin Can" (OpenSCAD).
    <https://www.thingiverse.com/thing:3133682>
31. CadQuery. *cadquery* and *awesome-cadquery* (no dedicated rocketry library
    found). <https://github.com/CadQuery/cadquery> ·
    <https://github.com/CadQuery/awesome-cadquery>

### Sharing, versioning, and forking

32. rocketreviews.com. RockSim/OpenRocket Designs Library (~3,800 files).
    <https://www.rocketreviews.com/rocksim-library.html> ·
    <https://www.rocketreviews.com/rocksimopenrocket-designs.html>
33. Apogee Components. Peak-of-Flight Rocket Plans (design files).
    <https://www.apogeerockets.com/Peak-of-Flight-Rocket-Plans>
34. ThrustCurve.org API (`saverockets`/`getrockets`, public rockets).
    <https://www.thrustcurve.org/info/api.html>
35. RocketryForum: "OpenRocket files in git version control" (ZIP wrapper rationale,
    uncompressed-save request, hooks/ReZipDoc workarounds); "Where do you download
    .ork files for Open Rocket?"; "Sharing OpenRocket files."
    <https://www.rocketryforum.com/threads/openrocket-files-in-git-version-control.189284/> ·
    <https://www.rocketryforum.com/threads/where-do-you-download-ork-files-for-open-rocket.67559/> ·
    <https://www.rocketryforum.com/threads/sharing-openrocket-files.44875/>

### Simulation-honesty / modeling hacks

36. RocketryForum: "The Rocksim/Openrocket base drag trick" (Levison, Peak of Flight
    #154; phantom zero-mass cone; remove-before-simulating caution).
    <https://www.rocketryforum.com/threads/the-rocksim-openrocket-base-drag-trick.169558/>
37. RocketryForum: "One method for objects of configurable mass in OpenRocket"
    (zero-mass dummy motor tubes).
    <https://www.rocketryforum.com/threads/one-method-for-objects-of-configurable-mass-in-openrocket.190232/>
38. RocketryForum: "Open Rocket help — Mass and CG Override — when to use it?";
    "Over-ride CG or enter 'mass component' to get correct CG (OpenRocket)?".
    <https://www.rocketryforum.com/threads/open-rocket-help-mass-and-cg-override-when-to-use-it.135253/> ·
    <https://www.rocketryforum.com/threads/over-ride-cg-or-enter-mass-component-to-get-correct-cg-openrocket.35852/>
39. RocketryForum: "How To Simulate Fiberglassed Rockets In OpenRocket? Try This...";
    "Simulating short, wide rockets in OpenRocket"; "Open rocket and fin cans"
    (phantom couplers).
    <https://www.rocketryforum.com/threads/how-to-simulate-fiberglassed-rockets-in-openrocket-try-this.195437/> ·
    <https://www.rocketryforum.com/threads/simulating-short-wide-rockets-in-openrocket.175924/> ·
    <https://www.rocketryforum.com/threads/open-rocket-and-fin-cans.185590/>

### Companion report

40. Free Rocket Tree Consortium. *Rocket Simulation Software: Models, Inputs, and
    Portability* (2026-08-22). `docs/research/rocket-open-simulation-designs.md`
    (this repository) — covers OpenRocket's simulator, RASAero II, RocketPy, and
    CamRocSim, including formats, embedding, and the common-core feature set.
