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
- `updateFlashLoanFee` : we trust the owner not to set the fees to 0 (which halts LP profits) or 100 (robbing the borrower) . There is no timeLock , no max cap belwo
- `setAllowedToken` : owner gates which token can be deposited.

## 4. Oracle Assumptions
<!-- next session -->

## 5. Invariants (exactly 8)
<!-- next session -->