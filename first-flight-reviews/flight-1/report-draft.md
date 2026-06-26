# Hawk High Report Draft

## [H-02] `graduateAndUpgrade()` never performs the actual UUPS upgrade

### Summary

`LevelOne.graduateAndUpgrade()` is intended to transition the ERC1967 proxy from `LevelOne` to `LevelTwo`. However, it directly calls `_authorizeUpgrade(_levelTwo)` instead of executing `upgradeToAndCall(_levelTwo, data)` or another UUPS upgrade function, so the proxy's ERC1967 implementation slot remains unchanged and the proxy continues executing `LevelOne` logic.

### Vulnerability Details

`LevelOne.sol:295` defines `graduateAndUpgrade(address _levelTwo, bytes memory)`, indicating that the function is expected to receive a new implementation address and optional calldata for an upgrade/reinitializer call. However, the `bytes memory` parameter is unnamed and unused.

Instead of executing the UUPS upgrade path, `graduateAndUpgrade()` directly calls `_authorizeUpgrade(_levelTwo)` at `LevelOne.sol:305`. The `_authorizeUpgrade()` function is defined at `LevelOne.sol:314` as an empty internal authorization hook guarded by `onlyPrincipal`:

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyPrincipal {}
```

This hook only controls whether a caller is allowed to upgrade when the actual UUPS upgrade function is executed. Calling `_authorizeUpgrade()` directly does not write to the ERC1967 implementation slot and does not delegatecall into the new implementation. Because `graduateAndUpgrade()` contains no call to `upgradeToAndCall(_levelTwo, data)`, `upgradeTo(_levelTwo)`, or an equivalent upgrade function, the proxy implementation is never changed.

### Impact

The intended graduation flow cannot move the proxy from `LevelOne` to `LevelTwo`. A call to `graduateAndUpgrade()` can complete successfully, including wage transfers, while the proxy still points to and executes the original `LevelOne` implementation.

As a result, `LevelTwo.graduate()` is never executed through the proxy, and all intended `LevelTwo` behavior, constants, views, and post-graduation state semantics remain unreachable through the protocol's graduation path. Users or integrations may treat the graduation transaction as successful even though no implementation upgrade occurred.

### Proof of Concept

The PoC reads the ERC1967 implementation slot before and after calling `graduateAndUpgrade()`. Before the call, the proxy points to the original `LevelOne` implementation. After calling `graduateAndUpgrade(levelTwoImplementation, abi.encodeCall(LevelTwo.graduate, ()))` as the principal, the implementation slot is unchanged and still points to `LevelOne`. The slot also does not equal the supplied `LevelTwo` implementation address.

Core assertions:

```solidity
assertEq(implBefore, levelOneImplementationAddress);
assertEq(implAfter, implBefore);
assertNotEq(implAfter, levelTwoImplementationAddress);
```

Test result:

```text
Ran 1 test for test/poc/H02_NoActualUpgrade.t.sol:H02_NoActualUpgradePoC
[PASS] test_graduateAndUpgrade_doesNotChangeProxyImplementation() (gas: 1080643)

Suite result: ok. 1 passed; 0 failed; 0 skipped
```

### Recommended Mitigation

Do not call `_authorizeUpgrade(_levelTwo)` directly from `graduateAndUpgrade()`. Replace it with the actual UUPS upgrade execution path, such as `upgradeToAndCall(_levelTwo, data)`, after all graduation preconditions and accounting requirements have been satisfied.

The `bytes memory` parameter should be named and used if the upgrade is expected to call `LevelTwo.graduate()` or another reinitializer. Add a regression test that reads the ERC1967 implementation slot before and after graduation and asserts that it changes from the `LevelOne` implementation address to the `LevelTwo` implementation address.

Before enabling the real upgrade path, the storage layout incompatibility between `LevelOne` and `LevelTwo` should also be fixed; otherwise, correcting this issue may expose the separate storage-corruption issue described in H-01.


## [H-03] Teacher wage calculation pays 35% of bursary to each teacher instead of splitting 35% among teachers

### Summary

The intended wage model is that teachers collectively receive 35% of the bursary and the principal receives 5%. However, `graduateAndUpgrade()` calculates `payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION` and then transfers that amount to every teacher in `listOfTeachers`. `totalTeachers` is read but is not used to divide the teacher wage pool.

With two teachers, the contract pays 70% of the bursary to teachers plus 5% to the principal, leaving only 25% instead of the expected 60%.

### Vulnerability Details

Principal calls `graduateAndUpgrade()` at `LevelOne.sol:295`. The teacher count is stored in `totalTeachers` at `LevelOne.sol:300`, and we also calculate `payPerTeacher` and `principalPay` at `LevelOne.sol:302-303`. 

```solidity
uint256 payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION;
```

At `LevelOne.sol:307-309`, `LevelOne.sol::graduateAndUpgrade()` calculates 35% of bursary to each teacher instead of a shared 35% of bursary between all teachers.

```solidity
for (uint256 n = 0; n < totalTeachers; n++) {
   usdc.safeTransfer(listOfTeachers[n], payPerTeacher);
}
```

Due to poor math calculation at `LevelOne.sol:302`, `payPerTeacher` allows the payment to be done as 35% of the bursary per teacher instead of calculating a total teacher pool and sharing the 35% amount among them. This directly breaks protocol invariant INV-1.

### Impact

With one teacher, the result is accidentally correct. With two teachers, the contract pays 70% of the bursary to teachers plus 5% to the principal, leaving only 25% instead of the expected 60%. 

This can drain excess funds to teachers or make graduation/wage payout impossible depending on teacher count (with 3 teachers, the required payout is 105% + 5% = 110%, causing `graduateAndUpgrade()` to revert due to insufficient balance).

### Proof of Concept

1. Enroll students so the contract has a nonzero `bursary`.
2. Add 2 teachers (Alice, Bob).
3. Record balances of Alice and Bob before graduation.
4. Call `graduateAndUpgrade()`.
5. Verify each teacher receives 35% of the bursary, proving total teacher payout is 70% instead of 35%.

```solidity
uint256 aliceDelta = usdc.balanceOf(alice) - aliceBalanceBefore;
uint256 bobDelta = usdc.balanceOf(bob) - bobBalanceBefore;

assertEq(aliceDelta, (bursaryBefore * 35) / 100);
assertEq(bobDelta, (bursaryBefore * 35) / 100);
assertEq(aliceDelta + bobDelta, (bursaryBefore * 70) / 100);
```

### Recommended Mitigation

Calculate a shared teacher wage pool and divide it by the number of teachers:

```solidity
uint256 teacherPool = (bursary * TEACHER_WAGE) / PRECISION; 
uint256 payPerTeacher = totalTeachers > 0 ? teacherPool / totalTeachers : 0;
```
Also handle `totalTeachers == 0` explicitly and account for rounding dust.

