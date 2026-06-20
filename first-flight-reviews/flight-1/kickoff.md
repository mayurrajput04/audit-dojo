# First Flight 1 | Hawk High: Kickoff & Mental Model

> Day 22 of 68 | Archived / Shadow Audit | Mental Model Day

---

## 1. Scope

| Field | Value |
|---|---|
| **Protocol** | Hawk High |
| **Contest / Platform** | CodeHawks First Flight #39 |
| **nSLOC** | 243 |
| **Review Type** | Shadow First Flight |
| **In Scope** | `src/LevelOne.sol`, `src/LevelTwo.sol` |
| **Out of Scope** | `test/`, `script/`, `lib/` |
| **Chain** | EVM Compatible |
| **Token** | USDC (assumed 18 decimals) |
| **Solidity** | 0.8.26 |
| **Architecture** | UUPS Upgradeable (ERC1967 Proxy) |

---

## 2. Contracts in Scope

### LevelOne.sol
Main school management contract. UUPS upgradeable. Handles enrollment, fee collection, teacher management, student reviews, session timing, wage distribution, and the upgrade/graduation flow to LevelTwo.

### LevelTwo.sol
Post-upgrade contract. Inherits `Initializable` (not UUPS). Contains `graduate()` reinitializer, view functions for student/teacher lists and scores. Has updated wage constants (40% teacher, 5% principal). No UUPS means cannot be upgraded further.

### MockUSDC.sol (test support , not in scope)
ERC20 mock with unrestricted `mint()`. Used in tests only.

---

## 3. Actors / Roles

| Actor | Who | Powers |
|---|---|---|
| **Principal** | Set at initialization | Hire/fire teachers, start session, expel students, trigger upgrade (`graduateAndUpgrade`), authorize upgrade (`_authorizeUpgrade`) |
| **Teachers** | Added by principal | Give weekly reviews to students (reduce score by 10 on bad review) |
| **Students** | Self-enroll | Pay school fees, receive reviews, graduate if score ≥ cutOffScore |
| **USDC Token** | External ERC20 | Payment token for fees and wages |

---

## 4. Main User Flows

### 4.1 Enroll Student
- Student calls `enroll()`
- Must not be a teacher or principal
- Must not already be a student
- Must approve USDC `safeTransferFrom` of `schoolFees` amount
- Student added to `listOfStudents`, `isStudent` = true, `studentScore` = 100, `bursary += schoolFees`
- Cannot enroll after session starts (`notYetInSession` modifier)

### 4.2 Pay School Fee
- Fee is paid during `enroll()`. single payment, no recurring
- Fee amount set at initialization, stored in `schoolFees`
- All fees accumulate in `bursary` state variable; USDC held by the proxy contract address

### 4.3 Teacher Review
- Teacher calls `giveReview(student, bool review)`
- `review = true` → score unchanged (good review)
- `review = false` → score reduced by 10 (bad review)
- Enforced: one review per student per week (`lastReviewTime + reviewTime`)
- Enforced: max 5 reviews per student (`reviewCount < 5`) , **spec says 4, code allows 5**
- No per-teacher review limit, any teacher can review any student

### 4.4 Session Timing
- Principal calls `startSession(cutOffScore)` , only before session starts
- Sets `sessionEnd = block.timestamp + 4 weeks`, `inSession = true`, stores `cutOffScore`
- No check for minimum students or teachers before starting session

### 4.5 Graduate / Upgrade
- Principal calls `graduateAndUpgrade(levelTwoAddress, data)`
- Calculates wages, transfers USDC, then calls `_authorizeUpgrade` + UUPS upgrade
- **No check for `sessionEnd` reached** : principal can upgrade anytime
- **No check that all students have 4 reviews** : spec invariant unenforced
- **No check that students below cutOffScore are filtered out** : spec invariant unenforced
- `LevelTwo.graduate()` called via `upgradeToAndCall`

### 4.6 Wage Distribution
- `principalPay = bursary * 5 / 100` : 5% of total bursary to principal ✅
- `payPerTeacher = bursary * 35 / 100` : **35% of total bursary PER teacher** ❌
- Spec says teachers SHARE 35%. Code gives 35% EACH.
- Remaining supposed to be 60%. With 2 teachers: 70% + 5% = 75%. With 3 teachers: 105% + 5% = 110% → contract reverts (insufficient balance)

