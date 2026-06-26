# First Flight 1 — Hawk High Candidate Findings

> Day 24 working draft. Candidate findings derived from `kickoff.md`, `function-map.md`, `checklist-pass.md`, and local source review of `LevelOne.sol` / `LevelTwo.sol`. These are candidate issues for later PoC/report polishing, not final judged severities.

---

### [H-01] Storage layout incompatibility corrupts LevelTwo state after upgrade

**Location:** `LevelOne.sol:38-57`, `LevelTwo.sol:11-26`

**Severity:** High

**Invariant Violated:** INV-8

**Description:**
`LevelTwo` does not preserve the storage layout of `LevelOne`. `LevelOne` declares `schoolFees` at slot 1, `reviewCount` at slot 8, and `lastReviewTime` at slot 9, but those variables are absent from `LevelTwo`. Because upgradeable proxy storage is reused across implementations, removing variables shifts the meaning of later slots. For example, `LevelTwo.sessionEnd` at slot 1 reads old `LevelOne.schoolFees`, `LevelTwo.bursary` at slot 2 reads old `LevelOne.sessionEnd`, and `LevelTwo.cutOffScore` at slot 3 reads old `LevelOne.bursary`. Mapping and array seed slots are also shifted, causing `studentScore`, `listOfStudents`, `listOfTeachers`, and `usdc` to read from incorrect storage locations.

**Impact:**
If the proxy is upgraded to `LevelTwo`, core protocol state is corrupted. The bursary value becomes a timestamp-like value, cutoff score becomes the old bursary amount, student score lookups use the wrong mapping seed, student/teacher arrays no longer point to the correct array length/data slots, and `getSchoolFeesToken()` may return a zero or invalid token address. This breaks graduation state, accounting, role/student views, and future token interactions.

**Proof of Concept (high level):**
1. Deploy `LevelOne` behind a proxy and initialize it.
2. Enroll students, add teachers, and start a session.
3. Upgrade the proxy implementation to `LevelTwo`.
4. Read state through `LevelTwo` getters.
5. Observe shifted-slot reads:
   - `sessionEnd` reads old `schoolFees` from slot 1.
   - `bursary` reads old `sessionEnd` from slot 2.
   - `cutOffScore` reads old `bursary` from slot 3.
   - `studentScore[student]` uses mapping seed slot 6 instead of LevelOne's slot 7.
   - `listOfStudents` uses slot 7 instead of LevelOne's slot 10.
   - `usdc` reads slot 9 instead of LevelOne's slot 12.

**Recommendation:**
Preserve the exact storage layout across upgrades. Keep removed variables in `LevelTwo` as deprecated/reserved fields, append new variables only after the existing layout, and add a `__gap` for future upgrades. If a layout change is unavoidable, implement a carefully designed migration using fixed storage slots/namespaced storage and test it with storage-layout tooling.

**Related Functions:** `graduateAndUpgrade()`, `LevelTwo.graduate()`, `getListOfStudents()`, `getListOfTeachers()`, `getSchoolFeesToken()`

---

### [H-02] `graduateAndUpgrade()` never performs the actual UUPS upgrade

**Location:** `LevelOne.sol:295-314`

**Severity:** High

**Invariant Violated:** INV-8 / Upgrade-flow invariant

**Description:**
`graduateAndUpgrade()` appears to implement the graduation and upgrade flow, but it never calls the UUPS upgrade function. The function directly calls `_authorizeUpgrade(_levelTwo)`, which is only an internal authorization hook. Calling this hook directly does not update the ERC1967 implementation slot and does not delegatecall into `LevelTwo.graduate()`. As a result, the proxy remains on `LevelOne` after `graduateAndUpgrade()` completes.

**Impact:**
The school cannot actually graduate to `LevelTwo` through the intended public flow. Any post-upgrade behavior, LevelTwo storage/views, LevelTwo wage constants, and `graduate()` reinitializer logic are never reached. Users and integrators may believe the system graduated while the proxy still executes `LevelOne` logic.

