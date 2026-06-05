# Puppy Raffle Audit Report Draft

**Contract:** `src/PuppyRaffle.sol` (Solidity ^0.7.6)  
**Auditor:** Gintoki Sakata  
**Date:** 2026-06-06  
**Scope:** Full contract review   

---

## [H-1] Unchanged array length on refund leads to incorrect prize calculation, failed winner selection, or stolen fees

**Severity:** High

**Summary:**  
When a player refunds, their index in the `players` array is set to `address(0)`, but the array length is not reduced. This desynchronizes the contract's actual ETH balance from the value calculated by `players.length * entranceFee`. As a result, `selectWinner()` either reverts (locking funds) or distributes more than 80% of actual funds to the winner, leaving zero fees and permanently bricking `withdrawFees()`.

**Root Cause:**  
In `refund()`, the line `players[playerIndex] = address(0);` leaves `players.length` unchanged. `selectWinner()` then calculates:
```solidity
uint256 totalAmountCollected = players.length * entranceFee;
uint256 prizePool = (totalAmountCollected * 80) / 100;
uint256 fee = (totalAmountCollected * 20) / 100;
```
This causes a mismatch between actual balance and expected amounts.

**Impact:**  
1. **Scenario A (Locked Funds):** 4 players enter → 1 refunds → `selectWinner()` tries to send 3.2 ETH but only 3 ETH exists → reverts on transfer, permanently locking all funds.  
2. **Scenario B (Fee Theft & Bricked Withdrawals):** 10 players enter → 2 refund → winner receives 100% of remaining balance (8 ETH). `totalFees` is set to 2 ETH but contract balance is now 0. `withdrawFees()` permanently reverts on the strict equality check.

**Proof / Scenario (Foundry PoCs):**

### Scenario A – Locked Funds
```solidity
function testH1_ArrayDesync_LockedFunds_ScenarioA() public playersEntered {
    uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerTwo);
    vm.startPrank(playerTwo);
    puppyRaffle.refund(indexOfPlayer);
    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);
    vm.expectRevert("PuppyRaffle: Failed to send prize pool to winner");
    puppyRaffle.selectWinner();
    vm.stopPrank();
}
```

### Scenario B – Fee Theft
```solidity
function testH1_ArrayDesync_FeeTheft_ScenarioB() public {
    address[] memory players = new address[](10);
    players[0] = playerOne;
    players[1] = playerTwo;
    players[2] = playerThree;
    players[3] = playerFour;
    players[4] = playerFive;
    players[5] = playerSix;
    players[6] = playerSeven;
    players[7] = playerEight;
    players[8] = playerNine;
    players[9] = playerTen;
    puppyRaffle.enterRaffle{value: entranceFee * 10}(players);

    uint256 indexOfFirstPlayer = puppyRaffle.getActivePlayerIndex(playerThree);
    uint256 indexOfSecondPlayer = puppyRaffle.getActivePlayerIndex(playerEight);

    vm.prank(playerThree);
    puppyRaffle.refund(indexOfFirstPlayer);
    vm.prank(playerEight);
    puppyRaffle.refund(indexOfSecondPlayer);

    vm.startPrank(playerFive);
    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);
    puppyRaffle.selectWinner();
    assertEq(address(puppyRaffle).balance, 0);
    vm.stopPrank();

    vm.startPrank(testUser);
    vm.expectRevert("PuppyRaffle: There are currently players active!");
    puppyRaffle.withdrawFees();
    vm.stopPrank();
}
```

**Recommendation:**  
Replace the zeroing pattern with swap-and-pop in `refund()` so the array length shrinks correctly.

---

## [H-2] Integer overflow in `totalFees` variable truncation bricks fee withdrawals and locks protocol revenue

**Severity:** High

**Summary:**  
`totalFees` is stored as `uint64` while fees are calculated as `uint256`. The cast `uint64(fee)` silently truncates on overflow in Solidity ^0.7.6. This desynchronizes `totalFees` from actual contract balance, causing `withdrawFees()` to permanently revert on its strict equality check.

**Root Cause:**  
```solidity
totalFees = totalFees + uint64(fee);
```
No overflow protection exists. When the 20% fee exceeds `type(uint64).max`, the stored value wraps around.

**Impact:**  
With 100 players (100 ETH total), the 20 ETH fee overflows `uint64`. `totalFees` becomes a tiny truncated value. Winner receives 80 ETH. Contract retains 20 ETH, but `withdrawFees()` reverts because `balance != totalFees`.

**Proof / Scenario (Foundry PoC):**

```solidity
function testH2_Uint64TotalFeesOverflow_BricksWithdraw() public {
    address[] memory players = new address[](100);
    for (uint160 i = 0; i < 100; i++) {
        address player = address(i + 1);
        players[i] = player;
    }

    vm.deal(players[0], entranceFee * 100);
    vm.prank(players[0]);
    puppyRaffle.enterRaffle{value: entranceFee * 100}(players);

    vm.warp(block.timestamp + duration + 1);
    vm.roll(block.number + 1);
    puppyRaffle.selectWinner();

    assertEq(address(puppyRaffle).balance, 20 ether);

    vm.prank(playerOne);
    vm.expectRevert("PuppyRaffle: There are currently players active!");
    puppyRaffle.withdrawFees();
}
```

**Recommendation:**  
1. Change `totalFees` to `uint256`.  
2. Use SafeMath or upgrade to Solidity ^0.8.0+ for automatic overflow checks.

---

## Summary

- **H-1** and **H-2** both confirmed with passing PoC tests that demonstrate the exact failure modes described in the candidate findings.
- All tests run green against the vulnerable contract (as expected for exploit PoCs).
- Next steps: Polish report, add to final-report.md, update checklist.

