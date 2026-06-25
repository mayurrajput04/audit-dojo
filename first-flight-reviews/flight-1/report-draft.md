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
