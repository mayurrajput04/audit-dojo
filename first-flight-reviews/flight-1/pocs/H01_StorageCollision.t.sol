// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployLevelOne} from "../../script/DeployLevelOne.s.sol";
import {LevelOne} from "../../src/LevelOne.sol";
import {LevelTwo} from "../../src/LevelTwo.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {console2} from "forge-std/console2.sol";

contract H01_StorageCollisionPoC is Test {
    DeployLevelOne deployBot;
    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;
    MockUSDC usdc;

    address proxyAddress;
    address principal;

    address alice;
    address bob;

    uint256 schoolFeesBefore;
    uint256 sessionEndBefore;
    uint256 bursaryBefore;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);

        usdc = deployBot.getUSDC();
        principal = deployBot.principal();

        alice = makeAddr("teacher_alice");
        bob = makeAddr("teacher_bob");

        _addTeachers();
        _enrollStudents();
        _startSession();
    }

    function _addTeachers() internal {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();
    }

    function _enrollStudents() internal {
        address[] memory students = new address[](3);
        students[0] = makeAddr("student_clara");
        students[1] = makeAddr("student_dan");
        students[2] = makeAddr("student_ella");

        for (uint256 i = 0; i < students.length; i++) {
            address student = students[i];
            uint256 fees = levelOneProxy.getSchoolFeesCost();

            vm.startPrank(student);
            usdc.mint(student, fees);
            usdc.approve(address(levelOneProxy), fees);
            levelOneProxy.enroll();
            vm.stopPrank();
        }
    }

    function _startSession() internal {
        vm.prank(principal);
        levelOneProxy.startSession(70);
    }

    function test_storageCollisionAfterUpgrade() public {
        // Record values from LevelOne
        schoolFeesBefore = levelOneProxy.getSchoolFeesCost();
        sessionEndBefore = levelOneProxy.getSessionEnd();
        bursaryBefore = levelOneProxy.bursary();

        console2.log("schoolFeesBefore:", schoolFeesBefore);
        console2.log("sessionEndBefore:", sessionEndBefore);
        console2.log("bursaryBefore:", bursaryBefore);

        // Deploy LevelTwo implementation
        levelTwoImplementation = new LevelTwo();

        // Simulate upgrade by replacing the proxy's code with LevelTwo
        vm.etch(proxyAddress, address(levelTwoImplementation).code);

        // Read state through LevelTwo interface
        LevelTwo levelTwoProxy = LevelTwo(proxyAddress);

        uint256 corruptedSessionEnd = levelTwoProxy.sessionEnd();
        uint256 corruptedBursary = levelTwoProxy.bursary();
        uint256 corruptedCutOffScore = levelTwoProxy.cutOffScore();

        console2.log("LevelTwo.sessionEnd():", corruptedSessionEnd);
        console2.log("LevelTwo.bursary():", corruptedBursary);
        console2.log("LevelTwo.cutOffScore():", corruptedCutOffScore);

        // Prove storage corruption
        assertNotEq(corruptedSessionEnd, sessionEndBefore, "sessionEnd should be corrupted");
        assertNotEq(corruptedBursary, bursaryBefore, "bursary should be corrupted");
        assertNotEq(corruptedCutOffScore, 70, "cutOffScore should be corrupted");
    }
}