**Proof of Concept (high level):**
1. Deploy `LevelOne` behind a proxy and initialize it.
2. Deploy a `LevelTwo` implementation.
3. Call `graduateAndUpgrade(levelTwo, data)` as principal.
4. The function calls `_authorizeUpgrade(levelTwo)`, pays wages, and exits.
5. The proxy implementation remains unchanged because no `upgradeToAndCall(levelTwo, data)` or equivalent upgrade execution is called.

**Recommendation:**
Call the proper UUPS upgrade function, such as `upgradeToAndCall(_levelTwo, data)`, after all required graduation checks are satisfied. Ensure `data` encodes a call to `LevelTwo.graduate()` if reinitialization is required. Also add tests that assert the proxy implementation address changes and LevelTwo functions execute after graduation.

**Related Functions:** `graduateAndUpgrade()`, `_authorizeUpgrade()`, `LevelTwo.graduate()`

---

### [H-03] Teacher wage calculation pays 35% of bursary to each teacher instead of splitting 35% among teachers

**Location:** `LevelOne.sol:300-311`

**Severity:** High

**Invariant Violated:** INV-1

**Description:**  
The intended wage model is that teachers collectively receive 35% of the bursary and the principal receives 5%. However, `graduateAndUpgrade()` calculates `payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION` and then transfers that amount to every teacher in `listOfTeachers`. `totalTeachers` is read but is not used to divide the teacher wage pool.

**Impact:**
With one teacher, the result is accidentally correct. With two teachers, the contract pays 70% of the bursary to teachers plus 5% to the principal, leaving only 25% instead of the expected 60%. With three teachers, teacher payments alone require 105% of the bursary before principal pay, causing the function to revert due to insufficient token balance. This can drain excess funds to teachers or make graduation/wage payout impossible depending on teacher count.

**Proof of Concept (high level):**
1. Enroll students so the contract has a nonzero `bursary`.
2. Add two teachers.
3. Call `graduateAndUpgrade()`.
4. Each teacher receives 35% of the bursary, so total teacher payout is 70% instead of 35%.
5. Repeat with three teachers and observe that required payouts exceed the contract's bursary balance.

**Recommendation:**
Calculate a shared teacher wage pool and divide it by the number of teachers:
`teacherPool = (bursary * TEACHER_WAGE) / PRECISION; payPerTeacher = teacherPool / totalTeachers;`. Also handle `totalTeachers == 0` explicitly and account for rounding dust.

**Related Functions:** `graduateAndUpgrade()`

---

### [M-01] `graduateAndUpgrade()` can be called before the session ends

**Location:** `LevelOne.sol:295-312`, `LevelOne.sol:269-274`

**Severity:** Medium

**Invariant Violated:** INV-3

**Description:**
`startSession()` sets `sessionEnd = block.timestamp + 4 weeks`, but `graduateAndUpgrade()` does not check that the current timestamp is greater than or equal to `sessionEnd`. The only access restriction is `onlyPrincipal`. Therefore, the principal can trigger the graduation/wage flow immediately after starting the session or at any other time before the intended four-week period ends.

**Impact:**
Students can be graduated or the graduation flow can be attempted before the full session period completes. This bypasses the intended time-based review window and can trigger wage payments before teachers and students complete the expected process.

**Proof of Concept (high level):**
1. Principal starts a session with `startSession(cutOffScore)`.
2. Without waiting four weeks, principal calls `graduateAndUpgrade(levelTwo, data)`.
3. The function does not revert for early execution because there is no `block.timestamp >= sessionEnd` check.

**Recommendation:**
Add a check in `graduateAndUpgrade()` requiring `block.timestamp >= sessionEnd`. Consider also requiring `inSession == true` and marking the session complete after graduation to prevent repeated/incorrect flows.

**Related Functions:** `startSession()`, `graduateAndUpgrade()`

---

### [M-02] `graduateAndUpgrade()` does not require students to complete the required number of reviews

