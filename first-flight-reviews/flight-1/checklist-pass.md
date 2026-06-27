# First Flight 1 — Hawk High Checklist Pass

> Day 24 working draft. Fill this from `personal-checklist-v1.md` against actual Hawk High code.

## 7. Upgradeable Storage Layout — HIGHEST PRIORITY

### Checklist item: Compare V1 and V2 variable declarations side-by-side. Do the storage slots line up exactly?

Applies? Yes.

| LevelTwo variable | L2 slot | What LevelOne stored at that slot | Where LevelOne stored intended value | Result after upgrade |
|---|---:|---|---:|---|
| `sessionEnd` | 1 | `schoolFees` | 2 | reads school fee amount as session end |
| `bursary` | 2 | `sessionEnd` | 3 | reads timestamp as bursary |
| `cutOffScore` | 3 | `bursary` | 4 | reads bursary amount as cutoff score |
| `isTeacher` | 4 | `cutOffScore` slot / wrong mapping seed | 5 | teacher mapping lookups use wrong seed |
| `isStudent` | 5 | `isTeacher` mapping seed | 6 | student mapping lookups may read teacher membership data |
| `studentScore` | 6 | `isStudent` mapping seed | 7 | student score may read bool membership as score, e.g. `1` |
| `listOfStudents` | 7 | `studentScore` mapping seed | 10 | array length/data not the real student list |
| `listOfTeachers` | 8 | `reviewCount` mapping seed | 11 | array length/data not the real teacher list |
| `usdc` | 9 | `lastReviewTime` mapping seed | 12 | token address likely zero/wrong |

### Storage layout checklist conclusions

- Missing LevelOne variables in LevelTwo:
  - `schoolFees`(uint256)
  - `reviewCount`(mapping)
  - `lastReviewTime`(mapping)

- First slot shift caused by:
  - `schoolFees` from LevelOne was Missing in LevelTwo. i.e. variable not declared in LevelTwo.

- Additional missing mapping slots:
  - `reviewCount`  mapping(address => uint256)  
  - `lastReviewTime` mapping(address => uint256) 
  
- `__gap` present?
  - I don't see `__gap` anywhere in contract.

- Migration function present?
  - No meaningful migration function exists. `LevelTwo.graduate()` is a `reinitializer(2)` but its body is empty, so it does not repair the shifted storage layout or initialize migrated state.

- Actual upgrade execution present in `graduateAndUpgrade()`?
  - No. `graduateAndUpgrade()` calls `_authorizeUpgrade(_levelTwo)` directly, but this only runs the authorization hook. It does not change the proxy implementation because there is no call to `upgradeToAndCall(_levelTwo, data)`.

- Namespaced storage / ERC-7201?
  - No. Hawk High uses normal declaration-order storage for protocol state. Variables like `principal`, `bursary`, `studentScore`, and `listOfStudents` depend on matching slot order between LevelOne and LevelTwo. There is no namespaced storage struct protecting layout across u pgrades.

- Does LevelTwo preserve UUPS upgradeability?
  - No. `LevelTwo` inherits only `Initializable`, not `UUPSUpgradeable`, and it does not implement `_authorizeUpgrade()`. If the proxy were upgraded to LevelTwo, the system would lose the normal UUPS upgrade interface for future upgrades.

- Raw function-map candidates connected:
  - **Location**: `LevelOne.sol` storage declarations vs `LevelTwo.sol`  
    **Observation**: schoolFees, reviewCount, lastReviewTime removed → 3-slot shift for all subsequent state.  
    **Invariant violated**: INV-8  
    **Severity guess**: High (storage collision / corruption on upgrade)
  - **Location**: `LevelTwo.sol:graduate()`  
    **Observation**: Empty `reinitializer(2)`. Does nothing. `graduate()` performs no migration or validation. Because proxy storage is reused during an upgrade, state would not be cleanly reset to defaults; instead, LevelTwo would interpret existing LevelOne storage using the wrong layout.  
    **Invariant violated**: All state-carrying invariants (INV-1,3,4,5,8 etc.)  
    **Severity guess**: High
  

## 1. State Accounting
### Checklist item: Are variables pulling double-duty? Can a state change break accounting?

Applies? Yes.

