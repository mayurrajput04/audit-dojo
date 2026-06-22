    # First Flight 1 | Hawk High: Function Map & First Pass

> **Day 23 of 68** | Archived / Shadow Audit | Function Map + First Pass  
> **Target:** CodeHawks First Flight #39 : Hawk High (nSLOC 243)  
> **Focus:** Trace every public/external function + storage layout + upgrade flow. No public submissions read. Pure mapping.

---

## 1. Function Map : LevelOne.sol

All external + public functions. (Views first for simplicity, then mutative.)

| # | Function Signature | Caller (Access) | Purpose (1-liner) | State Changed | Assets Moved | Dangerous Dependency / Risks | 🔴 Flags (from invariants or observation) |
|---|---------------------|-----------------|-------------------|---------------|--------------|------------------------------|---------------------------------------------|
| 1 | `initialize(address _principal, uint256 _schoolFees, address _usdcAddress)` | Deployer (initializer only) | Set up principal, fees, token. Runs once. | principal, schoolFees, usdc | None | Initializer guard; no re-init. | None (standard). |
| 2 | `enroll()` | Anyone (not teacher/principal, not already student) | Pay schoolFees, join as student. | listOfStudents.push, isStudent=true, studentScore=100, bursary += schoolFees | USDC: safeTransferFrom(msg.sender, this, schoolFees) | `notYetInSession` modifier; assumes USDC approval. | INV-7 risk (fees added to bursary forever). No check if expelled before (but expulsion only in session). |
| 3 | `addTeacher(address _teacher)` | onlyPrincipal + notYetInSession | Hire teacher pre-session. | listOfTeachers.push, isTeacher[_teacher]=true | None | Checks for zero, duplicate teacher, or already student. | Can only add before session. |
| 4 | `removeTeacher(address _teacher)` | onlyPrincipal (no session guard!) | Fire teacher anytime. | Remove from listOfTeachers (swap-pop), isTeacher=false | None | Loop search + pop. Can happen **during session**. | 🔴 INV-9: removed teacher reviews still count (scores already reduced), but no wage share. Wage math (INV-1) makes fairness messy. |
| 5 | `expel(address _student)` | onlyPrincipal (requires inSession) | Remove bad student mid-session. | Remove from listOfStudents (swap-pop), isStudent=false. **No other resets.** | None (fees stay) | Requires inSession; zero/does-not-exist checks. | 🔴 **INV-7 BROKEN**: bursary NOT decreased. Fees trapped. studentScore, reviewCount, lastReviewTime left dirty in mappings. |
| 6 | `startSession(uint256 _cutOffScore)` | onlyPrincipal + notYetInSession | Start 4-week session. | sessionEnd = now + 4w, inSession=true, cutOffScore=_cutOffScore | None | No min teachers/students check. | 🔴 INV-3/INV-4/INV-5 risk (upgrade can happen immediately after). cutOffScore can be 0 or insane. |
| 7 | `giveReview(address _student, bool review)` | onlyTeacher | Give weekly review (bad=false reduces score by 10). | studentScore (if !review -=10), lastReviewTime = now | None | reviewCount < 5 check (NOT <4!), lastReviewTime + reviewTime check. | 🔴 **INV-6 BROKEN** (allows 5 reviews). 🔴 **INV-2 partially broken**: only global per-student lock. 3 teachers can all review same student after 1 week gap from *any* previous review. No per-teacher tracking. reviewCount not incremented in code? (wait, require only, no ++ — bug?) |
| 8 | `graduateAndUpgrade(address _levelTwo, bytes memory data)` | onlyPrincipal | Pay wages then "upgrade". | None directly in L1 (but calls _authorize). **Critical path.** | USDC: safeTransfer to each teacher (payPerTeacher), then principal (principalPay) | `safeTransfer` in loop. _authorizeUpgrade called **before** transfers. | 🔴🔴🔴 **Multiple broken**: INV-1 (35% EACH), INV-3 (no sessionEnd), INV-4 (no reviewCount>=4), INV-5 (no cutOff filtering), INV-8 (layout). See full trace below. |
| 9 | `_authorizeUpgrade(address newImplementation)` | internal, onlyPrincipal (override) | UUPS auth hook. | Nothing (empty body) | None | Empty override. | 🔴 Does **NOT** perform upgrade. No call to upgradeToAndCall. |
| 10-18 | All `get*()` views (`getPrincipal`, `getSchoolFeesCost`, `getSchoolFeesToken`, `getTotalTeachers`, `getTotalStudents`, `getListOfStudents`, `getListOfTeachers`, `getSessionStatus`, `getSessionEnd`) | Anyone | Read-only getters. | None | None | Arrays returned by value (gas risk if large). | None. |

