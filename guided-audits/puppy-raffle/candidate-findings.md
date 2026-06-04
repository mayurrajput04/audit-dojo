### [H-1] Unchanged array length on refund leads to incorrect prize calculation, failed winner selection, or stolen fees

**Severity:** High

**Summary:**
When a player refunds, their index in the `players` array is set to `address(0)`, but the array length is not reduced. As a result, the contract's actual ETH balance becomes lower than the expected balance calculated by `players.length * entranceFee`. This desynchronization either causes `selectWinner` to revert (trapping funds) or distributes more than 80% of actual funds to the winner, leaving 0 ETH for fees and bricking fee withdrawals.

**Root Cause:**
In `refund()`, when a player gets a refund, their address in the `players` array is set to `address(0)` instead of being removed from the array:
```solidity
players[playerIndex] = address(0);
```
This leaves the array's length (`players.length`) unchanged. However, in `selectWinner()`, the contract calculates the total amount collected based on the full array length:
```solidity
uint256 totalAmountCollected = players.length * entranceFee;
```
This causes a desynchronization between the actual ETH balance of the contract and the calculated `totalAmountCollected` when any players have refunded.


**Impact:**
1. **Denial of Service / Locked Funds (Scenario A):** If any player refunds and the remaining active players are fewer than the array length, the calculated `prizePool` (80% of theoretical collection) may exceed the contract's actual ETH balance. When `selectWinner()` tries to send `prizePool` to the winner, the transfer will revert due to insufficient funds, permanently locking all players' ETH in the contract.
2. **Fee Theft & Bricked Withdrawals (Scenario B):** If the actual contract balance is enough to cover the inflated `prizePool`, the winner will receive more than 80% of the actual deposited funds. This drains the ETH meant for protocol fees, updating `totalFees` to an inflated amount that cannot be withdrawn, permanently bricking `withdrawFees()`.

**Proof / Scenario:**
* **Scenario A (Lockout):** 
  1. 4 players enter the raffle paying 1 ETH each. Contract balance = 4 ETH, `players.length` = 4.
  2. Player 4 calls `refund()`. Contract balance = 3 ETH, but `players.length` remains 4.
  3. `selectWinner()` is called. It calculates `totalAmountCollected = 4 * 1 ETH = 4 ETH`, and `prizePool = 3.2 ETH`.
  4. The contract attempts to transfer 3.2 ETH to the winner, but it only has 3 ETH. The transaction reverts, preventing the raffle from ever completing.

* **Scenario B (Fee Theft):**
  1. 10 players enter paying 1 ETH each. Contract balance = 10 ETH, `players.length` = 10.
  2. 2 players call `refund()`. Contract balance = 8 ETH, but `players.length` remains 10.
  3. `selectWinner()` calculates `totalAmountCollected = 10 ETH`, `prizePool = 8 ETH`, and `fee = 2 ETH`.
  4. The contract successfully sends 8 ETH (100% of its actual balance) to the winner. Contract balance is now 0 ETH.
  5. `totalFees` is updated to 2 ETH.
  6. The owner calls `withdrawFees()`, which reverts because `address(this).balance` (0) is not equal to `totalFees` (2 ETH).


**Recommendation:**
Instead of setting the refunded player's address to `address(0)` in `refund()`, use the "swap and pop" pattern to remove the player and shrink the array length:

```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
    require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

    payable(msg.sender).sendValue(entranceFee);

    // Swap and Pop
    players[playerIndex] = players[players.length - 1];
    players.pop();

    emit RaffleRefunded(playerAddress);
}
```


### [H-2] Integer overflow in `totalFees` variable truncation bricks fee withdrawals and locks protocol revenue

**Severity:** High 

**Root cause:** 
`totalFees` is a `uint64` state variable, but the `fee` is calculated as a `uint256`. The line `totalFees = totalFees + uint64(fee);` silenty truncates/overflows because Solidity `^0.7.6` has no built-in overflow checks.
```solidity
totalFees = totalFees + uint64(fee);
```

**Impact:** 
Truncated `totalFees` prevents the owner from calling `withdrawFees()` due to the strict equality check `require(address(this).balance == uint256(totalFees))`. Fees are locked in the contract forever.


**Proof of Concept / Scenario:**
1. The `entranceFee` is set to 1 ETH.
2. 93 players enter a single raffle. Total amount collected is 93 ETH.
3. `selectWinner()` calculates the fee as 20% of 93 ETH, which is 18.6 ETH ($1.86 \times 10^{19}$ Wei).
4. The maximum value of a `uint64` is $2^{64} - 1 \approx 1.8446 \times 10^{19}$ Wei (~18.4467 ETH).
5. Casting 18.6 ETH to `uint64` causes an integer overflow and silent truncation:
   `uint64(18.6 ETH) = 18,600,000,000,000,000,000 - 18,446,744,073,709,551,616 = 153,255,926,290,448,384 Wei` (~0.153 ETH).
6. `totalFees` is updated to ~0.153 ETH.
7. The winner receives 80% (74.4 ETH), and the contract has 18.6 ETH remaining in its balance.
8. The owner attempts to withdraw fees, but `withdrawFees()` reverts because `address(this).balance` (18.6 ETH) does not equal `totalFees` (0.153 ETH). All fees are permanently locked.

**Recommendation:**
1. Instead of setting the refunded player's address to `address(0)` in `refund()`, use the "swap and pop" pattern to remove the player and shrink the array length:

```solidity
function refund(uint256 playerIndex) public {
    address playerAddress = players[playerIndex];
    require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
    require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

    payable(msg.sender).sendValue(entranceFee);

    // Swap and Pop
    players[playerIndex] = players[players.length - 1];
    players.pop();

    emit RaffleRefunded(playerAddress);
}
```

2. Change the data type of `totalFees` from `uint64` to `uint256`.
3. Use OpenZeppelin's `SafeMath` library for arithmetic operations in Solidity `^0.7.6`, or upgrade the contract to Solidity `^0.8.0` where overflow checks are built-in.
```solidity
// Change state variable type
uint256 public totalFees = 0;

// Use SafeMath (or upgrade to Solidity 0.8+)
totalFees = totalFees.add(fee);
```