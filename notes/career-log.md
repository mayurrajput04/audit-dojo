# Applications Log

## Running total: 12 (verified from tracker)

Format per application:

- Date applied
- Company
- Role
- Platform/Link
- Status
- Notes

---

| #   | Date       | Company    | Role                               | Link                                                                     | Status                | Notes                                                                                                                             |
| --- | ---------- | ---------- | ---------------------------------- | ------------------------------------------------------------------------ | --------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 1   | 2026-05-26 | —          | —                                  | —                                                                        | —                     | ETH Vault deposit slice                                                                                                           |
| 2   | 2026-05-28 | —          | —                                  | —                                                                        | —                     | Reentrancy PoC                                                                                                                    |
| 3   | 2026-05-30 | —          | —                                  | —                                                                        | —                     | Signature replay PoC                                                                                                              |
| 4   | 2026-06-01 | —          | —                                  | —                                                                        | —                     | Puppy Raffle mental model                                                                                                         |
| 5   | 2026-06-03 | —          | —                                  | —                                                                        | —                     | Puppy Raffle pass 2                                                                                                               |
| 6   | 2026-06-04 | —          | —                                  | —                                                                        | —                     | PoC & report draft                                                                                                                |
| 7   | 2026-06-06 | —          | —                                  | —                                                                        | —                     | Checklist extraction                                                                                                              |
| 8   | 2026-06-08 | —          | —                                  | —                                                                        | —                     | Oracle pass                                                                                                                       |
| 9   | 2026-06-14 | —          | —                                  | —                                                                        | —                     | Guided audit 1 takeaways                                                                                                          |
| 10  | 2026-06-18 | —          | —                                  | —                                                                        | —                     | Flash loan logic pass                                                                                                             |
| 2026-07-06 | —          | —                                  | —                                                                        | —                     | MultiSig spec                                                                                                                     |
| 2026-07-10 | Binance    | Smart Contract Auditor             | https://jobs.lever.co/binance/6f64f1c8-2fdc-4231-8da3-631ebdf3ae2a/apply | Already applied (per user, pre-2026-07-14) | Previously logged as pending; user reports application was submitted prior to this session. |
| 2026-07-11 | Nethermind | Smart Contract Auditor / Evergreen | DM                                                              | Submitted             | Resume + GitHub portfolio included                                                                                                |

---

## Applications pending submission

### 2026-07-10 — Binance Smart Contract Auditor

- **URL:** https://jobs.lever.co/binance/6f64f1c8-2fdc-4231-8da3-631ebdf3ae2a/apply
- **Status:** Already applied (user confirmed, submission predates this session)
- **Note:** Previously tracked as pending; corrected to submitted.
- **Fit:** "Basic understanding" listed in requirements. Remote. Worth applying once resume is strong.

---

## Resume gap analysis (2026-07-10)

**Current state:** 1 page, 1 project (Audit Dojo) explicitly covers security. MultiSigWallet not yet complete. No audit findings listed. No certifications. No GitHub stats. Education is incomplete (2026 graduation, B.Tech CS).

**To submit competitive applications:**

- MultiSigWallet v1 must be complete (exec + revoke + README + self-audit)
- Audit Dojo description needs specific finding counts
- Resume should list: 4 PoCs, 2 guided audits, 1 First Flight report, 1 self-built multisig
- Cyfrin/Trail of Bits courses if available
- CodeHawks findings count (if any public)
- Test coverage numbers for FundChain

---

## Notes

- Entries 1–11: tracker says "1" but these are work-product days where an application was "sent" — likely self-audits or progress tracking days counted as career block. Actual application count is lower.
- True external applications need separate tracking starting from entry 12.
- Focus: junior/entry-level roles that say "basic understanding" or "learning mindset." Do NOT apply to 1+ year experience roles until MultiSig is complete.

---

## 2026-07-12 — Day 39 Career Action — Outreach

- Type: Outreach (not formal application)
- Target: EgisSec (@EgisSec on X) — team: deth + nmirchev8, Convergence contest winners, Hats Finance guest article on team auditing.
- Platform: X DM https://x.com/EgisSec
- Status: Sent — confirmed by user on 2026-07-12
- Context: Networking with elite independent researchers as per user strategy: show wins/achievement, not ask for job.
- Shipped today: Execute flow 22/22 green, derived count Option A, CEI enforced.
- Link to include: GitHub multi-sig wallet repo + audit-dojo first flight report
- Next: If no reply in 5-7 days, public build thread tagging learnings, not begging.

| # | Date | Company/Person | Role/Context | Link | Status | Notes |
|---|------|----------------|--------------|------|--------|-------|
| 13 | 2026-07-12 | EgisSec (deth + nmirchev8) | Elite audit team / Independent Security Researchers | https://x.com/EgisSec / https://www.egissec.com/ | Outreach Sent - DM confirmed 2026-07-12 | DM for feedback, not job ask. Execute flow shipped 22/22. Strategy: visibility among elites. |

---
Update 2026-07-12 23:50 IST: User confirmed DM sent to EgisSec via X
- Previous entry 13 status: Drafted -> Sent
- Evidence: user statement "i sent dm"
- Next: wait 5-7 days, no follow-up spam, continue public build threads

---

## 2026-07-13 — Career Action — OpenZeppelin Application

