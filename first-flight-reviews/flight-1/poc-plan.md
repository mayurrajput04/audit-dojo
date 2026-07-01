# Hawk High Day 25 H-02 PoC Plan

## Selected Finding

H-02 — `graduateAndUpgrade()` never performs the actual UUPS upgrade.

## Bug Summary

Coach scaffold — you must tighten this in your own words:

- The public graduation flow is supposed to move the ERC1967 proxy from `LevelOne` logic to `LevelTwo` logic.
- Instead, `graduateAndUpgrade()` only calls the UUPS authorization hook and never executes the actual upgrade.
- The proof should show the proxy implementation slot is unchanged after the call.

Your one-sentence version:

> TODO: Write one sentence explaining the bug without saying imaginary things like “marked graduated” or “event emitted.”

## Root Cause (exact lines)

Use these concrete references:

- `LevelOne.sol:295` — `graduateAndUpgrade(address _levelTwo, bytes memory)` receives calldata but does not use the `bytes memory` argument.
- `LevelOne.sol:305` — calls `_authorizeUpgrade(_levelTwo)` directly.
- `LevelOne.sol:314` — `_authorizeUpgrade(address newImplementation)` is an empty authorization hook guarded by `onlyPrincipal`.
- Missing from `LevelOne.sol:295-312` — no `upgradeToAndCall(_levelTwo, data)` or equivalent UUPS upgrade execution.

Your root-cause sentence:

> TODO: Convert the above into one precise root-cause sentence.

## Expected Behavior

- Principal calls `graduateAndUpgrade(levelTwoImplementation, data)`.
- The ERC1967 proxy implementation address changes from the `LevelOne` implementation to the `LevelTwo` implementation.
- If `data` is supplied, the proxy executes the intended reinitializer call, e.g. `LevelTwo.graduate()`.

## Actual Behavior

- `graduateAndUpgrade()` calls `_authorizeUpgrade(_levelTwo)` directly.
- `_authorizeUpgrade()` only checks authorization; it does not write the ERC1967 implementation slot.
- The proxy continues pointing to the original `LevelOne` implementation after the call.

## Test Setup

Minimum state needed:

1. Deploy `LevelOne` implementation behind `ERC1967Proxy` using the existing deploy script/test setup.
2. Record the proxy address.
3. Record the proxy implementation address before graduation.
4. Deploy a `LevelTwo` implementation.
5. Ensure `graduateAndUpgrade()` can complete without reverting:
   - use the existing `schoolInSession` setup, or
   - add enough students/fees and teachers so wage transfers succeed.

Note:

- Existing test helper `_teachersAdded()` adds two teachers.
- Existing helper `_studentsEnrolled()` enrolls six students.
- With two teachers, wage payout should not revert because total payout is 75% of bursary, even though it is economically wrong.

## Action

Call as principal:

```solidity
bytes memory data = abi.encodeCall(LevelTwo.graduate, ());
levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);
```

Do not paste this blindly. Explain why `principal` is needed before writing the test.

## Assertions

Core assertions to prove H-02:

```solidity
// before call
assertEq(implBefore, levelOneImplementationAddress);

// after call
assertEq(implAfter, implBefore);
assertNotEq(implAfter, levelTwoImplementationAddress);
```

Optional secondary assertion:

- A call only available on `LevelOne`, such as `getSchoolFeesCost()`, still succeeds through the proxy after `graduateAndUpgrade()`.

Question you must answer before coding:

> How will you read the ERC1967 implementation slot in Foundry?

## Edge Cases / Notes

- Do not claim a `Graduated` event is emitted. It is declared but not emitted.
- Do not claim a “graduated” state variable is updated. No such state exists.
- This PoC should isolate the no-upgrade bug. Do not mix H-03 wage math or H-01 storage corruption into the core assertion.
- H-01 storage corruption is only reachable if an actual upgrade occurs. H-02 proves the intended public flow never reaches that state.


# Hawk High Day 26 H-03 PoC Plan

## Selected Finding
[H-03] Teacher wage calculation pays 35% of bursary to each teacher instead of splitting 35% among teachers

## Bug Summary 
The intended wage model is that teachers collectively receive 35% of the bursary and the principal receives 5%. However, `graduateAndUpgrade()` calculates `payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION` and then transfers that amount to every teacher in `listOfTeachers`. `totalTeachers` is read but is not used to divide the teacher wage pool. 

With two teachers, the contract pays 70% of the bursary to teachers plus 5% to the principal, leaving only 25% instead of the expected 60%.

## Root Cause (exact lines)
`LevelOne.sol:300-311`

## Expected Behavior
- We have bursary of 10,000e18. 
- Contract calculates `noOfTeachers` (2 teachers for our test case).
- Both teachers get the share of 35%. 
- 35 percent divided into both equally i.e. 3,500e18 (Alice = 3500/2 = 1,750e18, Bob = 3500/2 = 1,750e18).

