# Thunder Loan — Security Audit & Vulnerability Report

## 1. Executive Summary

Thunder Loan is a decentralized lending protocol designed to offer efficient flash loans backed by liquidity provider (LP) deposits. During our deep-dive security assessment of the Thunder Loan protocol, multiple high-severity vulnerabilities were identified, including flash loan logic flaws, spot-price oracle manipulation, and critical storage collisions during implementation upgrades. Left unresolved, these vulnerabilities would result in immediate and complete pool insolvency, loss of protocol revenue, and absolute lockup of the upgradeability path.

## 2. Approach

Our security assessment was conducted using a multi-pass structured review methodology targeting distinct protocol layers:
1. **Mental Model Mapping & Invariant Definition:** Built a complete state-machine mapping and defined core protocol invariants (INV-1 through INV-10).
2. **Oracle & Pricing Pass:** Reviewed the spot-price integration with TSwap, verifying against manipulation vectors and external dependency failures.
3. **Admin & Upgrade Pass:** Examined all owner-restricted functions and validated the storage layout mapping of V1 and V2 implementations to identify upgrade hazards.
4. **Flash Loan Logic & Reentrancy Pass:** Analyzed `flashloan()`, `repay()`, and external call execution orders (`executeOperation`) to test control-flow hijacking and reentrancy vectors.
5. **Foundry Proof-of-Concept Validation:** Developed minimal, concrete executable PoCs to prove the exploitability of the top findings.

---

## 3. Findings

### [H-01] `deposit()` Incorrectly Updates Exchange Rate, Leading to Immediate Insolvency (H-2)

**Severity:** High
**Location:** `src/protocol/ThunderLoan.sol#L153-L154`

**Description:**
In the V1 `deposit` function, the protocol calculates a "phantom fee" using `getCalculatedFee` on the deposited amount and calls `assetToken.updateExchangeRate(calculatedFee)`. This immediately increases the exchange rate of the `AssetToken` contract, acting as if a flash loan fee had already been paid into the system. However, the depositor only transfers the principal `amount` to the contract.

Because of this, any depositor can:
1. Deposit `X` tokens.
2. Receive `AssetToken` shares.
3. Observe the exchange rate immediately inflate.
4. Immediately call `redeem()` to withdraw `X + profit` tokens, extracting value from other LPs' deposits.

**Impact:**
Any user can instantly drain all deposited assets from the pool in a single transaction, resulting in complete insolvency of the vault and total loss of LP capital.

**Recommendation:**
Remove lines 153-154 from `ThunderLoan.sol`. The exchange rate should only be updated when actual flash loan fees are paid into the `AssetToken` vault during a successful `flashloan()` settlement.

---

### [H-02] Oracle Manipulation via TSwap Spot Price Allows Near-Zero Fee Flash Loans (H-3)

**Severity:** High
**Location:** `src/protocol/OracleUpgradeable.sol#L19-L22`

**Description:**
Thunder Loan relies on a spot price oracle from TSwap to calculate the WETH value of the borrowed token to determine the flash loan fee. Because `getPriceOfOnePoolTokenInWeth()` retrieves the current instantaneous reserves of the TSwap pool, an attacker can manipulate this price within a single transaction by performing a large swap in the TSwap pool (using a flash loan or private capital) before requesting a flash loan from Thunder Loan.

**Impact:**
An attacker can temporarily crash the price of the borrowed asset on TSwap to near-zero. This forces Thunder Loan to calculate a fee of zero (or near-zero), depriving LPs of their yield and denying the protocol its core source of revenue.

**Recommendation:**
Do not use an instantaneous spot-price oracle. Instead, implement a Time-Weighted Average Price (TWAP) oracle (like Uniswap V3's Oracle) or integrate a decentralized oracle network like Chainlink to query robust, tamper-resistant price feeds.

---

### [H-03] Storage Layout Collision on V1→V2 Upgrade Bricks the Protocol with 100% Fees (H-5)

**Severity:** High
**Location:** `src/upgradedProtocol/ThunderLoanUpgraded.sol` State Variable Declarations

**Description:**
In the original implementation (`ThunderLoan.sol`), the state variables are declared in the following order:
1. `mapping(IERC20 => AssetToken) public s_tokenToAssetToken;`
2. `uint256 private s_feePrecision;` (initialized to `1e18`)
3. `uint256 private s_flashLoanFee;` (initialized to `3e15` or 0.3%)
4. `mapping(IERC20 => bool) private s_currentlyFlashLoaning;`

In the upgraded contract (`ThunderLoanUpgraded.sol`), `s_feePrecision` is replaced with a constant: `uint256 public constant FEE_PRECISION = 1e18;`. Constants do not occupy storage slots in Solidity. As a result, the storage layout of the upgraded contract collapses:
* `s_flashLoanFee` shifts from Slot N+3 to Slot N+2, which contains V1's old value for `s_feePrecision` (`1e18`).
* `s_currentlyFlashLoaning` shifts from Slot N+4 to Slot N+3, pointing to V1's old value of `s_flashLoanFee` (`3e15`).

When `getCalculatedFee` is called post-upgrade, it reads `s_flashLoanFee` as `1e18`.
$$\text{fee} = \frac{\text{valueOfBorrowedToken} \times 1\text{e}18}{1\text{e}18} = \text{valueOfBorrowedToken}$$

**Impact:**
Post-upgrade, every flash loan will charge a **100% fee**, forcing borrowers to repay double their borrowed amount. This completely bricks the utility of the protocol. Additionally, the flash loan state machine is corrupted since the boolean mapping reads Slot N+3 containing the raw uint256 `3e15`.

**Recommendation:**
Ensure identical storage layout in upgradeable implementations. Never remove or change a state variable to a constant in upgradeable contracts. If a state variable is no longer needed, preserve its storage slot (e.g., rename it to `uint256 private __gap_feePrecision`) or use structured storage layouts.

---

## 4. Appendix: PoC Code

The compilable and runnable Proof of Concepts are located in the following repository paths:

* **H-2 Deposit Exchange Rate Exploit PoC:**
  `audit-dojo/guided-audits/thunder-loan/pocs/H2_deposit_exchange_rate.sol`
* **H-3 TSwap Oracle Price Manipulation PoC:**
  `audit-dojo/guided-audits/thunder-loan/pocs/H3_oracle_manipulation.sol`
* **H-5 Storage Layout Collision PoC:**
  `audit-dojo/guided-audits/thunder-loan/pocs/H5_storage_collision.sol`
