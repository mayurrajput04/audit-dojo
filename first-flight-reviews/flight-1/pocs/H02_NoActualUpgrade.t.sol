// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployLevelOne} from "../../script/DeployLevelOne.s.sol";
import {LevelOne} from "../../src/LevelOne.sol";
import {LevelTwo} from "../../src/LevelTwo.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract H02_NoActualUpgradePoC is Test {
    DeployLevelOne deployBot;

    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;

    MockUSDC usdc;

    address proxyAddress;
    address levelOneImplementationAddress;
    address levelTwoImplementationAddress;

    address principal;
    uint256 schoolFees;

    address alice;
    address bob;

    address clara;
    address dan;

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _getImplementation(address proxy) internal view returns (address) {
        bytes32 raw = vm.load(proxy, IMPLEMENTATION_SLOT);
        return address(uint160(uint256(raw)));
    }

    function setUp() public {
        deployBot = new DeployLevelOne();

        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);

        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();
        levelOneImplementationAddress = deployBot.getImplementationAddress();

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

    function test_graduateAndUpgrade_doesNotChangeProxyImplementation() public {
        // arrange
        _addTeachers();
        _enrollStudents();
        _startSession();

        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        address implBefore = _getImplementation(proxyAddress);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        // act
        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        // assert
        address implAfter = _getImplementation(proxyAddress);

        // TODO: assert implBefore is LevelOne implementation
        assertEq(implBefore, levelOneImplementationAddress);
        // TODO: assert implAfter is unchanged
        assertEq(implBefore, implAfter);
        // TODO: assert implAfter is not LevelTwo implementation
        assertNotEq(implAfter, levelTwoImplementationAddress);
    }
}
