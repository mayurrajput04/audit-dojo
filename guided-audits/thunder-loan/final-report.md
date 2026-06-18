# Thunder Loan — Security Audit Final Report

| Field | Value |
|---|---|
| **Protocol** | Thunder Loan |
| **Auditor** | Gintoki Sakata |
| **Review Period** | 7 Jun 2026 – 19 Jun 2026 |
| **Repository** | [Cyfrin/2023-11-Thunder-Loan](https://github.com/Cyfrin/2023-11-Thunder-Loan) |
| **Commit (V1)** | `src/protocol/ThunderLoan.sol`, `AssetToken.sol`, `OracleUpgradeable.sol` |
| **Commit (V2)** | `src/upgradedProtocol/ThunderLoanUpgraded.sol` |
| **Type** | UUPS Upgradeable Flash Loan Protocol with TSwap Oracle Integration |
| **Methods** | Mental Model → Multi-pass manual review → Foundry PoC validation |

---

## Disclaimer

This audit reflects a best-effort security review conducted within the scope of a guided practice engagement. It does **not** guarantee the absence of vulnerabilities. The protocol team is responsible for additional testing, formal verification, and third-party audits before mainnet deployment. No bug bounty or financial liability is assumed.

---

## Severity Classification

| Severity | Definition |
|---|---|
| **Critical** | Funds directly at risk; exploit requires no unusual conditions. |
| **High** | Funds can be stolen or permanently locked; protocol can be rendered insolvent or unusable. |
| **Medium** | Functionality impaired, centralization risk exposed, or user funds placed at indirect risk. |
| **Low / Informational** | Code quality deviations, best-practice violations, no direct fund risk. |

---

## Executive Summary

r Loan is a decentralized flash loan protocol backed by LP deposits. It uses a UUPS upgradeable architecture with a spot-price oracle sourced from TSwap for fee calculation. Our review identified **6 High-severity findings**, **2 Medium-severity findings**, and **1 Informational finding** across the protocol.


| Severity | Count | Affected Areas |
|---|---|---|
| **Critical** | 0 | — |
| **High** | 6 | Deposit insolvency, oracle manipulation, storage collisions, LP fund orphaning, reentrancy theft, state-machine bricking |
| **Medium** | 2 | Missing fee floor, no admin timelock |
| **Low / Info** | 1 | Dead code / unused error |
| **Total** | **9** | Documented below |
---

## Methodology

Our assessment followed a structured multi-pass approach:

1. **Mental Model & Invariant Definition** : Mapped protocol state machine, defined 10 core invariants (INV-1 through INV-10).
2. **Oracle & Pricing Pass** : Reviewed spot-price integration with TSwap, assessed manipulation resistance.
3. **Admin & Upgrade Pass** : Examined owner-restricted functions, validated V1→V2 storage layout correspondence.
4. **Flash Loan Logic & Reentrancy Pass** : Analyzed control flow in `flashloan()`, `repay()`, and callback execution.
5. **Foundry PoC Validation** : Developed executable Proof of Concepts for confirmed findings.

---

## Detailed Findings

---

### [H-1] `setAllowedToken(token, false)` Orphans LP Funds

| Field | Value |
|---|---|
| **Severity** | High |
| **Location** | `src/protocol/ThunderLoan.sol` lines 237–243 |

#### Description

When the owner disallows a previously-allowed token, `setAllowedToken` calls `delete s_tokenToAssetToken[token]`, which sets the mapping entry to `address(0)`. The AssetToken contract itself is **not destroyed** and continues holding all LP-deposited underlying tokens. However, every redemption path in `ThunderLoan` looks up the AssetToken via `s_tokenToAssetToken[token]`, which now returns `address(0)`. All LP redemptions are permanently bricked.

Furthermore, recovery via re-allowing the same token is blocked: the `allowed = true` path checks `if (address(s_tokenToAssetToken[token]) != address(0)) revert ThunderLoan__AlreadyAllowed()`. Since the mapping entry is `address(0)`, this check passes but it deploys a **new** AssetToken contract with zero LPs, leaving the old one still carrying the funds.

#### Impact

- All LP funds in that token's pool become inaccessible through normal protocol interface.
- No recovery path exists in the contract.
- High severity (not Critical) because it requires owner action to trigger.

#### Recommended Mitigation

Separate the concerns of "is this token allowed for deposits" from "where is the AssetToken contract." Add a dedicated allow-list mapping:

```diff
+    mapping(IERC20 token => bool) private s_allowedTokens;

     function setAllowedToken(IERC20 token, bool allowed) external onlyOwner returns (AssetToken) {
         if (allowed) {
             if (address(s_tokenToAssetToken[token]) != address(0)) {
                 revert ThunderLoan__AlreadyAllowed();
             }
             string memory name = string.concat("ThunderLoan ", IERC20Metadata(address(token)).name());
             string memory symbol = string.concat("tl", IERC20Metadata(address(token)).symbol());
             AssetToken assetToken = new AssetToken(address(this), token, name, symbol);
             s_tokenToAssetToken[token] = assetToken;
+            s_allowedTokens[token] = true;
             emit AllowedTokenSet(token, assetToken, allowed);
             return assetToken;
         } else {
-            AssetToken assetToken = s_tokenToAssetToken[token];
-            delete s_tokenToAssetToken[token];
+            s_allowedTokens[token] = false;
-            emit AllowedTokenSet(token, assetToken, allowed);
+            emit AllowedTokenSet(token, s_tokenToAssetToken[token], allowed);
-            return assetToken;
+            return s_tokenToAssetToken[token];
         }
     }

+    function isAllowedToken(IERC20 token) public view returns (bool) {
+        return s_allowedTokens[token];
+    }
```

The `s_tokenToAssetToken` mapping is never deleted it always points to the existing AssetToken contract, allowing redemptions even when the token is disallowed for new deposits.


---
### [H-2] `deposit()` Incorrectly Updates Exchange Rate, Leading to Immediate Insolvency

| Field | Value |
|---|---|
| **Severity** | High |
| **Location** | `src/protocol/ThunderLoan.sol` lines 148–155 |

#### Description

In the `deposit()` function, the protocol calculates a **phantom fee** by calling `getCalculatedFee(token, amount)` on the depositor's principal, then immediately inflates the exchange rate via `assetToken.updateExchangeRate(calculatedFee)` on line 154. However, the depositor only transfers the principal `amount` & no fee is actually paid.

The exchange rate is a ratio that determines how many underlying tokens each AssetToken share can redeem. Inflating it without a corresponding inflow of underlying tokens creates an **unbacked liability**:

```
Before deposit:  1 AssetToken = 1.0 underlying (vault: 1000, supply: 1000)
Depositor adds 1000 tokens → phantom fee inflates rate by 0.3%
After deposit:   1 AssetToken = 1.003 underlying (vault: 2000, supply: 1994)
Depositor redeems → receives 1003 tokens → profit of 3 tokens from thin air
```

#### Exploit Walkthrough

1. LP deposits 1000 tokens to seed liquidity.
2. Attacker deposits 1000 tokens , so the exchange rate is immediately bumped by a phantom 0.3% fee.
3. Attacker calls `redeem(type(uint256).max)` receives ~1003 tokens.
4. Attacker profits 3 tokens drawn from the LP's principal.
5. Protocol is now insolvent: vault holds less than the sum of all LP claims.

#### Impact

- **Any user** can drain the protocol in a single transaction.
- No privileged role required, no capital requirement beyond the deposit itself.
- Immediate and total loss of LP funds.

#### Proof of Concept

```solidity
contract H2DepositExchangeRatePoC is BaseTest {

    uint256 public constant DEPOSIT_AMOUNT = 1000e18;
    address public attacker = address(0xdead);
    address public liquidityProvider = address(123);

    function test_POC_H2_deposit_exchange_rate() public {
        // 1. Setup state: owner allows tokenA
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        // 2. Setup state: LP deposits 1000e18 tokenA
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        // 3. Setup state: attacker gets 1000e18 tokenA and approves ThunderLoan
        vm.startPrank(attacker);
        tokenA.mint(attacker, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        // 4. Record attacker's starting balance
        uint256 attackerStartingBalance = tokenA.balanceOf(attacker);
        // 5. Attack step 1: attacker deposits 1000e18 tokenA
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        // 6. Attack step 2: attacker redeems all their AssetToken shares
        thunderLoan.redeem(tokenA, type(uint256).max);
        // 7. Record attacker's final balance
        uint256 attackerEndingBalance = tokenA.balanceOf(attacker);
        // 8. Assert: attacker redeemed more than they deposited
        vm.stopPrank();
        assertGt(attackerEndingBalance, attackerStartingBalance, "H-2: attacker should profit from phantom fee");
    }
}  
```

#### Downstream Impacts (H-5, H-6 merged under H-2)

The same root cause (exchange rate inflated before repayment is confirmed, plus missing reentrancy protection) enables two additional exploit paths. Both are **fully remediated** by the mitigations below and are documented here for completeness.

#### **[H-5] : Reentrancy via `redeem()` During Flashloan Callback:**
Because the exchange rate is bumped at line 194 **before** the borrower's `executeOperation` callback, an attacker who is also an LP can re-enter `redeem()` from inside the callback and cash out at the inflated rate. The repayment check on line 212 only verifies the vault reached `startingBalance + fee`, it does not detect the simultaneous withdrawal. Other LPs' principal is stolen.

#### **[H-6] : Nested Flashloan Flips `s_currentlyFlashLoaning` Early:**
`flashloan()` never checks `s_currentlyFlashLoaning[token]` at function entry. An attacker can re-enter `flashloan()` for the same token from inside `executeOperation`. The inner loan completes and sets the flag to `false` while the outer loan is still in flight. The outer `repay()` call reverts because the flag reads `false` , the loan is bricked.

#### Recommended Mitigation

Three changes, applied together:

**1. `deposit()` : Remove phantom fee logic, fix event ordering**

```diff
 function deposit(IERC20 token, uint256 amount) ... {
     AssetToken assetToken = s_tokenToAssetToken[token];
     uint256 exchangeRate = assetToken.getExchangeRate();
     uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
-    emit Deposit(msg.sender, token, amount);
     assetToken.mint(msg.sender, mintAmount);
-    uint256 calculatedFee = getCalculatedFee(token, amount);
-    assetToken.updateExchangeRate(calculatedFee);
     token.safeTransferFrom(msg.sender, address(assetToken), amount);
+    emit Deposit(msg.sender, token, amount);
 }
```

- **Removed:** `getCalculatedFee` and `updateExchangeRate` no phantom fee in deposit.
- **Moved:** `emit Deposit` fires **after** `safeTransferFrom` succeeds. If the transfer reverts, no inaccurate event is emitted.

**2. `flashloan()` : Move exchange rate update to after repayment is confirmed**

```diff
 function flashloan(...) ... {
     ...
-    assetToken.updateExchangeRate(fee);   // REMOVED from line 194
     ...
     // Repayment check
     uint256 endingBalance = token.balanceOf(address(assetToken));
     if (endingBalance < startingBalance + fee) {
         revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
     }
+    // Fee is confirmed in the vault — now safely update the exchange rate
+    assetToken.updateExchangeRate(fee);
     s_currentlyFlashLoaning[token] = false;
 }
```

- The exchange rate is only inflated **after** the fee lands in the vault.
- No inflated rate exists during the callback window → H-7 (reentrancy redeem) is killed.
- No window for nested loan flag manipulation → H-8 (nested bricking) is killed.

**3. Add `ReentrancyGuardUpgradeable` to all external state-mutating functions**

```diff
+import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

-contract ThunderLoan is Initializable, OwnableUpgradeable, UUPSUpgradeable, OracleUpgradeable {
+contract ThunderLoan is Initializable, OwnableUpgradeable, UUPSUpgradeable, OracleUpgradeable, ReentrancyGuardUpgradeable {
```

Add initialization:

```diff
 function initialize(address tswapAddress) external initializer {
     __Ownable_init();
     __UUPSUpgradeable_init();
+    __ReentrancyGuard_init();
     __Oracle_init(tswapAddress);
     ...
 }
```

Apply the `nonReentrant` modifier to all three external entry points:

```diff
-    function deposit(IERC20 token, uint256 amount) external ... {
+    function deposit(IERC20 token, uint256 amount) external nonReentrant ... {
```

```diff
-    function redeem(IERC20 token, uint256 amountOfAssetToken) external ... {
+    function redeem(IERC20 token, uint256 amountOfAssetToken) external nonReentrant ... {
```

```diff
-    function flashloan(address receiverAddress, IERC20 token, uint256 amount, bytes calldata params) external {
+    function flashloan(address receiverAddress, IERC20 token, uint256 amount, bytes calldata params) external nonReentrant {
```

---

### [H-3] Oracle Manipulation via TSwap Spot Price Enables Near-Zero Fee Flash Loans

| Field | Value |
|---|---|
| **Severity** | High |
| **Location** | `src/protocol/OracleUpgradeable.sol` lines 19–22 |

#### Description

Thunder Loan calculates flash loan fees using the WETH value of the borrowed token. The price is obtained at `OracleUpgradeable.sol#L21`:

```solidity
function getPriceInWeth(address token) public view returns (uint256) {
    address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
    return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
}
```

`getPriceOfOnePoolTokenInWeth()` returns the **instantaneous spot price** of the TSwap pool i.e., the ratio of the pool's current token reserves. Because TSwap pool reserves can be shifted within a single transaction via a large swap (funded by a flash loan from another source), the spot price can be manipulated to near-zero before the Thunder Loan fee is calculated.

The fee calculation at `ThunderLoan.sol#L247-L250`:

```solidity
uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;
```

If `getPriceInWeth` returns a manipulated price of `1e6` instead of the honest `1e18`, the fee drops by a factor of **1,000,000x**.

#### Exploit Walkthrough

1. Identify a token with a TSwap pool and a Thunder Loan market.
2. Take a flash loan of the token from another protocol.
3. Swap it on the TSwap pool, crashing the spot price of the token.
4. Call `ThunderLoan::flashloan()`, the fee is calculated against the manipulated price.
5. Repay the original flash loan.
6. Net cost of the Thunder Loan flash loan: near zero.

The Foundry PoC demonstrates a fee of `0.3 ETH` at honest price falling to `~3e-13 ETH` at the manipulated price with **1,000,000x reduction**.

#### Impact

- The protocol loses its primary revenue source (flash loan fees).
- LPs earn zero yield → rational LPs withdraw all capital.
- In extreme cases, could be combined with other protocol logic to extract net value.

#### Proof of Concept

```solidity
 function test_POC_H3_oracle_manipulation() public {
        // 1. Setup our manipulable infrastructure
        manipulableFactory = new MockPoolFactoryManipulable();
        
        // Deploy fresh ThunderLoan implementation and proxy
        ThunderLoan impl = new ThunderLoan();
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(impl), "");
        newThunderLoan = ThunderLoan(address(freshProxy));
        newThunderLoan.initialize(address(manipulableFactory));

        // Create pool for tokenA in our manipulable factory
        address poolAddress = manipulableFactory.createPool(address(tokenA));
        MockTSwapPoolManipulable pool = MockTSwapPoolManipulable(poolAddress);

        // Allow tokenA
        vm.prank(newThunderLoan.owner());
        newThunderLoan.setAllowedToken(tokenA, true);

        // LP deposits 1000e18 tokens to provide liquidity
        uint256 depositAmt = 1000e18;
        tokenA.mint(address(this), depositAmt);
        tokenA.approve(address(newThunderLoan), depositAmt);
        newThunderLoan.deposit(tokenA, depositAmt);

        // Deploy attack receiver
        attackReceiver = new OracleReceiver(address(newThunderLoan));

        // 2. Normal State: Get fee at 1:1 price
        pool.setPrice(1e18); // 1:1 price
        uint256 borrowAmt = 100e18;
        uint256 normalFee = newThunderLoan.getCalculatedFee(tokenA, borrowAmt);

        // 3. Attack State: Manipulate price down to near-zero
        pool.setPrice(1e12); // price slashed by 1,000,000x
        uint256 manipulatedFee = newThunderLoan.getCalculatedFee(tokenA, borrowAmt);

        // Execute flash loan under manipulated price
        tokenA.mint(address(attackReceiver), manipulatedFee); // fund the receiver with the tiny fee
        newThunderLoan.flashloan(address(attackReceiver), tokenA, borrowAmt, "");

        // 4. Assertions
        assertGt(normalFee, manipulatedFee, "Normal fee should be greater than manipulated fee");
        assertEq(manipulatedFee, normalFee / 1e6, "Fee should be exactly 1,000,000x cheaper due to manipulation");
    }
```

#### Recommended Mitigation

Two layers of defense - one structural, one belt-and-suspenders:

**1. Replace spot price oracle with TWAP (Time-Weighted Average Price)**

Switch from `ITSwapPool.getPriceOfOnePoolTokenInWeth()` (instantaneous reserves) to a TWAP oracle that averages the price over a meaningful window (e.g., 30 minutes ≈ 180 blocks on Ethereum).

```diff
 function getPriceInWeth(address token) public view returns (uint256) {
-    address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
-    return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
+    // Use TWAP with a 30-minute window
+    address pool = IPoolFactory(s_poolFactory).getPool(token);
+    (int24 arithmeticMeanTick, ) = OracleLibrary.consult(
+        address(pool),
+        1800  // 30 minutes in seconds
+    );
+    return OracleLibrary.getQuoteAtTick(
+        arithmeticMeanTick,
+        uint128(1e18),       // 1 token worth
+        address(token),
+        address(WETH)
+    );
 }
```

**2. Add a minimum fee floor (defense-in-depth)**

Even with TWAP, edge conditions (e.g., a newly listed token with thin liquidity) could produce unexpectedly low fees. Add a proportional floor:

```solidity
uint256 public constant MIN_FEE_BASIS_POINTS = 1; // 0.01%

function getCalculatedFee(IERC20 token, uint256 amount) public view returns (uint256 fee) {
    uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
    fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;

    // Enforce minimum fee: at least MIN_FEE_BASIS_POINTS of the borrowed value
    uint256 minFee = (amount * MIN_FEE_BASIS_POINTS * s_flashLoanFee) / (s_feePrecision * 10000);
    if (fee < minFee) {
        fee = minFee;
    }
}
```

This ensures that even if the oracle price is manipulated or returns an unexpectedly low value, the protocol always collects a baseline fee.

**3. If neither TWAP nor Chainlink is available for a token**

Some niche tokens may only be traded on TSwap with no secondary oracle. In that case:

- **Document the risk explicitly** in the token's allow-list entry.
- **Require a higher minimum fee floor** for such tokens (e.g., 0.5% instead of 0.01%).
- **Consider a circuit breaker:** if the spot price deviates more than X% from a trailing TWAP, pause flash loans for that token.

---


### [H-4] Storage Layout Collision on V1→V2 Upgrade (Merged)

| Field | Value |
|---|---|
| **Severity** | High |
| **Location** | `src/upgradedProtocol/ThunderLoanUpgraded.sol` state variable declarations vs `src/protocol/ThunderLoan.sol` |

#### Root Cause

Replacing `s_feePrecision` (a `uint256 private` state variable) with `uint256 public constant FEE_PRECISION` removes a storage slot. Constants do not occupy storage slots in Solidity, shifting every subsequent variable declaration by one slot.

**V1 layout:**

| Slot | Variable | Value |
|---|---|---|
| N | `s_tokenToAssetToken` (mapping) | — |
| N+1 | *(implicit ERC1967 / Ownable gap)* | — |
| N+2 | `uint256 private s_feePrecision` | `1e18` |
| N+3 | `uint256 private s_flashLoanFee` | `3e15` |
| N+4 | `mapping s_currentlyFlashLoaning` | — |

**V2 layout (broken):**

| Slot | Variable | Reads From V1 |
|---|---|---|
| N | `s_tokenToAssetToken` (mapping) | ✅ Correct |
| N+1 | *(implicit gap)* | ✅ Correct |
| N+2 | `uint256 private s_flashLoanFee` | ❌ Reads V1's `s_feePrecision` = `1e18` |
| N+3 | `mapping s_currentlyFlashLoaning` | ❌ Reads V1's `s_flashLoanFee` = `3e15` |
| N+4 | *(no variable)* | V1's real flash-loan state orphaned |

#### Downstream Impacts

**(a) 100% flash loan fee (H-4):**
`getCalculatedFee` reads `s_flashLoanFee` as `1e18` (V1's `s_feePrecision`). The calculation becomes:

```
fee = (valueOfBorrowedToken * 1e18) / 1e18 = valueOfBorrowedToken
```

Every flash loan charges 100% , borrower must repay double the loan amount. Protocol is functionally bricked.

**(b) Flash loan state corruption (H-5):**
V2's `s_currentlyFlashLoaning` mapping at slot N+3 reads V1's `s_flashLoanFee` value of `3e15` which is a raw `uint256`, not a valid mapping. V1's actual flash-loan state lives at slot N+4, which V2 has no variable referencing.

Consequences:
- **Mid-loan bricking:** If a flash loan was in progress during upgrade, `repay()` checks the wrong slot, finds `false`, and reverts. Borrower cannot repay , thus funds are stuck forever.
- **Storage corruption:** Every new flash loan after upgrade writes to slot N+3, which initially contained `3e15`. This corrupts the mapping state on every write.

#### Impact

- Protocol is unusable after upgrade (100% fees).
- Active flash loan borrowers lose their funds during upgrade.
- Permanent storage corruption affects all post-upgrade flash loans.

#### Proof of Concept

```solidity
contract H5StorageCollisionPoC is BaseTest {
    ThunderLoanUpgraded public upgradedThunderLoan;

    function test_POC_H5_storage_collision() public {
        // 1. Setup V1
        vm.startPrank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        vm.stopPrank();

        // 2. Record V1 fee (should be 0.3%)
        uint256 borrowAmt = 100e18;
        uint256 feeV1 = thunderLoan.getCalculatedFee(tokenA, borrowAmt);
        assertEq(feeV1, 3e17, "V1 fee should be exactly 0.3%");

        // 3. Upgrade to V2
        ThunderLoanUpgraded upgradedImpl = new ThunderLoanUpgraded();
        vm.startPrank(thunderLoan.owner());
        thunderLoan.upgradeTo(address(upgradedImpl));
        vm.stopPrank();

        upgradedThunderLoan = ThunderLoanUpgraded(address(thunderLoan));

        // 4. Record V2 fee (now 100% due to storage collision)
        uint256 feeV2 = upgradedThunderLoan.getCalculatedFee(tokenA, borrowAmt);
        assertEq(feeV2, borrowAmt, "V2 fee should be 100% of loan amount due to storage collision");
    }
}
```

#### Recommended Mitigation

**Never change a `private` state variable to a `constant` in an upgradeable contract.** Preserve the storage slot even if the variable becomes unused:

```diff
 // ThunderLoanUpgraded.sol
-uint256 public constant FEE_PRECISION = 1e18;
+/// @dev PRESERVED for storage layout compatibility with V1. Unused in V2.
+uint256 private __reserved_feePrecision_slot;
```

**Alternative: Namespaced storage (ERC-7201)**
Use `keccak256(abi.encode(uint256(keccak256("thunderloan.storage")) - 1)) & ~bytes32(uint256(0xff))` as the storage base. This decouples storage layout from contract inheritance and variable declaration order.

**If migration is required:**
Implement a one-time migration function that reads old slots and writes to new ones:

```solidity
function migrateStorage() external onlyOwner {
    // Read old s_currentlyFlashLoaning from V1 slot N+4
    // Write to new slot if needed
    // Must be called before any flash loan operations post-upgrade
}
```

---


### [M-1] `updateFlashLoanFee` Has No Lower Bound, Owner Can Set Fee to 0

| Field | Value |
|---|---|
| **Severity** | Medium |
| **Location** | `src/protocol/ThunderLoan.sol` lines 252–256 |

#### Description

`updateFlashLoanFee` only checks `newFee > s_feePrecision` (upper bound). There is no check for `newFee == 0` or any minimum threshold. The owner can set the fee to 0 instantly with no timelock.

#### Impact

- Centralization risk: owner can unilaterally destroy LP yield.
- No rational LP would deposit if fees can be zeroed at any moment.

#### Recommended Mitigation

```diff
+uint256 public constant MINIMUM_FEE = 1e15; // 0.1%

 function updateFlashLoanFee(uint256 newFee) external onlyOwner {
+    if (newFee < MINIMUM_FEE) {
+        revert ThunderLoan__FeeBelowMinimum();
+    }
     if (newFee > s_feePrecision) {
         revert ThunderLoan__BadNewFee();
     }
     s_flashLoanFee = newFee;
 }
```


---


### [M-2] All Admin Functions Have No Timelock

| Field | Value |
|---|---|
| **Severity** | Medium |
| **Location** | `ThunderLoan.sol::setAllowedToken`, `updateFlashLoanFee`, `_authorizeUpgrade` |

#### Description

All three owner-restricted functions execute immediately with no delay. No timelock, no multi-sig, no governance vote.

#### Impact

The owner can unilaterally at any moment:
- Upgrade to a malicious implementation → drain all funds.
- Disallow all tokens → brick all LP redemptions.
- Set fee to 100% or 0%.

#### Recommended Mitigation

```diff
+uint256 public constant ADMIN_TIMELOCK = 2 days;
+uint256 public s_feeUpdateScheduledAt;
+uint256 public s_pendingFee;
+
+function scheduleFeeUpdate(uint256 newFee) external onlyOwner {
+    s_feeUpdateScheduledAt = block.timestamp + ADMIN_TIMELOCK;
+    s_pendingFee = newFee;
+}
+
+function executeFeeUpdate() external onlyOwner {
+    if (block.timestamp < s_feeUpdateScheduledAt) revert TimelockNotElapsed();
+    s_flashLoanFee = s_pendingFee;
+}
```

Apply the same schedule/execute pattern to `setAllowedToken` and `_authorizeUpgrade`. Consider multi-sig for the upgrade path.

---


### [INFO-01] Unused Custom Error `ThunderLoan__ExhangeRateCanOnlyIncrease`

| Field | Value |
|---|---|
| **Severity** | Informational |
| **Location** | `ThunderLoan.sol#L83`, `ThunderLoanUpgraded.sol#L83` |

#### Description

The error `ThunderLoan__ExhangeRateCanOnlyIncrease()` is declared in both contracts but **never reverted** anywhere. The actual exchange-rate-monotonicity check lives in `AssetToken.sol#L91` using a different error: `AssetToken__ExhangeRateCanOnlyIncrease`.

#### Impact

- Dead code ,no security impact.
- Suggests incomplete refactor; the check may have been intended at the ThunderLoan layer and never wired up.
- Typo ("Exhange" instead of "Exchange") is propagated across files.

#### Recommended Mitigation

```diff
- error ThunderLoan__ExhangeRateCanOnlyIncrease();
+ // Removed. The actual check lives in AssetToken.sol.
```

Or if the invariant should be enforced at the ThunderLoan layer, add the check. And fix the typo.

---

## Appendix A: Systemic Recommendations

### 1. Upgradeable Contract Storage Layout

- Always maintain identical `private` variable declarations across upgrades.
- Use `__gap` arrays (50 slots) at the end of each upgradeable contract.
- Consider ERC-7201 namespaced storage for future contracts.
- Never replace a `private` state variable with a `constant`.

### 2. Reentrancy Guards

All state-mutating external functions should carry `nonReentrant`:
- `flashloan()`, `deposit()`, `redeem()`, `repay()` (if made external)
- Consider `nonReentrant` on `setAllowedToken` and `updateFlashLoanFee`

### 3. Oracle Design

- Never use spot prices for financial calculations.
- Minimum requirements: TWAP (≥ 30 min), fallback oracle, deviation checks.
- Add a minimum fee floor regardless of oracle price.

### 4. Timelocks

- All owner-only state changes should have a minimum 48-hour timelock.
- Upgrades should require multi-sig or governance.

---

*Report generated: 19 Jun 2026.