# Mental Model — Thunder Loan

## 1. System Overview

**One-line goal:**
"A flash loan protocol where Liquidity Provider (LP) deposit underlying assets to earn yield from user (borrower) who borrow loan for collateral swaps within a single transaction."

**Actors & motives:**
- **Liquidity Provider:** LP deposits ERC20 X → receives AssetToken (a share/receipt). Earns yield because 'user' (flash loan borrower ) pays a fee on every flash loan, which accrues to the AssetToken's exchange rate.
- **Borrower (Flash Loan User):** Borrower takes out the loan for collateral swaps . They repay principle + fee in same tx. If user don't pay back , whole transaction reverts , meaning loan gets canceled/ fails.
- **Owner:** owner has following powers - authorizeUpgrade , updateFlashLoanFee, setAllowedToken.

**Core flow (one paragraph):**
LP deposits underlying → AssetToken minted → borrower takes flashloan → repays principal + fee in same tx → fee lands in AssetToken balance → s_exchangeRate increases → LP redeems more underlying than they deposited. If repayment fails, whole tx reverts.

---

## 2. Key Assets

- **Underlying ERC20 (the deposited token):**
  - Lives in: AssetToken contract balance
  - Claimed by: LP via burning AssetToken receipt; borrower temporarily during flashloan

- **AssetToken (share / receipt):**
  - Lives in: LP's wallet
  - Mint/burn: minted on deposit, burned on redeem
  - Represents: pro-rata claim on the underlying pool; claim size grows as s_exchangeRate increases

- **Fee (yield source):**
  - Paid in: the underlying token
  - Calculated using: WETH price of underlying (oracle), NOT paid in WETH
  - Accounting: lands in AssetToken balance + bumps s_exchangeRate upward (two-step, must stay consistent)
  - Accrues to: LPs only (no protocol treasury)

- **Price (oracle data, not a token but a key asset):**
  - Source: external TSwap pool, fetched via OracleUpgradeable.getPriceInWeth()
  - Why it's a "key asset": determines fee amount → determines LP yield. Lying oracle = silent theft.

---

## 3. Upgrade / Admin Assumptions
- `_authorizeUpgrade` : owner controls the entire implementation, if storage layout breaks the protocol dies. "Storage layout breaks → all LP funds become inaccessible or misallocated to attacker."
- `updateFlashLoanFee` : we trust the owner not to set the fees to 0 (which halts LP profits) or 100 (robbing the borrower) . There is no timeLock , no max cap below 100%, no LP vote ; instant unilateral economic change.
- `setAllowedToken` : We trust owner not to disallow a token while LPs still hold AssetTokens for it.

## 4. Oracle Assumptions

- **Source:** OracleUpgradeable wraps an external TSwap DEX (via IPoolFactory → ITSwapPool).
  Thunder Loan does NOT control TSwap.

- **Price type:** Spot price (`getPriceOfOnePoolTokenInWeth`). No TWAP, no time-weighted smoothing.
  → Manipulation-resistance assumption is BROKEN by design.

- **Trust trio:**
  - Authenticity → trusting IPoolFactory to return the *real* pool for the token.
  - Manipulation-resistance → violated (spot, no TWAP). // TODO pass-2: find concrete exploit
  - Availability → if no TSwap pool exists for an allowed token, oracle reverts → flashloan bricked.

- **Key insight to remember during pass 1:**
  A flash loan protocol that prices its own fees with a spot DEX oracle is the textbook setup
  for flash-loan-based oracle manipulation INSIDE the same transaction. Hunt for this.

## 5. Invariants (exactly 8)
- INV-1: For every `AssetToken`, `s_exchangeRate` MUST be monotonically non-decreasing across all calls to `updateExchangeRate()`
- INV-2: `token.balanceOf(address(assetToken)) >= startingBalance + fee` MUST hold at the end of every `flashloan()` call, else revert with `ThunderLoan__NotPaidBack`
- INV-3: For every successful `flashloan(token, amount)`, the fee charged MUST equal `getCalculatedFee(token, amount)` = `(amount * priceInWeth * s_flashLoanFee) / s_feePrecision`. The borrower cannot underpay
- INV-4: `s_currentlyFlashLoaning[token]` MUST be False outside of any active flashloan() call, and MUST be True only between the lines `s_currentlyFlashLoaning[token] = true;` and `s_currentlyFlashLoaning[token] = false;`. Equivalently: no two flashloans for the same token may overlap.
- INV-5: Functions `updateExchangeRate`, `transferUnderlyingTo`, `mint`, `burn` on AssetToken MUST only be callable by ThunderLoan address. Any other `msg.sender` MUST revert.
- INV-6: `s_tokenToAssetToken[token] != address(0)` ⇔ `isAllowedToken(token) == true`. AND: if `setAllowedToken(token, false)` is ever called while `assetToken.totalSupply() > 0`, LP redemption invariant (INV-8) is silently violated. This is a protocol-level invariant the owner MUST not violate.
- INV-7: `s_flashLoanFee` MUST always satisfy `s_flashLoanFee <= s_feePrecision` (≤ 100%). Enforced by `ThunderLoan__BadNewFee` in `updateFlashLoanFee`.
- INV-8: For every allowed token, the underlying balance held by its AssetToken contract MUST be sufficient that all LPs can redeem their full claim:
`IERC20(token).balanceOf(address(assetToken)) >= (assetToken.totalSupply() * s_exchangeRate) / STARTING_EXCHANGE_RATE`
at all times outside an active flashloan. meaning if everyone redeemed at once, the math has to work.
