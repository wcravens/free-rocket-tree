# Flight Logging and As-Flown Data: The Existing Landscape

A survey of what exists today for recording hobby/high-power rocket flights — flight-log
websites and apps, club launch-management and flight-card systems, certification
documentation, altimeter/flight-computer data ecosystems, telemetry and GPS-tracking
formats, and the tools (if any) that close the loop between simulation prediction and
recorded flight. The motivating consortium concept: a **Flight Log module** backed by a
flight-sim configuration separate from the design model (mass/CG overrides after the
model is prepped for flight), so that as-flown records tie to what actually flew.

*Research date: 2026-08-23. Facts verified against primary sources (vendor sites,
project repositories, published format specifications) where possible; unverified or
secondary-source items are flagged inline. Several key sites (nar.org,
rocketreviews.com) block automated access behind Cloudflare; claims about them rest on
cached search excerpts and forum sources and are flagged accordingly.*

---

## 1. Flight-log websites and applications

### 1.1 RocketReviews.com (EMRR heritage)

**What it is.** The community's longest-running flight-log website. Essence's Model
Rocket Reviews (EMRR) — the dominant kit-review site of the late 1990s–2000s — added a
Flight Log around 2007; the site continues today as RocketReviews.com with the same
database (flights entered on either incarnation appear in both). Alongside reviews it
offers per-user rocket lists, flight logs, and a "Builds" feature for documenting
construction projects. Individual users report logging hundreds of flights (one
RocketryForum user cites 440+). *(Site details verified only via search excerpts and
forum threads — the site itself is behind a Cloudflare challenge that blocks
programmatic access, which is itself a data point about machine accessibility.)*

| Aspect | Assessment |
|---|---|
| Data recorded | Per-rocket, per-flight records: rocket, motor, date, outcome, notes (exact field list unverified — site inaccessible to automated fetch) |
| Export | "My Flights" export as **BBCode/HTML** and as an **Excel spreadsheet** (`export-flights.html` page exists) |
| API | None found |
| Openness | Closed platform, free accounts; no published schema; no bulk/open data |
| Linkage to design/sim files | None |
| Status | Operating; maintenance level unclear (unverified) |

### 1.2 ThrustCurve.org — adjacent infrastructure, not a flight log

ThrustCurve.org is the de-facto motor-data repository (1,000+ motors, ~2,000 data
files) with a **documented REST API** (JSON or XML) exposing six actions: `metadata`,
`search`, `download` (simulator files, or parsed data points via `data=samples`),
`getrockets`, `saverockets`, and `motorguide`. Users can store **saved rockets**
(basic geometry/mass, used for motor guidance), and public rockets are retrievable by
any caller. The site's code is open source (`JohnCoker/thrustcurve3` on GitHub), and a
community JSON mirror of the database exists (`broofa/thrustcurve-db`).

**There is no flight-logging feature.** Its relevance to a consortium Flight Log is as
*referenceable infrastructure*: stable motor identities (manufacturer + designation +
certification data) that a flight record can point at, plus a working example of an
open hobby-rocketry API.

### 1.3 FlightSketch — device-tied cloud flight log

FlightSketch sells low-cost Bluetooth recording altimeters (Mini, Sport, Comp) whose
free iOS/Android app transfers flight data wirelessly; data can be kept local or
uploaded to the **online flight-log service at flightsketch.com**, where a free account
gives interactive plots, photos/notes, and sharing. This is the closest existing thing
to a "flights as first-class web objects" service — but it is tied to one vendor's
devices, has no published API or export schema (none found), and the company's current
activity level is modest (site active, mixed retail focus).

### 1.4 Altimeter Cloud (Rocketry Ltd) — signed flight logs and a nascent API

**What it is.** A cloud flight-data platform at altimetercloud.com operated by
**Rocketry Ltd** (UK company no. 15297535), serving the company's own line of low-cost
altimeters: the **Nano V1** (£49.99, 1.35 g, 50 Hz barometric logger) and **Mercury V1**
(£56.99, 9-axis IMU, WiFi, servo outputs), with Mercury PLUS, Neptune V1, and Jupiter V1
announced. Like FlightSketch it is a vendor-tied cloud log — but it goes materially
further on three fronts: cryptographic log verification, a public API, and cloud-side
device management.

| Aspect | Detail |
|---|---|
| Flight log | Unlimited storage; interactive charts (apogee, velocity, acceleration, stability); notes; sharing; browsable public flight listing; periodic competitions with prizes |
| Per-flight metadata | Flight number/tags, altimeter model with hardware+firmware versions, apogee, max velocity (up/down), max acceleration, burnout/landing times, sample count, log rate, **motor brand/designation** (clickable filter — free-text, not a ThrustCurve reference), date, country, stability score (Mercury), device ID linking to that device's flight history |
| Ingest | Drag-and-drop upload of device logs; Mercury V1 can **auto-upload over WiFi** post-flight |
| Formats | **CSV** plus a compressed **`.aclz`** equivalent; the upload page converts between the two. Column layout not formally specified |
| **Log verification** | The distinguishing feature: device firmware generates a **cryptographic signature over the flight data and settings** (the site variously describes an AES-256-encrypted-firmware signing scheme and a SHA-256 verification hash — exact construction unpublished); the server independently re-validates on upload and **rejects logs that have been edited**. Verification is also exposed as a standalone public tool |
| API | Documented early-stage REST API: **CSV verification (public, no credentials), flight info, upload, and search** endpoints, with account-scoped credentials promised for future private endpoints |
| Device management | Browser-based firmware update, USB/WiFi configuration, flight-summary readout |
| Free tools | ~20 web calculators/utilities: altitude predictor, descent/drift/ejection-charge/fin-flutter/rail-exit calculators, a **laser-cut parts designer** (bulkheads, centering rings, fins → DXF/SVG) and **3D-printable parts generator**, GNSS assisted-fix seed data |
| Openness | Closed source; own-brand devices only (no third-party altimeter import); free accounts. *(Feature claims verified from the site itself, 2026-08-23; no independent coverage found)* |

