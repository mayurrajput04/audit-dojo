# Day 8 — Phase 1 Close Reflection

**Date:** 2026-05-31  
**Phase:** 1 (Reset + anti‑freeze + tiny security reps)  
**Days completed:** 1‑7

---

## What felt easy?

- Foundry setup was smooth because of the `anti_black_screen_setup.md` blank‑contract skeleton. Having the ERRORS / EVENTS / STORAGE / CONSTRUCTOR / EXTERNAL / VIEW / INTERNAL structure ready removed all friction.
- Test file creation and the `setUp()` function felt natural almost immediately.
- The CEI (Checks‑Effects‑Interactions) pattern clicked fast , it became a mental checklist every time I wrote a state‑changing function.

## What felt hard or uncomfortable?

- Writing attacker logic in tests, particularly for the signature replay PoC. Getting into the mindset of the exploiter required extra mental modelling.
- Signature concepts and the replay attack: I understand the theory, but there was a persistent under‑confidence. I could follow v, r, s and OpenZeppelin’s ECDSA, yet I didn’t feel I “owned” the knowledge.
- The signature replay test suite felt medium‑hard, more nuance than the others.

## Bug class I want to revisit later

- **Signature replay**, definitely. The theory is clear, but I want to reach the same level of hands‑on confidence I have with reentrancy. I’ll likely dive deeper into EIP‑712 and cross‑chain replay in Phase 2.

## What surprised me about my learning process?

- Logic building became easier as the days went on. Having a PLAN.md before code eliminated blank‑screen paralysis.
- I genuinely enjoyed exploiting the bugs , writing PoCs felt like solving puzzles.
- Signature replay was my favourite bug *because* it made me uncomfortable. It pushed me.
- I have never been this consistent in 1.5 years of learning. Daily commits, daily shipping.
- I wrote more contract code in one week than in my entire journey before this.

## PoC I’m most proud of

- **Reentrancy** : my first ever PoC. I started underconfident, but once I sat down and built the vulnerable vault, the attacker, and the fix, I loved every minute. It proved I could do this.

## Advice to Day 1 me

- Stop overthinking. Trust the system, trust the plan.
- Every small step compounds. Don’t waste time worrying , just ship.
- Be a little faster; quick action beats perfect deliberation.

## What I’m carrying into Phase 2

- **Attacking mindset** : always think “how do I break this?” during tests and PoCs.
- **Plan first, precisely, then code.** Scoped, quick planning prevents chaos.
- **Consistency** : daily commits, daily X/LinkedIn posts, PoCs linked in posts.
- **Send that one DM.** Ghosted or not, every shot counts. Outreach compounds.