## Actual Behavior
- We have bursary of 10,000e18. 
- Contract calculates `noOfTeachers` (2 teachers for our test case).
- Both teachers get 35% each, meaning both get 3,500e18 individually i.e. 7,000e18 collectively.

## Test Setup
1. Enroll students so the contract has a nonzero `bursary`.
2. Add 2 Teachers (Alice, Bob).
3. Record balances of Alice and Bob before graduation.

## Action
Call `graduateAndUpgrade()` as the principal.

## Assertions
```solidity
uint256 aliceDelta = usdc.balanceOf(alice) - aliceBalanceBefore;
uint256 bobDelta = usdc.balanceOf(bob) - bobBalanceBefore;

// Prove they got 35% EACH instead of sharing 35%
assertEq(aliceDelta, (bursaryBefore * 35) / 100);
assertEq(bobDelta, (bursaryBefore * 35) / 100);
assertEq(aliceDelta + bobDelta, (bursaryBefore * 70) / 100);
```

## Edge Cases / Notes
- There is no totalTeacher check, so handle `totalTeachers == 0` explicitly in mitigation and account for rounding dust.



# Hawk High Day 27 H-01 PoC Plan

## Selected Finding
[H-01] Storage layout incompatibility corrupts LevelTwo state after upgrade


## Bug Summary
`LevelTwo` does not preserve the storage layout of `LevelOne`. `LevelOne` declares `schoolFees` at slot 1, `reviewCount` at slot 8, and `lastReviewTime` at slot 9, but those variables are absent from `LevelTwo`. Because upgradeable proxy storage is reused across implementations, removing variables shifts the meaning of later slots. For example, `LevelTwo.sessionEnd` at slot 1 reads old `LevelOne.schoolFees`, `LevelTwo.bursary` at slot 2 reads old `LevelOne.sessionEnd`, and `LevelTwo.cutOffScore` at slot 3 reads old `LevelOne.bursary`. Mapping and array seed slots are also shifted, causing `studentScore`, `listOfStudents`, `listOfTeachers`, and `usdc` to read from incorrect storage locations.


## Root Cause (exact lines & slot comparison)

LevelOne.sol declares:
- `schoolFees` at slot 1 (line 40)
- `sessionEnd` at slot 2
- `bursary` at slot 3
- `reviewCount` at slot 8
- `lastReviewTime` at slot 9

LevelTwo.sol declares:
- `sessionEnd` at slot 1
- `bursary` at slot 2
- `cutOffScore` at slot 3
- `studentScore` at slot 6
- `listOfStudents` at slot 7
- `usdc` at slot 9

Because `schoolFees`, `reviewCount`, and `lastReviewTime` are removed, every subsequent variable in LevelTwo reads from the wrong slot.

## Expected Behavior

After an upgrade from `LevelOne` to `LevelTwo`, the proxy must preserve the meaning of all state variables:

- `sessionEnd` must still return the timestamp written during `startSession()`
- `bursary` must still return the accumulated `schoolFees` collected from students
- `cutOffScore` must still return the value passed to `startSession()`
- Mapping and array operations (`isStudent`, `studentScore`, `listOfStudents`, `usdc`) must continue to read/write the correct data.

## Actual Behavior

Because `schoolFees` (slot 1), `reviewCount` (slot 8), and `lastReviewTime` (slot 9) are missing in `LevelTwo`, all subsequent variables are shifted:

- `LevelTwo.sessionEnd()` (slot 1) returns the old `schoolFees` value instead of the session timestamp.
- `LevelTwo.bursary()` (slot 2) returns the old `sessionEnd` timestamp instead of the token balance.
- `LevelTwo.cutOffScore()` (slot 3) returns the old `bursary` amount.
- `studentScore`, `listOfStudents`, `listOfTeachers`, and `usdc` all read from incorrect storage locations due to the shifted mapping seeds and array slots.

## Test Setup

1. Deploy `LevelOne` behind an ERC1967Proxy using the existing deploy script.
2. As principal, add at least two teachers and enroll at least two students so `bursary > 0`.
3. Call `startSession(70)` to set a known `sessionEnd` and `cutOffScore`.
4. Record the current values through `LevelOne` getters:
   - `getSchoolFeesCost()`
   - `getSessionEnd()`
   - `bursary`
   - `cutOffScore`
5. Deploy a `LevelTwo` implementation contract.
6. (Note: We will bypass the broken `graduateAndUpgrade()` for this PoC and simulate the upgrade directly in the test harness.)

## Action

In the test:
1. Deploy `LevelOne` proxy + implementation.
2. Set up state (add teachers, enroll students, start session).
3. Record critical values through `LevelOne`:
   - `uint256 schoolFeesBefore = levelOneProxy.getSchoolFeesCost();`
   - `uint256 sessionEndBefore = levelOneProxy.getSessionEnd();`
   - `uint256 bursaryBefore = levelOneProxy.bursary();`
