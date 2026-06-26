// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployLevelOne} from "../../script/DeployLevelOne.s.sol";
import {LevelOne} from "../../src/LevelOne.sol";
import {LevelTwo} from "../../src/LevelTwo.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract H03_TeacherWagePerTeacherPoC is Test {
    DeployLevelOne deployBot;
    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;
    MockUSDC usdc;

    address proxyAddress;
    address principal;
    uint256 schoolFees;

    address alice;
    address bob;
    address clara;
    address dan;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);

        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();

        alice = makeAddr("teacher_alice");
        bob = makeAddr("teacher_bob");
        clara = makeAddr("student_clara");
        dan = makeAddr("student_dan");

        usdc.mint(clara, schoolFees);
        usdc.mint(dan, schoolFees);
    }

    function _addTeachers() internal {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();
    }

    function _enrollStudents() internal {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(dan);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();
    }

    function _startSession() internal {
        vm.prank(principal);
        levelOneProxy.startSession(70);
    }

    function test_graduateAndUpgrade_paysEachTeacher35Percent() public {
        // 1. Arrange: Add teachers, enroll students, start session
        _addTeachers();
        _enrollStudents();
        _startSession();

        levelTwoImplementation = new LevelTwo();
        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        uint256 bursaryBefore = usdc.balanceOf(address(levelOneProxy));
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);

        // 2. Act: Call graduateAndUpgrade as principal
        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(address(levelTwoImplementation), data);

        // 3. Assert: Calculate deltas and prove Alice and Bob got 35% EACH (70% total)
        uint256 aliceDelta = usdc.balanceOf(alice) - aliceBalanceBefore;
        uint256 bobDelta = usdc.balanceOf(bob) - bobBalanceBefore;

        assertEq(aliceDelta, (bursaryBefore * 35) / 100);
        assertEq(bobDelta, (bursaryBefore * 35) / 100);
        assertEq(aliceDelta + bobDelta, (bursaryBefore * 70) / 100);
    }
}
