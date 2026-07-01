# Hawk High — Self-Critique (Day 30)

Coach-authored pass. This is a hostile-judge read of `final-report.md`. Every finding gets scored on four axes. Any ⚠️ or ❌ is a real weakness — the "Notes" column says exactly what to fix and whether it was fixed in this pass.

**Rubric:**

- ✅ = defensible against a hostile judge with no changes
- ⚠️ = defensible but has a soft spot; note the risk
- ❌ = would get downgraded or thrown out; must change

**Axes:**

1. **Title** — one-line tells the judge the exact bug (function + effect)?
2. **Root cause** — exact function + line number(s) or storage slot named?
3. **Impact** — provable from PoC / arithmetic; no overclaim; severity matches?
4. **Fix** — smallest patch; no scope creep; addresses the root cause not a symptom?

Every LevelOne.sol line reference was grep-verified against the reviewed commit before scoring. All refs match.

---

## Per-finding scores

| ID   | Title | Root cause | Impact | Fix | Notes |
|------|-------|-----------|--------|-----|-------|
| H-01 | ✅ | ✅ | ⚠️ | ✅ | Two slot tables + line-by-line correspondence + `assertEq` proof. **Soft spot:** PoC uses `vm.etch` because H-02 blocks the real upgrade — an aggressive judge might argue "this doesn't happen in the wild." Cross-ref up top already addresses it. Do NOT change. |
| H-02 | ✅ | ✅ | ✅ | ✅ | Names both LevelOne.sol:305 (bad call) and :314 (empty hook) and prescribes `upgradeToAndCall`. Reads the ERC-1967 slot directly — irrefutable. Fix is one line. Zero weaknesses. |
| H-03 | ✅ | ✅ | ⚠️ | ✅ | Table showing 1/2/3-teacher outcomes is excellent. PoC nails the 2-teacher case. **Soft spot:** the 3-teacher revert claim is inferred, not tested. Report already discloses this honestly. Consider a 10-minute follow-up PoC before submission — but not required. |
| M-01 | ✅ | ✅ | ✅ | ✅ | Names three missing checks (`sessionEnd`, `inSession`, on-exit reset). Fix snippet is minimal. Clean. |
| M-02 | ✅ | ✅ | ✅ | ✅ | Explicit "independent of M-04" line prevents a judge from merging. Fix snippet uses a `REQUIRED_REVIEWS` constant that the codebase doesn't yet define — that's fine, it's a mitigation prescription, not a code paste. |
| M-03 | ✅ | ✅ | ⚠️ | ✅ | **Soft spot:** Impact says "carried into LevelTwo (once H-01/H-02 are fixed)" — a strict judge could argue "so today's impact is zero." Counter: state remains inconsistent within LevelOne itself (failing students still marked `isStudent`). If you want to harden this, add one line: "Even without upgrade, `listOfStudents` retains failing entries, breaking any downstream integration reading it." |
| M-04 | ✅ | ✅ | ✅ | ✅ | The dead-check is right there in the source. Fix is two lines. Clean. |
| M-05 | ✅ | ✅ | ✅ | ✅ | Great "combines multiplicatively with H-03" phrasing — shows systemic thinking. Refund vs. Forfeit choice is presented neutrally, which is correct (auditor doesn't dictate business policy). |
| L-01 | ✅ | ✅ | ⚠️ | ✅ | **Judgment call:** severity. If governance/principal risk is in scope, this is Medium. See "Judgment calls" section below. Kept as Low because principal is trusted per README. |
| L-02 | ✅ | ✅ | ✅ | ✅ | Input validation classic. One-line fix. Correct Low. |
| L-03 | ✅ | ✅ | ✅ | ✅ | Two `require`s. Trivial fix. Correct Low. |
| L-04 | ✅ | ✅ | ✅ | ✅ | Correctly linked to H-02 to avoid the "emit before real upgrade would mislead" trap. Sequencing note is smart. |
| L-05 | ✅ | ✅ | ✅ | ✅ | Dormant-bug framing is textbook. Explicitly ties to M-04 fix ordering. Correct Low. |
| I-01 | ✅ | ✅ | ✅ | ✅ | Info is Info. No inflation. Clean. |
| I-02 | ✅ | ✅ | ✅ | ✅ | Info is Info. No inflation. Clean. |

**Aggregate:** 15 findings scored. 0 ❌. 4 ⚠️ (all with mitigation notes, none blocking). 56 ✅ of 60 axis cells.

---

## Judgment calls — explicit defence

- **L-05 severity (Low, not Medium).** In the as-shipped codebase the `< 5` check is unreachable because M-04 means `reviewCount` is always 0. A bug that requires another fix to become exploitable is textbook Low. Firms like Pashov/Immunefi grade "latent" bugs one severity below live ones. Defensible.

- **L-01 severity (Low, not Medium).** Hawk High README treats the principal as a trusted admin (sole `onlyPrincipal` role, controls teacher roster, session lifecycle, and graduation). Under "trusted admin" scope, wage confiscation is a governance-abuse pattern, not a protocol-integrity break. Same firms typically call this Low unless the report explicitly claims trust minimization. If a live-contest judge disagrees they'll bump it; not worth losing sleep over.

- **H-03 3-teacher revert claim without a shipped 3-teacher PoC.** Acceptable disclosure because (a) the arithmetic is trivial and shown in the impact table, (b) the report explicitly says "not separately tested," and (c) the 2-teacher PoC proves the underlying formula. If you have 10 spare minutes before submission, copy `H03_TeacherWagePerTeacher.t.sol`, add a third `addTeacher`, add `vm.expectRevert()`, done. Would move H-03 to full ✅.

- **Parked "unused `bytes` param" — merged into H-02, not promoted to I-03.** Correct. Promoting it would duplicate H-02's mitigation, violating the one condition you stated ("findings should not be similar"). If a judge asks about it, point them at H-02 Recommended Mitigation which explicitly says "The `bytes memory` parameter should be named and used."

---

## Report-level checks

1. **Protocol Summary in your own words?** ✅ *Trust user — you filled this yourself and the workspace hasn't synced back; not directly verifiable from my side.*
2. **`Issues Found` table sorted by severity then ID?** ✅ Verified: H-01,H-02,H-03,M-01…M-05,L-01…L-05,I-01,I-02. Strict order.
3. **H-01↔H-02 cross-refs readable, not confusing?** ✅ Each finding names the other exactly once in Summary and once in Recommended Mitigation. Not tangled.
4. **Every `LevelOne.sol:XYZ` line ref correct against reviewed commit?** ✅ Grep-verified: `:70` (Graduated event), `:220` (removeTeacher), `:243` (expel), `:269` (startSession), `:277` (giveReview), `:281` (reviewCount<5), `:295` (graduateAndUpgrade), `:305` (bad _authorizeUpgrade call), `:314` (empty hook). All match.
5. **Any `TODO` / `FILL` / `XXX` left?** ⚠️ At the moment I ran this pass, workspace still showed `<FILL: git rev-parse HEAD>` at line 6 and the `[YOU WRITE THIS]` block at line 15. You said you filled them locally. Do a final `grep -n "FILL\|TODO\|XXX\|\[YOU WRITE" final-report.md` before submission.
6. **Weakest finding, honestly?** L-04 (event never emitted). It's real and correctly Low, but a judge who wants to be strict could argue it's a subset of H-02's observability gap and dedupe it. Kept as its own Low because the fix (add one `emit`) is independent of the H-02 fix (add `upgradeToAndCall`) and the event was intentionally declared in the source, signalling authorial intent — auditor's job is to flag that broken intent.

---

## Report shape check (bonus)

- Total length: 655 lines including 3 embedded PoC contracts. Roughly 300 lines of prose + 350 lines of Solidity/output. That's the right ratio for a report claiming "working PoCs."
- Section balance: Highs get ~70% of the page count. Mediums/Lows/Infos are terse. Correct for a First Flight — a High finding earns real estate; an Info does not.
- No PDF-hostile markdown (no unclosed code fences, tables render). Pandoc/eisvogel should convert cleanly.

---

## Top 3 lessons for Flight 2

1. **Ship PoCs into the target repo, not just into audit-dojo.** For Hawk High, running the PoCs against `CodeHawks-Contests/2025-05-hawk-high` under the exact contest Foundry/OZ pin caught that H-01's `assertNotEq` was giving weak zero-output logs. Running it live produced the shifted-value output that made the finding irrefutable. Next Flight, `forge test` in the *target* repo is the finish line, not `forge test` in the dojo.

2. **Merge/dedup decisions belong in a written "candidate → final" ledger, not in your head.** On Day 24 you had 13 candidates and a parking lot. On Day 29 those had to collapse to 15 report findings. The M-05→L-05 downgrade, the "unused bytes param" merge into H-02, and the M-02/M-04 stay-separate call all needed explicit reasoning. Next Flight, add a `promotions.md` alongside `candidate-findings.md`: one row per candidate, decision, one-line why. Judges never see it; future-you does.

3. **The 4-week calendar drift was invisible until Day 28.** Between Day 25 and Day 28 the tracker rows kept shipping but you never checked the tracker date against `date +%F`. That's how "Day 28" landed 11 real days late. Next Flight, add a self-check at the top of every daily row: `days_behind_calendar = today - (day1_date + N - 1)`. If it goes above 3, either compress or explicitly renegotiate the plan. Don't just keep shipping and hoping.
