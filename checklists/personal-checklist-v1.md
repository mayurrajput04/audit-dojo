# Personal Smart Contract Audit Checklist (v1)

## 1. State Accounting
- If an array's length is used to calculate payouts or fees, is it possible for elements to be "deleted" or "refunded" without the array length decreasing? (e.g., `array[i] = address(0)` vs `pop()`)
- Are variables pulling double-duty? (e.g., an array tracking both "who is playing" and "how much ETH we hold"). If yes, can a state change break the link between the two?
- Does the contract rely on strict equality (`==`) against `address(this).balance`? (If yes, it can likely be bricked or manipulated by selfdestruct/accounting drift).
- Are wider integer types (like `uint256` from `msg.value`) ever cast down to narrower types (like `uint64`) when saving to state? Does this risk silent truncation/overflow?

## 2. Duplicate Action Prevention
- If a function issues a payout, refund, or reward, can the same user call it twice and succeed? (Look for missing state updates *before* the transfer, or failure to clear the user's eligibility).
- How does the contract track "already processed" users? (e.g., mapping vs array search). If it uses an array search, does it risk a Denial of Service (DoS) as the array grows?
- If the system requires unique participants, is there a strict mechanism preventing the same address from entering multiple times?


## 3. External Calls
- Does the function make an external call (e.g., sending ETH or calling another contract) *before* fully updating the state? (Violation of Checks-Effects-Interactions pattern = Reentrancy risk).
- What happens if an external call fails, reverts, or consumes all available gas? Does it cause a Denial of Service (DoS) for the entire function or brick the contract?
- When sending ETH via low-level `.call`, is the return value (`bool success`) explicitly checked and handled?


## 4. Access Control
- Does the function perform privileged actions (e.g., withdrawing funds, changing configurations)? If so, is there a robust access control mechanism (like `onlyOwner` or strict `msg.sender` checks) validating the caller?

## 5. Input Validation
- Does the function blindly trust user-supplied parameters? Are arrays checked for length/emptiness? Are addresses checked against `address(0)`? Are numerical inputs checked for zero or maximum bounds?

## 6. Event Correctness
- Are state-changing actions (especially those involving value transfers or critical state updates) reliably emitting events? Are those events logging the correct, fully-updated data rather than stale variables?

## 7. Upgradeable Storage Layout
- Compare V1 and V2 variable declarations side-by-side. Do the storage slots line up exactly?
- Is any `private` state variable in V1 replaced with a `constant` in V2? (Constants do not occupy storage slots, this shifts all subsequent variables by 1 slot).
- Is there a `__gap` array at the end of each upgradeable contract to absorb future variable additions?
- If an upgrade changes storage layout, is there a dedicated one-time migration function that reads old slots and writes to new ones?
- Are storage variables using namespaced storage (ERC-7201) to decouple layout from inheritance/declaration order?

## 8. Oracle & Pricing
- Is the oracle source a **spot price** (instantaneous pool reserves)? If yes, it can be manipulated in one transaction.
- Is there a Time-Weighted Average Price (TWAP) with a meaningful window (≥ 30 minutes)?
- Is there a fallback oracle (e.g., Chainlink) with deviation/staleness checks?
- Does the fee calculation have a **minimum fee floor** regardless of oracle price?

## 9. Flash Loan Safety
- Does `flashloan()` check `s_currentlyFlashLoaning[token]` at the **top** of the function to prevent nesting?
- Is the exchange rate updated **before** or **after** the repayment is confirmed? (Must be after — the fee must be physically in the vault before inflating the rate).
- Are `deposit()`, `redeem()`, and `flashloan()` guarded by a reentrancy lock (`nonReentrant`)?
- Can `redeem()` or `deposit()` be called during an active flashloan callback? (If yes, the exchange rate window is exploitable for principal theft).
- Does `repay()` check `s_currentlyFlashLoaning[token]` before accepting repayment? (If the flag is false, the borrower can't repay ,state-machine break).

## 10. Timelocks & Centralization
- Do admin functions (fee updates, token allow-listing, upgrades) execute **instantly** or through a timelock?
- Is there a minimum fee threshold to prevent owner from setting fee to 0%?
- Can the owner disallow a token and **orphan** LP funds? (Check if the AssetToken mapping is deleted vs. just marked inactive).
