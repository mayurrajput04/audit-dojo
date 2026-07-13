# Audit-Dojo ⚔️

**68 days. One mission: become a junior smart contract auditor.**  
_I break things so you don’t have to. Then I fix them. Then I break them again._

This repo is my public training log: exploit PoCs, guided audit reports, checklists, reflections, and first-flight/shadow-audit work.

---

## Portfolio snapshot

| Category | Status | Artifacts |
|---|---:|---|
| Core exploit PoCs | 4 shipped | [`self-audits/exploit-pocs/`](self-audits/exploit-pocs/) |
| Guided audits | 2 completed | [`guided-audits/puppy-raffle/`](guided-audits/puppy-raffle/), [`guided-audits/thunder-loan/`](guided-audits/thunder-loan/) |
| First Flight / solo reviews | completed | [`first-flight-reviews/flight-1/final-report.md`](first-flight-reviews/flight-1/final-report.md) |
| MultiSigWallet v1 | completed | [https://github.com/samuraiigintoki/multisig-wallet](https://github.com/samuraiigintoki/multisig-wallet) |
| Personal audit checklist | v1 active | [`checklists/personal-checklist-v1.md`](checklists/personal-checklist-v1.md) |
| Progress tracker | active | [`notes/tracker.md`](notes/tracker.md) |

---

## Phase 1 - Core Exploit PoCs

_If you can’t spot the bug, you’re the liquidity._

| # | Vulnerability | One-liner | Artifact |
|---|---|---|---|
| 1 | **ETH Vault Baseline** | Secure deposit/withdraw flow using CEI as the control specimen. | [`eth-vault`](self-audits/exploit-pocs/eth-vault/) |
| 2 | **Reentrancy** | External call before state update lets an attacker withdraw repeatedly. | [`reentrancy-poc`](self-audits/exploit-pocs/reentrancy-poc/) |
| 3 | **State-Update Arithmetic** | Allowance grows instead of shrinking; spender drains more than intended. | [`allowance-bank`](self-audits/exploit-pocs/allowance-bank/) |
| 4 | **Signature Replay** | Missing nonce/domain separation lets a valid signature be reused. | [`signature-replay`](self-audits/exploit-pocs/signature-replay/) |

---

## Phase 2 - Guided Audits

| # | Protocol | Type | Focus Areas | Final Report |
|---|---|---|---|---|
| 1 | **Puppy Raffle** | Guided audit | Raffle accounting, refunds, fee accounting, integer truncation | [`final-report.md`](guided-audits/puppy-raffle/final-report.md) |
| 2 | **Thunder Loan** | Guided audit | UUPS upgrades, storage layout, oracle pricing, flash loan safety, admin controls | [`final-report.md`](guided-audits/thunder-loan/final-report.md) |

### Current Thunder Loan result

- **6 High**, **2 Medium**, **1 Informational** findings documented.
- PoCs exist for deposit/exchange-rate insolvency, oracle manipulation, and upgrade storage collision.
- Checklist expanded with upgradeable storage, oracle/pricing, flash loan safety, and timelock/centralization questions.

---

## Phase 3 - First Flight Reviews (CodeHawks)

| # | Protocol | Type | Focus Areas | Final Report |
|---|---|---|---|---|
| 1 | **Hawk High** | First Flight (solo review) | Proxy upgradeability (`ERC1967`), storage layout collisions, access control, logic bugs | [`final-report.md`](first-flight-reviews/flight-1/final-report.md) |

### Current Hawk High result

- **15 documented findings: 3 High, 5 Medium, 5 Low, 2 Informational**
- 3 High-severity issues reproduced and verified with standalone Foundry PoCs (`first-flight-reviews/flight-1/pocs/`).
- Note: This is an archived training/contest review, not a paid client audit or production finding.

---

## Phase 4 - MultiSigWallet v1

Standalone security-focused repository: [https://github.com/samuraiigintoki/multisig-wallet](https://github.com/samuraiigintoki/multisig-wallet)

- **Architecture:** Fixed-owner multisig with `submitTransaction`, `confirmTransaction`, `revokeConfirmation`, and `executeTransaction` lifecycle plus `receive()` funding path.
- **Security Hardening:** Strict Checks-Effects-Interactions (CEI), zero-address constructor validation (`MultiSigWallet__ZeroAddressOwner`), duplicate confirmation/revoke guards, and execution-failure rollback.
- **Verification:** Self-audited against personal checklist (`docs/self-audit.md`) with **24 passing Foundry tests** (`24/24` green).

---

## Checklist

My checklist is not a vibe-board. It is an interrogation manual built from bugs I actually studied.

Current version: [`checklists/personal-checklist-v1.md`](checklists/personal-checklist-v1.md)

It currently covers:

1. State accounting
2. Duplicate action prevention
3. External calls
4. Access control
5. Input validation
6. Event correctness
7. Upgradeable storage layout
8. Oracle & pricing
9. Flash loan safety
10. Timelocks & centralization

---

## What I’m learning

- Turn vague “look for bugs” fear into repeatable passes: mental model → invariants → function map → checklist pass → PoC → report.
- Treat accounting variables as claims on real assets, not decorative numbers in storage.
- For upgradeable contracts: storage layout is part of the protocol’s security boundary.
- For oracle-dependent systems: spot price is not truth; it is often an invitation.
- Write findings like a client needs to fix them, not like a detective trying to sound mysterious in the rain.

---

## How to run local PoCs

```bash
git clone https://github.com/mayurrajput04/audit-dojo
cd audit-dojo/self-audits/exploit-pocs/<folder>
forge test -vvv
```

Some guided-audit PoCs are stored as standalone proof files under the relevant protocol folder.

---

## Archive

Older PDF reports live in [`archive/`](archive/).

---

**Shipped by:** Gintoki Sakata / Mayur Rajput  
**Tracked in:** [`notes/tracker.md`](notes/tracker.md)  
**Canonical Recruiter Portfolio:** [mayurrajput04](https://github.com/mayurrajput04) (`audit-dojo` main repository)  
**Security Dev & Commit Log Identity:** [samuraiigintoki](https://github.com/samuraiigintoki) (`multisig-wallet` & commit history)  
**LinkedIn:** https://www.linkedin.com/in/samuraiigintoki  
**Twitter/X:** https://x.com/samuraigintokii
