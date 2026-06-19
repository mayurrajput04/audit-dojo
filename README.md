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
| Personal audit checklist | v1 active | [`checklists/personal-checklist-v1.md`](checklists/personal-checklist-v1.md) |
| Progress tracker | active | [`notes/tracker.md`](notes/tracker.md) |
| First Flight / solo reviews | next | [`first-flight-reviews/`](first-flight-reviews/) |

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

**Shipped by:** Gintoki Sakata  
**Tracked in:** [`notes/tracker.md`](notes/tracker.md)  
**LinkedIn:** https://www.linkedin.com/in/samuraiigintoki  
**Twitter/X:** https://x.com/samuraigintokii
