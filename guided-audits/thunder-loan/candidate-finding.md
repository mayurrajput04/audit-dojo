# Candidate Findings — Thunder Loan

## [H-1] `setAllowedToken(token, false)` orphans LP funds

**Location:** `src/protocol/ThunderLoan.sol#L237-L243`

**Description:**
When the owner disallows a previously-allowed token, `setAllowedToken` calls
`delete s_tokenToAssetToken[token]`, which sets the mapping entry to `address(0)`.
The AssetToken contract itself is NOT destroyed and still holds the LP's
underlying tokens. However, all redemption paths in `ThunderLoan` look up the
AssetToken via `s_tokenToAssetToken[token]`, which now returns `address(0)`,
bricking redemption.

**Impact:** LP funds become inaccessible through normal protocol entry points
after a token is disallowed. Requires owner re-allow (which `revert`s with
`ThunderLoan__AlreadyAllowed` if mapping logic isn't carefully reset).

**Severity (tentative):** High — direct loss of access to user funds via single
admin call. Centralization risk borderline → could be Medium depending on
trust model.

**Status:** Hypothesis from mental-model phase. Verify in pass 2 with PoC
attempting redeem after disallow.


## [H-03] `deposit()` incorrectly updates exchange rate, leading to immediate insolvency

**Location:** `src/protocol/ThunderLoan.sol#L153-L154`

**Description:**
In the `deposit` function, the protocol calls `getCalculatedFee` on the deposited amount and then calls `assetToken.updateExchangeRate(calculatedFee)`. This increases the exchange rate of the `AssetToken` as if a flash loan fee had been paid into the protocol. However, the depositor only transfers the principal `amount` (line 155), not the fee.

This allows a depositor to:
1. Deposit `X` tokens.
2. Receive shares based on current exchange rate.
3. Observe the exchange rate immediately increase due to the "phantom fee."
4. Immediately redeem shares for `X + profit` tokens.

**Impact:** High. Any depositor can immediately drain funds from the protocol. This leads to insolvency as the `AssetToken`'s exchange rate claims more underlying tokens than the contract actually holds.

**Recommendation:** Remove lines 153-154 from `ThunderLoan.sol`. The exchange rate should only increase when an actual flash loan fee is paid into the `AssetToken` contract.

## [H-04] Oracle manipulation via TSwap spot price allows near-zero fee flash loans

**Location:** `src/protocol/OracleUpgradeable.sol#L19-L22`

**Description:**
The protocol uses a spot price oracle from TSwap to determine the WETH value of tokens for fee calculation. Since `getPriceOfOnePoolTokenInWeth()` looks at the current balance of the TSwap pool, an attacker can manipulate this price within a single transaction using a flash loan from another source.

By tanking the price of the borrowed token on TSwap before calling `ThunderLoan::flashloan`, the `valueOfBorrowedToken` (and thus the `fee`) can be reduced to near zero.

**Impact:** High. The protocol loses its primary source of revenue (fees), and LPs earn nothing. In extreme cases, this could be combined with other logic to extract value from the system.

**Recommendation:** Use a Time-Weighted Average Price (TWAP) oracle instead of a spot price, or use a decentralized oracle network like Chainlink for price feeds of allowed tokens.

## [H-05] Storage layout collision on V1→V2 upgrade: `s_flashLoanFee` reads old `s_feePrecision` slot, causing 100% fee

**Location:** `src/upgradedProtocol/ThunderLoanUpgraded.sol` — State variable declarations vs `src/protocol/ThunderLoan.sol`

**Description:**
In V1 (`ThunderLoan.sol`), the state variables after the mapping are declared in this order:
1. `uint256 private s_feePrecision` (slot N+2, value 1e18)
2. `uint256 private s_flashLoanFee` (slot N+3, value 3e15)
3. `mapping s_currentlyFlashLoaning` (slot N+4)

In V2 (`ThunderLoanUpgraded.sol`), `s_feePrecision` is replaced with `uint256 public constant FEE_PRECISION = 1e18`. Constants do NOT occupy storage slots. So V2's layout becomes:
1. `uint256 private s_flashLoanFee` (slot N+2 , **now pointing at V1's old `s_feePrecision` value of 1e18**)
2. `mapping s_currentlyFlashLoaning` (slot N+3 , **now pointing at V1's old `s_flashLoanFee` value of 3e15**)

After upgrade, when V2 reads `s_flashLoanFee`, it gets `1e18` instead of `3e15`. In `getCalculatedFee`:
```
fee = (valueOfBorrowedToken * 1e18) / 1e18 = valueOfBorrowedToken
```
This means every flash loan charges a **100% fee** , the borrower must repay double the loan amount. The protocol is functionally bricked for all rational users.

**Impact:** High. Protocol is unusable after upgrade. All LP yield ceases because no borrower will take a 100% fee loan.

**Recommendation:** Never change a `private` state variable to a `constant` in an upgradeable contract. If a value is truly constant, it should have been `constant` from the start. If it must be migrated, use a new variable name and storage slot, and handle the old slot in a migration function.


## [H-06] Storage layout collision on V1→V2 upgrade: `s_currentlyFlashLoaning` mapping shifted, orphaning real state

**Location:** `src/upgradedProtocol/ThunderLoanUpgraded.sol` — State variable declarations vs `src/protocol/ThunderLoan.sol`

**Description:**
Due to the same slot shift described in H-05, V2's `s_currentlyFlashLoaning` mapping is at slot N+3, which held V1's `s_flashLoanFee` value of `3e15` — a raw uint256, not a mapping.

V1's actual `s_currentlyFlashLoaning` data lives at slot N+4, which V2 has no variable referencing. This data is permanently orphaned.

**Concrete impacts:**
1. **Mid-loan tokens are bricked:** If a flash loan was in progress during the upgrade (`s_currentlyFlashLoaning[token] = true` at slot N+4), V2 cannot see it. `repay()` checks `s_currentlyFlashLoaning[token]` at the new slot N+3, finds `false`, and reverts with `ThunderLoan__NotCurrentlyFlashLoaning()`. The borrower cannot repay, funds are stuck.
2. **New flash loans corrupt the slot:** When V2 writes `s_currentlyFlashLoaning[token] = true` at slot N+3, it writes to a mapping base slot that initially contained `3e15` (a fee value). This corrupts storage further on every new flash loan.

**Impact:** High. Loss of funds for borrowers mid-loan during upgrade. Storage corruption for all new flash loans after upgrade.

**Recommendation:** Same as H-05. Maintain identical storage layout across upgrades. If state migration is needed, implement a dedicated migration function that reads from old slots and writes to new ones.


## [M-01] `updateFlashLoanFee` has no lower bound — owner can set fee to 0, halting all LP yield

**Location:** `src/protocol/ThunderLoan.sol#L252-L256`

**Description:**
`updateFlashLoanFee` only checks `newFee > s_feePrecision` (upper bound). There is no check for `newFee == 0` or any minimum threshold. The owner can set the fee to 0 instantly, with no timelock.

**Impact:** Medium. Centralization risk, owner can unilaterally zero out LP yield. No rational LP would deposit if they know the fee can be set to 0 at any moment.

**Recommendation:** Add a minimum fee threshold and/or a timelock on fee changes.


## [M-02] All admin functions have no timelock, instant unilateral action

**Location:** `ThunderLoan.sol` : `setAllowedToken`, `updateFlashLoanFee`, `_authorizeUpgrade`

**Description:**
All three owner-restricted functions execute immediately with no delay. There is no timelock, no multi-sig, no governance vote.

**Impact:** Medium. Centralization risk. The owner can:
- Upgrade to a malicious implementation and drain all funds
- Disallow all tokens, bricking all LP redemptions
- Set fee to 100% or 0%

**Recommendation:** Implement a timelock (e.g., 48-hour delay) on all admin actions. Consider multi-sig or governance for upgrades.



## [INFO-01] Unused custom error `ThunderLoan__ExhangeRateCanOnlyIncrease`

**Location:**
- `src/protocol/ThunderLoan.sol#L83`
- `src/upgradedProtocol/ThunderLoanUpgraded.sol#L83`

**Description:**
The error `ThunderLoan__ExhangeRateCanOnlyIncrease()` is declared in both
`ThunderLoan.sol` and `ThunderLoanUpgraded.sol`, but is never reverted anywhere
in scope. The actual exchange-rate-monotonicity check is enforced in
`AssetToken.sol#L91` via a *different* error: `AssetToken__ExhangeRateCanOnlyIncrease`.

**Impact:** Informational. Dead code. No security impact directly, but:
- Suggests incomplete refactor — possibly the check was intended at the ThunderLoan
  level (e.g., as a safety net) and never wired up.
- Typo in error name ("Exhange" instead of "Exchange") is propagated across files.

**Recommendation:** Remove the unused error, OR if the intent was to enforce the
invariant at the ThunderLoan layer, add the missing check. Also fix the typo.

**Status:** Hypothesis — verify in pass 2 whether removal vs. wiring-up is correct.