**Location:** `LevelOne.sol:277-292`, `LevelOne.sol:295-312`

**Severity:** Medium

**Invariant Violated:** INV-4

**Description:**
The protocol invariant requires students to receive the required number of reviews before graduation. `graduateAndUpgrade()` does not iterate over `listOfStudents` or check `reviewCount[student]` for any student. Additionally, `giveReview()` never increments `reviewCount`, so even if a graduation check were added using the current state, the counter would not reflect actual reviews.

**Impact:**
Students can be included in the graduation/upgrade flow without receiving the required reviews. This bypasses the intended academic/review process and makes the graduation decision unreliable.

**Proof of Concept (high level):**
1. Enroll a student and start a session.
2. Give the student zero reviews.
3. Principal calls `graduateAndUpgrade(levelTwo, data)`.
4. The function does not check the student's review count and continues execution.

**Recommendation:**
Increment `reviewCount[_student]` inside `giveReview()`. In `graduateAndUpgrade()`, iterate through active students and require each student to have the required number of reviews before graduation. Consider exposing review count via a getter for testing/transparency.

**Related Functions:** `giveReview()`, `graduateAndUpgrade()`

---

### [M-03] `graduateAndUpgrade()` does not filter out students below `cutOffScore`

**Location:** `LevelOne.sol:269-274`, `LevelOne.sol:295-312`, `LevelTwo.sol:19`

**Severity:** Medium

**Invariant Violated:** INV-5

**Description:**
`startSession()` stores a `cutOffScore`, and student scores can decrease through bad reviews. However, `graduateAndUpgrade()` does not compare each student's `studentScore` against `cutOffScore` before graduation. It also does not remove failing students from `listOfStudents` or migrate only passing students to `LevelTwo`.

**Impact:**
Students below the cutoff can remain in the student list used after graduation. This breaks the expected graduation semantics and can make LevelTwo report non-qualified students as graduated/active students.

**Proof of Concept (high level):**
1. Enroll a student with starting score `100`.
2. Start a session with cutoff `70`.
3. Give the student four bad reviews to reduce score to `60`.
4. Call `graduateAndUpgrade()`.
5. The function does not check `studentScore[student] < cutOffScore` and does not remove the failing student.

**Recommendation:**
During graduation, evaluate each active student against `cutOffScore`. Migrate only passing students, remove or mark failing students separately, and emit events documenting graduation/failure results.

**Related Functions:** `startSession()`, `giveReview()`, `graduateAndUpgrade()`, `LevelTwo.graduate()`

---

### [M-04] `reviewCount` is never incremented and the review cap is unenforced

**Location:** `LevelOne.sol:277-292`

**Severity:** Medium

**Invariant Violated:** INV-4 / INV-6

**Description:**
`giveReview()` checks `require(reviewCount[_student] < 5, ...)`, but the function never increments `reviewCount[_student]`. Because the mapping defaults to zero and remains zero forever, the review-count cap never activates. The only active rate limit is `lastReviewTime[_student] + reviewTime`.

**Impact:**
A teacher can continue reviewing the same student over time as long as the weekly delay has passed. Repeated bad reviews can continue reducing student scores beyond the intended review limit. The system also cannot prove that a student received the required number of reviews before graduation.

**Proof of Concept (high level):**
1. Enroll a student and add a teacher.
2. Teacher calls `giveReview(student, false)` after each weekly interval.
3. Since `reviewCount[student]` is never incremented, the `< 5` check continues to pass.
4. Student score continues decreasing beyond the intended review limit.

**Recommendation:**
Increment `reviewCount[_student]` after a successful review. If the intended maximum is four reviews, use a boundary that enforces four total reviews, such as `reviewCount[_student] < 4` before incrementing.

**Related Functions:** `giveReview()`, `graduateAndUpgrade()`

---

### [M-05] Off-by-one review limit allows five reviews if the counter is fixed

**Location:** `LevelOne.sol:281`

**Severity:** Medium / Low

**Invariant Violated:** INV-6

