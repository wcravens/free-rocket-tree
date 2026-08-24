# Reference Library

Local copies of the primary sources cited from `docs/`.

Papers move, get paywalled, and lose their hosting. Keeping a copy here is the same bargain
we make with the pinned submodules in [`subs/`](../../subs/CLAUDE.md): a fixed artifact means a
page or section number we cite stays accurate. Cite the local file for locators, and give the
canonical link so a reader can reach the version of record.

Only redistributable copies belong here — author preprints, open-access articles, and public
technical reports. If a source is not redistributable, add an index entry with links and no file.

## Index

### RocketPy: A Six Degree-of-Freedom Rocket Trajectory Simulator

[`RocketPyASixDegree-of-FreedomRocketTrajectorySimulator-Manuscript.pdf`](RocketPyASixDegree-of-FreedomRocketTrajectorySimulator-Manuscript.pdf)
— 31 pages, 3.4 MB.

Giovani H. Ceotto, Rodrigo N. Schmitt, Guilherme F. Alves, Lucas A. Pezente, and Bruno S. Carmo
(University of São Paulo / Projeto Jupiter).
*Journal of Aerospace Engineering* (ASCE), 2021, vol. 34, no. 6.

- ResearchGate: <https://www.researchgate.net/publication/354034513_RocketPy_Six_Degree-of-Freedom_Rocket_Trajectory_Simulator>
- Version of record: <https://ascelibrary.org/doi/10.1061/%28ASCE%29AS.1943-5525.0001331>
- DOI: `10.1061/(ASCE)AS.1943-5525.0001331`
- Supporting data and code: <https://doi.org/10.5281/zenodo.4279966>

The peer-reviewed description of RocketPy's physics and architecture — the companion to the source
vendored at [`subs/rocketpy`](../../subs/CLAUDE-rocketpy.md), and the citation behind the RocketPy
section of [Rocket Simulation Software: Models, Inputs, and Portability](../research/rocket-flight-simulation-designs.md).

**What it covers.** After the introduction it runs: *RocketPy Architecture* (the four-class data
flow — Solid Motor → Rocket, plus Environment, into Flight; Figure 1); *Simulation Models and
Methods* (environment and atmospheric models, solid motor model, rocket model, then the flight
model broken into launch-rail motion, six-degree-of-freedom free flight, descent under parachute,
and numerical integration; the phase-switching integrator is Figure 3); and *Results* (comparison
against other simulators, validation against measured flight data, Monte Carlo dispersion analysis,
and the Multivariate Rejection Sampling algorithm).

**Why it is worth reading directly.** Three things are stated more plainly here than anywhere in
the source tree or the online docs:

- **The equations of motion**, including the mass-variation and nozzle-gyration terms that make
  `u_dot_generalized` differ from the simpler `u_dot`.
- **The phase-switching integrator design** (Figure 3) — the paper's diagram of rail → free flight
  → parachute with trigger feeds is the clearest available picture of what `Flight.__simulate` does.
- **Multivariate Rejection Sampling**, the paper's own contribution: re-weighting a completed Monte
  Carlo run to a new input distribution instead of re-simulating. It survives in the code as
  `simulation/multivariate_rejection_sampler.py`.

**Validation results** (Table 3), useful as a yardstick for any simulator we build or compare:

| Mission | Parameter | RocketPy | Measured | Rel. error |
|---|---|---|---|---|
| Bella Lui Kaltbrunn (ERT) | Apogee altitude | 461.03 m | 458.97 m | 0.45% |
| | Apogee time | 10.61 s | 10.56 s | 0.47% |
| | Max velocity | 86.18 m/s | 90.00 m/s | 4.24% |
| NDRT launch vehicle | Apogee altitude | 1310.44 m | 1320.37 m | −0.75% |
| | Apogee time | 16.77 s | 17.10 s | −1.90% |
| | Max velocity | 172.86 m/s | 168.95 m/s | 2.31% |

A third vehicle, Projeto Jupiter's *Valetudo*, is used for the software-to-software comparison
against OpenRocket and the Cambridge Rocketry Simulator, and for the Monte Carlo dispersion study.

**Read it as a 2021 snapshot, not as documentation of the pinned code.** The paper describes
RocketPy well before v1.0.0, and several of its stated limits have since been lifted — it covers
**solid motors only** and lists hybrid and liquid motors as future work, where the vendored v1.13.0
tree ships `LiquidMotor`, `HybridMotor`, `RingClusterMotor`, and tank models. It also predates the
`camelCase` → `snake_case` rename, so its API names no longer match. Limits that do still hold in
the current code: Barrowman-based aerodynamics, instantaneous parachute inflation, and **6-DOF
motion only during ascent** — descent under parachute is integrated with a reduced model.

*Note on dates:* the PDF is the authors' preprint and carries an August 23, 2022 footer, while the
journal article it points to was published in 2021. Cite the 2021 article; use the PDF for page
locators.

## Adding a reference

Keep the two halves together — a file with no entry is unattributed, and drift between them is
worse than either alone.

1. Drop the file in this directory. Keep the publisher's filename if it has one; otherwise use a
   descriptive name rather than a bare identifier.
2. Add a section to the index above with: the local link, the full author list, the publication and
   year, a DOI or other stable identifier, the canonical URL, and enough of a summary that someone
   can tell from this page alone whether the source answers their question.
3. Say what has gone stale. Every source here is a snapshot; the gap between it and the current
   software is usually the most useful thing we can record about it.
