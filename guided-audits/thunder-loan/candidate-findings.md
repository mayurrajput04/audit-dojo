# Candidate Findings: Thunder Loan

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

**Status: CONFIRMED** (Validated via Foundry PoC: `audit-dojo/guided-audits/thunder-loan/pocs/H2_deposit_exchange_rate.sol`)


## [H-04] Oracle manipulation via TSwap spot price allows near-zero fee flash loans

**Location:** `src/protocol/OracleUpgradeable.sol#L19-L22`

**Description:**
The protocol uses a spot price oracle from TSwap to determine the WETH value of tokens for fee calculation. Since `getPriceOfOnePoolTokenInWeth()` looks at the current balance of the TSwap pool, an attacker can manipulate this price within a single transaction using a flash loan from another source.

By tanking the price of the borrowed token on TSwap before calling `ThunderLoan::flashloan`, the `valueOfBorrowedToken` (and thus the `fee`) can be reduced to near zero.

**Impact:** High. The protocol loses its primary source of revenue (fees), and LPs earn nothing. In extreme cases, this could be combined with other logic to extract value from the system.

**Recommendation:** Use a Time-Weighted Average Price (TWAP) oracle instead of a spot price, or use a decentralized oracle network like Chainlink for price feeds of allowed tokens.

**Status: CONFIRMED** (Validated via Foundry PoC: `audit-dojo/guided-audits/thunder-loan/pocs/H3_oracle_manipulation.sol`)


## [H-05] Storage layout collision on V1→V2 upgrade: `s_flashLoanFee` reads old `s_feePrecision` slot, causing 100% fee

**Location:** `src/upgradedProtocol/ThunderLoanUpgraded.sol` State variable declarations vs `src/protocol/ThunderLoan.sol`

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

**Status: CONFIRMED** (Validated via Foundry PoC: `audit-dojo/guided-audits/thunder-loan/pocs/H5_storage_collision.sol`)


## [H-06] Storage layout collision on V1→V2 upgrade: `s_currentlyFlashLoaning` mapping shifted, orphaning real state

**Location:** `src/upgradedProtocol/ThunderLoanUpgraded.sol` State variable declarations vs `src/protocol/ThunderLoan.sol`

**Description:**
Due to the same slot shift described in H-05, V2's `s_currentlyFlashLoaning` mapping is at slot N+3, which held V1's `s_flashLoanFee` value of `3e15` — a raw uint256, not a mapping.

V1's actual `s_currentlyFlashLoaning` data lives at slot N+4, which V2 has no variable referencing. This data is permanently orphaned.

**Concrete impacts:**
1. **Mid-loan tokens are bricked:** If a flash loan was in progress during the upgrade (`s_currentlyFlashLoaning[token] = true` at slot N+4), V2 cannot see it. `repay()` checks `s_currentlyFlashLoaning[token]` at the new slot N+3, finds `false`, and reverts with `ThunderLoan__NotCurrentlyFlashLoaning()`. The borrower cannot repay, funds are stuck.
2. **New flash loans corrupt the slot:** When V2 writes `s_currentlyFlashLoaning[token] = true` at slot N+3, it writes to a mapping base slot that initially contained `3e15` (a fee value). This corrupts storage further on every new flash loan.

**Impact:** High. Loss of funds for borrowers mid-loan during upgrade. Storage corruption for all new flash loans after upgrade.

**Recommendation:** Same as H-05. Maintain identical storage layout across upgrades. If state migration is needed, implement a dedicated migration function that reads from old slots and writes to new ones.

**Status: CONFIRMED** (As a direct corollary of the slot shift validated in `audit-dojo/guided-audits/thunder-loan/pocs/H5_storage_collision.sol`)


## [H-07] Reentrancy via `redeem()` during flashloan callback steals other LPs' principal

**Location:**
- `src/protocol/ThunderLoan.sol#L194` (exchange rate bumped before fee is secured)
- `src/protocol/ThunderLoan.sol#L201` (control handed to attacker via `executeOperation`)
- `src/protocol/ThunderLoan.sol#L161-L178` (`redeem` has no flashloaning-guard / reentrancy guard)
- `src/protocol/ThunderLoan.sol#L212-L214` (repayment check reads a stale `startingBalance` snapshot from L182)

**Description:**
Inside `flashloan()`, the exchange rate is increased at L194 (`assetToken.updateExchangeRate(fee)`)
*before* control is handed to the borrower's `executeOperation` callback at L201, and *before* the fee
is actually paid into the vault. The `redeem()` function (L161) has no check on
`s_currentlyFlashLoaning` and no reentrancy guard, so an attacker who is also an LP can re-enter
`redeem()` from inside `executeOperation` and cash out their shares at the **inflated** exchange rate
while the inflation is still unbacked by real assets.

