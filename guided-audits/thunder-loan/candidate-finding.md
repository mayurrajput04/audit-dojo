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

