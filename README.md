# Audit‑Dojo ⚔️

**68 days. One mission: become a junior smart contract auditor.**  
_I break things so you don’t have to. Then I fix them. Then I break them again._

---

## 🎯 Phase 1 : Core Exploit PoCs  
_If you can’t spot the bug, you’re the liquidity._

| # | Vulnerability | One‑Liner | PoC |
|---|---------------|-----------|-----|
| 1 | **Reentrancy** | Oldest trick in the book – call `withdraw` again before the balance updates. | [`reentrancy-poc`](exploit-pocs/reentrancy-poc/) |
| 2 | **State‑Update Arithmetic** | Allowance grows instead of shrinking. Spender drains more than intended. | [`allowance-bank`](exploit-pocs/allowance-bank/) |
| 3 | **Signature Replay** | No nonce = a signature valid forever. Same signature spends twice. | [`signature-replay`](exploit-pocs/signature-replay/) |
| 4 | **ETH Vault (Baseline)** | Secure deposit/withdraw with CEI – the “safe” contract that started the journey. | [`eth-vault`](exploit-pocs/eth-vault/) |

> _“A sword that only cuts what you want is boring. A smart contract that breaks exactly how you predicted? Now that’s art.” — Sakata Gintoki_

---

## ⚙️ How to run

```bash
git clone https://github.com/mayurrajput04/audit-dojo
cd audit-dojo/exploit-pocs/<any-folder>
forge test -vvv
```

All tests green. Every PoC comes with a `PLAN.md` and a `README.md` explaining the attack, the fix, and the lesson.

---

## 📦 What’s next (Phase 2)

More chaos. Deeper bugs. Fuzz tests. Maybe a real audit contest.  
_I’m not here to print “Hello World.” I’m here to find the line of code that makes the protocol say “goodbye.”_

---

**Shipped by:** Gintoki Sakata  
**Tracked in:** [`notes/tracker.md`](notes/tracker.md)  
**LinkedIn: https://www.linkedin.com/in/samuraiigintoki**  
**Twitter: https://x.com/samuraigintokii** 
```