Walkthrough (jar = vault balance, round numbers):
1. Vault holds 1000 underlying. Attacker-LP is owed 100, other LPs owed 900 (balanced).
2. Flashloan begins. L194 bumps the rate up, so the attacker's shares now claim ~105.
3. L199 sends the loan out. Control leaves at L201 into the attacker's `executeOperation`.
4. Inside the callback the attacker repays loan + fee (satisfying the L212 check, which only compares
   against the stale `startingBalance + fee` snapshot from L182), then calls `redeem()` at the inflated
   rate and pulls ~105 instead of 100.
5. Vault now holds ~895; other LPs are still owed 900. They are permanently short ~5, drawn from
   their deposited principal, not from any earned fee.

The L212 repayment check is blind to the redeem because it only verifies the vault reached
`startingBalance + fee`; it does not detect that LP shares were also burned and underlying withdrawn
during the same call.

**Impact:** High → likely Critical. Direct loss of other LPs' deposited principal. Exploitable by any
user (no privileged role), no large capital requirement, single transaction. Violates INV-8 (the
vault balance must back all LP claims).

**Recommendation:**
- Add a `nonReentrant` guard (or a `s_currentlyFlashLoaning`-aware guard) to `redeem()` and `deposit()`
  so they cannot be entered during an active flashloan.
- Better: do not bump the exchange rate (L194) until the fee is actually received. Move the
  `updateExchangeRate` accounting to *after* the repayment check, or account for the fee only once it
  is confirmed in the vault.

**Status:** Hypothesis derived in Day 18 flashloan logic pass. Verify in pass 2 with a Foundry PoC:
deposit as LP -> initiate flashloan -> inside callback repay then redeem at inflated rate -> assert a
second honest LP can no longer redeem their full claim.


## [H-08] No re-entry guard on `flashloan()` — nested loan flips `s_currentlyFlashLoaning` early, bricking the outer repay (state-machine break)

**Location:**
- `src/protocol/ThunderLoan.sol#L180-L186` (`flashloan` top — no `s_currentlyFlashLoaning` check)
- `src/protocol/ThunderLoan.sol#L216` (inner loan sets flag false)
- `src/protocol/ThunderLoan.sol#L219-L222` (`repay` requires the flag to be true)

**Description:**
`flashloan()` sets `s_currentlyFlashLoaning[token] = true` (L198) but never checks it at the top of
the function. Because the callback at L201 hands arbitrary control to the borrower, the borrower can
re-enter `flashloan()` (for the same token) from inside `executeOperation`. The inner loan runs to
completion and at L216 sets `s_currentlyFlashLoaning[token] = false` — while the OUTER loan is still
in progress.

The flag is now false mid-outer-loan. INV-4 (the flag must be true for the entire duration of a single
loan) is violated. Concretely, when the outer borrower then calls `repay()` (L220), the guard
`if (!s_currentlyFlashLoaning[token]) revert ThunderLoan__NotCurrentlyFlashLoaning()` triggers a
revert. The outer loan can no longer be repaid, so the outer `flashloan()` fails its own L212 check
and the whole transaction reverts.

**Impact:** On its own, a self-bricking denial-of-service on nested loans. More importantly, it shows
the `s_currentlyFlashLoaning` state machine is not re-entrancy safe. Combined with H-07 (redeem at
inflated rate during the callback), the lack of any global re-entry lock lets an attacker open loans
across multiple tokens at once and stack the H-07 principal theft across every pool in a single
transaction — raising the combined severity to Critical.

**Recommendation:**
- Add a check at the top of `flashloan()`: `if (s_currentlyFlashLoaning[token]) revert ...;` to forbid
  nesting per token, or
- Add a contract-wide `nonReentrant` guard covering `flashloan`, `deposit`, and `redeem`, so no state-
  mutating entry point can be re-entered while a flashloan is active.

**Status:** Hypothesis derived in Day 18 flashloan logic pass. Verify in pass 2 with a Foundry PoC:
flashloan(tokenA) -> inside callback flashloan(tokenA) again -> outer repay reverts with
`ThunderLoan__NotCurrentlyFlashLoaning()`. Then extend to cross-token to demonstrate stacked H-07 theft.


## [M-01] `updateFlashLoanFee` has no lower bound thus owner can set fee to 0, halting all LP yield

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
- Suggests incomplete refactor , possibly the check was intended at the ThunderLoan
  level (e.g., as a safety net) and never wired up.
- Typo in error name ("Exhange" instead of "Exchange") is propagated across files.

**Recommendation:** Remove the unused error, OR if the intent was to enforce the
invariant at the ThunderLoan layer, add the missing check. Also fix the typo.
