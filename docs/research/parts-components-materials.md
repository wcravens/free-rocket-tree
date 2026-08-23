# Rocket Parts, Components, and Materials Data Management

A survey of the existing landscape a Free Rocket Tree Consortium "Parts / Component /
Materials Manager" module would build on: how the incumbent design tools (OpenRocket,
RockSim) store and distribute component and material data, what part data the major
vendors actually publish, where materials properties come from today, what the
adjacent maker/electronics world has already solved, and — just as important — what
simply does not exist yet.

*Research date: 2026-08-23. Facts verified against primary sources (project
repositories, official documentation, vendor sites) where possible; unverified or
secondary items are flagged inline.*

---

## 1. OpenRocket's component and material system

**What it is.** OpenRocket builds every rocket from a component tree, and each
component's mass is computed from its geometry times a **material density** — so the
component/material database is not a convenience layer, it is the mass model. Two
data systems are involved: **materials** (named densities) and **component presets**
(vendor part records that pre-fill a component's dimensions, material, and optionally
mass). Presets are selected in the design UI via the *"From database…"* button, which
opens the "Choose component preset" chooser.

- Repo: <https://github.com/openrocket/openrocket> · Docs:
  <https://openrocket.readthedocs.io/>

### Material model

| Aspect | Design |
|---|---|
| Identity | A material is a **name + density + type** triple. No other properties (strength, stiffness, cost, finish) are modeled. |
| Types | **BULK** (3-D density), **SURFACE** (areal density, for parachute cloth etc.), **LINE** (linear density, for shock cord / shroud line). |
| Units | Bulk: g/cm³, kg/m³, lb/ft³; surface: g/cm², oz/in²; line: g/cm, oz/in (per the `.orc` `UnitsOfMeasure` attribute). Stock databases use g/cm³, g/cm² and g/m. |
| Built-ins | A hardcoded list of common materials (papers, balsa, plywoods, phenolic, fiberglass, plastics, nylon, etc.) ships inside the application (`Databases` class in the core module); users can define additional materials in preferences or per-document. |
| Custom materials | User-defined materials are stored in application preferences and embedded in `.ork` design files, so a design travels with its materials — but there is **no standalone interchange format for a materials library** other than the `<Materials>` block of a `.orc` file. |

### The `.orc` component-preset format

An OpenRocket Component file (`.orc`) is a plain, human-readable XML file with root
element `<OpenRocketComponent>`, a `<Version>0.1</Version>` marker, a `<Materials>`
section, and a `<Components>` section. Representative entries (from the Estes file of
the parts-database project):

```xml
<Material UnitsOfMeasure="kg/m3">
  <Name>Balsa, bulk, Estes typical</Name>
  <Density>160.2</Density>
  <Type>BULK</Type>
</Material>

<BodyTube>
  <Manufacturer>Estes</Manufacturer>
  <PartNumber>BT-5, 030302</PartNumber>
  <Description>Body tube, BT-5, 18 in., PN 030302</Description>
  <Material Type="BULK">Paper, spiral kraft glassine, Estes avg, bulk</Material>
  <InsideDiameter Unit="in">0.515</InsideDiameter>
  <OutsideDiameter Unit="in">0.541</OutsideDiameter>
  <Length Unit="in">18.0</Length>
</BodyTube>
```

Key properties of the format:

- **Identity fields:** `Manufacturer`, `PartNumber`, `Description` — the closest thing
  the hobby has to a part identifier scheme, and it is per-vendor free text.
- **Dimensioned fields** carry a `Unit` attribute per element (mixed units within one
  file are legal).
- **Mass** may be given explicitly (`Mass` element) or derived from geometry ×
  density; a `Filled` flag exists for solid nose cones/transitions.
- **Component types supported as presets:** body tubes, nose cones, transitions, tube
  couplers, centering rings, bulkheads, engine blocks, launch lugs, rail buttons,
  parachutes, streamers. **Not supported:** fins, shock cords, and mass components
  cannot be defined as presets at all — a significant format limitation for kit
  representation.
