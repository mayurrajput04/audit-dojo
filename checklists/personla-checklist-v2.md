# DEFI PRIMITIVES: ERC-4626 VAULTS & POOLS
<!-- 10 checks written BY USER understanding on Day 43 quick mode — theory -> real primitive -->

1. **Rounding Direction:** Does deposit/previewDeposit round DOWN shares (mulDiv Floor) and mint/previewMint round UP assets needed? Does withdraw round UP shares burned and redeem round DOWN assets out? If flipped, 1-wei dust extractable each tx. Check Math.Rounding param.

2. **First-Depositor Inflation Protection:** Is _decimalsOffset() overridden >0 (e.g., 6) and does _convertToShares use (totalSupply + 10**offset)/(totalAssets+1)? If offset=0 and no dead shares, attacker can deposit 1 wei + donate 20k to make next 20k deposit round to 0. Check MIN_LIQUIDITY burn.

3. **Donation Attack Surface:** Is totalAssets() = asset.balanceOf(address(this))? If yes, direct asset.transfer(vault) inflates share price. Secure: internal accounting or offset defense. Flag if yield via balance increase AND offset=0.

4. **Zero-Share Griefing Guard:** Does deposit() enforce require(previewDeposit !=0)? Without it, victim deposit silently becomes donation. Check empty-vault case: first depositor gets reasonable shares?

5. **Preview vs Execution Consistency:** Do previewDeposit/mint/withdraw/redeem return exactly what state-changing fn does same block (fees, rounding)? EIP says MUST match. Mismatch enables fee bypass.

6. **Empty Vault & Reset Attack:** After totalSupply=0 full withdrawal, does vault reset safely? If attacker deposits 1, withdraws all but 1 wei, leaves inflated price for next user? Check OZ virtual shares vs naive if totalSupply==0 ? assets : ...

7. **Yield/Fee Accrual Accounting:** How does totalAssets grow? Via realized harvest or unchecked balance? Does fee-on-yield take fee BEFORE updating share price? Double-counting donation as yield?

8. **Reward Distribution Math (Staking):** MasterChef pattern: updatePool() -> pending = amount*accPerShare/PRECISION - rewardDebt -> transfer -> amount update -> rewardDebt = amount*accPerShare. If order flipped, extra rewards. Is accPerShare skipped when lpSupply==0 to avoid div0?

9. **Fee-on-Transfer / Rebasing Tokens:** Does vault use transferFrom amount directly as deposit, not measuring received via balance before/after? If fee-on-transfer, totalAssets over-counts, conversion breaks.

10. **Share Price as Oracle Sandwich:** Is convertToAssets() used as price oracle downstream (lending/liquidation)? If vault price manipulable via donation/flashloan single block, downstream spot oracle at risk ($11M class). Need TWAP/EMA or reentrancy guard on donation?