- Type: Formal application
- Company: OpenZeppelin
- Role: Blockchain Security Researcher — Future Openings
- Official listing/application: https://www.openzeppelin.com/careers/opening?gh_jid=4254142003
- Location: Remote — Worldwide
- Status: **Submitted — user confirmed 2026-07-13**
- Caveat: This is an active future-opening pipeline, not an immediate vacancy and not explicitly titled junior. It has no stated minimum years requirement, accepts worldwide applicants, and is the strongest verified geography-compatible security role found after excluding prior targets and stale listings.

### Why this target won

- Official application is live and explicitly Remote — Worldwide.
- Work directly matches the portfolio: smart-contract review, vulnerability prioritization, design/trust-assumption analysis, smart-contract development, and security research.
- The listing asks for practical software/security experience, smart-contract development, Solidity/EVM knowledge, clear writing, and public research output. Current repositories provide evidence for each.
- Foundry, invariant testing, audit-contest work, and public findings are listed as advantages rather than fixed experience gates.
- Main gaps: no judged contest placement, no production client audit, limited advanced fuzzing/formal verification, and no public custom AI security tooling. Do not hide these.

### Evidence to submit

- Audit portfolio: https://github.com/mayurrajput04/audit-dojo
- GitHub / MultiSigWallet: https://github.com/samuraiigintoki/multisig-wallet
- Portfolio facts: 4 exploit PoCs; 2 guided audit reports; 1 First Flight report with 15 documented findings; fixed-owner multisig with self-audit and 24 passing Foundry tests.

### Cover letter draft

Hello OpenZeppelin team,

I am a 2026 B.Tech Computer Science candidate building toward professional smart-contract security research through public, reproducible work. My Audit Dojo portfolio contains four exploit proof-of-concepts, two guided audit reports, and a completed First Flight review with 15 documented findings. I also built and self-audited a fixed-owner MultiSigWallet v1 with constructor hardening, explicit state-transition tests, CEI-based execution, failure-path coverage, documentation, and 24 passing Foundry tests.

My strongest current areas are Solidity/EVM reasoning, mapping trust assumptions and state transitions, reproducing exploits in Foundry, and writing concise findings with impact and mitigation. I am early in my professional career and do not yet have production client-audit experience or judged contest placements; the linked repositories are the evidence for what I can currently do.

OpenZeppelin's combination of protocol design review, adversarial code review, smart-contract development, and public research is the direction in which I want to grow. I would welcome consideration for a future opening and the opportunity to demonstrate my reasoning through the technical process.

Regards,  
Mayur Rajput

### Required application answers

**Our mission is to accelerate the world’s transition to an open and secure financial system. Could you please tell me how you identify with that mission?**

Open finance is not useful if users still have to blindly trust code they cannot verify. That is what pulled me toward smart contract security: a small mistake in access control, accounting, or a state transition can put real user funds at risk. My work so far is small but concrete—exploit PoCs, audit reports, and a self-audited multisig. I want to keep doing work that turns hidden assumptions into tested invariants and makes onchain systems safer to use.

**How would you describe your knowledge of smart contract security?**

I have a strong practical foundation, but I am still early professionally. I am comfortable reviewing Solidity contracts, mapping actors and trust assumptions, tracing state transitions and external calls, and turning suspected issues into Foundry PoCs. My work has covered reentrancy, signature replay, allowance bugs, oracle manipulation, upgrade and storage-layout mistakes, accounting errors, and broken state machines. I have not worked on a production client audit yet, and I am still building depth in advanced fuzzing, formal verification, cryptography, and non-EVM ecosystems.

**What's the most interesting smart contract vulnerability you've discovered or encountered in your work?**

The most interesting issue I found was during my Hawk High review. A function called `graduateAndUpgrade()` directly called `_authorizeUpgrade()`, but that function is only an authorization hook—it does not update the ERC-1967 implementation slot. The transaction could succeed while the proxy quietly stayed on the old implementation. I proved that with a Foundry test that read the implementation slot before and after the call. The more interesting part was that the new implementation also had an incompatible storage layout, so fixing the missing upgrade call alone would activate state corruption. Both issues had to be understood together, not patched in isolation.

**How do you use AI in your personal and professional life?**

I mostly use AI to argue with my reasoning. I ask it for edge cases, alternate attack paths, and criticism of my reports, then verify the useful parts against the source code and Foundry tests. If I cannot prove a technical claim, it does not go into the report. I also use AI for planning and repetitive tracking work. I have not built a production AI security agent or auditing tool, and I would not claim that I have.

**Where are you legally based? Do you require visa sponsorship?**

I am legally based in Maharashtra, India. I do not require visa sponsorship to work remotely from India.

### Submission record

- Submitted through the official OpenZeppelin Greenhouse form.
- User confirmed submission on 2026-07-13.
- Evidence available to coach: user confirmation in session; no confirmation screenshot or email stored in the workspace.
- Career action for 2026-07-13: **1**.

---

## 2026-07-14 — Career Action — Veridise Application

- Type: Formal application (open form)
- Company: Veridise
- Role: Blockchain Security Analyst (open interest form — user selected security analyst track)
- Platform: Veridise open application form
- Status: **Submitted — user confirmed 2026-07-14**
- Evidence: Email + resume attached via their form
- Note: Career action corrected mid-session. Original coach suggestion (InfiniteSec DM) was bad advice — user rightly rejected it and submitted a real application instead.
- Career action for 2026-07-14: **1**.
