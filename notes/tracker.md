| date | main task | shipped artifact | applications | blocker |
|------|-----------|-----------------|--------------|---------|
| 2026-05-24 | Reset and setup |  epo structure (folders + .gitkeep), baseline.md, tracker.md, definition of success, GitHub bio updated | 0  | none |
| 2026-05-25 | Tiny contract planning: ETH Vault | PLAN.md, EthVault.sol skeleton, day2_reflection.md | 0 | none |
| 2026-05-26 | ETH Vault deposit slice 1 | deposit() implemented, 2 deposit tests passing, SECURITY.md | 1 | none |
| 2026-05-27 | ETH Vault withdraw slice 2 | withdraw() with CEI checks, 4 new tests pass (6 total), SECURITY.md updated with withdraw analysis | 0 | none |
| 2026-05-28 | Reentrancy PoC | VulnerableVault.sol, Attacker.sol, FixedVault.sol, AnotherAttacker.sol, test/ReentrancyPoC.t.sol (2 tests green), PLAN.md, README.md | 1 | none |
| 2026-05-29 | Allowance bug PoC | PLAN, Buggy/Fixed contracts, 4 tests, README | 0 | none |
| 2026-05-30 | Signature replay PoC | BuggyReplayVault.sol, FixedReplayVault.sol, 4 passing tests, README.md, PLAN.md | 1 | none |
| 2026-05-31 | Phase 1 close | day8_phase1_close.md, root README updated, baseline refreshed, all tests green | 0  | none |
| 2026-06-01 | Day 9: Puppy Raffle mental model | `guided-audits/puppy-raffle/mental-model.md` (10 invariants) | 1 | none |
| 2026-06-02 | Guided audit 1 - Pass 1 scan | pass1_notes.md, 10 flags across 7 functions | 0 | boredom wall on function 5, pushed through |
| 2026-06-03 | Guided audit 1 - Pass 2 (Accounting) | candidate-findings.md with 2 high severity findings | 1 | none |
| 2026-06-04 | Day 12: PoC & Report Draft | 3 PoCs (H-1 Scenario A, H-1 Scenario B, H-2) + report_draft.md | 0 | none |
| 2026-06-05 | Day 13: Guided audit 1 finalization | final-report.md, day13-guided-audit1-finalization.md, tracker updated | 0 | none |
| 2026-06-06 | Day 14: Extract Checklist | personal-checklist-v1.md, guided_audit_1_takeaways.md, tracker updated | 1 | none |
| 2026-06-07 | Day 15: Thunder Loan mental model | thunder-loan/mental-model.md, candidate-findings.md | 0 | none |
| 2026-06-08 | Day 16: Oracle & Pricing Pass | oracle_pass.md, 2 new Highs in candidate-findings.md | 1 | none |
| 2026-06-09 | Day 17: Admin & Upgrade Pass | admin_upgrade_pass.md, 2 new Highs (H-05, H-06), 2 new Mediums (M-01, M-02) in candidate-findings.md | 0 | fatigue wall , rescue protocol triggered on Section 2 |
| 2026-06-15 | Day 18: Flash Loan Logic & Reentrancy Pass | flashloan_logic_pass.md (all 5 sections), 2 new Highs (H-07 redeem reentrancy/INV-8, H-08 nested-flashloan state-machine break/INV-4) in candidate-finding.md, applications-log.md created | 1  | rescue protocol triggered once on "backed by other LPs' principal" \u2014 cleared via piggy-bank model |
| 2026-06-18 | Day 19: Guided Audit 2 (Thunder Loan) — PoC & Report Draft | H2_deposit_exchange_rate.sol, H3_oracle_manipulation.sol, H5_storage_collision.sol, report_draft.md, updated candidate-findings.md, applications-log.md updated | 0 | none |
| 2026-06-19 | Day 20: Guided Audit 2 (Thunder Loan) — Final Report & Mitigation Review | final-report.md (6 Highs,2 Mediums:,1 Info), personal-checklist-v1.md updated (4 new sections), tracker updated | 0 | none |
| 2026-06-20 | Day 21: Guided Audit 2 (Thunder Loan) — Portfolio & Retrospective Day | README.md updated for 2 guided audits; Thunder final-report.md PDF-readiness cleanup; notes/guided_audit_2_takeaways.md scaffolded; first-flight-reviews/flight-1/target-selection.md created with Hawk High selected | 0 | none |
| 2026-06-21 | Day 22: Hawk High Kickoff & Mental Model | first-flight-reviews/flight-1/kickoff.md (scope, contracts, actors, flows, trust assumptions, 10 invariants, function list), identified INV-1/INV-3/INV-4/INV-5/INV-6/INV-7/INV-8 as BROKEN | 0 | none |
| 2026-06-22 | Day 23: Hawk High Function Map & First Pass | first-flight-reviews/flight-1/function-map.md (LevelOne + LevelTwo tables, storage layout side-by-side, full graduateAndUpgrade trace, 11 raw candidate issues) | 1 | none |