Area:
- `enroll()`
- `expel()`
- `graduateAndUpgrade()`

Notes:
- `enroll()` increases `bursary` by `schoolFees`.
- `expel()` removes the student from `listOfStudents` and sets `isStudent[_student] = false`.
- `expel()` does not decrease `bursary` and does not refund the expelled student.
- Later, `graduateAndUpgrade()` uses `bursary` to calculate teacher and principal payouts.

Cross-reference:
- Raw candidate from `function-map.md`: expel / bursary unchanged.
- Invariant: INV-7.

Potential finding?
- Yes.

Impact:
- Expelled student fees remain counted in bursary and can be used in later wage calculations even though the student is no longer eligible/active.

### Checklist item: If an array's length is used to calculate payouts or fees, can it break accounting?

Applies? Yes.

Area:
- `graduateAndUpgrade()`

Notes:
- `totalTeachers = listOfTeachers.length`.
- `payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION`.
- `payPerTeacher` is not divided by `totalTeachers`.
- The loop pays `payPerTeacher` once to each teacher.

Cross-reference:
- Raw candidate from `function-map.md`: wage calculation.
- Invariant: INV-1.

Potential finding?
- Yes.

Example:
- With 2 teachers, total teacher payout is 70% of bursary instead of 35%.
- With 3 teachers, teacher payout alone is 105% of bursary, before principal pay.

## 2. Duplicate Action Prevention

### Checklist item: If the system tracks already-processed actions, is the tracking state updated?

Applies? Yes.

Area:
- `giveReview(address _student, bool review)`

Code references:
- `reviewCount[_student]`
- `lastReviewTime[_student]`
- `studentScore[_student]`

Notes:
- `giveReview()` checks `reviewCount[_student] < 5`.
- `reviewCount[_student]` is never incremented anywhere in `giveReview()`.
- Because the counter stays at its default value of `0`, the review-count cap never activates.
- As long as `block.timestamp >= lastReviewTime[_student] + reviewTime`, a teacher can continue reviewing the same student over time.
- This also means the protocol cannot reliably prove that a student received exactly/at least the required number of reviews before graduation.

Cross-reference:
- Raw candidate from `function-map.md`: `giveReview()` reviewCount never incremented.
- Invariant: INV-4 / INV-6.

Potential finding?
- Yes.

Impact:
- The intended maximum review count is unenforced. Students can continue receiving reviews beyond the intended session review limit, allowing repeated bad reviews to reduce scores over time.

### Checklist item: Is there an off-by-one or duplicate action boundary error?

Applies? Yes.

Area:
- `giveReview(address _student, bool review)`

Notes:
- The code uses `require(reviewCount[_student] < 5, ...)`.
- If `reviewCount` were incremented correctly, this condition would allow review counts `0, 1, 2, 3, 4`, meaning five reviews total.
- The expected maximum is four reviews, so the boundary should be based on `< 4` or equivalent logic.
- Starting from score `100`, four bad reviews reduce the score to `60`, which is below a cutoff of `70`. A fifth bad review would reduce it further to `50`.

Cross-reference:
- Raw candidate from `function-map.md`: `< 5` allows 5.
- Invariant: INV-6.

Potential finding?
- Likely combine with missing `reviewCount` increment.

Impact:
- Even if the missing increment were fixed, the current boundary would still allow one extra review, which can further reduce a student's score beyond the intended review limit.

### Checklist item: If multiple actors can perform the same action, is uniqueness enforced per actor or globally?

Applies? Yes.

Area:
- `giveReview(address _student, bool review)`

Notes:
- `lastReviewTime[_student]` is tracked per student, not per teacher-student pair.
- This means the system enforces one review per student per week globally, regardless of which teacher gives it.
- There is no mapping like `lastReviewTime[teacher][student]`.

Cross-reference:
- Raw candidate from `function-map.md`: only global `lastReviewTime`, no per-teacher tracking.
- Invariant: INV-2.

Potential finding?
- Needs spec check. Could be intended if the school wants only one review per student per week total.

### New checklist issue surfaced: reviews are not bounded to the active session window

Applies? Yes.

Area:
- `giveReview(address _student, bool review)`
- `startSession(uint256 _cutOffScore)`

