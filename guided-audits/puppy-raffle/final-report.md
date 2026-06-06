# Puppy Raffle Audit Report

**Contract:** `src/PuppyRaffle.sol`  
**Language:** Solidity `^0.7.6`  
**Prepared on:** 2026-06-06  
**Scope:** Single-contract review of raffle entry, refund, winner selection, and fee withdrawal logic

---

## [H-1] Refunded entries remain counted as active players, breaking raffle accounting and settlement

**Severity:** High

**Summary**  
`refund()` marks a refunded player slot as `address(0)` but does not remove that entry from `players`. `selectWinner()` later assumes `players.length` still equals the number of funded active entrants and uses it to calculate both the winner payout and protocol fee. After any refund, that assumption is false. As a result, the contract can either become unable to settle a raffle due to insufficient balance or overpay the winner using ETH that should have remained as protocol fees.

**Root Cause**  
The contract uses the `players` array as both:
1. the participant registry, and  
2. the accounting source of truth for how much ETH was collected.

That invariant is broken in `refund()`:

```solidity
players[playerIndex] = address(0);
```

The refunded entry is invalidated, but the array length is left unchanged. `selectWinner()` then continues to treat `players.length` as if every slot represents a paid, active entrant:

```solidity
uint256 totalAmountCollected = players.length * entranceFee;
uint256 prizePool = (totalAmountCollected * 80) / 100;
uint256 fee = (totalAmountCollected * 20) / 100;
```

Once a refund occurs, `players.length` no longer matches the number of active paid tickets or the contract's actual raffle balance, so all payout accounting derived from it becomes unreliable.

**Impact**  
This is **High** because a single refund can break core raffle settlement and put both user funds and protocol fees at risk.

- **Settlement DoS / locked raffle funds:** if the computed `prizePool` exceeds the contract's actual balance, `selectWinner()` reverts when attempting to pay the winner. The raffle cannot be finalized, and the round's funds remain stuck in the contract.
- **Winner overpayment / fee backing loss:** if the remaining balance is still enough to pay the inflated `prizePool`, the winner can receive more than 80% of the actual collected funds. This consumes ETH that should have backed protocol fees.
- **Downstream fee withdrawal failure:** `totalFees` is still incremented using the inflated accounting value, so `withdrawFees()` later reverts because the contract balance no longer equals the recorded fee amount.

**Proof of Concept**

### Scenario A — settlement reverts after a refund
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

**Walkthrough**
1. Four players enter at `1 ether` each. Contract balance = `4 ether`, `players.length = 4`.
2. One player refunds. Contract balance drops to `3 ether`, but `players.length` remains `4`.
3. `selectWinner()` computes `totalAmountCollected = 4 ether` and `prizePool = 3.2 ether`.
4. The contract only holds `3 ether`, so the winner payment fails and the raffle cannot be finalized.

### Scenario B — winner is overpaid and fee withdrawal becomes impossible
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

**Walkthrough**
1. Ten players enter at `1 ether` each. Contract balance = `10 ether`, `players.length = 10`.
2. Two players refund. Contract balance becomes `8 ether`, but `players.length` is still `10`.
3. `selectWinner()` computes `prizePool = 8 ether` and `fee = 2 ether` from the stale length.
4. The winner receives `8 ether`, which is 100% of the remaining balance rather than the intended 80% split.
5. `totalFees` is still increased by `2 ether`, even though no ETH remains in the contract to back those fees.
6. `withdrawFees()` later reverts because `address(this).balance != totalFees`.

**Recommendation**  
Do not leave refunded placeholders inside the active participant set.

- Remove refunded players using a pattern such as swap-and-pop so `players.length` always matches the number of active entrants.
- Alternatively, maintain a separate active-player count and derive prize/fee calculations from that value rather than the raw array length.
- More generally, payout accounting should be based on a state variable that cannot diverge from the contract's actual raffle balance after refunds.

---

## [H-2] Narrowing fee accounting to `uint64` can overflow and permanently lock protocol fees

**Severity:** High

**Summary**  
`selectWinner()` calculates fees in `uint256` but stores cumulative fees in `uint64`. Under Solidity `^0.7.6`, the explicit cast to `uint64` silently truncates on overflow. Once the accumulated fee amount exceeds the `uint64` range, `totalFees` no longer reflects the actual fee balance held by the contract. Because `withdrawFees()` requires exact equality between contract balance and `totalFees`, protocol fees can become permanently unwithdrawable.

**Root Cause**  
The contract performs fee accounting in a wider type and then stores the result in a narrower type without overflow protection:

```solidity
uint64 public totalFees = 0;
...
totalFees = totalFees + uint64(fee);
```

`fee` is derived as a `uint256`, but the contract truncates it to `uint64` before storing it. In Solidity `^0.7.6`, this conversion does not revert if the value exceeds `type(uint64).max`; it silently wraps. The issue becomes critical because `withdrawFees()` assumes `totalFees` exactly mirrors the contract's fee balance:

```solidity
require(address(this).balance == uint256(totalFees), "PuppyRaffle: There are currently players active!");
```

Once truncation occurs, that equality can no longer hold.

**Impact**  
This is **High** because it can permanently freeze protocol-owned funds.

- Once cumulative fees exceed the `uint64` limit, `totalFees` becomes smaller than the actual fee balance held by the contract.
- `withdrawFees()` then reverts indefinitely because the recorded fee amount no longer matches the contract balance.
- The failure does not require an exotic edge case: with a `1 ether` entrance fee, overflow begins once a round's fee exceeds approximately `18.4467 ether`, which happens at `93` entrants in a single round. The included PoC uses `100` entrants for simplicity.

**Proof of Concept**
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

**Walkthrough**
1. A raffle collects `100 ether` in entrance fees.
2. `selectWinner()` computes `fee = 20 ether`.
3. `20 ether` exceeds `type(uint64).max` when expressed in wei, so `uint64(fee)` truncates.
4. The contract retains the real fee balance (`20 ether`), but `totalFees` stores only the wrapped value.
5. `withdrawFees()` reverts because `address(this).balance` reflects the real fees while `totalFees` reflects the truncated amount.
6. Protocol revenue is now stuck in the contract.

**Recommendation**  
Use a type large enough to hold the full fee amount and avoid lossy casts.

- Change `totalFees` from `uint64` to `uint256`.
- If storage packing is important, add explicit bounds checks before any narrowing conversion.
- Use checked arithmetic by upgrading to Solidity `^0.8.0` or by applying a library such as SafeMath in Solidity `^0.7.6`.
- Keep `withdrawFees()` resilient to accounting desynchronization; a strict balance-equality dependency turns a bookkeeping bug into a permanent fund-locking condition.

---

## Conclusion

Both findings were validated against the live workspace code and supported by exploit-oriented tests:

- **H-1** shows that refund handling breaks the accounting invariant relied upon by raffle settlement.
- **H-2** shows that fee accounting can overflow due to a narrowing cast, permanently locking protocol revenue.

Together, these issues demonstrate two core audit lessons from this target: maintain explicit accounting invariants across state transitions, and never rely on lossy integer conversions for fund tracking.