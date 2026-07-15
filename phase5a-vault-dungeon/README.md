# 🏯 VAULT DUNGEON — HARDCORE MODE (Clean Workspace)
## Location: audit-dojo/phase5a-vault-dungeon/
## Day 43 Reset — Real Study, Real XP

This folder is your clean dojo. All Phase 5A study lives here.
When you clear dungeon, we sync final artifacts to `notes/` and `checklists/` for portfolio.

### Structure:
- `README.md` = this file, dungeon rules + all floors challenges (Game Master board)
- `vault-study-notes.md` = YOUR working notes, fill floors here (final copy -> notes/vault-study-notes.md)
- `checklist-draft.md` = Draft your 10 checks here (final copy -> checklists/personal-checklist-v2.md)
- `floors/` = per-floor scratch pads

Final sync on clear:
- `phase5a-vault-dungeon/vault-study-notes.md` -> `notes/vault-study-notes.md`
- `phase5a-vault-dungeon/checklist-draft.md` -> `checklists/personal-checklist-v2.md`

---

### FLOOR 0: The Contract (5 min)

Open `vault-study-notes.md` in THIS folder and write:

```
I, Mayur, will not copy-paste from blogs. I will derive formulas and write attack tables by hand.
If I fail a floor, I loop it. No skipping.
```

---

### FLOOR 1: The Empty Vault (10 XP)
Lore: Every vault born empty. totalSupply=0, totalAssets=0. First depositor sets price.

Read (point only):
- RareSkills ERC4626: "What happens if pool is empty?" and formula shares = assets * totalSupply / totalAssets
- OZ Docs ERC4626: Search "virtual assets" — why totalAssets+1 exists?

Challenge 1A: Division by zero trap. What happens with naive formula? Why OZ uses +1?
Challenge 1B Math: assets=1000e18, supply=0, totalAssets=0, offset=0 => shares = ? Same with offset=6 (1e6 virtual shares): shares = 1000e18 * (0+1e6)/(0+1) = ? Why is it not breaking 1:1? Explain price = assets/shares.

Artifact: Write in vault-study-notes.md under ## Floor 1

---

### FLOOR 2: The 1 Wei Troll (10 XP)
Lore: Attacker enters first. Why 1 wei? Cheap + max leverage.

Read: MixBytes Overview Example 1 paragraph, Eco article Share Inflation why 1 wei

Challenge 2A: Why 1 wei not 1000e18? Use formula victimShares = victimAssets * attackerSupply / (attackerAssets+donation). Compare attackerSupply=1 vs 1000.
Challenge 2B: Given attackerSupply=1, attackerAssets=1 wei, victimAssets=5000e6, find donation D such that 5000e6*1/(1+D) <1 => victim 0 shares. Solve D.

Artifact: ## Floor 2

---

### FLOOR 3: The Donation Nuke (10 XP)
Lore: Front-run + donate = theft.

Challenge 3A: Reconstruct table YOURSELF:

| Step | Actor | Action | totalSupply | totalAssets | Share Price | Notes |
| 0 | - | Empty | | | | |
| 1 | Attacker | deposit(1 wei) | | | | |
| 2 | Attacker | transfer 20000e6 directly | | | | |
| 3 | Victim | deposit 20000e6 | | | | Expected vs actual? |
| 4 | Attacker | redeem all | | | | Profit? |

Challenge 3B: Profit %: Victim lost 20000e6, attacker spent 1 wei + 20000e6, redeem = ? Profit %?

Artifact: ## Floor 3 with table.

---

### FLOOR 4: The Virtual Shield (10 XP)
Lore: OZ forged shield: virtual shares.

Read: OZ Docs Defending with virtual offset table, RareSkills Adding virtual liquidity, BlockMagnates $11M article

Challenge 4A: Recalc Floor 3 with offset=6: shares = assets * (supply+1e6)/(totalAssets+1). After donation 20000e6, victim deposit 20000e6 => shares = 20000e6*(1+1e6)/(20000e6+1+1) = ? Is it 0?
Challenge 4B: Cost to still zero: Find D needed now to make victim shares <1 with offset 6. Approx D ~ 20000e6*1e6 = 2e16. Show.

Artifact: ## Floor 4

---

### FLOOR 5: The Grief That Still Works (10 XP)
Lore: Devs thought require(shares !=0) fixed it. MixBytes proved not.

Read: MixBytes Example 2 Rounding to one share, C4 Ditto Issue #17 double deposit summary

Challenge 5A: Attacker deposit 1, donation 10000e6, victim deposit 20000e6 gets 1 share (not 0). Pool = 1+10000e6+20000e6=30000e6. Attacker redeems 1 share =15000e6. Profit =5000e6. Show.
Challenge 5B: What fixes BOTH zero and 1-share? Write 1 checklist question from this.

Artifact: ## Floor 5

---

### FINAL BOSS: Reward Keeper (20 XP)
Lore: Staking pools same disease.

Read: MixBytes Yield Aggregators Rewards calc wrong paragraph, MasterChef accRewardPerShare

Boss-A: Write TWO pseudocode versions: INSECURE (update user.amount before accPerShare) vs SECURE (updatePool() -> pending -> transfer -> user.amount += -> rewardDebt =...). Explain bug.
Boss-B: What if lpSupply==0 and you do accPerShare += reward*1e12/lpSupply? Division by zero. Correct handling? Skip if lpSupply==0
Boss-C: From boss, create 2 of your 10 final checklist questions for personal-checklist-v2.md

---

### VICTORY CONDITIONS — Day 43 Real Done

- [ ] phase5a-vault-dungeon/vault-study-notes.md has Floor 1-5 + Boss with YOUR calculations
- [ ] phase5a-vault-dungeon/checklist-draft.md has 10 checks WRITTEN BY YOU
- [ ] Sync to notes/vault-study-notes.md and checklists/personal-checklist-v2.md
- [ ] You can answer 3 random questions from floors without looking
- [ ] Tracker updated with career action 0

No skipping floors. Start Floor 0 oath now.