Two aspects matter beyond this section. **Signed, tamper-evident flight logs** are new
to the hobby: nothing else surveyed here — paper cert forms included — can prove a
recorded flight is genuine and unedited, which is exactly the property competition
scoring and (potentially) certification records need; the mechanism is proprietary,
but it demonstrates feasibility at the £50-altimeter price point. And the platform is
the ecosystem's third working example of an open(ish) hobby-rocketry web API, after
ThrustCurve and flightcard's cert-lookup worker — though, like the rest of its stack,
the schema is vendor-controlled and single-company.

### 1.5 Mobile flight-logging apps (verified current, 2026)

| App | Platform / status | What it does | Data in/out |
|---|---|---|---|
| **Rocket Logs** (Braden Carlson) | iOS/iPadOS/macOS, released Oct 2025, $7.99 | Rocket library (weight, diameter, length, ejection charge sizes), flight logs (altitude, location, landing coordinates), live analytics (totals, records, cumulative impulse), inventory, BP calculator, checklists; fully offline, no account | **Spreadsheet import/export**; full app-data export for backup; no altimeter or sim-file integration |
| **Featherweight UI** | iOS/Android, active | Vendor app for Blue Raven/Blue Jay/GPS tracker — configuration, download, live tracking (see §2.2) | CSV files on-device, shareable; KML for GPS flights |
| **FlightSketch** | iOS/Android, active | Vendor app for FlightSketch altimeters + cloud log upload | Local or cloud; no documented export API |
| **SmartLaunch 2** (GetSmart Software) | iOS, dated (v2 era ~2012–2016) | Launch/cluster simulation with saved flights synced via iCloud — a sim aid more than a flight log | iCloud only |
| Unnamed logging app in beta (developer "chewbacca", [RocketryForum thread 197687](https://www.rocketryforum.com/threads/beta-testers-wanted-iphone-logging-app.197687/), June 2026) | iOS + macOS companion, beta | The most ambitious feature set seen: **altimeter and simulator file import from multiple vendors** (incl. direct WiFi read from Eggtimer and Bluetooth from FlightSketch devices), **OpenRocket sim import**, voice notes, auto location/weather capture (NOAA/ERA5 wind profiles), photos/video, NAR/TRA/UKRA cert walkthroughs, delay recommendations, rocket catalog with photos | Freemium; formats not yet published |

The beta app is notable as independent evidence of demand for exactly the
sim-import + altimeter-import + as-flown-record combination the consortium proposes —
and that it is being built, again, as a closed silo.

### 1.6 Club launch management and electronic flight cards

- **Paper flight cards remain the universal practice.** Every club launch runs on a
  card handed through check-in → RSO → LCO (see §5 for the fields).
- **`broofa/flightcard`** (Robert Kieffer — also author of `thrustcurve-db`) is an
  **open-source (ISC) single-page web app "for managing model rocketry launch
  events"**: launches, attendees, and flight cards in a Firebase Realtime Database
  with live sync to all clients (LCO/RSO views update in real time), plus a Cloudflare
  Worker API that caches **TRA and NAR member-certification lookups** (refreshed
  daily). Deployed at flightcard-broofa.vercel.app. Last observed development activity
  Nov 2024. This is the most complete open digitization of launch-day operations
  found, though data lives in a proprietary BaaS (Firebase) with no interchange
  format.
- **iLaunch (AeroTech/RCS)** — often assumed to be launch management, it is actually a
  **wireless launch controller**: a pad box commanded from a phone app (iOS/Android)
  with safety interlocks. No flight records are produced. *(Verified from AeroTech
  product pages.)*
- **Wilson F/X Digital Control Systems** — wired/wireless (XBee) club launch-control
  hardware up to 64 pads, used by ROC, FAR, and many clubs. Marketing and forum
  material describe pad control; no evidence found of flight-card data capture or
  flight records in the PC software (claim of "pad-management software" unverified —
  site content is sparse).
- No NAR/TRA-endorsed or widely shared launch-management/flight-card database system
  was found. Clubs that digitize (e.g., NOVAAR's printable cards, Syracuse Rocket
  Club, Northern Colorado Rocketry) publish **PDF card templates**, not software.

### 1.7 NAR/TRA certification flight documentation

High-power certification (L1–L3) is documented on **paper forms**: the NAR High Power
Certification Application has the application on one side and a **safety-inspection
form on the back**, where the certification team initials blocks confirming model
safety, motor certification, and FAA-waiver status verified before flight; the flight
must be witnessed in person, with oral construction/safety questions at inspection,
and L2 adds a written exam. L3 adds a documentation package reviewed by L3CC/TAP
committee members (construction, electronics, recovery redundancy). Completed forms
are mailed/submitted to the organization; certification *status* (not flight data)
ends up in the member databases — which `broofa/flightcard` demonstrates can be
queried programmatically (its Cloudflare worker scrapes/caches both organizations'
member-cert rosters). The certification flight itself — the one flight where actual
liftoff mass, motor, and stability are formally verified by a third party — produces
**no machine-readable record at all**.

### Openness summary — flight-log services

| | RocketReviews | ThrustCurve | FlightSketch | Altimeter Cloud | Rocket Logs | flightcard (broofa) | Paper cards / cert forms |
|---|---|---|---|---|---|---|---|
| Open source | No | **Yes** (site code) | No | No | No | **Yes** (ISC) | n/a |
| Data export | Excel/BBCode | API (motors/rockets) | No API found | CSV/`.aclz` download | Spreadsheet | No (Firebase) | No |
| Public API | No | **Yes** | No | **Yes** (early: verify/info/upload/search) | No | Cert-lookup worker | No |
| Schema published | No | API docs | No | API docs; CSV layout informal | No | Implicit in code | De-facto card layout |
| Ties to design file | No | No | No | No | No | No | No |
| Ties to altimeter data | No | No | **Yes (own devices)** | **Yes (own devices, signed logs)** | Planned/no | No | No |

---

## 2. Altimeter / flight-computer data ecosystems

The major vendors each ship their own download software and their own file layout.
Everything eventually reaches the user as *some* CSV or spreadsheet — but no two
vendors share column names, units conventions, sampling-rate framing, or metadata
headers. This section documents each ecosystem, then the fragmentation.

### 2.1 Altus Metrum — the fully open reference ecosystem

**What it is.** Open-hardware, open-software flight computers and trackers by Bdale
Garbee and Keith Packard: TeleMetrum, TeleMega, TeleMini (telemetry altimeters),
EasyMini, EasyMega, EasyTimer (non-RF), TeleGPS (tracker), TeleDongle/TeleBT (ground
stations), MicroPeak. Firmware (**AltOS**) and the cross-platform Java ground software
(**AltosUI**) are **GPL v2**; source is public (git.gag.com), and the hardware designs
are likewise published under open licenses.

| Aspect | Detail |
|---|---|
| Onboard log | Flash "eeprom" log: acceleration, barometric altitude, GPS (on GPS-equipped units), voltages, pyro continuity, flight state, at high rate |
| Files | **`.eeprom`** (full-rate onboard log, downloaded post-flight) and **`.telem`** (as-received telemetry log, including RSSI), both AltosUI-native |
| Export | **CSV** (sensor values in standard units) and **KML** (Google Earth flight path) from either file type |
| Telemetry | Sub-GHz FSK with rate-1/2 constraint-4 convolutional coding; **packet formats publicly documented** in the *AltOS Telemetry* specification |
| APRS | TeleMetrum/TeleMega/TeleGPS transmit standard **APRS position reports** (compressed and uncompressed), interoperable with any ham APRS receiver; status in the comment field |
| Post-flight UI | AltosUI: graphing, flight statistics, Google Earth export, replay of recorded flights |

Altus Metrum is the proof-of-concept that a *fully open pipeline* — open firmware,
open documented RF protocol, open ground software, open export — is viable in this
market. It is also effectively the only one.

### 2.2 Featherweight — Raven, Blue Raven, GPS tracker

Closed-source but CSV-friendly. The classic **Raven4** downloads through the
Windows-only Featherweight Interface Program (FIP). The **Blue Raven** (Bluetooth LE)
uses the **Featherweight UI app** (iOS/Android): after a flight it automatically pulls
a **low-rate and a high-rate data file, stored as CSV on the phone**, shareable by
email/etc.; flight summaries (apogee, max velocity, event times) are shown in-app, and
data stays on the altimeter until explicitly erased. High-rate inertial data is
recorded at ~500 Hz *(rate widely reported; not verified against a primary spec)*.
The **Featherweight GPS tracker** (900 MHz LoRa to a paired ground station, phone
display) exports recorded tracks including a **`.kml` file** and flight-summary +
time-history export; the packet format is not published, and a community tool
(`fw2kml`) exists to convert its data files for Google Earth. FIP v2 can also plot the
phone-downloaded Blue Raven files. No public file-format spec for any of it.

### 2.3 Eggtimer Rocketry — open-spec telemetry, kit hardware, closed firmware

Eggtimer sells solder-it-yourself kits (Quark, Quantum, ION, Proton altimeters;
Eggfinder GPS trackers). Flight data downloads over USB serial **directly as CSV**
("use with virtually any spreadsheet…"). Uniquely among the closed vendors, Eggtimer
**publishes its telemetry format**: a one-page public spec (May 2021) describing a
human-readable ASCII stream — trigger byte + 1–8 ASCII data bytes + `>` terminator,
sent every 2 s, with elements for flight time, altitude, velocity, acceleration,
flight phase (9 coded states), pyro-channel status, temperature, battery voltage,
callsign, and post-apogee apogee/max-velocity/max-acceleration retransmission; which
elements appear depends on the device. Eggfinder GPS units stream standard **NMEA**
sentences over the RF link (the telemetry spec's trigger characters were chosen not to
collide with NMEA). Firmware itself is not open source. *(Format details verified
directly from the published PDF.)*

### 2.4 PerfectFlite — StratoLogger family

The StratoLogger SL100/CF samples altitude, temperature, and battery voltage at
20 samples/s; download requires the proprietary **DT4U** USB adapter and the Windows
**DataCap** program for graphing/printing. (The older "FlightView" name attaches to
PerfectFlite's earlier miniAlt-era software — unverified.) Data can be coaxed into
spreadsheets (users rename the saved file to `.xls`), and the serial protocol has been
reverse-documented by university teams (e.g., UND ARC's StratoLogger interface notes),
but there is no vendor-published file or protocol spec and no non-Windows support.

### 2.5 Jolly Logic — AltimeterOne/Two/Three

Consumer-grade recording altimeters. AltimeterOne/Two show summary numbers on an LCD
(no download). **AltimeterThree** logs to a phone app (iOS/Android) over Bluetooth,
where flights can be viewed, trimmed, annotated, and **shared as a standard
spreadsheet file**. No published format, no desktop path, app-bound workflow.

### 2.6 MissileWorks — RRC2/RRC3, RTx

The RRC3 dual-deploy altimeter logs altitude/velocity/temperature/voltage and
downloads via the UDC USB interface into the Windows **mDACS** application
(mDACS v1.61 also serves the RTx GPS telemetry system) for plotting and device
configuration. Proprietary format; CSV export from mDACS is reported by users but not
verified against vendor documentation.

### 2.7 Open-source DIY flight computers (brief)

A large ecosystem of open flight-computer projects exists on GitHub — e.g.
`SparkyVT/HPR-Rocket-Flight-Computer` (Teensy-based, 1,600 samples/s logging, GPS +
LoRa telemetry), `shanet/Osprey` (telemetry/tracking + dual deploy), BPS.space
designs, university team avionics. Each defines yet another ad-hoc CSV/binary log
layout; none has become a de-facto standard.

### Format fragmentation — the state of play

| Vendor | Download path | Native format | Spec published? | CSV out | KML out | Open source |
|---|---|---|---|---|---|---|
| Altus Metrum | USB / RF, AltosUI (Win/Mac/Linux) | `.eeprom`, `.telem` | **Yes** (telemetry spec; code is the file spec) | **Yes** | **Yes** | **Yes (GPL v2)** |
| Featherweight | FIP (Win) / phone app (BLE) | Proprietary + CSV pair (low/high rate) | No | **Yes** | GPS tracker: yes | No |
| Eggtimer | USB serial / 70cm or 900MHz RF | CSV; ASCII telemetry stream; NMEA (GPS) | **Yes** (telemetry) | **Yes** | Via community tools | Hardware kit; firmware closed |
| PerfectFlite | DT4U + DataCap (Win) | Proprietary (`.dat`-style) | No (community reverse docs) | Workaround (`.xls` rename) | No | No |
| Jolly Logic | Phone app (BLE) | App-internal | No | Spreadsheet share | No | No |
| MissileWorks | UDC + mDACS (Win) | Proprietary | No | Reported (unverified) | No | No |
| FlightSketch | Phone app (BLE) → cloud | App/cloud-internal | No | Unclear | No | No |
| Rocketry Ltd (Altimeter Cloud, §1.4) | USB / WiFi auto-upload → cloud | CSV / `.aclz`, firmware-signed | Partial (API docs; CSV columns informal) | **Yes** | No | No |
| DIY (SparkyVT etc.) | SD card | Ad-hoc CSV/binary | Per-project | Usually | Sometimes | Usually |

**There is no common flight-data format.** The nearest things to interchange are
(a) "some CSV, columns vary," (b) KML for trajectory display, and (c) APRS/NMEA on the
radio side. No vendor CSV carries structured metadata identifying the *vehicle
configuration* that flew (motor, mass, CG, delay) — at best a device serial number and
flight index.

---

## 3. Telemetry and GPS-tracking data (brief)

Downlink and recovery-tracking practice clusters around four format families:

1. **APRS (AX.25 position reports, amateur 70 cm/2 m).** Used by Altus Metrum
   (TeleMetrum/TeleMega/TeleGPS, compressed and uncompressed formats documented) and
   BigRedBee BeeLine GPS transmitters. Interoperable with the entire ham ecosystem —
   handheld TNCs, aprs.fi, Google-Earth bridges. Requires a ham license; position-only
   (plus a comment field).
2. **NMEA sentences over a transparent serial radio link.** Eggfinder's model: the
   airborne GPS streams NMEA; the ground unit forwards it to displays/phones. Trivially
   parseable; position-only; no vehicle metadata.
3. **Vendor-proprietary packet formats.** Featherweight GPS (LoRa), MissileWorks RTx,
   most DIY LoRa telemetry. Only Altus Metrum and Eggtimer publish their packet
   specifications.
4. **KML as the universal post-flight trajectory format.** AltosUI exports KML;
   Featherweight exports KML; BigRedBee's BRB433L stores a KML onboard; community
   converters (fw2kml, TH-D72 workflows) exist; RocketPy *imports nothing but exports*
   trajectories and dispersion ellipses to KML. KML is display-oriented (Google
   Earth) — coordinates and altitude, no sensor channels — but it is the one format
   nearly everyone can emit.

For a Flight Log module, telemetry formats matter mainly as *sources* to ingest; the
observed pattern (documented ASCII/APRS at the open end, undocumented binary at the
closed end, KML as lowest-common-denominator output) mirrors §2.

---

## 4. Sim-vs-actual: does anything close the loop?

This is the consortium's central question, and the answer is: **only one tool has
shipped anything, and it is very recent.**

### 4.1 OpenRocket — requested, acknowledged, not implemented

OpenRocket's own documentation lists *"Importing and plotting actual flight data from
altimeters"* under **Planned Future Features** — it is not in any released version
(through 24.12). The request is crisply articulated in GitHub issue **#2356** ("Import
external logs," Sept 2023, still open as of this research), which reads like the
consortium README avant la lettre:

> "a standardized format for importing logs created by other programs … I'd probably
> lean towards a JSON-based format. Store them somehow associated with, or in, the
> .ORK file. Eventually, I'd like to be able to compare actual flights with
> simulations … I'd also like to be able to input additional info concerning the
> flight, such as actual mass/weight, altitude ASL for the launch site, etc."

What OpenRocket *does* have today is the other half of the story: per-flight
**flight configurations** (motor + deployment settings per simulation) and mass/CG
overrides, i.e. the "prepped-for-flight configuration separate from the design
model" — but flights flown against those configurations cannot be recorded, imported,
or compared inside the tool. Community practice is manual: fly, read apogee off the
altimeter, tweak the sim (mass override, drag fudge) until it matches, repeat.

### 4.2 RocketPy — FlightDataImporter and FlightComparator

RocketPy is the only surveyed tool with shipped, first-class sim-vs-actual machinery
(verified in the `RocketPy-Team/RocketPy` source tree):

- **`FlightDataImporter`** (`rocketpy.simulation.flight_data_importer`): builds a
  `Flight`-like object **from a `.csv`/`.txt` recorded flight log**, with a
  user-supplied `columns_map` translating arbitrary vendor column names onto ~30
  canonical flight attributes (altitude, vx/vy/vz, accelerations, quaternions,
  lat/lon, Mach, stability margin, …) with unit conversion. The column map *is* the
  admission that no standard exists: every altimeter needs its own mapping.
- **`FlightComparator`** (`rocketpy.simulation.flight_comparator`): compares a RocketPy
  `Flight` "against external data sources (such as flight logs, OpenRocket
  simulations, RASAero)," handling resampling/time-interpolation across different
  recording frequencies and computing **error metrics (RMSE, MAE, etc.)**, with
  plotting helpers. Documented at `docs/user/flight_comparator.rst`.
- The documentation's flights gallery (~19 real flights from EPFL, Notre Dame, Projeto
  Jupiter, and others) opens with a **measured-vs-simulated apogee comparison plot**,
  and acceptance tests in CI validate simulated apogee/max-velocity/event times
  against recorded flight data for specific rockets (e.g. Prometheus, Valetudo,
  Bella Lui) — self-reported apogee errors in the 0.5–5% range.

This is the strongest existing prior art for the consortium's loop-closing ambition —
but it is a *library workflow for engineers*, not a flight log: nothing is persisted,
there is no flight-record store, and the as-flown configuration (which motor, what
liftoff mass) lives in the user's script, not in a schema.

### 4.3 Everything else

No flight-log website or mobile app surveyed performs any comparison against a
simulation. The June-2026 beta iPhone app (§1.5) advertises importing both OpenRocket
sims and altimeter data into one flight record — the first consumer product seen to
attempt the pairing — but it is unreleased and closed. Flight-computer vendor software
(AltosUI, FIP, DataCap, mDACS) plots recorded data only; none loads a prediction.

---

## 5. As-flown configuration records

### 5.1 The paper analog: the flight card

The flight card is the only *universally practiced* as-flown record in the hobby. From
a verified club card (METRA; NOVAAR/Syracuse/NCR cards are closely similar), the
fields are:

| Section | Fields |
|---|---|
| Admin | Pad number; flyer name; NAR/TRA member number; city/state; **cert-flight flag** |
| Vehicle | Rocket name; color(s) (for tracking in the air); diameter & length |
| Prediction | **Expected peak altitude** (a sim output, transcribed by hand) |
| Propulsion | Motor(s): type, diameter, count |
| Electronics | Free text + checkboxes: dual deploy (with main-deploy altitude), air starts, staged, tracker |
| Recovery | Parachute size, drogue size, streamer, separate nose-cone recovery, other |
| Pad needs | Rail (mini/1010/1515/Unistrut) or rod size |
| RSO block | **Rocket weight** (measured at check-in), comments, RSO initials |

Note what the RSO line implies: at essentially every high-power launch in the country,
the *actual liftoff mass* of the as-flown vehicle is measured or verified and written
down — then the card goes in a shoebox. Delay drilled, measured CG (against the marked
CP), and igniter/charge details are commonly checked verbally or noted in comments but
are not standard fields. Certification flights add the witnessed safety-inspection
form (§1.7) — again paper.

### 5.2 Digitization efforts

- **`broofa/flightcard`** (§1.6) digitizes the card itself — flyer, rocket, motor,
  pad, RSO/LCO workflow — in real time, with live NAR/TRA cert verification. It is the
  only found system where an as-flown record (card + RSO check) exists as structured
  data. Its records do not link to design files, sims, or altimeter data, and reside
  in a private Firebase instance.
- **Rocket Logs** and similar apps (§1.5) let the flyer self-record actual motor,
  altitude achieved, and landing location per flight, with spreadsheet export — a
  personal, unstandardized as-flown log.
- **ThrustCurve saved rockets** store a vehicle's dry mass/geometry for motor
  selection — a design-side summary, never connected to flights.
- **Simulation side:** OpenRocket's flight configurations + per-component/stage
  mass/CG/CD overrides, RASAero's directly entered liftoff weight/CG, and RocketPy's
  direct-input mass properties (surveyed in the companion simulation report) all
  provide the *pre-flight* half — a sim configuration decoupled from the design
  model — but none of them can attach a *post-flight* record to that configuration.

**Conclusion:** the exact as-flown vehicle (actual liftoff mass, actual motor and
delay, measured CG, field repairs) is recorded today only on paper cards and in
memory. No surveyed system persists it digitally in a form linked to either the design
file or the recorded flight data.

---

## 6. Gaps

Stated explicitly, because this module's landscape — unlike simulation's — is mostly
empty space:

1. **No standard flight-record schema.** Nothing plays the role RASP `.eng` plays for
   motors or `.ork`/`.rkt` play for designs. Every altimeter CSV, every website, every
   app has private columns. RocketPy's `columns_map` and OpenRocket issue #2356 both
   independently reinvent "we need a canonical field list."
2. **No design-file linkage.** No flight record anywhere carries a reference to the
   design document (or its version/hash) of the vehicle that flew. Sim files
   (`.ork`) store simulations; flight logs store flights; nothing joins them.
3. **No as-flown configuration object.** The "flight-sim configuration separate from
   the design model" exists pre-flight in OpenRocket/RASAero/RocketPy, and its
   real-world counterpart is measured at every RSO table — but no schema captures
   {design ref + motor instance + drilled delay + measured mass/CG + charges +
   recovery config} as a durable record that both a simulator and a flight log can
   reference.
4. **No sim-vs-actual loop in any end-user tool.** RocketPy's FlightComparator is the
   only shipped implementation, and it is script-level. OpenRocket's is a 3-year-old
   open feature request. Websites and apps do not attempt it.
5. **Vendor data-format fragmentation with mostly undocumented formats.** Only Altus
   Metrum (fully open) and Eggtimer (published telemetry spec) document their data
   paths; Altimeter Cloud documents its API but not its log columns or signing
   scheme; PerfectFlite, Featherweight, Jolly Logic, MissileWorks, FlightSketch are
   effectively closed, several Windows-only.
6. **No flight-data metadata.** Even the open formats identify the *device and flight
   index*, not the vehicle, motor, site, or flyer; pairing a data file with a flight
   is manual bookkeeping.
7. **Institutional records are paper.** Certification flights — the best-verified
   flights flown — produce no digital flight record; club flight cards are discarded.
   The one open digitization (flightcard) is a single-maintainer project on a
   proprietary backend.
8. **No open aggregate dataset.** Thousands of well-instrumented flights are recorded
   yearly; there is no public corpus pairing designs, conditions, and recorded data —
   the dataset any simulation-validation effort (see the companion report's
   "published validation suite" requirement) would want.

---

## Observations for the consortium

1. **This module has no incumbent to interoperate with — the consortium would be
   defining the first real standard.** Unlike simulation (where `.ork`/`.eng` already
   anchor interchange), flight logging has no de-facto format to adopt. The practical
   anchors that *do* exist and should be referenced rather than reinvented:
   ThrustCurve motor identities, NAR/TRA member numbers, design-file references
   (`.ork` et al.), KML for trajectory display, and ISO-standard geodetic/time types.
2. **The as-flown configuration should be the schema's pivot.** The evidence
   converges from three directions: simulators already separate flight configuration
   from design model (OpenRocket flight configs, RASAero/RocketPy direct mass
   inputs); the RSO table already measures the as-flown vehicle at every launch; and
   OpenRocket #2356 explicitly asks to store actual mass/site data with the design.
   A `FlightRecord` that references a `FlightConfiguration` (which references a
   design + overrides) — rather than a flat log row — is what closes the loop and is
   what nobody has built.
3. **Ingest breadth is the adoption lever, and it is tractable.** A converter layer
   over ~8 vendor formats (Altus Metrum `.eeprom`/CSV, Featherweight CSV pair,
   Eggtimer CSV/telemetry, PerfectFlite, Jolly Logic, MissileWorks, FlightSketch,
   generic CSV-with-column-map à la RocketPy's `FlightDataImporter`) would cover
   nearly the whole installed base. RocketPy's canonical-attribute list is a ready
   starting point for the field dictionary; Altus Metrum and Eggtimer prove vendors
   will tolerate (or embrace) documented formats.
4. **Partner-shaped prior art exists.** RocketPy's
   `FlightDataImporter`/`FlightComparator` (MIT) could consume or emit the
   consortium format with minimal friction; OpenRocket has an open issue asking for
   exactly this and a preference for "a JSON-based format"; `broofa/flightcard` (ISC)
   demonstrates launch-day capture including live NAR/TRA cert checks; Altus Metrum
   shows a fully open device pipeline. A consortium flight-record schema with those
   four integrations would immediately span device → launch ops → log → sim
   comparison.
5. **Launch-day capture is where as-flown truth exists — meet it there.** The RSO
   weight measurement and motor check happen once, at the field, on paper. A
   flight-card-shaped front end (or an adapter for flightcard-style systems) that
   emits consortium flight records would capture liftoff mass, motor, delay, and cert
   status at the moment they are verified, rather than asking flyers to transcribe
   later — the failure mode of every personal logging app to date.
6. **Sim-vs-actual comparison should be a library function over the standard record**
   (resampling, error metrics, event alignment), per the RocketPy pattern — usable
   headlessly by any front end — rather than a feature locked inside one GUI. Paired
   with an open aggregate corpus of contributed flight records, it would also supply
   the validation benchmark data the consortium's simulation-core ambitions require.
7. **Mind the closed-platform trap.** The most active current development (FlightSketch
   cloud, Altimeter Cloud, Rocket Logs, the 2026 beta app) is all closed, device- or
   app-siloed, and export-poor — the flight-logging ecosystem is fragmenting in real
   time exactly the way the consortium README warns about. A published schema with
   permissively licensed reference readers/writers, offered early to those
   developers, is the countermove.
8. **Tamper-evident flight records are worth standardizing.** Altimeter Cloud's
   firmware-signed logs (§1.4) show that cryptographic authenticity for flight data
   is feasible on £50 hardware — the property competition scoring, altitude records,
   and certification flights actually need, and one no paper process provides. Its
   scheme is proprietary and single-vendor; a consortium flight-record schema could
   define an open signature envelope (device-attested hash over data + configuration)
   that any vendor's firmware could implement, making verifiability an ecosystem
   property instead of a platform lock-in feature.

---

## References

All URLs accessed 2026-08-23.

### Flight-log websites and apps

1. RocketReviews.com (EMRR successor): flight logs, builds, reviews.
   <https://www.rocketreviews.com/> · Flight log: <https://www.rocketreviews.com/my-flights.html> ·
   Export: <https://www.rocketreviews.com/export-flights.html>
2. "EMRR/RocketReviews.com Flight Log Improvements Beta Release." Ye Olde Rocket
   Forum (EMRR heritage and shared database).
   <https://www.oldrocketforum.com/forum/weather-cocked/freeforall/13899-emrr-rocketreviews-com-flight-log-improvements-beta-release>
3. ThrustCurve.org API documentation. <https://www.thrustcurve.org/info/api.html>
4. Coker, J. *thrustcurve3* [software] — ThrustCurve.org site source.
   <https://github.com/JohnCoker/thrustcurve3>
5. Kieffer, R. (broofa). *thrustcurve-db* [software] — JSON mirror of ThrustCurve data.
   <https://github.com/broofa/thrustcurve-db>
6. FlightSketch — Bluetooth altimeters and online flight-log service.
   <https://flightsketch.com/> · FlightSketch Mini:
   <https://flightsketch.com/store/catalog/flightsketch-mini_1/>
7. Carlson, B. *Rocket Logs* [iOS app], released 2025-10-27.
   <https://apps.apple.com/us/app/rocket-logs/id6752035826> · Announcement thread:
   <https://www.rocketryforum.com/threads/rocket-logs-a-rocketry-companion-app.194729/>
8. GetSmart Software. *SmartLaunch 2* [iOS app].
   <https://itunes.apple.com/us/app/smartlaunch-2/id568729036>
9. chewbacca (username). "Beta Testers Wanted — iPhone Logging App." RocketryForum
   thread 197687, June 13, 2026 (altimeter + OpenRocket import, cert walkthroughs).
   <https://www.rocketryforum.com/threads/beta-testers-wanted-iphone-logging-app.197687/>
10. "App for logging rocket launches?" and "Flight Logging." RocketryForum threads
    (community practice survey).
    <https://www.rocketryforum.com/threads/app-for-logging-rocket-launches.175293/> ·
    <https://www.rocketryforum.com/threads/flight-logging.145516/>
10a. Rocketry Ltd. *Altimeter Cloud* — flight data & configuration platform
    (signed-log upload/verification, public flight listing, API, altimeters, free
    tools). <https://www.altimetercloud.com/> ·
    Upload/verification: <https://www.altimetercloud.com/upload/> ·
    API: <https://www.altimetercloud.com/api/> ·
    Altimeters: <https://www.altimetercloud.com/altimeters/> ·
    Tools: <https://www.altimetercloud.com/tools/> ·
    Nano V1 manual: <https://www.altimetercloud.com/support/manuals/nanov1/>

### Launch management, flight cards, certification

11. Kieffer, R. (broofa). *FlightCard* [software] — "an application for managing model
    rocketry launch events." ISC license; Firebase + Cloudflare NAR/TRA cert-lookup
    worker. <https://github.com/broofa/flightcard> ·
    Deployment: <https://flightcard-broofa.vercel.app>
12. METRA flight card (verified field set).
    <https://metrarocketclub.org/wp-content/uploads/2020/03/Flight-Cards.pdf>
13. NOVAAR flight cards. <http://www.novaar.org/drupal7/flightcards> ·
    Syracuse Rocket Club card: <https://syracuserocketclub.org/SRC_FlightCard.pdf> ·
    Northern Colorado Rocketry: <https://ncrocketry.club/flight-cards/>
14. National Association of Rocketry. "It's Launch Day" (flight-card/RSO procedure);
    Level 1 / Level 2 HPR certification pages (paper application + safety-inspection
    form, witnessed flights, L2 written exam).
    <https://www.nar.org/site/section703/its-launch-day/> ·
    <https://www.nar.org/high-power-rocketry-info/level-1-hpr-certification/> ·
    <https://www.nar.org/high-power-rocketry-info/level-2-hpr-certification/>
15. AeroTech/RCS. *iLaunch* wireless launch controller (phone-app-driven pad
    controller — not a launch-management system).
    <https://aerotech-rocketry.com/products/ilaunch-wireless-launch-controller> ·
    <https://play.google.com/store/apps/details?id=com.aerotech.ilaunch>
16. Wilson F/X Digital Control Systems (club launch-control hardware).
    <http://www.wilsonfx.com/> · Background: 
    <https://rrs.org/tag/wilson-f-x/>
17. "Flight Card Requirements?" RocketryForum (card fields and LCO/RSO usage in
    practice). <https://www.rocketryforum.com/threads/flight-card-requirements.165814/>

### Altimeter / flight-computer vendors

18. Altus Metrum. *AltOS* firmware and *AltosUI* [software], GPL v2; product and
    source information. <https://altusmetrum.org/AltOS/>
19. Packard, K., & Garbee, B. *The Altus Metrum System: An Owner's Manual* —
    `.eeprom`/`.telem` files, CSV and KML export, APRS support.
    <https://altusmetrum.org/AltOS/doc/altusmetrum.html>
20. Packard, K., & Garbee, B. *AltOS Telemetry* — public telemetry packet-format
    specification. <https://altusmetrum.org/AltOS/doc/telemetry.html>
21. Featherweight Altimeters. Blue Raven / Raven4 product and interface-program pages
    (phone-app CSV download; Windows FIP).
    <https://www.featherweightaltimeters.com/raven-altimeter.html> ·
    <https://www.featherweightaltimeters.com/interface-program.html> ·
    Featherweight UI app: <https://apps.apple.com/us/app/featherweight-ui/id1641310058>
22. Featherweight GPS Tracker User's Manual (Feb 2025; KML and summary export).
    <https://www.featherweightaltimeters.com/uploads/1/0/9/5/109510427/gps_tracker_manual_2025feb20.pdf>
23. "fw2kml — A Tool to Convert Featherweight GPS Data to .kml files." RocketryForum.
    <https://www.rocketryforum.com/threads/fw2kml-a-tool-to-convert-featherweight-gps-data-to-kml-files-for-google-earth.176864/>
24. Eggtimer Rocketry. *Eggtimer Telemetry Data Format Specification* (May 2021) —
    public ASCII telemetry format.
    <https://eggtimerrocketry.com/wp-content/uploads/2021/05/Eggtimer-Telemetry-Data-Format.pdf>
25. Eggtimer Rocketry. Altimeters & AV-bay products (CSV data download).
    <https://eggtimerrocketry.com/home/altimeters-av-bay/>
26. PerfectFlite. StratoLogger SL100/CF pages, DT4U manual, downloads (DataCap
    software). <http://www.perfectflite.com/sl100.html> ·
    <http://www.perfectflite.com/SLCF.html> ·
    <http://www.perfectflite.com/Download.html>
27. UND Advanced Rocketry Club. StratoLogger interface documentation
    (community reverse-documentation of the serial protocol).
    <https://und-arc.github.io/StratoLogger/iface.html>
28. Jolly Logic. *AltimeterThree* [product + iOS app] (Bluetooth download, spreadsheet
    sharing). <https://apps.apple.com/us/app/altimeterthree/id924087924>
29. MissileWorks. RRC3 altimeter and mDACS software; downloads page.
    <https://www.missileworks.com/rrc3> · <https://www.missileworks.com/downloads> ·
    RRC3/mDACS user manual:
    <https://www.apogeerockets.com/downloads/PDFs/mDACS-usb-io-user-manual.pdf>
30. SparkyVT. *HPR-Rocket-Flight-Computer* [software] (representative open DIY
    flight computer, 1600 SPS logging, GPS/telemetry).
    <https://github.com/SparkyVT/HPR-Rocket-Flight-Computer>
31. shanet. *Osprey* [software] — open telemetry/tracking/dual-deploy system.
    <https://github.com/shanet/Osprey>

### GPS tracking / telemetry formats

32. BigRedBee, LLC — BeeLine GPS/APRS transmitters; BRB433L (onboard KML storage,
    flight logging). <https://shop.bigredbee.com/> · Introduction thread:
    <https://www.rocketryforum.com/threads/introducing-the-bigredbee-brb433l-gps-tracker.197072/>
33. Rocketry Organization of California. "Advanced Rocket Tracking Using Onboard
    Radio Transmitters" (APRS practice, KML workflows).
    <https://rocstock.org/learn/advanced/advanced-rocket-tracking-using-onboard-radio-transmitters/>
34. Coker, J. "GPS Tracking." jcrocket.com (survey of tracker ecosystems).
    <http://jcrocket.com/gps-tracking.shtml>

### Sim-vs-actual comparison

35. OpenRocket documentation, "Features" — *"Importing and plotting actual flight data
    from altimeters"* listed under Planned Future Features.
    <https://openrocket.readthedocs.io/en/latest/introduction/features.html>
36. OpenRocket GitHub issue #2356, "[Feature Request] Import external logs"
    (Sept 2023, open) — standardized log format, storage with the `.ork`, actual
    mass/site fields, sim comparison.
    <https://github.com/openrocket/openrocket/issues/2356>
37. RocketPy Team. `FlightDataImporter` — build a Flight object from recorded
    CSV/TXT flight data with column mapping.
    <https://github.com/RocketPy-Team/RocketPy/blob/master/rocketpy/simulation/flight_data_importer.py>
38. RocketPy Team. `FlightComparator` — compare a RocketPy flight against external
    data (flight logs, OpenRocket, RASAero) with resampling and RMSE/MAE metrics.
    <https://github.com/RocketPy-Team/RocketPy/blob/master/rocketpy/simulation/flight_comparator.py> ·
    Docs: <https://docs.rocketpy.org/en/latest/user/flight_comparator.html>
39. RocketPy Team. "Flights simulated with RocketPy" — real-flight examples with
    measured-vs-simulated apogee comparison.
    <https://docs.rocketpy.org/en/latest/examples/index.html>

### Companion report

40. *Rocket Simulation Software: Models, Inputs, and Portability.* Free Rocket Tree
    Consortium research document (this repository),
    `docs/research/rocket-open-simulation-designs.md` — flight-configuration override
    support in OpenRocket/RASAero/RocketPy referenced in §5.2 above.
