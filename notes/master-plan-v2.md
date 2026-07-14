# Web3 Security Career Master Plan — Version 2.0
## Date: 14 July 2026 (Day 42/52) → Target: 30 July 2026 (End of Plan) & Post-Plan (Aug-Dec 2026)
## Single Source of Truth for Gintoki / Mayur

This master plan integrates your 4.5-month runway, your 40,000 INR monthly target, your spoken English bottleneck, your home hacking setup (floor + hall TV), and your specialized **Vaults & Yield** primitive track. It replaces all previous roadmaps.

---

## Part 1: Educational Resources — "Vaults & Yield" Deep Dive
Before you open the code for Protocol 4 or 5, you must spend **July 15 - July 17** studying these exact external resources. This will build your mathematical and logical foundation so you do not go in empty-handed.

### 1. ERC-4626 & Vault Rounding Mechanics (Core Vault Foundations)
*   **RareSkills: ERC4626 Tokenized Vault Standard**
    *   *Link:* `https://rareskills.io/post/smart-contract-security` (Navigate to their specialized ERC-4626 guides).
    *   *What to study:* Master the formulas for `convertToShares` and `convertToAssets`. Understand why the standard requires rounding *down* for deposits (so users get slightly fewer shares and the vault is protected) and rounding *up* for withdrawals (so users pay slightly more assets, preventing 1-wei exploits).
*   **MixBytes Blog: Yield & Vault Defect Analysis**
    *   *Link:* `https://mixbytes.io/blog` (Search for "Vaults", "ERC-4626", "inflation").
    *   *What to study:* Read their deep-dives on vault share inflation attacks. Learn how a first-depositor donates 1 million tokens directly to the vault to inflate the exchange rate, making subsequent small deposits round to zero shares.
*   **Mr. Steal Yo Crypto: Vaults Chapter**
    *   *Link:* `https://mrstealyocrypto.xyz/index.html` (Read the "Vaults" and "Flash Loans" sections).
    *   *What to study:* Study how flash loans are used to manipulate the underlying token balances of vaults to artificially inflate share values before calling `withdraw()`.

### 2. Real-World Vault & Yield Exploits (Case Studies)
*   **SunWeb3Sec's DeFi Hacks Analysis Database**
    *   *Link:* `https://wooded-meter-1d8.notion.site/0e85e02c5ed34df3855ea9f3ca40f53b?v=22e5e2c506ef4caeb40b4f78e23517ee`
    *   *What to study:* Filter for "Vault", "Yield", "Share Inflation", and "ERC4626".
    *   *Specific targets to study:*
        *   **Euler Finance (Donation Attack):** How donating funds directly to the vault broke the internal accounting logic.
        *   **Wyre / Rari Capital Rounding Exploits:** How subtle rounding issues during conversions allowed attackers to drain assets in small, repetitive transactions.

### 3. Crowdfunding & Escrow Milestone Logic (CrowdHelp Foundations)
*   **Solidity by Example: Crowd Fund**
    *   *Link:* `https://solidity-by-example.org/` (Go to "Crowd Fund" and "Multi-sig Wallet").
    *   *What to study:* Study the state transitions of pledges, campaign deadlines, and refund states. See how the state machine prevents double-claims and reentrancy during payouts.
*   **The Red Guild Blog: Escrow & Trust Assumptions**
    *   *Link:* `https://blog.theredguild.org/`
    *   *What to study:* Read their breakdowns of trust assumptions in peer-to-peer escrows. Learn to map out the exact permissions of the Admin/Principal versus the Users/Contributors.

---

## Part 2: Tactical 16-Day Schedule (15 July → 30 July 2026)

### Phase 5A: Pure Study & Theoretical Calibration
#### Days 43–44 (15 Jul → 16 Jul) — ERC-4626 & Rounding Masterclass
*   **Focus:** Core Vault Accounting Math.
*   **Action:** Read the RareSkills, MixBytes, and Mr. Steal Yo Crypto vault guides.
*   **Output:** In `audit-dojo/checklists/personal-checklist-v2.md`, create a dedicated section titled `# DEFI PRIMITIVES: ERC-4626 VAULTS` listing 10 critical validation checks (including rounding directions and first-depositor inflation protections).

