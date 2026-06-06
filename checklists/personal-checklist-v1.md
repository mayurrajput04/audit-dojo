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
