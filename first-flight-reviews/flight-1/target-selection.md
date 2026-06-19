# Flight 1 Target Selection — Day 21

## Selected target

**CodeHawks First Flight #39: Hawk High**

## Why this target fits now

- **Size:** 243 nSLOC — small enough for a 3-day solo/shadow audit.
- **Security theme continuity:** UUPS upgradeable contracts directly reinforce the Thunder Loan storage-layout lessons.
- **Attack surface:** enrollment/payment accounting, weekly reviews, graduation/upgrade flow, role-based permissions, wage distribution.
- **Portfolio value:** real contest format, public platform, scoped deliverables, and clean enough to show as a first solo/shadow review.

## Why not the heavier alternative yet

**Sherlock DRE App dreUSD** is more resume-real but much heavier: stablecoin, ERC4626 vault, rewards, oracle, withdrawal NFT/keeper flow, governance, and LayerZero/OFT adapters. It is better after one smaller solo review, not as the first jump after guided audits.

## Day 22 kickoff scope

Create:

- `first-flight-reviews/flight-1/kickoff.md`

Include:

1. Scope
2. Contracts in scope
3. Actors / roles
4. Main user flows
5. Trust assumptions
6. 10 invariants
7. Functions to map on Day 23

## 3-day audit plan

### Day 22 — Kickoff / mental model

- Read contest page and repo README only.
- Write roles, flows, trust assumptions, and 10 invariants.
- Do not read public submissions/results yet.

### Day 23 — Function map + first pass

- Map every external/public function.
- For each: caller, purpose, state changed, assets moved, dangerous dependency.
- Mark candidate issues but do not polish yet.

### Day 24 — Checklist + candidate findings

- Run personal checklist against the code.
- Focus especially on:
  - upgrade storage layout
  - role/access control
  - accounting claims vs actual token balances
  - time/session boundary conditions
  - repeated/duplicate reviews

### Optional Day 25 — PoC/report polish

- Pick strongest candidate.
- Write PoC or precise scenario.
- Draft report-style finding.

## Research lock

Do **not** open public submissions or results until after your own report draft exists. No spoon-feeding. We are not here to cosplay as a copy-paste raccoon.