- Other documented limitations (from the parts-database project's docs): no way to
  mark a tube as a motor-mount tube, no shoulder wall-thickness/capped flags for
  hollow nose cones (making molded-plastic cone mass hard to model honestly), no
  versioning of entries, no appearance/graphics attributes.
- The built-in presets are compiled at build time from `.orc` sources into a
  serialized binary (`datafiles/presets/system.ser`) inside the OpenRocket jar
  (described by the parts-database project and forum posts; the mechanism is
  build-internal and undocumented in the official docs).

### How users add custom components

Users drop additional `.orc` files into a platform-specific directory, scanned at
startup and merged into one preset list: `%APPDATA%\OpenRocket\Components\`
(Windows), `~/.openrocket/Components/` (Linux),
`~/Library/Application Support/OpenRocket/Components/` (macOS). There is no in-app
preset editor of consequence; the community workflow is editing the XML by hand or in
a spreadsheet and converting. The old wiki's plan for CSV↔ORC tooling and an "online
library of OpenRocket components" (<http://wiki.openrocket.info/Component_databases>)
was never fully realized as an online service.

### The component database project (openrocket-database)

**Verified repo:** the database originated as **`dbcook/openrocket-database`**
("Enhanced parts database for OpenRocket") and now also exists under the official
organization as **`github.com/openrocket/openrocket-database`** with the same
description and license; since the **2022.02 release**, it ships as OpenRocket's
default component database.

| Aspect | Detail |
|---|---|
| Contents | ~20+ vendor `.orc` files: Estes (classic + Pro Series II), Semroc/Centuri-compatible, Quest, MPC, FSI, CMR, BMS, Fliskits (low power); LOC Precision, Madcow, Public Missiles, Giant Leap, Wildman, Blue Tube (high power); Apogee, Top Flight, Rocketarium, competition parachutes/streamers. Hundreds of nose cones, tubes, transitions, rings, parachutes, streamers. |
| Structure | `/orc` (component XML), `/ork` (example designs), `/data` (reference data), `/docs` (extensive research notes on vendors, part history, and OpenRocket mechanics). |
| Materials handling | Densities consolidated into a master `generic_materials.orc` reference file, then pasted into each vendor file where used — a manual normalization pass to stop per-file density drift. This file is, in practice, **the closest thing to an open, structured rocketry materials dataset that exists today.** |
| Data sourcing | Vendor catalogs and sites, archived documentation (JimZ plan scans, Estes archives), John Brohm's Estes part cross-reference documents, the legacy Semroc website's dimension tables, and **direct measurement/weighing of physical parts**. The docs explicitly instruct users to "ALWAYS WEIGH AND MEASURE YOUR ACTUAL PARTS." |
| License | **Apache 2.0** — permissive; redistribution and reuse in other tools is unproblematic. |
| Status | Functionally complete ~2021; **maintenance mode** since ~2022, with the author aiming to hand it to the OpenRocket community. The `.orc` files inside the main OpenRocket source tree had been stale since ~2013–2014 before this adoption. |

This project is the single most important prior art for a consortium parts module:
it demonstrates both the value (corrected masses, resolved vendor conflicts, recovered
historical data) and the cost (five-plus years of one person's research and
measurement labor) of a curated cross-vendor database.

---

## 2. RockSim's component database

**What it is.** RockSim (Apogee Components; originally PKF Systems / Paul Fossey) is
the commercial design/simulation package whose part and design formats remain
de-facto interchange standards. It ships with a parts database and a materials
database used the same way OpenRocket uses them: pick a part, get its dimensions,
mass, and material pre-filled.

- Product: <https://www.apogeerockets.com/RockSim/RockSim_Information>

| Aspect | Detail |
|---|---|
| Storage format | The parts and materials databases are **CSV files** ("comma separated values" spreadsheets, per Apogee's own newsletter documentation). New parts are imported by naming files per component type (e.g. `NCDATA.CSV` for nose cones) and placing them in the `\RockSim\DataImport` directory, then using *File → Import → Database files…*. |
| Distribution | Apogee hosts downloadable zipped "Parts and Materials Database Files" (the defaults from RockSim v10.0-era) plus motor data files. |
| Maintenance | **Apogee has stated it does not issue updates to the parts (or motor) databases** (reported by users of Apogee support on The Rocketry Forum; motors instead auto-update from ThrustCurve.org inside the app). Users extend the database themselves, including for 3-D-printed parts. |
| Materials | A named materials list with densities backs mass computation, analogous to OpenRocket's; users can add materials. (Details of the materials file schema not verified against a primary schema document.) |
| Part discovery UX | Apogee's own tutorial notes the DB "doesn't sort parts by what sizes they are, nor which components they match with… there is no easy way to tell which parts fit together" — compatibility is encoded, if at all, in naming conventions. |
| Licensing/openness | RockSim is closed-source commercial software (~$50/seat with paid upgrades). The database CSVs are distributed freely from Apogee's site but carry **no explicit license**; their legal reuse status in third-party tools is undefined. OpenRocket historically imported RockSim component data (a `rocksim_components` datafile tree exists in old source trees), suggesting tolerated reuse, but nothing formal. |
| Interchange role | The `.rkt` design format (XML) is read and written by OpenRocket and read by RASAero II, and — more relevant here — **`.rkt` files are the format vendors actually publish part/kit data in** (see §3). The RockSim engine format `.rse` plays the same role for motors. |

Net: RockSim's parts database is a frozen, license-ambiguous snapshot that users
patch locally; its living contribution to the ecosystem is the `.rkt`/`.rse` file
formats, not the database itself.

---

## 3. Vendor part catalogs as data sources

No hobby-rocketry vendor publishes a machine-readable parts catalog (no API, no
CSV/JSON download, no data feed). What exists is human-readable spec tables on
product pages, plus — the one bright spot — per-kit **RockSim `.rkt` design files**
that embed component dimensions and masses as a side effect. Findings by vendor:

| Vendor | Human-readable specs | Machine-readable data | Notes |
|---|---|---|---|
| **Apogee Components** | Good: product pages list dimensions/weights for tubes, cones, etc. | **Free RockSim design files for most kits they sell**; RockSim default parts/materials CSVs downloadable | The best of the group, but the data serves the RockSim product, not an open ecosystem. |
| **Estes** | Instruction sheets (PDF) and catalog scans; community archives (JimZ, Brohm cross-references) hold the historical data | **None found.** No official `.ork`/`.rkt` or data downloads located | The community reconstructed the entire Estes part catalog by hand into the openrocket-database Estes files. |
| **LOC Precision / Public Missiles** | Product-page specs (LOC acquired the PML product lines; PML products now sold via locprecision.com) | None published; forum reports say LOC will **e-mail RockSim files on request** (secondary, unverified) | LOC's tube dimensions are the de-facto high-power standards others copy. PML Quantum Tube specs (36 in lengths, ≤ Mach 0.85 guidance) appear only as page prose. |
| **Madcow Rocketry** (absorbed Rocketry Warehouse — widely reported, not verified from a primary statement) | Product pages list length, diameter, weight, fin material per kit | **Downloadable RockSim file per kit** on many product pages | Kit-level, not component-level, data. |
| **Always Ready Rocketry** (Blue Tube 2.0) | Marketing-level specs (lengths, diameters) on site | None | Blue Tube dimensional/mass data in circulation comes from community measurement (a dedicated `bluetube` file exists in openrocket-database). |
| **Giant Leap, Wildman, Rocketarium, Top Flight, BMS, Fliskits, Quest** | Page-level specs of varying completeness | None found | All covered in openrocket-database via measurement/catalog transcription. |
| **Semroc (now eRockets)** | The legacy Semroc site's part dimension tables were unusually thorough | None (legacy HTML tables only) | Those tables were a primary source for the openrocket-database Semroc file — an example of vendor data surviving only because the community copied it. |

Community aggregation fills the vendor gap in two forms:

- **rocketreviews.com (formerly EMRR) RockSim library** — a site-claimed ~3,800
  RockSim design/simulation files organized by manufacturer and kit
  (<https://www.rocketreviews.com/rocksim-library.html>).
- **The Rocketry Forum "OpenRocket files" threads** (e.g. K'Tesh's long-running
  thread) — thousands of `.ork` files for commercial kits, alphabetized by
  manufacturer, living in forum attachments.

Both are valuable and fragile: forum attachments and a volunteer-run site are the
de-facto archival layer for vendor part data.

**Contrast — motors.** The motor side of the hobby solved this problem:
**ThrustCurve.org** offers a searchable database of certified motor data with a
documented JSON **API** (<https://www.thrustcurve.org/info/api.html>), standard file
formats (RASP `.eng`, RockSim `.rse`), and downstream consumption by OpenRocket,
RockSim, and RocketPy. Nothing equivalent exists for airframe components; motors
prove the model works in this community when certification bodies (NAR/TRA/CAR)
generate authoritative data.

---

## 4. Materials data

Where density (and occasionally strength) data for common rocketry materials comes
from today:

| Material family | Current data sources | Structured/open? |
|---|---|---|
| Kraft/glassine tube stock, fish paper | Densities embedded in OpenRocket built-ins, RockSim materials CSV, and openrocket-database `generic_materials.orc` — largely back-derived from weighing actual tubes | Only via `generic_materials.orc` (Apache 2.0) |
| Balsa, basswood, plywood (aircraft ply, birch ply) | Same embedded lists; authoritative underlying data in the USDA Forest Products Laboratory *Wood Handbook* (FPL-GTR-282, public domain) — includes density **and** strength/stiffness | Wood Handbook is open but not rocketry-shaped; simulator lists are density-only |
| Phenolic tube (kraft-phenolic), Quantum/styrene | Vendor prose + community measurement; simulator material lists | No |
| Fiberglass (G10/G12/FW tube), carbon fiber | Vendor pages (rarely give laminate density), community measurement; engineering sources: MatWeb entries, manufacturer datasheets, CMH-17 composites handbook (paywalled) | No open rocketry-specific dataset; density varies with layup/resin fraction, so nominal values are weak |
| 3-D print filaments (PLA, PETG, ABS, ASA, PC, PA-CF…) | Manufacturer technical data sheets (e.g. Prusament publishes density + mechanical TDS per filament); community fills print-density gap ad hoc (infill % makes bulk density user-specific) | TDS are PDFs; no aggregated open dataset |
| General engineering lookup | **MatWeb** (<https://www.matweb.com>) — huge property database, free to browse, but proprietary, no bulk download/API for open reuse | No |

Observations:

- **Density is the only property the ecosystem manages at all**, because mass
  simulation is the only consumer. Strength/stiffness data — needed for fin flutter,
  fin thickness, airframe buckling, bulkhead/eyebolt loads — has no home in any
  rocketry tool and is looked up ad hoc (Wood Handbook, MatWeb, vendor TDS, forum
  folklore).
- The dbcook project's practice of naming materials with provenance ("Balsa, bulk,
  Estes typical"; "Paper, spiral kraft glassine, Estes avg") is an informal but
  smart pattern: it acknowledges that *the same nominal material differs by vendor
  and era* and encodes the distinction in the identifier.
- Nothing versions material data or records how a value was obtained (measured n
  samples vs. vendor claim vs. handbook figure).

---

## 5. Adjacent and general-purpose solutions

Tools from the maker/electronics world worth mining for patterns (none is a drop-in
fit, all are instructive):

| Tool | What it is | Fit for rocketry parts management |
|---|---|---|
| **InvenTree** (<https://inventree.org>, MIT, active — releases through 2026) | Open-source part/stock/BOM management: Django + REST API, part categories with **custom parameter templates**, supplier/manufacturer part separation, BOMs, plugin system | The strongest pattern donor. Its core distinction — an abstract *Part* vs. concrete *Supplier Part* vs. *Manufacturer Part* — is exactly the canonical-part-vs-vendor-SKU split rocketry lacks. Parameter templates could carry dimensions/densities. What it lacks: any physics semantics (units-aware dimensional data feeding a mass model) and any notion of exporting `.orc`-style preset data. |
| **PartKeepr** (<https://partkeepr.org>) | The earlier PHP open-source electronics inventory manager | **Archived July 2025** (read-only; effectively unmaintained since ~2018). A cautionary tale about single-maintainer inventory projects, and the reason InvenTree exists. |
| **Octopart / Nexar API** (commercial) | Electronics part aggregation keyed on **manufacturer part number (MPN)**, normalizing distributor offers onto canonical parts with parametric specs | The reference model for cross-vendor canonical identifiers + parametric search — precisely the missing layer in rocketry, where "BT-60-compatible tube" has no machine expression. Closed/commercial, so a pattern to copy, not a service to use. |
| **ThrustCurve.org** (in-domain) | Community-run motor database with JSON API and standard file formats | Proof that a curated, API-fronted component database is sustainable in this exact hobby; its data model (manufacturer + designation + certified measured data + downloadable per-tool formats) is the template a parts service should follow. |
| **Altimeter Cloud tools** (<https://www.altimetercloud.com/tools/>, Rocketry Ltd, closed, free) | Browser-based parametric generators — laser-cut bulkheads/centering rings/fins to DXF/SVG, 3D-printable parts — plus ~20 rocketry calculators, attached to the vendor's altimeter/flight-log platform | In-domain evidence that parts can be *generated from parameters* rather than only cataloged: a consortium parts manager could emit fabrication outputs (DXF/SVG/STL) from canonical dimensional data the same way. No catalog, no persistence, no API — generation only. |
| **Open Rocket Document (openrocketdoc)**, Open Aerospace (<https://open-aerospace.github.io/openrocketdoc/>) | An attempt at a clean YAML-based rocket-description format independent of any one tool | Evidence of prior consortium-style format thinking; low activity (status not re-verified in depth) — useful as design input, not as living infrastructure. |
| Open Know-How / OSHWA-style hardware metadata | Manifest standards for describing open hardware projects | Only tangentially relevant; useful if the consortium wants kit/design metadata (attribution, licensing) conventions rather than dimensional data. |

---

## 6. Comparative summary

| | OpenRocket presets + openrocket-database | RockSim database | Vendor catalogs | Materials data | InvenTree (pattern) |
|---|---|---|---|---|---|
| Data format | `.orc` XML (open, documented by example) | CSV files + `.rkt` XML | HTML pages, PDFs, per-kit `.rkt` | Embedded lists; `generic_materials.orc`; PDFs/handbooks | SQL + REST/JSON |
| License | **Apache 2.0** (database); GPL v3 (app) | Proprietary app; DB freely downloadable, **no license stated** | None stated | Mixed (Apache 2.0 / public domain / proprietary) | MIT |
| Coverage | ~20+ vendors, LPR strong, HPR good | Frozen v10-era snapshot + user additions | Per-vendor, partial | Density only | n/a |
| Maintenance (2026) | Maintenance mode; shipped as OpenRocket default | Explicitly not updated by Apogee | Ongoing but unstructured | Static | Active |
| Canonical part IDs | Manufacturer + free-text part number | Same | Vendor SKUs only | n/a | MPN/supplier-part split |
| Measured vs. nominal | Mix, distinguished only in comments/material names | Nominal | Nominal | Mostly nominal | n/a |
| API / service | None (files only) | None | None | None (MatWeb closed) | Full REST API |

---

## 7. Gaps — what does not exist

Stated explicitly, because these define the module's opportunity space:

1. **No cross-vendor canonical part identity.** "BT-60", "38 mm coupler",
   "54 mm thin-wall fiberglass" exist only as naming conventions. There is no
   registry, no compatibility relation ("fits inside", "couples", "replaces"), and no
   way to say two vendors' parts are equivalent. Every database keys on
   `(Manufacturer, free-text PartNumber)`.
2. **No vendor publishes machine-readable data.** All structured part data in
   circulation was transcribed or measured by volunteers; the authoritative sources
   (vendors) are data-silent, and the community archives (forum attachments, one
   volunteer's GitHub repo, rocketreviews.com) are fragile.
3. **No as-measured vs. nominal distinction.** Formats carry a single value per
   dimension/mass with no provenance, tolerance, sample count, or date. The
   openrocket-database docs *warn* users to weigh their own parts precisely because
   the format cannot express variation; manufacturing spread (notably in molded nose
   cone and tube masses) is known to be significant.
4. **No materials dataset worthy of the name.** Density-only, scattered,
   unversioned; zero structural properties (modulus, strength) despite fin flutter
   and airframe loading being routine design questions. `generic_materials.orc` is
   the best available and it is a by-product of one parts project.
5. **Preset formats cannot represent whole kits.** `.orc` cannot define fins, shock
   cords, or mass objects; neither `.orc` nor RockSim CSVs express a bill of
   materials, so "kit" data circulates only as full design files (`.rkt`/`.ork`) that
   conflate the part list with one person's simulation setup.
6. **No service layer.** Unlike motors (ThrustCurve API), component data has no
   queryable endpoint, no update channel, no versioning — consumption means vendoring
   XML files into each application.
7. **No inventory/build linkage.** Nothing connects "parts that exist" (catalog) to
   "parts I have" (inventory) to "parts this design consumes" (BOM) — the triad
   InvenTree handles for electronics — nor to flight records (which airframe flew,
   with what measured mass).

---

## Observations for the consortium

1. **Adopt, don't replace, the `.orc` corpus.** The Apache-2.0
   openrocket-database is the ecosystem's crown-jewel dataset and is explicitly
   looking for institutional stewardship ("maintenance mode… transition to the
   OpenRocket development community"). A consortium parts module should ingest it
   losslessly, contribute fixes upstream, and treat `.orc` (and RockSim CSV) as
   export targets — the same "start from de-facto formats" conclusion the simulation
   survey reached for `.ork`/`.eng`/`.rkt`.

2. **ThrustCurve.org is the in-domain existence proof** for what a parts service
   should be: curated data + stable identifiers + JSON API + per-tool export formats.
   Replicating that model for airframe components (with vendor participation where
   possible, community measurement where not) is a better goal than another file
   format alone.

3. **The data model should separate three layers** that current formats conflate:
   *canonical part* (identity, nominal geometry, compatibility relations), *vendor
   offering* (SKU, price, availability), and *observation* (measured dimensions/mass
   with provenance, date, and method). This is the InvenTree/Octopart MPN pattern
   plus a metrology layer, and it directly resolves gaps 1–3. The dbcook practice of
   provenance-bearing material names shows the community already wants this.

4. **Materials deserve first-class treatment beyond density.** A versioned, cited
   materials dataset (density + basic mechanical properties, per vendor/process
   where it matters, seeded from `generic_materials.orc`, the public-domain Wood
   Handbook, and manufacturer TDS) would serve simulators, fin-flutter calculators,
   and structural tools at once — a genuinely new capability, not a port.

5. **Licensing is already favorable.** Apache 2.0 (component DB), public-domain
   handbook data, and MIT tooling patterns mean a permissively licensed parts module
   is achievable without the GPL entanglement questions the simulation-core survey
   had to navigate. The one caution: RockSim's database CSVs carry no license, so
   RockSim-derived records need clean-room transcription from vendor sources or
   fresh measurement, not bulk import.

6. **Plan for curation labor, not just schema.** The single clearest lesson of
   openrocket-database is that the hard part was years of research and physical
   measurement by one person. A consortium module succeeds or fails on making
   contribution cheap (submission tooling, spreadsheet round-tripping, measurement
   protocols) and credited — which aligns with the consortium's stated
   attribution-and-collaboration values.

---

## References

All URLs accessed 2026-08-23.

### OpenRocket component/material system

1. OpenRocket project. *OpenRocket* [software]. GNU GPL v3.
   <https://github.com/openrocket/openrocket> · <https://openrocket.info/>
2. OpenRocket project. *OpenRocket Documentation* — file specification, basic
   rocket design (component preset chooser).
   <https://openrocket.readthedocs.io/en/latest/dev_guide/file_specification.html> ·
   <https://openrocket.readthedocs.io/en/latest/user_guide/basic_rocket_design.html>
3. OpenRocket wiki. "Component databases" — original `.orc` design/planning page.
   <http://wiki.openrocket.info/Component_databases>
4. Cook, D. *openrocket-database* — enhanced parts database for OpenRocket
   [data + docs]. Apache License 2.0.
   <https://github.com/dbcook/openrocket-database> · README:
   <https://github.com/dbcook/openrocket-database/blob/master/README.md>
5. OpenRocket organization mirror/adoption of the parts database.
   <https://github.com/openrocket/openrocket-database>
6. Example `.orc` vendor file (format reference):
   <https://github.com/dbcook/openrocket-database/blob/master/orc/estes_classic.orc>
7. Rocketry Forum. "OpenRocket Component Presets" — built-in preset serialization
   (`system.ser`), staleness of in-tree `.orc` files.
   <https://www.rocketryforum.com/threads/openrocket-component-presets.173973/>
8. Rocketry Forum. "Custom Component files (.orc) for Open Rocket."
   <https://www.rocketryforum.com/threads/custom-component-files-orc-for-open-rocket.191669/>

### RockSim

9. Apogee Components. *RockSim* [software] product and support pages.
   <https://www.apogeerockets.com/RockSim/RockSim_Information>
10. Apogee Components. *Peak of Flight Newsletter* #241, "How To Add New Items To
    Your RockSim Database" (CSV import files, `DataImport` directory).
    <https://www.apogeerockets.com/education/downloads/Newsletter241_Large.pdf>
11. Apogee Components. RockSim help series, "Message 4: Selecting Parts From The
    Database." <https://www.apogeerockets.com/RockSim/Help_Message_4>
12. Fossey, P. L. *RockSim Program Guide* (v7 era; PKF Systems).
    <https://www.apogeerockets.com/downloads/PDFs/Rocksim.pdf>
13. Rocketry Forum. "Updated RockSim Parts Database Files?" — Apogee's no-updates
    stance (user-reported).
    <https://www.rocketryforum.com/threads/updated-rocksim-parts-database-files.146115/>

### Vendors and community aggregation

14. Apogee Components — component product pages with specs and free RockSim design
    files for kits. <https://www.apogeerockets.com/>
15. Estes Industries — support/instructions downloads (no machine-readable part
    data found). <https://estesrockets.com/>
16. LOC Precision / Public Missiles Ltd. — product pages incl. Quantum tube.
    <https://locprecision.com/> · <https://publicmissiles.com/>
17. Madcow Rocketry — kit pages with specs and RockSim file downloads.
    <https://www.madcowrocketry.com/>
18. Always Ready Rocketry — Blue Tube 2.0. <https://alwaysreadyrocketry.com/>
19. eRockets / Semroc legacy parts data (as absorbed into openrocket-database).
    <https://www.erockets.biz/>
20. rocketreviews.com (formerly EMRR) — RockSim design-file library (~3,800 files,
    site-claimed). <https://www.rocketreviews.com/rocksim-library.html>
21. Rocketry Forum. "Where to get general OpenRocket or Rocksim files?" — community
    file-sharing practices (K'Tesh thread, vendor e-mail requests).
    <https://www.rocketryforum.com/threads/where-to-get-general-openrocket-or-rocksim-files.52183/>
22. ThrustCurve.org — motor database and JSON API (contrast case).
    <https://www.thrustcurve.org/> · <https://www.thrustcurve.org/info/api.html>

### Materials data

23. Cook, D. `generic_materials.orc` — consolidated materials reference in
    openrocket-database.
    <https://github.com/dbcook/openrocket-database/blob/master/orc/generic_materials.orc>
24. USDA Forest Products Laboratory. *Wood Handbook — Wood as an Engineering
    Material*, FPL-GTR-282 (2021). Public domain.
    <https://www.fpl.fs.usda.gov/documnts/fplgtr/fplgtr282/fpl_gtr282.pdf>
25. MatWeb — material property data aggregator (proprietary, no open bulk access).
    <https://www.matweb.com/>
26. Prusa Polymers. Prusament technical data sheets (filament density/mechanical
    data example). <https://prusament.com/>
27. CMH-17 — Composite Materials Handbook (paywalled composites data).
    <https://www.cmh17.org/>

### Adjacent solutions

28. InvenTree [software]. MIT License; part/supplier-part/BOM model, REST API.
    <https://inventree.org/> · <https://github.com/inventree/InvenTree>
29. PartKeepr [software] — archived July 2025, read-only.
    <https://partkeepr.org/> · <https://github.com/partkeepr/PartKeepr>
30. Octopart / Nexar API — electronics part aggregation on manufacturer part
    numbers (commercial pattern reference). <https://octopart.com/>
31. Open Aerospace. *Open Rocket Document* format (openrocketdoc).
    <https://open-aerospace.github.io/openrocketdoc/>
