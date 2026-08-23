# Rocket Motor Data Sources and Motor Inventory Management

A survey of the existing landscape a consortium **Motor Inventory** module would build on:
the de-facto motor database (**ThrustCurve.org**), the motor data file formats in
circulation (RASP `.eng`, RockSim `.rse`, and others), the certification organizations
as primary data sources (**NAR**, **TRA**, **CAR**, **AMRS**), the state of personal
motor-inventory tracking tools, and the regulatory context that shapes what an inventory
record needs to hold.

*Research date: 2026-08-23. Facts verified against primary sources (thrustcurve.org
documentation and live API, certification-organization sites, GitHub repositories) where
possible; unverified or secondary items are flagged inline.*

---

## 1. ThrustCurve.org

**What it is.** The de-facto database of hobby rocket motor data: certified motor
specifications, measured thrust curves, and downloadable simulator data files for every
motor certified by the recognized certification organizations. Created and maintained by
**John Coker** (with Mark Koelsch as a major data contributor until his death in 2018).
Launched in 1998 to distribute simulator files derived from Tripoli firing data; after
TRA stopped sharing raw data, the site pivoted in 2006 (v2) to a community-contribution
model; a full rewrite (v3, Node.js) went live in 2020. The site itself notes that its
data is consequently "no longer as authoritative" — it combines the official
certification lists with data files contributed by users and manufacturers. The site
software is **open source (ISC license)** at
<https://github.com/JohnCoker/thrustcurve3>.

- Site: <https://www.thrustcurve.org/> · Background: <https://www.thrustcurve.org/info/background.html>
- Its centrality is now *official*, not just de-facto: Tripoli's Motor Testing
  committee page states that TMT motor performance data "is made publicly available and
  can be accessed through the thrustcurve.org website," and both the NAR and TRA motor
  pages link individual motors to their ThrustCurve pages (see §3).

### Data held per motor

The certified-spec fields (as returned by the search API) are effectively the
ecosystem's canonical motor metadata schema:

