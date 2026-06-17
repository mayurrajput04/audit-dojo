// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseTest } from "./BaseTest.t.sol";
import { ThunderLoan } from "../../src/protocol/ThunderLoan.sol";
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract H5StorageCollisionPoC is BaseTest {
    ThunderLoanUpgraded public upgradedThunderLoan;

    function test_POC_H5_storage_collision() public {
        // 1. Setup V1: owner allows tokenA
        vm.startPrank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        vm.stopPrank();

        // 2. Record fee of borrowing 100e18 in V1 (should be 0.3%)
        uint256 borrowAmt = 100e18;
        uint256 feeV1 = thunderLoan.getCalculatedFee(tokenA, borrowAmt);
        
        // Assert V1 fee is indeed 0.3% (0.3e18)
        assertEq(feeV1, 3e17, "V1 fee should be exactly 0.3%");

        // 3. Deploy Upgraded (V2) implementation and perform the upgrade
        ThunderLoanUpgraded upgradedImpl = new ThunderLoanUpgraded();

        vm.startPrank(thunderLoan.owner());
        // Since we are using ERC1967Proxy and ThunderLoan inherits UUPSUpgradeable, we can upgrade via proxy
        thunderLoan.upgradeTo(address(upgradedImpl));
        vm.stopPrank();

        // Bind upgraded implementation abi to our proxy address
        upgradedThunderLoan = ThunderLoanUpgraded(address(thunderLoan));

        // 4. Record fee of borrowing 100e18 in V2 (which reads V1's old s_feePrecision = 1e18 as the fee)
        uint256 feeV2 = upgradedThunderLoan.getCalculatedFee(tokenA, borrowAmt);

        // 5. Assert: V2 fee is now 100% of the loan amount!
        assertEq(feeV2, borrowAmt, "V2 fee should be 100% of the loan amount due to storage layout collision");
    }
}
