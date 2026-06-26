# Hawk High Day 25 PoC Plan

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