| Field group | Fields |
|---|---|
| Identity | `motorId` (24-hex-digit string), `manufacturer`, `manufacturerAbbrev`, `designation` (manufacturer's exact designation), `commonName` (e.g. "H128"), `impulseClass` (A–O), `certOrg` |
| Geometry | `diameter` (mm), `length` (mm), `type` (`SU` single-use / `reload` / `hybrid`) |
| Certified performance | `avgThrustN`, `maxThrustN`, `totImpulseNs`, `burnTimeS` |
| Mass | `totalWeightG`, `propWeightG` |
| Operation | `delays` (available ejection delays), `delayAdjustable`, `caseInfo` (reload case), `propInfo` (propellant family), `sparky` flag |
| Lifecycle | `availability` (`regular` / `occasional` / `OOP` out-of-production), `updatedOn`, `dataFiles` count, `infoUrl` |

Units are SI/MKS throughout except motor-mount diameters (mm). The homepage claims
"well over a thousand data files contributed by many users"; certification coverage is
"all the ones that have been certified" by NAR/TRA/CAR (plus AMRS, below).

### REST API

Documented at <https://www.thrustcurve.org/info/api.html>, with an OpenAPI/Swagger spec
at `/api/v1/swagger.json` (hosted docs on SwaggerHub) and a TypeScript client on npm
(`@thrustcurve/api1`). JSON and XML variants of every action; GET or POST; legacy
`/servlets/*` endpoints are deprecated.

| Endpoint | Purpose |
|---|---|
| `GET/POST /api/v1/metadata.json\|.xml` | Enumerate valid search criteria (26 manufacturers, 5 cert. orgs — NAR, TRA, CAR, AMRS, "Uncertified" — 3 motor types, impulse classes A–O, available diameters) for populating UI pickers |
| `GET/POST /api/v1/search.json\|.xml` | Motor search by any combination of criteria (`manufacturer`, `designation`, `commonName`, `impulseClass`, `diameter`, `type`, `certOrg`, `sparky`, `availability`, `hasDataFiles`, `infoUpdatedSince`, `dataUpdatedSince` …); returns the full spec record above incl. the `motorId` needed for downloads |
| `GET/POST /api/v1/download.json\|.xml` | Fetch simulator data files for motor IDs; filter by `format` (**`RASP` or `RockSim`** — the only two formats in the v1 API) and `license` (`PD` / `free` / `other`); `data=file\|samples\|both` returns Base64 file content and/or parsed time–thrust sample arrays; response includes `source` (`cert` / `mfr` / `user`) and per-file `license` |
| `POST /api/v1/getrockets.json\|.xml` | Retrieve a user's saved rockets (email/password auth; public rockets without) |
| `POST /api/v1/saverockets.json\|.xml` | Save rocket definitions to a user account |
| `GET/POST /api/v1/motorguide.json\|.xml` | Server-side motor guide: given rocket parameters, returns motors that fit and fly safely |

The `dataUpdatedSince`/`infoUpdatedSince` criteria make incremental mirroring practical
— this is what downstream consumers rely on.

### Licensing and terms

There is **no single license on the database**. Since the 2006 community-contribution
pivot, each uploaded data file carries a contributor-selected license class: **public
domain**, **free** (GPL/CC/Apache-style), **other/restricted**, or **unknown**
(<https://www.thrustcurve.org/info/contribute.html>). The download API exposes the
license per file and can filter on it. The certified *specification numbers*
themselves originate with the certification organizations; ThrustCurve does not claim
copyright over them. OpenRocket's motor-database project notes that redistributed files
retain "their original internal copyright headers" and recommends consuming the live
API "to ensure you are respecting the latest updates and restrictions."
*(No formal site-wide terms-of-service document was located; treat redistribution
policy as per-file license + courtesy, unverified beyond the pages cited.)*

### How the ecosystem consumes it

- **OpenRocket** — bundles a motor database built from ThrustCurve data; since the
  motor-database project (<https://github.com/openrocket/motor-database>, GPL-3.0) this
  is a *dynamic backend*: a weekly GitHub Action pulls `.eng`/`.rse` files via the
  ThrustCurve API, compiles them into a SQLite `motors.db`, gzips + SHA-256 hashes it,
  and publishes it via GitHub Pages as a CDN for the application to update from.
- **RocketPy** — primary motor input is RASP `.eng`/CSV (see §2), but recent releases
  include a ThrustCurve.org API client (release notes cite "persistent caching for
  ThrustCurve API" and explicit request timeouts). *(Integration verified only via the
  release notes at <https://github.com/RocketPy-Team/RocketPy/releases>; the thrust-source
  docs page does not yet document it.)*
- **thrustcurve-db** (<https://github.com/broofa/thrustcurve-db>) — third-party
  re-bundling of the whole database as a single JSON file (schema = the API's
  `SearchResponse` plus normalized `samples` arrays), on npm/jsDelivr for browser use.
- **Motor Dashboard** (Mountain Man Rockets, <https://motor.mountainmanrockets.com/>) —
  browser tool fetching every certified motor live from the API on page load.
- **Tripoli TMT** — links each certification record to the motor's ThrustCurve page and
  names ThrustCurve as the public outlet for its performance data.
- The site's own **mobile app** ("ThrustCurve to-go," Cordova, iOS/Android, 2015) was
  **discontinued in 2025**; the responsive web site is the supported mobile experience.

### Portability / re-use

**High — it is the ecosystem's motor-data hub and is built to be consumed.**
Open-source site code (ISC), a documented JSON/XML API with OpenAPI spec, incremental
update queries, per-file license metadata, and no API key requirement. Two caveats: it
is a **single-maintainer** service (one person, one hosting arrangement — the 2020
migration happened because the previous provider closed), and the **per-file license
patchwork** means a redistributing consumer must track licenses file-by-file rather
than assuming one blanket right. Both argue for consortium-side mirroring (the
OpenRocket motor-database pattern) rather than hard runtime dependence.

---

## 2. Motor data file formats

### RASP `.eng`

**What it is.** The universal interchange format for hobby motor thrust curves —
plain text, originating with the RASP simulator lineage (attributed by ThrustCurve to
G. Harry Stine's original RASP program). Every surveyed simulator except CamRocSim
reads it. Spec (informal but canonical):
<https://www.thrustcurve.org/info/raspformat.html>.

| Element | Content |
|---|---|
| Comments | Lines starting with `;`, ignored; multiple motors per file separated by comments |
| Header line | 7 space-separated fields: **common name** · **casing diameter (mm)** · **casing length (mm)** · **delays** (dash-separated list; `0` = none, `P` = plugged) · **propellant weight (kg)** · **loaded motor weight (kg)** · **manufacturer code** |
| Data lines | `time(s) thrust(N)` pairs, chronological; implicit `0,0` at ignition; final point **must** be zero thrust (burnout); zero thrust may appear *only* as the final point |
| Legacy limit | Max **32 data points** for compatibility with older programs (modern parsers accept more) |

**Limitations** — the reasons `.rse` exists:

- **No mass/CG over time.** Only initial propellant and loaded masses; consumers must
  assume a depletion model (typically mass ∝ impulse delivered) and a fixed CG.
- **No motor type** (single-use/reload/hybrid), no case designation, no total-impulse
  or average-thrust fields (derived), no manufacturer full name, no certification
  metadata, no ignition/burn-time semantics beyond the curve itself.
- No formal grammar or versioning; real-world files vary (comment conventions,
  delimiter tolerance), so robust parsers are defensive by necessity.

### RockSim `.rse`

**What it is.** XML motor format introduced with RockSim (recommended over `.eng` for
RockSim v8+ "for greater simulation accuracy"). Carries everything `.eng` does plus
mass properties over time. Format guide (third-party, hosted by ThrustCurve):
<https://www.thrustcurve.org/thirdparty/RockSim%20Engine%20File%20Format.pdf>; see also
the OpenRocket wiki page <http://wiki.openrocket.info/RSE_File>.

Structure: an `<engine>` element with attributes, containing a `<data>` element of
`<eng-data>` / `<point>` entries.

| `<engine>` attribute | Meaning |
|---|---|
| `mfg`, `code` | Manufacturer name; unique engine identifier (lookup key) |
| `type` | `single-use` / `reloadable` / `hybrid` — **not in `.eng`** |
| `dia`, `len` | Diameter, length (mm) |
| `initWt`, `propWt` | Initial (loaded) and propellant mass (g) |
| `Itot`, `avgThrust`, `peakThrust`, `burn-time` | Total impulse (N·s), average/peak thrust (N), burn duration (s) — explicit, not derived |
| `delays` | Comma-separated ejection-delay list |
| `auto-calc-mass`, `auto-calc-cg` | If `1`, simulator generates mass/CG curves internally: `m(t) = initWt − (propWt/burnTime)·t`; CG fixed at casing center |
| (rendering) | `tDiv`, `FDiv`, etc. — graph-drawing hints, optional |

| Data-point field | Meaning |
|---|---|
| `t`, `f` | Time (s), thrust (N) — required |
| `m` | Remaining motor mass (g) at `t` — **the field `.eng` cannot express** |
| `cg` | CG position (mm from reference) at `t` — enables the burning-motor CG shift OpenRocket/RockSim simulate |

Units are SI (mm/g-or-kg/N/s). If `m`/`cg` values *and* the auto-calc flags are both
absent, simulators show flat or wrong mass/CG histories — a real-world data-quality
trap in contributed files.

### Other formats

- **CSV thrust data** — static-fire test stands and RocketPy workflows use bare
  time/thrust CSV; RocketPy can also re-export CSV as `.eng`. No standard header.
- **Historical formats** — the pre-2006 ecosystem had additional simulator formats
  (wRASP-era `.eng` variant archives, Mac **CompuRoc**, **ALT4**). The current
  ThrustCurve v1 API's `format` enum is **`RASP` and `RockSim` only** (verified in the
  swagger spec), so these are effectively dead as interchange targets. *(CompuRoc/ALT4
  details not verified against primary sources; recorded here only as historical
  context.)*
- **Compiled/derived databases** — OpenRocket's `motors.db` (SQLite, gzip+SHA-256,
  weekly builds) and `thrustcurve-db` (single JSON) are downstream *packagings* of
  ThrustCurve data, not independent formats; both preserve the upstream schema.
- **Bespoke XML** — CamRocSim used its own XML motor library (see the simulation
  survey); no adoption elsewhere.

### Format comparison

| | RASP `.eng` | RockSim `.rse` |
|---|---|---|
| Encoding | Plain text | XML |
| Thrust curve | Yes (≤32 pts legacy) | Yes (no practical limit) |
| Propellant/loaded mass | Header only | Attributes + per-point `m` |
| Mass vs time | No (consumer assumes) | Yes (`m` or auto-calc) |
| CG vs time | No | Yes (`cg` or auto-calc) |
| Motor type / case | No | `type` (case still absent) |
| Certified totals (Itot, avg/peak) | Derived | Explicit attributes |
| Universality | **Every simulator** | RockSim, OpenRocket, ThrustCurve |
| Spec quality | Informal page | Informal PDF / documented-by-implementation |

Neither format carries: certification organization/date/status, per-file provenance,
pricing, hazmat classification, manufacturer URLs, or any identity beyond
`mfg`+`code` — all of that lives only in ThrustCurve's database layer. **There is no
standard machine-readable format for a *motor record* (as opposed to a thrust
curve);** the closest thing is ThrustCurve's API JSON schema.

---

## 3. Certification organizations as data sources

NAR, TRA, and CAR maintain **reciprocal certification**: a motor certified by any one
may be flown at launches of the others, and the published lists are combined.
Certification testing is performed to **NFPA 1125** (the standard itself is paywalled
and access-restricted by NFPA). Australia's AMRS certifies for its domestic market to
NFPA 1125 and recognizes CAR/NAR/TRA certifications; ThrustCurve records AMRS as a
certification organization alongside the North American three.

| Org | Body | What it publishes | Form |
|---|---|---|---|
| **NAR** (US, est. 1957) | Standards & Testing (S&T) | Certified motor list; per-motor data sheets with as-tested thrust curve and performance values; combined CAR/NAR/TRA list | Interactive web listing (`nar.org` → Rocket Motor Resources → Certified Motors) + **combined-list PDF** download; per-motor sheets linked from motor designations. Historically the per-motor sheets included "32 data points for use in altitude simulation programs" *(historical claim, from an archived combined-list PDF)* |
| **TRA** (US) | Tripoli Motor Testing (TMT) | Certification records: test data, certification documents, notices of compliance; per-motor certification PDFs | TMT page links each recently certified motor to a certification PDF **and to its thrustcurve.org page**; states TMT performance data "is made publicly available … through the thrustcurve.org website"; for the combined list it links to **NAR's** interactive listing |
| **CAR** (Canada) | Motor Certification Committee | **Certified Motor Index** + motor testing manual (`car_motor_testing_manual r20181121.pdf`) | The index is a live **Airtable** shared view linked from canadianrocketry.org — i.e., a queryable table, but on a proprietary platform with no stable API contract |
| **AMRS** (Australia) | AMRS motor certification | Domestic certifications (e.g. Southern Cross Rocketry motors); recognition of CAR/NAR/TRA certs | Web pages at rocketry.org.au; certificates hosted by the manufacturer |

Additional shared infrastructure: **motorcato.org** — the joint motor-failure
("CATO") reporting site, linked as the official failure-report channel by NAR, TRA
*and* CAR. A consortium inventory module recording burn outcomes per motor is a
natural feeder for exactly this kind of reporting.

**Assessment as data sources.** The certification organizations are the *authoritative
origin* of certified specs but are **poor machine interfaces**: one interactive
HTML listing + PDF (NAR), one page of per-motor PDFs that outsources its data
distribution to ThrustCurve (TRA), and one Airtable (CAR). None offers a documented
API or bulk machine-readable export of its own. In practice **ThrustCurve.org is the
de-facto aggregation and API layer over all of them**, with the organizations'
blessing (explicit in TRA's case). Certification *documents* (PDFs) are, however,
only available from the organizations, and decertification/expiry status is
maintained in the org lists — availability (`OOP`) in ThrustCurve is a related but
distinct concept (production status, not certification status).

---

## 4. Existing inventory-tracking solutions

**Headline finding: there is no established motor-inventory system.** The de-facto
standard for tracking a flyer's purchased motors is a **personal spreadsheet**
(Google Sheets or Excel), and a significant fraction of flyers track nothing at all.
This was checked directly against community discussion (RocketryForum "Motor
Inventory" thread, 2022+): spreadsheets dominate; physical organization (ammo cans by
diameter, ziplock bags for opened reload packs) substitutes for records; no
specialized app was named as standard by any participant. A gap, not a crowded field.

What does exist, verified individually:

| Tool | Platform / model | Motor-inventory capability | Notes |
|---|---|---|---|
| **Personal spreadsheets** | Google Sheets / Excel | Whatever the flyer builds: motors on hand, specs, sometimes flight cross-reference | The actual de-facto solution; praised for offline field use and multi-device access; zero standardization |
| **ThrustCurve.org accounts** | Web | **None** — favorites (motor bookmarks) and saved rockets (for the motor guide) only; both exposed via the getrockets/saverockets API | Closest thing to shared per-user motor state in the ecosystem; not an inventory (no quantities, purchases, burn status) |
| **Rocket Logs** (UPscaler) | iOS ($8; Android in development) | Yes: motor inventory with notes (size, case, date, price, source), rocket inventory, flight logging ("virtual flight card"), BP charge estimator | Offline-first, no accounts; **JSON and .xlsx import/export** for batch editing — implicitly acknowledging the spreadsheet as the source of truth. v1.1 (Oct 2025) |
| **Rocket Tracker** | iOS (App Store id 455751461) | Maintains an engine list and matches engines to rockets | Older app; inventory in the loose sense (catalog, not stock/burn tracking) *(feature depth unverified beyond store listing)* |
| **Motor Dashboard** (Mountain Man Rockets) | Free web tool, no login | Built "to keep an inventory of motors on hand and match them with rockets" (author's stated motivation); primarily a live browser/filter over the full ThrustCurve API dataset with motor detail panels and a cluster/staging combiner | Demonstrates the API-consumer pattern an inventory module would use; local-only persistence *(inventory-feature depth unverified — site blocks automated fetch)* |
| **RocketReviews.com flight logs** | Web (long-running community site) | Indirect: members log flights incl. motors used; site computes statistics **including motor spend**; motor guide over its own motor database | Flight-log-first, not stock-first: records *consumption*, not on-hand inventory |
| **Flight Logs** (SourceForge) | Desktop | Motors + flights tracking | Described in-community as "a school project"; not maintained *(status unverified)* |
| **Club/vendor systems** | — | **None found.** No club-level motor inventory tool, and no point-of-sale or vendor integration (order history → inventory import) was located at any motor vendor (BuyRocketMotors, etc.) | Vendor sites commonly *link to* ThrustCurve motor pages, but no purchase-data export exists |

Two structural observations:

1. **Consumption is tracked; possession is not.** Flight logs (RocketReviews, Rocket
   Logs, personal flight cards) record which motor was burned in which flight.
   Nothing standard records the pipeline before that: purchased → in storage →
   assembled/prepped → flown/CATO'd/returned, with quantities, lot numbers, delays
   on hand, hardware (reload cases owned) vs consumables (reload kits).
2. **Reload hardware vs. propellant is the modeling wrinkle spreadsheets handle
   badly.** A reloadable "motor" in inventory is really a *case* (durable, owned,
   diameter/length-specific) plus *reload kits* (consumable, delay-adjustable,
   hazmat-relevant). ThrustCurve's `caseInfo`/`type` fields carry the linkage; no
   inventory tool surveyed models it explicitly.

---

## 5. Regulatory context relevant to inventory (brief)

Only as it shapes what an inventory record should be able to store. US-centric;
other jurisdictions flagged. *This section summarizes legal/regulatory material from
secondary sources and organization statements; it is background, not legal advice,
and the specific CFR citations were not independently verified.*

- **US federal explosives permitting (LEUP) — historical.** After the nine-year
  *Tripoli/NAR v. ATF* litigation, the DC district court ruled (March 16, 2009) that
  APCP be removed from ATF's list of regulated explosives; ATF's July 2009 open
  letter confirms APCP-only rocket motors are outside federal explosives
  licensing/permitting, recordkeeping, and storage rules (27 CFR 555). **No LEUP is
  required today for APCP motors** — an inventory module needs no federal-permit
  bookkeeping for them. Black-powder motors and some pyrotechnic devices can differ;
  and pre-2009 designs/articles referencing LEUP magazine storage are obsolete.
- **Hazmat shipping classes (why mail-order motors carry fees).** Model rocket
  motors ship as Division **1.4C** (NA0276, >30 g propellant) or **1.4S** (NA0323,
  ≤30 g); most manufacturers hold DOT special permits letting motors ≤62.5 g
  propellant ship as **Flammable Solid 4.1 (UN1325)** with Limited Quantity marking;
  larger motors ship UPS Ground with a hazmat fee (~$44 per package, varies).
  **Individuals are not parties to those special permits** — a flyer cannot legally
  re-ship motors the same way, which is why there is no meaningful resale/transfer
  tooling. Inventory-relevant fields: propellant mass per unit, shipping class,
  "acquired how" (retail on-site vs hazmat shipment).
- **Consumer sale thresholds.** US consumer ("model rocket") motors are limited to
  ≤80 N average thrust and ≤62.5 g propellant (CPSC regulations, 16 CFR 1500/1507
  family); above that, purchase/use requires NAR/TRA **high-power certification**
  (Level 1–3 by impulse class), verified at point of sale and at launches. An
  inventory module that knows the owner's cert level can flag motors the owner
  cannot legally buy or fly — a genuinely useful feature no surveyed tool has.
- **Storage.** With ATF out of the picture for APCP, storage guidance comes from
  **NFPA 1127** (high power) and **NFPA 1122** (model rocketry) codes and state/local
  fire codes adopting them; some states add their own permits (California is the
  commonly cited example — *unverified detail*). Inventory-relevant: storage
  location, quantity aggregation (total propellant mass on hand is the number a fire
  marshal conversation needs), and NFPA-code references rather than hard rules.
- **Non-US.** Canada (Natural Resources Canada explosives regs + CAR), UK/EU
  (ADR transport classes, national explosives licensing), Australia (state
  regulators + AMRS certification) all differ materially. *(Not researched in depth;
  a module should treat "regulatory profile" as pluggable per jurisdiction.)*

**Minimum regulatory-aware fields for an inventory record:** propellant type
(APCP/BP/hybrid/sparky), propellant mass per unit, hazmat class of the packaged
article, impulse class vs owner certification level, storage location, and
jurisdiction profile. Everything else above is context, not schema.

---

## Observations for the consortium

1. **ThrustCurve.org is the motor-data layer — build on it, mirror it, don't fork
   it.** It is the aggregation point the certification organizations themselves point
   to (explicitly, in TRA's case), it has a documented JSON API with incremental
   update queries, and its site code is ISC-licensed. The right consortium pattern is
   the one OpenRocket already runs: a scheduled mirror job → compiled artifact
   (SQLite/JSON) → CDN, with per-file license metadata preserved. This respects the
   single-maintainer risk without duplicating John Coker's curation work.

2. **Adopt the existing de-facto standards: `.eng` for universality, `.rse` for
   fidelity, ThrustCurve's API schema for motor records.** A Motor Inventory module
   should key motors by ThrustCurve `motorId` (with manufacturer+designation as the
   human-readable alternate key), ingest both file formats, and treat ThrustCurve's
   search-result JSON as the canonical spec record. Inventing a new thrust-curve
   format would be pure fragmentation; what *is* missing is a standard **motor
   record + provenance** format, and the pragmatic answer is "ThrustCurve API JSON,
   versioned."

3. **The inventory layer itself is a genuine gap — the community runs on
   spreadsheets.** No club tools, no vendor/POS integration, no standard app; the
   best existing efforts (Rocket Logs, Motor Dashboard) are one-person projects, and
   the most-used "feature" is .xlsx import/export. An open inventory module with a
   documented schema, first-class spreadsheet round-tripping, and offline-first
   operation (launch sites have no coverage — every successful tool in this space is
   offline-capable) would be filling empty space, not competing.

4. **Model the domain the spreadsheets can't: lifecycle and reload structure.**
   The differentiating schema is: acquisition (date, price, source, hazmat-shipped) →
   on-hand (location, quantity, delay variants) → prepped (assembled reload, delay
   drilled) → outcome (flown [link to flight log + `.eng`/sim data], CATO [feeder
   for motorcato.org], sold/transferred), with reload **cases** as durable assets
   linked to consumable **reload kits** via ThrustCurve's `caseInfo`. Consumption
   tracking already exists in flight-log tools; possession tracking does not — and
   the flight-log link is the natural join point to the rest of the Rocket Tree
   (flight logging module, simulation modules that need the exact motor flown).

5. **Certification-org data is authoritative but not machine-friendly; treat the
   orgs as verification sources, not APIs.** Keep per-motor links to NAR data
   sheets, TMT certification PDFs, and CAR's index for provenance; take the
   machine-readable data from the ThrustCurve layer. Track certification *status*
   (incl. decertification) and production status (`availability`) as separate
   fields.

6. **Bake in the light-touch regulatory fields from day one** (propellant mass,
   propellant type, hazmat class, impulse class vs owner cert level, storage
   location, jurisdiction) — they are cheap columns now and painful retrofits later,
   and cert-level-aware warnings are an immediately useful feature no existing tool
   offers. Keep rules engines pluggable per jurisdiction; do not hard-code US
   assumptions.

---

## References

All URLs accessed 2026-08-23.

### ThrustCurve.org (primary)

1. ThrustCurve.org — hobby rocket motor data. <https://www.thrustcurve.org/>
2. ThrustCurve.org. "Background" (history, maintainership, data model).
   <https://www.thrustcurve.org/info/background.html>
3. ThrustCurve.org. "ThrustCurve API" (endpoints, formats, units, auth).
   <https://www.thrustcurve.org/info/api.html> · OpenAPI spec:
   <https://www.thrustcurve.org/api/v1/swagger.json> · Live metadata:
   <https://www.thrustcurve.org/api/v1/metadata.json>
4. ThrustCurve.org. "Contribute Data" (per-file license classes: PD/free/other/unknown).
   <https://www.thrustcurve.org/info/contribute.html>
5. ThrustCurve.org. "RASP File Format." <https://www.thrustcurve.org/info/raspformat.html>
6. ThrustCurve.org. "Flight Simulators" (per-simulator motor format support).
   <https://www.thrustcurve.org/info/simulators.html>
7. ThrustCurve.org. "Motor Certification" (NAR/TRA/CAR roles, reciprocity, NFPA 1125).
   <https://www.thrustcurve.org/info/certification.html>
8. ThrustCurve.org. "Mobile App" (ThrustCurve to-go; discontinued 2025).
   <https://www.thrustcurve.org/info/mobile.html>
9. Coker, J. *thrustcurve3* [software] — ThrustCurve.org site source, ISC license.
   <https://github.com/JohnCoker/thrustcurve3>
10. `@thrustcurve/api1` [npm package] — TypeScript API client.
    <https://www.npmjs.com/package/@thrustcurve/api1>

### Motor file formats

11. *RockSim & EngEdit – Engine File (.rse) Format Guide* (third-party PDF hosted by
    ThrustCurve).
    <https://www.thrustcurve.org/thirdparty/RockSim%20Engine%20File%20Format.pdf>
12. OpenRocket wiki. "RSE File." <http://wiki.openrocket.info/RSE_File>
13. RocketPy documentation. "Thrust Source" (eng/CSV/callable/constant inputs).
    <https://docs.rocketpy.org/en/latest/user/motors/thrust.html>

### Downstream consumers

14. OpenRocket project. *motor-database* [software] — weekly ThrustCurve-API mirror →
    SQLite `motors.db` CDN backend for OpenRocket. GPL-3.0.
    <https://github.com/openrocket/motor-database>
15. broofa. *thrustcurve-db* [software] — ThrustCurve dataset re-bundled as JSON
    (npm/jsDelivr). <https://github.com/broofa/thrustcurve-db>
16. RocketPy Team. RocketPy release notes (ThrustCurve API caching/timeouts).
    <https://github.com/RocketPy-Team/RocketPy/releases>
17. Mountain Man Rockets. *Motor Dashboard — ThrustCurve.org Live Data* [web tool].
    <https://motor.mountainmanrockets.com/> · Forum thread:
    <https://www.rocketryforum.com/threads/motor-dashboard-tool.197810/>

### Certification organizations

18. National Association of Rocketry. "Rocket Motor Resources" and "Certified Motors"
    (interactive S&T listing + combined-list PDF).
    <https://www.nar.org/content.aspx?page_id=22&club_id=114127&module_id=669253> ·
    <https://www.nar.org/content.aspx?page_id=22&club_id=114127&module_id=669684>
19. Tripoli Rocketry Association. "Tripoli Motor Testing" (TMT role, NFPA 1125,
    per-motor certification PDFs, ThrustCurve as public data outlet).
    <https://www.tripoli.org/TMT>
20. Canadian Association of Rocketry. "Motor Certifications" (Airtable Certified
    Motor Index; motor testing manual).
    <https://www.canadianrocketry.org/en/certifications/motor-certifications>
21. Australian Model Rocket Society. "Motor Certification" (NFPA 1125 testing;
    recognition of CAR/NAR/TRA). <https://rocketry.org.au/education/motor-certification/>
22. MESS / motor failure reporting (linked by NAR, TRA, CAR).
    <https://www.motorcato.org/>
23. Archived Combined CAR/NAR/TRA Certified Rocket Motors List (historical PDF;
    per-motor data sheets with 32 simulation data points).
    <http://blogs.nwic.edu/rocketteam/files/2011/10/NAR-TRACombinedMotorList.pdf>

### Inventory tools and community practice

24. RocketryForum. "Motor Inventory" thread (community practice: spreadsheets,
    physical organization, no standard app).
    <https://www.rocketryforum.com/threads/motor-inventory.171720/>
25. UPscaler. *Rocket Logs* [iOS app] — rocket/motor inventory + flight logging,
    JSON/xlsx import-export. Forum thread:
    <https://www.rocketryforum.com/threads/rocket-logs-a-rocketry-companion-app.194729/>
26. *Rocket Tracker* [iOS app].
    <https://apps.apple.com/us/app/rocket-tracker/id455751461>
27. RocketReviews.com — flight logs, motor guide, motor-spend statistics.
    <https://www.rocketreviews.com/> · Feature overview:
    <https://www.blog.rocketreviews.com/site-features.html>

### Regulatory

28. ATF. *Open Letter to All Federal Explosives Licensees/Permittees re: Ammonium
    Perchlorate Composite Propellant* (July 2009) — APCP outside federal explosives
    regulation post-ruling.
    <https://www.atf.gov/explosives/docs/open-letter/all-fels-july2009-open-letter-ammonium-perchlorate-composite-propellant/download>
29. *Tripoli Rocketry Ass'n v. ATF* — litigation record.
    <https://www.courtlistener.com/opinion/2470169/tripoli-rocketry-assn-inc-v-us-bureau-of-alcohol-tobacco-firearms-and/>
30. HazMat Tool. NA0276 (model rocket motor, 1.4C) and UN0186 (rocket motors, 1.3C)
    entries. <https://www.hazmattool.com/info.php?b=NA0276> ·
    <https://www.hazmattool.com/info.php?language=en&a=Rocket+motors&b=UN0186&c=1.3C>
31. BuyRocketMotors.com. "Shipping and Certification" (vendor hazmat practice:
    special permits, 4.1 reclassification, hazmat fees, cert verification).
    <https://www.buyrocketmotors.com/pages/shipping-and-certification>