### 4.7 Expel Student
- Principal calls `expel(student)` only during session
- Student removed from `listOfStudents`, `isStudent` = false
- **No refund** student's paid fees remain in bursary
- **bursary is NOT decreased** , expelled student's fees effectively become protocol revenue

### 4.8 Add / Remove Teacher
- `addTeacher()` : principal only, before session starts, cannot be existing teacher or student
- `removeTeacher()` : principal only, can remove during session (no `notYetInSession` guard)
- Removed teacher's past reviews still count , no score recalculation

---

## 5. Trust Assumptions

### Principal is trusted with:
- Starting and ending school sessions
- Hiring and firing teachers at any time (even mid-session)
- Expelling students without refund
- Setting cutOffScore (including 0 or 1000)
- Triggering upgrade at any time (no sessionEnd check, no timelock)
- Upgrading to **any** implementation address (can be malicious)
- Receiving 5% of bursary as wages

### Teachers are trusted with:
- Giving honest reviews (no mechanism to verify review quality)
- Not colluding to tank/boost specific students' scores
- Each teacher can review each student once per week , no limit on number of teachers reviewing same student

### Students can try to abuse:
- **Re-enrollment after expulsion**: `expel()` sets `isStudent = false`, but `enroll()` only checks `isStudent[msg.sender]`. After expulsion, student could re-enroll and pay fees again (if session hasn't started yet... but expulsion only happens *during* session, and enrollment is blocked during session. So re-enrollment is NOT possible. ✅)
- **Cannot call giveReview on themselves**: access controlled to `onlyTeacher` ✅
- **Cannot avoid bad reviews**: passive role, no way to influence reviews

### Upgrade assumptions:
- UUPS pattern ( `_authorizeUpgrade` is `onlyPrincipal` ) no timelock, no multisig
- Principal can upgrade to arbitrary address at arbitrary time
- Storage layout compatibility between LevelOne and LevelTwo is **NOT maintained** , variables removed, slots shift

### Token / payment assumptions:
- USDC assumed to have 18 decimals
- Single flat fee per student, no partial payments
- No refund mechanism exists for any scenario (expulsion, session cancellation, etc.)

---

## 6. Invariants (10 specific)

### INV-1: Wage distribution must match the documented percentages
> Principal gets exactly 5% of bursary. Teachers **share** exactly 35% of bursary (not 35% each). Remaining 60% stays in bursary after upgrade.
> **CURRENT STATE (BROKEN)**: each teacher gets 35% individually.

### INV-2: A student must not be reviewed more than once per week
> `lastReviewTime[_student] + reviewTime` must elapse before next review.
> **CURRENT STATE (ENFORCED)** : but only per-student, not per-teacher. Multiple teachers can review the same student in the same week as long as `reviewTime` has passed since the last review by ANY teacher.

### INV-3: System upgrade must not occur before session end
> `graduateAndUpgrade()` should require `block.timestamp >= sessionEnd`.
> **CURRENT STATE (BROKEN)** : no timestamp check exists.

### INV-4: All students must receive 4 reviews before upgrade
> Every student in `listOfStudents` must have `reviewCount >= 4` before upgrade.
> **CURRENT STATE (BROKEN)** : no review count check in `graduateAndUpgrade()`.

### INV-5: Students below cutOffScore must not be upgraded
> Students with `studentScore < cutOffScore` should not appear in LevelTwo's `listOfStudents`.
> **CURRENT STATE (BROKEN)** : no filtering happens during upgrade. All students in LevelOne's array persist in LevelTwo.

### INV-6: A student cannot be reviewed more than 4 times (one per week for 4 weeks)
> `reviewCount` must not exceed 4.
> **CURRENT STATE (BROKEN)** : check is `< 5`, allowing 5 reviews. Spec says 4.

### INV-7: Expelled student's fees must not remain in bursary as phantom funds
> When a student is expelled, the `bursary` should decrease by `schoolFees`, or the student should receive a refund.
> **CURRENT STATE (BROKEN)** : bursary unchanged on expulsion. Funds are trapped.

### INV-8: Storage layout must be compatible across LevelOne → LevelTwo upgrade
> All storage variables in LevelOne must have corresponding declarations in LevelTwo at the same slots.
> **CURRENT STATE (BROKEN)** : `schoolFees`, `reviewCount`, `lastReviewTime` removed in LevelTwo, shifting all subsequent variable slots.

### INV-9: Teacher removal during session must not corrupt wage distribution or review integrity
> If a teacher is removed mid-session, their given reviews still count (student scores already reduced). But they should not receive wage share for work they didn't complete, and wage math should still be correct.
> **CURRENT STATE (PARTIALLY BROKEN)** : removed teacher is not in `listOfTeachers` so won't receive wages (good), but past reviews remain (acceptable), and wage math bug (INV-1) makes this area risky.

### INV-10: Principal cannot expel students after session end to manipulate graduation/upgrade
> Expulsion should only be possible during active session.
> **CURRENT STATE (ENFORCED)** : `expel()` checks `inSession == true`.

---

## 7. Functions to Map (Day 23)

### LevelOne.sol : External/Public Functions

| # | Function | Visibility | Caller | Purpose | 🔴 Flags |
|---|----------|-----------|--------|---------|---------|
| 1 | `initialize()` | public | deployer | Set principal, fees, USDC address | initializer only |
| 2 | `enroll()` | external | anyone (not teacher/principal) | Pay fees, become student | bursary accounting, no re-enroll guard post-expulsion during session |
| 3 | `addTeacher()` | public | principal | Add teacher before session | cannot be student |
| 4 | `removeTeacher()` | public | principal | Remove teacher (anytime) | **can remove during session**, no review recalculation |
| 5 | `expel()` | public | principal | Remove student during session | **no refund, bursary not decreased** |
| 6 | `startSession()` | public | principal | Begin 4-week session | **no minimum students/teachers check** |
| 7 | `giveReview()` | public | teachers | Review student (good/bad) | **reviewCount < 5 (should be 4)**, no per-teacher limit, multiple teachers can review same student same week after time gap |
| 8 | `graduateAndUpgrade()` | public | principal | Pay wages, upgrade to LevelTwo | 🔴🔴🔴 **no sessionEnd check, no reviewCount check, no cutOffScore filtering, wage math wrong, upgrade before transfers could revert** |
| 9 | `_authorizeUpgrade()` | internal | principal | UUPS auth hook | no timelock |
| 10 | `getPrincipal()` | external view | anyone | Read principal | — |
| 11 | `getSchoolFeesCost()` | external view | anyone | Read schoolFees | — |
| 12 | `getSchoolFeesToken()` | external view | anyone | Read USDC address | — |
| 13 | `getTotalTeachers()` | external view | anyone | Teacher count | — |
| 14 | `getTotalStudents()` | external view | anyone | Student count | — |
| 15 | `getListOfStudents()` | external view | anyone | Student array | gas concern for large arrays |
| 16 | `getListOfTeachers()` | external view | anyone | Teacher array | gas concern for large arrays |
| 17 | `getSessionStatus()` | external view | anyone | inSession bool | — |
| 18 | `getSessionEnd()` | external view | anyone | sessionEnd timestamp | — |

### LevelTwo.sol — External/Public Functions

| # | Function | Visibility | Caller | Purpose | 🔴 Flags |
|---|----------|-----------|--------|---------|---------|
| 1 | `graduate()` | public | reinitializer(2) | Post-upgrade init | **empty function body — does nothing** |
| 2 | `getPrincipal()` | external view | anyone | Read principal | — |
| 3 | `getSchoolFeesToken()` | external view | anyone | Read USDC address | — |
| 4 | `getTotalTeachers()` | external view | anyone | Teacher count | — |
| 5 | `getTotalStudents()` | external view | anyone | Student count | — |
| 6 | `getListOfStudents()` | external view | anyone | Student array | — |
| 7 | `getListOfTeachers()` | external view | anyone | Teacher array | — |

---

## Checklist Sections That Matter Most (for Day 24)

Based on today's mental model, these checklist areas will be most productive:

1. **Upgradeable Storage Layout** : INV-8, variables removed, slot shift. Thunder Loan lesson round 2.
2. **State Accounting** : INV-1 (wage math), INV-7 (expulsion doesn't reduce bursary), INV-5 (no score filtering on upgrade).
3. **Access Control** : principal has no timelock, can upgrade anytime, can expel anytime during session.
4. **Timelocks / Centralization** : all admin functions instant, no multisig, no delay.
5. **External Calls** : `safeTransfer` in wage loop during `graduateAndUpgrade()`, order of operations (upgrade before transfers).
6. **Input Validation** : `giveReview` allows 5 instead of 4, no minimum students/teachers to start session, cutOffScore has no bounds.

---

## Research Lock

⛔ **Do NOT read public submissions, results, or judged findings until your own report draft exists.**

---

*Kickoff created: Day 22 (21 Jun 2026)*
*Next: Day 23. Function map + first pass*