**Note on giveReview**: `reviewCount` is **never incremented** in the function body — only a `require(reviewCount[_student] < 5)`. So reviewCount stays at 0 forever in practice. Another silent violation of INV-6.

---

## 2. Function Map : LevelTwo.sol

Much thinner. Post-upgrade "graduate" contract.

| # | Function Signature | Caller | Purpose (1-liner) | State Changed | Assets Moved | Dangerous Dependency | 🔴 Flags |
|---|---------------------|--------|-------------------|---------------|--------------|----------------------|----------|
| 1 | `graduate()` | reinitializer(2) | Post-upgrade initializer. | Nothing (empty body) | None | Called via upgradeToAndCall data (never happens in L1). | 🔴 **EMPTY**. Should carry forward principal, bursary, students, teachers, scores, cutOffScore, etc. State will be zeroed/defaults. |
| 2 | `getPrincipal()` | Anyone | Read principal | None | None | — | — |
| 3 | `getSchoolFeesToken()` | Anyone | Read USDC addr | None | None | — | — |
| 4 | `getTotalTeachers()` | Anyone | Teacher count | None | None | — | — |
| 5 | `getTotalStudents()` | Anyone | Student count | None | None | — | — |
| 6 | `getListOfStudents()` | Anyone | Full student array | None | None | Gas for large arrays | — |
| 7 | `getListOfTeachers()` | Anyone | Full teacher array | None | None | Gas for large arrays | — |

**LevelTwo has no UUPS** (no UUPSUpgradeable inheritance), no wage payout logic, no review logic, no session controls. It's basically a read-only snapshot (that never gets properly initialized).

---

## 3. Storage Layout Comparison (Rigorous Slot-by-Slot)

**Thunder Loan lesson applied. No hand-waving.**

### LevelOne.sol (user-declared storage, declaration order)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0 | `principal` + `inSession` | address + bool (packed) | Slot 0 |
| 1 | `schoolFees` | uint256 | **MISSING in L2** |
| 2 | `sessionEnd` | uint256 | |
| 3 | `bursary` | uint256 | |
| 4 | `cutOffScore` | uint256 | |
| 5 | `isTeacher` | mapping(address => bool) | |
| 6 | `isStudent` | mapping(address => bool) | |
| 7 | `studentScore` | mapping(address => uint256) | |
| 8 | `reviewCount` | mapping(address => uint256) | **MISSING in L2** |
| 9 | `lastReviewTime` | mapping(address => uint256) | **MISSING in L2** |
| 10 | `listOfStudents` | address[] | |
| 11 | `listOfTeachers` | address[] | |
| 12 | `usdc` | IERC20 | |

**Immutable**: `reviewTime` (no slot). Constants: no slots.

### LevelTwo.sol (user-declared storage)

| Slot | Variable | Type | Notes |
|------|----------|------|-------|
| 0 | `principal` + `inSession` | address + bool (packed) | Matches L1 slot 0 |
| 1 | `sessionEnd` | uint256 | **Garbage** (L1 slot 2 data here? No — L1 slot 1 was schoolFees) |
| 2 | `bursary` | uint256 | Matches L1 slot 3? **Shifted** |
| 3 | `cutOffScore` | uint256 | Shifted |
| 4 | `isTeacher` | mapping | Shifted |
| 5 | `isStudent` | mapping | Shifted |
| 6 | `studentScore` | mapping | Shifted |
| 7 | `listOfStudents` | address[] | Shifted by 3 |
| 8 | `listOfTeachers` | address[] | Shifted by 3 |
| 9 | `usdc` | IERC20 | Shifted |

