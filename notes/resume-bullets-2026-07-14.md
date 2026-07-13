# Resume Bullet Points — 14 Jul 2026
## Sync target: Master PDF Resume
## Verified against disk truth (audit-dojo + multisig-wallet)

---

### Summary / Profile Section (pick one)

**Option A — Security-focused:**
> Smart contract security researcher with 3 independent protocol reviews, 7 Foundry exploit PoCs, and a self-audited MultiSigWallet v1 — all publicly verifiable on GitHub. Proficient in Solidity, Foundry testing, CEI pattenrs, access-control analysis, storage-layout auditing, and structured finding writing. OpenZeppelin Blockchain Security Researcher applicant (July 2026).

**Option B — Concise (ATS-optimized):**
> Solidity Security Researcher | Foundry | CEI | MultiSigWallet v1 | 3 protocol audits | 7 exploit PoCs | 24 findings documented | OpenZeppelin applicant

---

### MultiSigWallet v1 (Project Section)

**Option 1 — Security-heavy (best for auditor roles):**
> Designed and self-audited a fixed-owner multi-signature wallet in Solidity with Foundry, implementing Checks-Effects-Interactions (CEI) enforcement, zero-address constructor hardening, and duplicate-confirmation prevention. Achieved **100% test coverage (24/24 passing Foundry tests)** across submit, confirm, revoke, and execute flows. Published a self-audit report (`docs/self-audit.md`) documenting 1 resolved finding and 2 accepted v1 limitations.

**Option 2 — Concise bullet list (best for mixed roles):**
- Architected a Solidity multi-signature wallet enforcing **Checks-Effects-Interactions** on all execution paths with explicit state-transition guards.
- Hardened constructor against **zero-address owners**, **duplicate owners**, and **invalid thresholds** with corresponding negative tests.
- Delivered **24/24 Foundry tests** covering confirmation idempotency, execution-failure rollback, and revoke-before-execute transitions.
- Published self-audit referencing personal checklist (`personal-checklist-v1.md`) documenting access-control assumptions, event gaps, and v1 scope boundaries.

**Option 3 — Ultra-short (ATS scanner):**
> MultiSigWallet | Solidity, Foundry, CEI — Self-audited fixed-owner multisig wallet with 100% Foundry test coverage (24/24 passing), zero-address protection, and CEI-enforced execution.

---

### Audit Dojo / Security Research Section

**Option 1 — Finding-count heavy (best for audit roles):**
> Conducted **independent and guided security reviews across 3 protocols (Puppy Raffle, Thunder Loan, Hawk High)**, identifying and documenting **24 total issues including 9 High-severity vulnerabilities** covering reentrancy, signature replay, access-control gaps, storage-collision hazards, oracle manipulation, upgrade failures, and state-accounting errors.

**Option 2 — PoC-focused (best for technical roles):**
> Authored **7 standalone Foundry exploit proof-of-concepts** proving reentrancy, cross-chain signature replay, unbounded-loop denial-of-service, allowance-drain state bugs, storage collisions, and proxy upgrade failures. Each PoC includes a vulnerable contract, exploit contract, and fixed variant with annotated README explaining root cause, attack flow, and mitigation.

**Option 3 — Combined (recommended):**
- Independently reviewed **3 Solidity protocols** (Puppy Raffle, Thunder Loan, Hawk High) and wrote structured security reports documenting **24 total findings: 9 High, 5 Medium, 5 Low, 2 Informational**.
- Built **7 Foundry exploit PoCs** demonstrating reentrancy, signature replay, allowance-drain, storage collisions, proxy upgrade failures, oracle manipulation, and denial-of-service loops.
- Maintain a personal audit checklist (`personal-checklist-v1.md`) with 10 interrogation categories refined across guided and independent reviews.

---

### Technical Skills / Tools Section

- **Languages:** Solidity
- **Testing & Audit:** Foundry (forge, cast), invariant testing, PoC development
- **Security Concepts:** CEI pattern, reentrancy, signature replay, storage collisions, access control, oracle manipulation, upgradeable contracts (UUPS/ERC-1967), state-accounting bugs
- **Tools:** Git, VS Code, Slither (basic)

---

### Recommended Combination for Master PDF

**Profile:** Option A
**MultiSig:** Option 1 (if applying to auditor roles) or Option 2 (if applying to dev roles)
**Audit Dojo:** Option 3 (combined — covers both finding count and PoC breadth)
**Skills:** As listed above