#### Day 45 (17 Jul) — Real Hack Analysis
*   **Focus:** Reverse-engineering real exploits.
*   **Action:** Open SunWeb3Sec's Notion database. Find 2 classic vault hacks. Tracing the transaction logs and writing down the exact state changes in your own words.
*   **Output:** Save notes in `notes/vault-hack-breakdowns.md`.

---

### Phase 5B: Protocol 4 — BattleChain Confidence Pools (Staking & Pools)
#### Day 46 (18 Jul) — BattleChain Confidence Pools Kickoff
*   **Focus:** Scope, setup, and mental model.
*   **Action:** Clone the codebase (`git clone https://github.com/CodeHawks-Contests/2026-07-bc-confidence-pools.git`). Set up a new folder `guided-audits/bc-confidence-pools/`. Write `PLAN.md` mapping out the actors, system goals, yield sources, and 8 invariants.
*   **Output:** `PLAN.md` compiled.

#### Days 47–48 (19 Jul → 20 Jul) — BattleChain Confidence Pools Scanning
*   **Focus:** Manual codebase audit.
*   **Action:** 
    *   *Pass 1 (July 19):* Trace the yield routing and deposit/stake and reward distribution mechanisms. Create a detailed function map.
    *   *Pass 2 (July 20):* Run your upgraded checklist over the math conversions. Look for fee-on-transfer, precision loss, or reentrancy vectors.
*   **Output:** `checklist-pass.md` and `candidate-findings.md`.

#### Day 49 (21 Jul) — The Comparison & PoC Day
*   **Focus:** Verifying findings under fire.
*   **Action:** Open the official Code4rena BattleChain Confidence Pools audit report. Compare your candidate findings with the published results. If you caught a valid finding, write a green Foundry PoC for it. If you missed a finding, study the root cause and update your checklist.
*   **Output:** `report-draft.md` + active Foundry test proving any vulnerabilities.

#### Day 50 (22 Jul) — BattleChain Confidence Pools Finalization & X Thread
*   **Focus:** Polishing output and building visibility.
*   **Action:** Write the final structured report. Draft a 3-part educational X thread detailing a mathematical invariant or vulnerability you analyzed in BattleChain Confidence Pools.
*   **Output:** `guided-audits/bc-confidence-pools/final-report.md` + X thread drafted.

---

### Phase 5C: Protocol 5 — CrowdHelp Audit (Independent Open Source Audit)
#### Day 51 (23 Jul) — CrowdHelp Kickoff
*   **Focus:** Setting up the blind audit.
*   **Action:** Clone `https://github.com/Balaji-Ganesh/CrowdHelp-Blockchain-based-crowdfunding-platform.git`. Set up `first-flight-reviews/crowdhelp/`. Write `PLAN.md` mapping out campaign initialization, milestone release triggers, and refund logic.
*   **Output:** `PLAN.md` compiled.

#### Days 52–53 (24 Jul → 25 Jul) — CrowdHelp Blind Auditing
*   **Focus:** Independent scanning.
*   **Action:** 
    *   *Pass 1 (July 24):* Audit access control on milestone execution and withdrawal functions.
    *   *Pass 2 (July 25):* Audit state transition logic. Can a contributor execute a reentrancy attack on refunds? Can a campaigner claim milestones twice?
*   **Output:** `checklist-pass.md` + draft findings.

#### Day 54 (26 Jul) — CrowdHelp Exploit Development
*   **Focus:** Proof of Concept.
*   **Action:** Choose your strongest blind finding. Write a custom Foundry exploit test in `pocs/` that demonstrates the exploit and drains funds or bypasses milestones.
*   **Output:** Green exploit test on CrowdHelp.