### Mismatches (INV-8 — BROKEN)

- **schoolFees** (L1 slot 1) → L2 slot 1 becomes `sessionEnd` (reads garbage or wrong value).
- **reviewCount** (L1 slot 8) and **lastReviewTime** (L1 slot 9) completely absent → all arrays + usdc shift left by 2 slots.
- **listOfStudents** / **listOfTeachers** / **usdc** read from wrong slots after upgrade.
- After upgrade (if it ever happened), `bursary`, `studentScore`, `listOf*` would be garbage or point to wrong data.
- LevelTwo also declares new constants (`TEACHER_WAGE_L2 = 40`) but no wage logic.
- **No `__gap`** arrays. No migration function.

**Result**: Even if upgradeToAndCall were called, state would be corrupted. Proxy storage is permanent.

---

## 4. Upgrade Flow Trace — `graduateAndUpgrade()` (Line-by-Line)

**The most dangerous path. Trace exactly.**

### Exact order in `graduateAndUpgrade(address _levelTwo, bytes memory)`:

```solidity
function graduateAndUpgrade(address _levelTwo, bytes memory) public onlyPrincipal {
    if (_levelTwo == address(0)) revert HH__ZeroAddress();

    uint256 totalTeachers = listOfTeachers.length;

    uint256 payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION;   // 35% * bursary  (per teacher!)
    uint256 principalPay = (bursary * PRINCIPAL_WAGE) / PRECISION;  // 5%

    _authorizeUpgrade(_levelTwo);   // <--- STEP 1: called FIRST

    for (uint256 n = 0; n < totalTeachers; n++) {
        usdc.safeTransfer(listOfTeachers[n], payPerTeacher);   // STEP 2: transfers
    }

    usdc.safeTransfer(principal, principalPay);   // STEP 3
}
```

### Critical observations:

1. **What happens first: upgrade or wage transfers?**  
   `_authorizeUpgrade` is called **BEFORE** any transfers. But `_authorizeUpgrade` is **empty** (`internal override onlyPrincipal {}`) — it does **NOT** upgrade the implementation.

2. **Does the actual proxy switch happen?**  
   **No.** There is no `upgradeToAndCall(_levelTwo, data)` anywhere.  
   The proxy's implementation address is **never updated**.  
   Calling `graduateAndUpgrade` does **nothing** to the proxy logic.  
   (The test casts the proxy address as LevelTwo after the call — this is an illusion; the underlying implementation remains LevelOne.)