Notes:
- `giveReview()` does not check `inSession == true`.
- `giveReview()` does not check `block.timestamp <= sessionEnd`.
- Therefore, reviews are not explicitly limited to the 4-week school session.
- If the contract remains on LevelOne, teachers can keep reviewing students after the intended 4-week period, subject only to the weekly `lastReviewTime` delay.

Cross-reference:
- Related to raw candidate: `giveReview()` / reviewCount never incremented.
- Related invariant: INV-2 / INV-3 / INV-6.

Potential finding?
- Maybe. Severity depends on spec expectations, but it supports the review-system findings.

## 3. External Calls

### Checklist item: Does the function make an external call before fully updating state?

Applies? Yes.

Area:
- `enroll()`

External call:
- `usdc.safeTransferFrom(msg.sender, address(this), schoolFees)`

Notes:
- `enroll()` performs the token transfer after access/existence checks but before updating `listOfStudents`, `isStudent`, `studentScore`, and `bursary`.
- If `safeTransferFrom()` reverts, the whole transaction reverts and `bursary` is not increased.
- This ordering prevents unpaid enrollment because student state is only written after payment succeeds.
- Reentrancy risk appears low with normal USDC, but the contract accepts an arbitrary ERC20 token address at initialization and has no `nonReentrant` guard.

Cross-reference:
- Related to `enroll()` accounting path in `function-map.md`.

Potential finding?
- Probably not standalone unless malicious/non-standard token behavior is in scope.

### Checklist item: What happens if an external call fails, reverts, or consumes all gas?

Applies? Yes.

Area:
- `graduateAndUpgrade()`

External calls:
- `usdc.safeTransfer(listOfTeachers[n], payPerTeacher)`
- `usdc.safeTransfer(principal, principalPay)`

Notes:
- `graduateAndUpgrade()` loops through `listOfTeachers` and transfers `payPerTeacher` to each teacher.
- If any teacher transfer reverts, the whole transaction reverts and no wage payouts are finalized.
- The principal transfer happens after teacher transfers, so it also does not execute if a teacher transfer reverts first.
- The larger issue is that `payPerTeacher` is calculated as 35% of `bursary` per teacher, so with enough teachers the function can revert due to insufficient balance.

Cross-reference:
- Raw candidate from `function-map.md`: wage calculation / `graduateAndUpgrade()`.

Potential finding?
- Yes, but likely as part of the wage-math finding, not as a separate external-call finding.

### Checklist item: Is `_authorizeUpgrade()` an external call or actual upgrade?

Applies? Yes.

Area:
- `graduateAndUpgrade()`
- `_authorizeUpgrade(address newImplementation)`

Notes:
- `_authorizeUpgrade(_levelTwo)` is an internal authorization hook.
- Calling `_authorizeUpgrade()` directly does not update the proxy implementation.
- `graduateAndUpgrade()` does not call `upgradeToAndCall(_levelTwo, data)`.
- Therefore, `LevelTwo.graduate()` is not called and the proxy remains on LevelOne.

Cross-reference:
- Raw candidate from `function-map.md`: no actual upgrade execution.
- Invariant: INV-8 / upgrade-flow invariant.

Potential finding?
- Yes.


## 4. Access Control

### Checklist item: Does the function perform privileged actions, and is caller validation present?

Applies? Yes.

Area:
- `addTeacher()`
- `removeTeacher()`
- `expel()`
- `startSession()`
- `graduateAndUpgrade()`
- `_authorizeUpgrade()`
- `giveReview()`

Notes:
- `addTeacher()`, `removeTeacher()`, `expel()`, `startSession()`, `graduateAndUpgrade()`, and `_authorizeUpgrade()` are restricted with `onlyPrincipal`.
- `giveReview()` is restricted with `onlyTeacher`.
- Basic role checks exist for privileged actions.

Cross-reference:
- Function map role table.

Potential finding?
- Not from missing role modifiers alone.

### Checklist item: Can privileged role bypass expected protocol flow?

Applies? Yes.

Area:
- `graduateAndUpgrade()`

Notes:
- `graduateAndUpgrade()` is restricted to the principal, but it does not check that the session has ended.
- There is no check like `block.timestamp >= sessionEnd`.
- There is no check that each student received the required number of reviews.
- There is no cutoff filtering before the attempted graduation/upgrade flow.
- The principal can call the function before the intended end of the 4-week session.