4. Deploy `LevelTwo` implementation.
5. Simulate the upgrade (using `vm.etch` or direct proxy admin call to change implementation, bypassing the broken `graduateAndUpgrade`).
6. Cast the proxy to `LevelTwo` and read the corrupted values.

## Assertions

After the upgrade to `LevelTwo`:

```solidity
// Core storage collision assertions
assertEq(levelTwoProxy.sessionEnd(), schoolFeesBefore, "sessionEnd should read old schoolFees");
assertEq(levelTwoProxy.bursary(), sessionEndBefore, "bursary should read old sessionEnd timestamp");
assertEq(levelTwoProxy.cutOffScore(), bursaryBefore, "cutOffScore should read old bursary");

// Optional deeper checks
uint256 studentScore = levelTwoProxy.studentScore(studentAddr);
assertTrue(studentScore != 100, "studentScore should be corrupted due to wrong mapping slot");
```
## Edge Cases / Notes

- This PoC must **only** prove storage slot corruption. Do not mix it with the broken `graduateAndUpgrade()` (H-02) or wage math (H-03).
- We will need to simulate the upgrade directly in the test (using `vm.etch` or proxy admin) because `graduateAndUpgrade()` is broken.
- The goal is to show that after the upgrade, `LevelTwo` reads completely wrong values for `bursary`, `sessionEnd`, and `cutOffScore`.
- Mappings (`studentScore`, `isStudent`) and arrays (`listOfStudents`) will also be corrupted due to shifted mapping seeds, this can be shown with at least one optional assertion.
- No need to call any `LevelTwo` functions that require reinitialization for this PoC.



**✅ Choice confirmed: M-01**

**Finding selected:**  
**[M-01] `graduateAndUpgrade()` can be called before the session ends**

**Exact references (verified from source):**
- `LevelOne.sol:269-274` → `startSession(uint256 _cutOffScore)` sets `sessionEnd = block.timestamp + 4 weeks`
- `LevelOne.sol:295-312` → `graduateAndUpgrade(address _levelTwo, bytes memory)` has **no** `block.timestamp >= sessionEnd` check (only `onlyPrincipal`)

---

### Proposed `poc-plan.md` Section (M-01)

I will add this as a new section at the end of the current file (after the H-01 section).

```markdown
# Hawk High Day 28 M-01 PoC Plan

## Selected Finding
[M-01] `graduateAndUpgrade()` can be called before the session ends

## Bug Summary
`startSession()` sets `sessionEnd = block.timestamp + 4 weeks`. However, `graduateAndUpgrade()` has no check that `block.timestamp >= sessionEnd`. The only access control is `onlyPrincipal`. As a result, the principal can trigger graduation and wage payouts immediately after (or even during) the session start.

## Root Cause (exact lines)
- `LevelOne.sol:269-274` — `startSession()` writes `sessionEnd = block.timestamp + 4 weeks`
- `LevelOne.sol:295` — `graduateAndUpgrade(address _levelTwo, bytes memory)` signature
- `LevelOne.sol:300-311` — the function body performs wage transfers and calls `_authorizeUpgrade` with **no** timing guard
- Missing: any `require(block.timestamp >= sessionEnd, ...)` or equivalent check inside `graduateAndUpgrade()`

## Expected Behavior
- Principal must wait until `block.timestamp >= sessionEnd` (4 weeks after `startSession()`) before calling `graduateAndUpgrade()`.
- Calling `graduateAndUpgrade()` before the session ends should revert.

## Actual Behavior
- Principal can call `graduateAndUpgrade()` at any time after `startSession()` (even in the same block or the next block).
- The function executes wage transfers and the broken upgrade path without waiting for the intended review period.

## Test Setup
1. Deploy `LevelOne` behind proxy using `DeployLevelOne`.
2. Add teachers and enroll students.
3. Record `sessionEnd` right after calling `startSession(70)`.
4. Immediately (same block or next block) attempt to call `graduateAndUpgrade()` as principal.
5. The call should succeed (no revert) even though `block.timestamp < sessionEnd`.

## Action
```solidity
vm.prank(principal);
levelOneProxy.startSession(70);

// Immediately call graduation (no time warp)
vm.prank(principal);
levelOneProxy.graduateAndUpgrade(levelTwoImpl, data);
```

## Assertions
```solidity
uint256 sessionEnd = levelOneProxy.getSessionEnd();

// Core assertion: graduation succeeds before sessionEnd
assertTrue(block.timestamp < sessionEnd, "test must run before session ends");
assertGt(usdc.balanceOf(alice), 0, "wages were paid even though session had not ended");
```

## Edge Cases / Notes
- This finding isolates the missing timing check. Do not mix it with H-02 (no actual upgrade) or H-03 (wage math).
- The PoC should demonstrate that `graduateAndUpgrade()` can be called successfully with `block.timestamp < sessionEnd`.
- Consider adding a secondary assertion that shows wages are paid early.