3. **What happens if a `safeTransfer` reverts mid-loop?**  
   - If first transfer succeeds → funds leave the contract.  
   - Second teacher transfer reverts → **entire tx reverts**.  
   - But since `_authorizeUpgrade` already ran (empty), **no state rollback for upgrade** (because there is none).  
   - Funds transferred so far are **not rolled back** (transfers are not atomic with the rest of the tx in the sense that prior transfers are permanent if later revert? Wait — no: the whole tx reverts on any revert, including safeTransfer. So prior transfers **are** reverted because tx fails. SafeERC20 reverts the tx on failure.

   **Key**: If any transfer fails, the **entire call reverts**. No partial payout. But since upgrade never actually happens, the proxy stays in LevelOne.

4. **What happens to the proxy state if upgrade "succeeds" but transfers fail?**  
   Upgrade never succeeds. Transfers failing = whole tx fails = no state change at all (except gas spent). Bursary stays intact.

5. **Does `upgradeToAndCall` execute `LevelTwo.graduate()` before or after the transfers?**  
   **Never executes.** No `upgradeToAndCall` call exists.  
   `graduate()` (the reinitializer) is **never called**. It is empty anyway.

6. **If upgrade somehow happened (hypothetical):**  
   - Transfers happen **after** the (non-existent) upgrade call.  
   - If a transfer reverted, proxy would be stuck pointing at LevelTwo while wages unpaid + funds partially moved.  
   - But because of the bug, this scenario is unreachable.

### INV-1 wage math in action here:
```solidity
payPerTeacher = (bursary * 35) / 100;   // EACH teacher gets 35%
```
With 2 teachers: 70% teachers + 5% principal = 75% of bursary leaves. Remaining 25% should be 60% per spec. With 3+ teachers → over 100% → reverts on insufficient balance.

---

## 5. Candidate Issues from First Pass (Raw Observations)

Do **not** treat these as polished findings. Just raw flags from mapping.

- **Location**: `LevelOne.sol:graduateAndUpgrade` (lines ~280-300)  
  **Observation**: `_authorizeUpgrade` called before transfers; actual upgrade never performed (no `upgradeToAndCall`). Wage calculations use 35% per teacher. No sessionEnd / reviewCount / cutOffScore checks.  
  **Invariant violated**: INV-1, INV-3, INV-4, INV-5, INV-8  
  **Severity guess**: High (multiple)

- **Location**: `LevelOne.sol:graduateAndUpgrade` + `_authorizeUpgrade`  
  **Observation**: Empty `_authorizeUpgrade` body + no upgrade execution means the whole graduate flow is broken.  
  **Invariant violated**: INV-3, INV-8 (plus protocol invariant that upgrade should actually upgrade)  
  **Severity guess**: High

- **Location**: `LevelOne.sol:giveReview` (lines ~260-275)  
  **Observation**: `require(reviewCount[_student] < 5)` (allows 5). `reviewCount` is **never incremented**. Only global `lastReviewTime`. No per-teacher tracking.  
  **Invariant violated**: INV-6 (and INV-2)  
  **Severity guess**: Medium

- **Location**: `LevelOne.sol:expel` (lines ~220-240)  
  **Observation**: Array pop + `isStudent=false` only. `bursary` unchanged. `studentScore`, `reviewCount`, `lastReviewTime` untouched.  
  **Invariant violated**: INV-7  
  **Severity guess**: Medium (accounting + trapped funds)

- **Location**: `LevelOne.sol` storage declarations vs `LevelTwo.sol`  
  **Observation**: schoolFees, reviewCount, lastReviewTime removed → 3-slot shift for all subsequent state.  
  **Invariant violated**: INV-8  
  **Severity guess**: High (storage collision / corruption on upgrade)

- **Location**: `LevelOne.sol:removeTeacher` (anytime)  
  **Observation**: Can fire mid-session. Past reviews remain (scores reduced), but teacher removed from wage list.  
  **Invariant violated**: INV-9 (partially)  
  **Severity guess**: Low-Medium

- **Location**: `LevelOne.sol:startSession` + `enroll`  
  **Observation**: No minimum # of teachers/students to start. Principal can enroll? No (blocked), but teachers added pre-session only.  
  **Invariant violated**: None directly, but enables other broken invariants.  
  **Severity guess**: Low

- **Location**: `LevelTwo.sol:graduate()`  
  **Observation**: Empty `reinitializer(2)`. Does nothing. Would leave all state at default (0) even if called.  
  **Invariant violated**: All state-carrying invariants (INV-1,3,4,5,8 etc.)  
  **Severity guess**: High

- **Location**: `LevelOne.sol:graduateAndUpgrade` wage calc  
  **Observation**: `payPerTeacher = (bursary * 35) / 100` inside loop (per teacher). `totalTeachers` used only for loop count.  
  **Invariant violated**: INV-1  
  **Severity guess**: High

- **Location**: All `getListOf*` views  
  **Observation**: Return full arrays. Potential gas grief if 100s of students.  
  **Severity guess**: Low

- **Location**: `LevelOne.sol:enroll`  
  **Observation**: `bursary += schoolFees` with no corresponding decrease on expel.  
  **Invariant violated**: INV-7  
  **Severity guess**: Medium

---

## 6. Quick Answers to Today's Mapping Questions (From Code Trace)

(We walked these together via structured questioning.)_student

1. **graduateAndUpgrade upgrade vs transfers?**  
   `_authorizeUpgrade` (empty) **first**, transfers **after**. If upgrade "succeeded" (it doesn't), proxy would switch before transfers. If a transfer later reverts → whole tx reverts (no upgrade effect anyway).

2. **3 teachers review same student same week?**  
   Only global per-student time lock + `reviewCount < 5`. After 1 week from the *last* review (by anyone), **any** teacher can review again. No per-teacher mapping. Multiple teachers allowed in same "week window" as long as time has passed since last review.

3. **expel() + no reset of studentScore / reviewCount / lastReviewTime?**  
   Bursary stays the same (INV-7 broken). Dirty data left in mappings. If student somehow re-enrolls later (impossible during session), old score/review history would still be there. Fees trapped forever.

4. **safeTransfer teacher[0] succeeds, teacher[1] reverts?**  
   Entire transaction reverts (SafeERC20 reverts on failure). No partial payouts. Upgrade path (non-functional) also rolled back. But because `_authorizeUpgrade` is before loop, if it did real work the state change would be part of the revert.

5. **Storage layout slot-by-slot?**  
   See Section 3 above. Principal + inSession match (slot 0). Everything after slot 0 is shifted/garbage because of 3 missing variables (schoolFees + 2 review mappings).

6. **removeTeacher during session fair?**  
   Removed teacher won't get paid (good). But their bad reviews already tanked student scores with no recalc. Wage math bug makes the whole thing unfair anyway. Potential INV-9 violation.

7. **enroll() — can principal add self as student?**  
   No (`if (isTeacher[msg.sender] || msg.sender == principal) revert`). Can a teacher enroll as student before being added? No — `addTeacher` checks `if (isStudent[_teacher]) revert`. But order of operations could be abused if principal adds teacher who was previously a student.

8. **Exact order in graduateAndUpgrade + _authorizeUpgrade?**  
   `_authorizeUpgrade` sets permission conceptually but here is empty. **Actual proxy switch never happens**. Transfers after. The real upgrade mechanism (`upgradeToAndCall`) is never invoked.

9. **LevelTwo's empty `graduate()`?**  
   It should reinitialize/carry forward state from L1. Does nothing → all state zeroed on hypothetical upgrade. Creates massive issues with bursary, students, principal, etc.

10. **Test scenarios NOT covered?**  
    - Multiple teachers reviewing same student.  
    - `reviewCount` actually reaching 4/5.  
    - Expel + check bursary unchanged.  
    - Wage math with 2+ teachers (overdraw).  
    - graduateAndUpgrade when session not ended / reviews incomplete / students below cutoff.  
    - Actual upgrade behavior (storage after cast).  
    - Re-entrancy on safeTransfer in wage loop.  
    - Principal calling expel after sessionEnd.  
    - Zero teachers or zero students at startSession/graduate.  
    - What happens to funds if graduateAndUpgrade partially succeeds (it doesn't).

---

## Next Steps (Coach Note)

You now know every function cold. The upgrade flow is a total mess (empty authorize + no upgrade call + wrong wage math + storage collision). The 7 broken invariants from kickoff are now **tied to exact lines**.

**Tomorrow (Day 24)**: Run full personal checklist + turn raw candidates into structured findings. Focus on storage layout first (Thunder Loan PTSD).

**Rescue protocol reminder**: If you freeze, pick **one** function, write its row, move to next.

You did the hard part today. The map is the skeleton.

---

*Function map created: Day 23 (2026-06-22)*  
*Gintoki-style: "The code is lying to you about upgrading. And paying teachers. And graduating students. Classic."*

**Research lock still active.** Do not peek at submissions.