**Description:**
The review cap uses `require(reviewCount[_student] < 5, ...)`. If `reviewCount` were incremented correctly, this condition would allow counts `0, 1, 2, 3, 4` to pass, meaning five total reviews. The expected maximum from the invariant is four reviews.

**Impact:**
Even after fixing the missing increment, the current boundary would still permit one extra review. If the fifth review is bad, it can reduce a student's score by an additional 10 points beyond the intended limit.

**Proof of Concept (high level):**
1. Fix or assume `reviewCount` increments after reviews.
2. Submit reviews while `reviewCount` is 0, 1, 2, 3, and 4.
3. All five reviews pass because the check is `< 5`.
4. A student starting at `100` can be reduced to `50` after five bad reviews instead of `60` after four.

**Recommendation:**
Use a boundary that matches the intended maximum. For a maximum of four reviews, require `reviewCount[_student] < 4` before incrementing.

**Related Functions:** `giveReview()`

---

### [M-06] Expelled student fees remain in bursary and can affect later wage calculations

**Location:** `LevelOne.sol:143-156`, `LevelOne.sol:243-266`, `LevelOne.sol:300-311`

**Severity:** Medium

**Invariant Violated:** INV-7

**Description:**
`enroll()` transfers `schoolFees` from the student and increases `bursary` by `schoolFees`. `expel()` removes the student from `listOfStudents` and sets `isStudent[_student] = false`, but it does not refund the expelled student and does not decrease `bursary`. Later, `graduateAndUpgrade()` uses `bursary` to calculate teacher and principal payouts.

**Impact:**
Fees paid by expelled students remain counted as bursary funds even though those students are no longer active participants. These retained funds can increase principal and teacher wage calculations, effectively allowing expelled students' fees to be distributed rather than refunded or removed from accounting.

**Proof of Concept (high level):**
1. A student enrolls and pays `schoolFees`, increasing `bursary`.
2. The principal starts a session and expels the student.
3. `isStudent[student]` becomes false and the student is removed from `listOfStudents`.
4. `bursary` remains unchanged.
5. `graduateAndUpgrade()` later calculates wages using the unchanged bursary.

**Recommendation:**
Define explicit expulsion accounting. Either refund the student's fee and decrement `bursary`, or document that fees are non-refundable and separate active-student accounting from total funds. Emit an event showing the accounting treatment.

**Related Functions:** `enroll()`, `expel()`, `graduateAndUpgrade()`

---

### [L-01] Principal can remove teachers mid-session, affecting wage distribution while past reviews remain

**Location:** `LevelOne.sol:220-240`

**Severity:** Low / Medium

**Invariant Violated:** INV-9

**Description:**
`removeTeacher()` is restricted to the principal but does not use the `notYetInSession` modifier. The principal can remove a teacher during an active session. Any reviews already given by that teacher remain reflected in student scores, but the teacher is removed from `listOfTeachers` and therefore excluded from later wage distribution.

**Impact:**
A teacher can perform review work during a session and then be removed before wages are paid. Their prior reviews still affect student outcomes, but they no longer receive a wage share. This creates a mismatch between review contribution, student scoring impact, and wage distribution.

**Proof of Concept (high level):**
1. Principal adds a teacher before session starts.
2. Session starts and the teacher gives reviews.
3. Principal calls `removeTeacher(teacher)` during the session.
4. Student scores remain changed by the teacher's reviews.
5. The teacher is no longer in `listOfTeachers` and will not be paid in `graduateAndUpgrade()`.

**Recommendation:**
Decide whether teacher removal should be allowed during active sessions. If not, add `notYetInSession` or an equivalent session-state guard. If mid-session removal is intended, separately track earned wages or completed review work so compensation and review integrity remain consistent.

**Related Functions:** `removeTeacher()`, `giveReview()`, `graduateAndUpgrade()`

---

### [L-02] `startSession()` accepts arbitrary cutoff scores

**Location:** `LevelOne.sol:269-274`

**Severity:** Low / Medium