#### Day 55 (27 Jul) — CrowdHelp Final Report & X Thread
*   **Focus:** Independent report delivery.
*   **Action:** Package the final report using the standard template. Draft a Twitter thread highlighting how you audited an active open-source crowdfunding codebase and developed an exploit PoC.
*   **Output:** `first-flight-reviews/crowdhelp/final-report.md` + X thread drafted.

---

### Phase 5D: Final Packaging, Resume, & Pitch Customization
#### Day 56 (28 Jul) — Resume Mastery (Indian & Boutique Focus)
*   **Focus:** ATS optimization and profile alignment.
*   **Action:** Compile your master resume focusing on your specialized "Vaults & Yield" expertise. Add your 5 completed reviews (including BattleChain Confidence Pools and CrowdHelp) and your 100% tested MultiSig.
*   **Output:** Resume PDF generated and pinned on your `mayurrajput04` profile.

#### Day 57 (29 Jul) — Application Setup & Pitch Optimization
*   **Focus:** Target sourcing.
*   **Action:** Research and list 15 boutique/domestic firms (QuillAudits, CredShields, BlockSec, Shieldify) and the Sherlock/Cantina triager application pipelines in `notes/job-tracker.md`. Prepare your semi-customized pitches.
*   **Output:** Pitch templates saved.

#### Day 58 (30 Jul) — Final Review & The X Campaign Launch
*   **Focus:** Plan close-out.
*   **Action:** Write your `notes/final-review-july30.md` showing your absolute growth. Post your massive Web3 Security transition thread on X, tagging your portfolio and detailing your 68-day journey from "tutorial hell" to "independent auditor."
*   **Output:** Final review signed off + X thread launched.

---

## Part 3: Post-Plan Strategy — The Road to 40,000 INR (August → December 2026)

### August 2026: Active Contest & Boutique Application Sprint
*   **Contest Grind:** Participate in **1 live CodeHawks or Sherlock contest**. Spend 15 hours on it, focusing purely on the vault, staking, or yield contracts in scope.
*   **The Indian Domestic Push:** Submit your optimized resume to QuillAudits, CredShields (SolidityScan), and BlockSec.
*   **The Triage Pipeline:** Submit applications to Sherlock and Cantina for junior triage positions.
*   **X Activity:** Maintain a schedule of 2 high-quality, specialized DeFi mathematical tweets per week.

### September 2026: The Dev-Security Bridge
*   If you haven't landed a pure junior audit role, expand your applications to **Security-focused Solidity Developer internships** at domestic Indian startups.
*   Your MultiSig and CrowdHelp repos prove you write cleaner, more secure, and better-tested code than 99% of normal developers. This is a very high-probability path to hitting your 40k INR target.
*   Keep auditing independently on Hats Finance to build on-chain bounty proof.

### October – November 2026: The High-Volume and Warm-Lead Push
*   Leverage your growing X network. Follow up on every single DM and interaction you built during the plan.
*   Run high-volume, structured applications (10 per week) on Web3.career and CryptoJobsList using your specialized resume.

### December 2026: Drop-Dead Target Met
*   By this point, through a combination of local Indian internships, security-focused dev roles, junior auditing, or direct triaging contracts, you will have multiple avenues to confidently secure your **40,000 INR monthly target**.

---

## Part 4: Accountability Scoreboard

Use this to track your progress at the end of every midnight session. Commit your updates daily.

| Target | Baseline (May 24) | Phase 1–4 Result (Jul 14) | July 30 Target | Actual Shipped (Jul 30) |
| :--- | :---: | :---: | :---: | :---: |
| **Exploit PoCs** | 0 | 4 | **4** | [ ] |
| **Protocol Reviews** | 0 | 3 | **5 (BattleChain Confidence Pools, CrowdHelp)** | [ ] |
| **MultiSig Wallet** | 0 | Shipped & Hardened | **Completed v1** | [ ] |
| **Resume & Portfolio** | Unusable | Partial | **Recruiter-Ready & Clean** | [ ] |
| **Applications Sent** | 0 | 4 | **35–50** | [ ] |
| **Follow-ups / DMs** | 0 | ~4 | **15–20** | [ ] |
