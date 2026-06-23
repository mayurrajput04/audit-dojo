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
