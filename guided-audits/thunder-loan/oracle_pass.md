# Oracle & Pricing Pass — Thunder Loan

## 1. Price Sources
- **Primary Source:** `OracleUpgradeable::getPriceInWeth(address token)`
- **External Dependency:** `ITSwapPool::getPriceOfOnePoolTokenInWeth()`
- **Factory:** `IPoolFactory(s_poolFactory).getPool(token)`

## 2. Price Sinks
- **Sink A: `ThunderLoan::deposit`**
  - **Location:** Line 153-154
  - **Logic:** `uint256 calculatedFee = getCalculatedFee(token, amount);` followed by `assetToken.updateExchangeRate(calculatedFee);`
  - **Impact:** The exchange rate is bumped during a deposit based on the oracle price of the deposited amount.

- **Sink B: `ThunderLoan::flashloan`**
  - **Location:** Line 192-194
  - **Logic:** `uint256 fee = getCalculatedFee(token, amount);` followed by `assetToken.updateExchangeRate(fee);`
  - **Impact:** Determines the fee the borrower must repay. If the price is low, the fee is low.

## 3. Trust Assumptions
- **Pool Existence:** Assumes `IPoolFactory` will always return a valid pool address for any "allowed" token.
- **Price Accuracy:** Assumes the spot price in TSwap is a fair representation of the token's value.
- **No Manipulation:** Assumes users cannot or will not manipulate the TSwap pool balance mid-transaction.

## 4. Manipulation Vectors
- **Flash-Loan-the-Oracle:** Attacker takes a flash loan from *another* protocol, swaps a huge amount in TSwap to tank the price of `Token X`, then takes a flash loan of `Token X` from Thunder Loan at a near-zero fee.
- **Missing Pool Denial of Service:** If a token is "allowed" but the TSwap pool is drained or destroyed, `getPriceInWeth` reverts, bricking all deposits and flash loans for that token.

## 5. Findings / Hypotheses Table
| ID | Severity | Hypothesis | Invariant Broken |
|----|----------|------------|------------------|
| H-03 | High | `deposit()` incorrectly updates exchange rate using a fee that isn't paid, leading to immediate "phantom" profit for the depositor and eventual insolvency of the pool. | INV-3, INV-8 |
| H-04 | High | TSwap Spot Price manipulation allows borrowers to pay near-zero fees by tanking the token price in the same transaction. | INV-3 |