Cross-reference:
- Raw candidate from `function-map.md`: `graduateAndUpgrade()` missing `sessionEnd`, `reviewCount`, and cutoff checks.
- Invariants: INV-3, INV-4, INV-5.

Potential finding?
- Yes.

### Checklist item: Can admin change role composition during active protocol period?

Applies? Yes.

Area:
- `removeTeacher(address _teacher)`

Notes:
- `removeTeacher()` is `onlyPrincipal`, but it does not use `notYetInSession`.
- Therefore, the principal can remove a teacher during an active session.
- Past reviews already applied by the teacher remain reflected in student scores.
- The removed teacher is removed from `listOfTeachers`, so they are excluded from later wage distribution.

Cross-reference:
- Raw candidate from `function-map.md`: teacher removal mid-session.
- Invariant: INV-9.

Potential finding?
- Maybe Low/Medium depending intended teacher wage/review rules.

### Checklist item: Can admin choose arbitrary upgrade implementation?

Applies? Yes.

Area:
- `graduateAndUpgrade(address _levelTwo, bytes memory)`
- `_authorizeUpgrade(address newImplementation)`

Notes:
- `graduateAndUpgrade()` only checks `_levelTwo != address(0)`.
- It does not check that `_levelTwo` is a contract.
- It does not restrict `_levelTwo` to a known audited implementation.
- There is no timelock or multisig delay around upgrade authorization.
- `_authorizeUpgrade()` is restricted to `onlyPrincipal`, but its body is otherwise empty.

Cross-reference:
- Raw candidate from `function-map.md`: upgrade flow / arbitrary `_levelTwo`.
- Invariant: INV-8 / centralization risk.

Potential finding?
- Likely centralization / trust assumption unless the threat model requires restricted upgrade targets.


## 5. Input Validation

### Checklist item: Are numerical inputs checked for zero or maximum bounds?

Applies? Yes.

Area:
- `startSession(uint256 _cutOffScore)`

Notes:
- `startSession()` accepts `_cutOffScore` from the principal.
- There is no lower bound check.
- There is no upper bound check.
- The principal can set `_cutOffScore` to `0`, greater than `100`, or any arbitrary value.
- Since student scores start at `100`, a cutoff above `100` can make graduation impossible, while a cutoff of `0` can make every student pass.

Cross-reference:
- Raw candidate from `function-map.md`: `startSession()` no validation.
- Invariant: INV-5 / graduation correctness.

Potential finding?
- Maybe Low/Medium depending spec and principal trust assumptions.

### Checklist item: Are addresses checked against `address(0)`?

Applies? Yes.

Area:
- `initialize()`
- `addTeacher()`
- `removeTeacher()`
- `expel()`
- `graduateAndUpgrade()`

Notes:
- `initialize()` checks `_principal` and `_usdcAddress` against `address(0)`.
- `addTeacher()`, `removeTeacher()`, `expel()`, and `graduateAndUpgrade()` check address inputs against `address(0)`.
- However, `graduateAndUpgrade()` does not check whether `_levelTwo` contains contract code.

Cross-reference:
- Upgrade-flow candidate.

Potential finding?
- Maybe Low/Medium only if arbitrary non-contract upgrade targets are in scope.

### Checklist item: Are required preconditions checked before critical flow?

Applies? Yes.

Area:
- `startSession()`
- `graduateAndUpgrade()`

Notes:
- `startSession()` does not require at least one teacher.
- `startSession()` does not require at least one student.
- `graduateAndUpgrade()` does not require the session to have ended.
- `graduateAndUpgrade()` does not require each student to have completed the required number of reviews.
- `graduateAndUpgrade()` does not filter or remove students below `cutOffScore`.

Cross-reference:
- Raw candidates from `function-map.md`: startSession no minimums; graduateAndUpgrade missing critical checks.
- Invariants: INV-3, INV-4, INV-5.

Potential finding?
- Yes for the missing `graduateAndUpgrade()` checks. Start-session minimums are probably lower severity.


## 6. Event Correctness

### Checklist item: Are state-changing actions reliably emitting events?

Applies? Yes.