**Invariant Violated:** INV-5 / Input validation

**Description:**
`startSession(uint256 _cutOffScore)` stores `_cutOffScore` without validating a minimum or maximum. Student scores begin at `100`, but the principal can set the cutoff to `0`, greater than `100`, or any arbitrary value.

**Impact:**
A cutoff of `0` can make every student pass regardless of reviews. A cutoff greater than `100` can make graduation impossible for all students. This makes graduation semantics dependent on an unconstrained admin input.

**Proof of Concept (high level):**
1. Principal calls `startSession(0)` and all students satisfy `score >= cutoff`.
2. Alternatively, principal calls `startSession(101)` and no student with starting score `100` can satisfy the cutoff.
3. The contract accepts both values without reverting.

**Recommendation:**
Validate `_cutOffScore` against the intended score range. For example, require `_cutOffScore > 0 && _cutOffScore <= 100`, or define explicit allowed bounds in the protocol specification.

**Related Functions:** `startSession()`, `graduateAndUpgrade()`

---

### [L-03] Reviews are not bounded to the active session window

**Location:** `LevelOne.sol:277-292`, `LevelOne.sol:269-274`

**Severity:** Low / Medium

**Invariant Violated:** INV-2 / INV-3 / INV-6

**Description:**
`giveReview()` does not check `inSession == true` and does not check `block.timestamp <= sessionEnd`. The function only checks that the caller is a teacher, the target is a student, the review count is below the cap, and the weekly delay has passed. Because the review count is never incremented, the practical limiter is only the weekly timestamp check.

**Impact:**
Teachers can submit reviews outside the intended four-week active session window, including after `sessionEnd`. If the contract remains on `LevelOne`, students can continue receiving reviews indefinitely over time, which can keep changing scores after the intended session period.

**Proof of Concept (high level):**
1. Add a teacher and enroll a student.
2. Start a session and allow `sessionEnd` to pass.
3. Teacher calls `giveReview(student, false)` after the weekly delay.
4. The function does not check that the session is active or that `block.timestamp <= sessionEnd`, so the review can proceed.

**Recommendation:**
Add session-window guards to `giveReview()`, such as requiring `inSession == true` and `block.timestamp <= sessionEnd`. Consider marking the session closed after graduation or after session end to prevent post-session score changes.

**Related Functions:** `giveReview()`, `startSession()`, `graduateAndUpgrade()`

---

### [L-04] Graduation event is declared but never emitted

**Location:** `LevelOne.sol:70`, `LevelOne.sol:295-312`

**Severity:** Low / Informational

**Invariant Violated:** Event correctness / Upgrade-flow observability

**Description:**
`LevelOne` declares `event Graduated(address indexed levelTwo)`, but `graduateAndUpgrade()` never emits it. The function also does not actually perform the upgrade, so there is no reliable event signal indicating graduation or implementation transition.

**Impact:**
Off-chain indexers, users, and monitoring systems cannot rely on an emitted event to detect graduation. This is not the root cause of the broken upgrade flow, but it reduces observability and supports the broader issue that the graduation path is incomplete.

**Proof of Concept (high level):**
1. Principal calls `graduateAndUpgrade(levelTwo, data)`.
2. The function completes if transfers succeed.
3. No `Graduated(levelTwo)` event is emitted.

**Recommendation:**
After a successful validated graduation and upgrade execution, emit `Graduated(levelTwo)`. Ensure the event is emitted only after the intended state transition has actually occurred.

**Related Functions:** `graduateAndUpgrade()`


## Additional Low / Info Parking Lot

- `expel()` uses raw `revert()` when `inSession == false`; consider custom error for clearer failure reason.
- `startSession()` does not require at least one teacher or student before starting a session.
- `graduateAndUpgrade()` accepts a `bytes memory` parameter but ignores it, supporting the missing `upgradeToAndCall` issue.
- `graduateAndUpgrade()` checks `_levelTwo != address(0)` but does not verify `_levelTwo` has contract code.