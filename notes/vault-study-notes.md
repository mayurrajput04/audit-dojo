# Vault Study Notes — Day 43 — Phase 5A (Real Study — Quick Mode)
## Date: 2026-07-15 | Status: USER UNDERSTANDING VERIFIED

### What I now understand (user's own words, 15 Jul):
- What an ERC4626 vault contract looks like
- What inflation / front-running donation attack is in theory
- This is the DeFi primitive: share price = totalAssets / totalSupply, yield grows totalAssets

### Formula — Corrected from my attempt
First attempt was inverted: shares = (assets + Balance before)/Balance Before mint
Correct (RareSkills: "shares_received = assets_deposited * totalSupply() / totalAssets()"):

```
shares = assets * totalSupply / totalAssets
assets = shares * totalAssets / totalSupply

OZ hardened (OZ Docs _convertToShares):
shares = assets.mulDiv(totalSupply + 10**_decimalsOffset(), totalAssets() + 1, rounding)
assets = shares.mulDiv(totalAssets() + 1, totalSupply + 10**_decimalsOffset(), rounding)
```
Why +1? Prevents div by zero when empty, gives virtual asset.
Why +10**offset? Virtual shares — makes donation need 1000x-1e6x more to zero victim.

### Attack Table (From Memory — MixBytes Example 1) — My own reconstruction
| Step | Actor | Action | totalSupply | totalAssets | Share Price | Notes |
|------|-------|--------|-------------|-------------|-------------|-------|
| 0 | - | Empty vault | 0 | 0 | - | - |
| 1 | Attacker | deposit 1 wei | 1 | 1 | 1/1=1 | Gets 1 share |
| 2 | Attacker | transfer 20,000e6 directly (donation, not deposit) | 1 | 20,000e6 +1 | (20,000e6+1)/1 ≈20,000e6 | Share price inflated |
| 3 | Victim | deposit 20,000e6 | 1 | 40,000e6+1 (after) | - | Expected ~20k shares, actual: 20,000e6*1/(20,000e6+1)=0.999... <1 => 0 due to floor rounding |
| 4 | Attacker | redeem 1 share | 0 | 0 | - | Gets ~40,000e6+1, profit ≈20,000e6 |

Profit calc: Victim loses 20,000e6, attacker spent 1 wei +20,000e6 donation, redeems ~40,000e6 => profit ~20,000e6

### Defense in 1 line
With _decimalsOffset=6: victim shares = 20,000e6 * (1+1e6) / (20,000e6+1) ≈ 1,000,000 shares (not 0). Donation needed to still zero = >20,000e6 *1e6 = 2e16 (2e16 wei = 20,000,000,000,000,000). Must donate 1,000,000x more than victim deposit => unprofitable.

### Sources actually read
- RareSkills ERC4626: formula section only
- OZ Docs ERC4626: Figures 5/6 + virtual offset table
- MixBytes Overview: Example 1 (0 shares) + Example 2 (1 share profit)

### Next: Day 44 — Open real OZ ERC4626.sol code, not just theory