Area:
- `addTeacher()`
- `removeTeacher()`
- `enroll()`
- `expel()`
- `startSession()`
- `giveReview()`
- `graduateAndUpgrade()`

Notes:
- `addTeacher()` emits `TeacherAdded`.
- `removeTeacher()` emits `TeacherRemoved`.
- `enroll()` emits `Enrolled`.
- `expel()` emits `Expelled`.
- `startSession()` emits `SchoolInSession`.
- `giveReview()` emits `ReviewGiven`.
- `graduateAndUpgrade()` declares/has `Graduated`, but the function does not emit it.

Cross-reference:
- Raw candidate from `function-map.md`: `graduateAndUpgrade()` does not actually upgrade.
- Related invariant: INV-8 / upgrade-flow correctness.

Potential finding?
- Low/Info only by itself. Stronger as supporting evidence for the broken graduation/upgrade flow.

### Checklist item: Are events logging correct updated data?

Applies? Yes.

Area:
- `giveReview()`
- `startSession()`
- `expel()`

Notes:
- `ReviewGiven` emits `studentScore[_student]` after the score mutation, so it logs the updated score.
- `SchoolInSession` emits `block.timestamp` and `sessionEnd` after `sessionEnd` is assigned.
- `Expelled` only logs the student address. It does not log whether any fee was refunded or retained in bursary.

Cross-reference:
- Expel / bursary accounting candidate.
- Invariant: INV-7.

Potential finding?
- Likely Low/Info. Useful as supporting context, not a primary finding.


## 8. Oracle & Pricing

### Checklist item: Oracle and pricing checks

Applies? No.

Notes:
- Hawk High does not use an oracle.
- There is no AMM spot price, TWAP, Chainlink feed, or exchange-rate pricing logic in the scoped contracts.
- School fees are set directly in `initialize()` as `_schoolFees`.
- Wage calculations use fixed constants: `TEACHER_WAGE`, `PRINCIPAL_WAGE`, and `PRECISION`.

Cross-reference:
- Wage math is handled under State Accounting, not Oracle & Pricing.

Potential finding?
- No.


## 9. Flash Loan Safety

### Checklist item: Flash loan safety checks

Applies? No.

Notes:
- Hawk High does not implement flash loans.
- There are no `flashloan()`, `deposit()`, `redeem()`, repayment, exchange-rate, or active-loan state-machine functions.
- No flash-loan-specific checklist items apply.

Potential finding?
- No.

## 10. Timelocks & Centralization

### Checklist item: Do admin functions execute instantly or through a timelock?

Applies? Yes.

Area:
- `addTeacher()`
- `removeTeacher()`
- `expel()`
- `startSession()`
- `graduateAndUpgrade()`
- `_authorizeUpgrade()`

Notes:
- All principal-controlled functions execute immediately.
- There is no timelock, multisig, delay, or two-step process.
- The principal can start the session, remove teachers, expel students, and trigger the graduation/upgrade path without delay.
- `graduateAndUpgrade()` accepts an arbitrary `_levelTwo` address except for the zero-address check.
- `_authorizeUpgrade()` is restricted to `onlyPrincipal`, but has no additional validation in its body.

Cross-reference:
- Raw candidates from `function-map.md`: arbitrary upgrade path, missing upgrade checks, teacher removal mid-session.
- Invariants: INV-3, INV-4, INV-5, INV-8, INV-9.

Potential finding?
- Likely Low/Medium centralization/trust issue unless the protocol explicitly requires stronger upgrade governance.

### Checklist item: Can admin actions affect funds or participant outcomes?

Applies? Yes.

Area:
- `removeTeacher()`
- `expel()`
- `graduateAndUpgrade()`

Notes:
- `removeTeacher()` can be called during an active session and removes the teacher from the wage recipient list.
- `expel()` removes a student during session, but does not refund their fee or reduce `bursary`.
- `graduateAndUpgrade()` calculates wages from `bursary` and can be called without checking session end, completed reviews, or cutoff filtering.

Cross-reference:
- Raw candidates from `function-map.md`: teacher removal mid-session, expel accounting, missing graduate checks.
- Invariants: INV-3, INV-4, INV-5, INV-7, INV-9.

Potential finding?
- Yes, but these likely become separate findings rather than one broad centralization finding.