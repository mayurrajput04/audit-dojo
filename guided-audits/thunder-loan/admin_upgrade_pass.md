# Admin & Upgrade Pass — Thunder Loan

## 1. Admin Power Map

### Owner-Restricted Functions (via `onlyOwner`)

| Function | What it controls | What breaks if abused |
|----------|-----------------|----------------------|
| `setAllowedToken(IERC20 token, bool allowed)` | Adds/removes tokens from the protocol. When adding, deploys a new `AssetToken` contract with `address(this)` as the `i_thunderLoan`. When removing, `delete`s the mapping entry — orphans LP funds. | Owner can brick all redemptions for a token by disallowing it (H-1). No timelock, no LP vote. Instant unilateral action. |
| `updateFlashLoanFee(uint256 newFee)` | Changes `s_flashLoanFee`. Bounded only by `newFee <= s_feePrecision` (i.e. ≤ 100%). | Owner can set fee to 0 → LPs earn nothing. Owner can set fee to 100% → borrower repays entire loan as fee. No timelock, no bounds beyond ≤100%. |
| `_authorizeUpgrade(address newImplementation)` | Allows owner to swap the implementation contract via UUPS. | Storage layout mismatch between V1 and V2 causes critical collision (see Section 2). No timelock on upgrades. |

### `onlyThunderLoan`-Restricted Functions (via `AssetToken`)

| Function | What it controls | Key observation |
|----------|-----------------|-----------------|
| `AssetToken.mint(address, uint256)` | Mints receipt tokens to LPs | Only callable by `i_thunderLoan` (immutable, set in constructor) |
| `AssetToken.burn(address, uint256)` | Burns receipt tokens on redeem | Same — `i_thunderLoan` only |
| `AssetToken.transferUnderlyingTo(address, uint256)` | Moves underlying ERC20 out of AssetToken | Same — `i_thunderLoan` only |
| `AssetToken.updateExchangeRate(uint256 fee)` | Bumps the exchange rate upward | Same — `i_thunderLoan` only |

**Critical detail:** `i_thunderLoan` is `immutable` in `AssetToken`. It is set once in `AssetToken`'s constructor to `address(this)` — which is the **proxy address** at the time `setAllowedToken` is called. This means an upgrade does NOT break `i_thunderLoan` (the proxy address stays the same). BUT — if `setAllowedToken` is called AFTER an upgrade, the new `AssetToken` still gets `address(this)` = proxy address. So the immutable reference is safe across upgrades. ✅

---

## 2. Upgradeability Analysis

### V1 State Variables (ThunderLoan.sol) — After Inherited Storage

| Slot Offset | Variable | Type | Value after V1 `initialize()` |
|-------------|----------|------|-------------------------------|
| N+1 | `s_tokenToAssetToken` | `mapping(IERC20 => AssetToken)` | {token → AssetToken addresses} |
| N+2 | `s_feePrecision` | `uint256 private` | **1e18** |
| N+3 | `s_flashLoanFee` | `uint256 private` | **3e15** (0.3%) |
| N+4 | `s_currentlyFlashLoaning` | `mapping(IERC20 => bool)` | {token → true/false} |

### V2 State Variables (ThunderLoanUpgraded.sol) — After Inherited Storage

| Slot Offset | Variable | Type | V2's read after upgrade (V1's old data still in storage) |
|-------------|----------|------|----------------------------------------------------------|
| N+1 | `s_tokenToAssetToken` | `mapping(IERC20 => AssetToken)` | ✅ Same slot — still correct |
| N+2 | `s_flashLoanFee` | `uint256 private` | ⚠️ Reads old `s_feePrecision` = **1e18** |
| *(none)* | `FEE_PRECISION` | `uint256 public constant` | Inlined at compile time = 1e18 — **NO STORAGE SLOT** |
| N+3 | `s_currentlyFlashLoaning` | `mapping(IERC20 => bool)` | ⚠️ Reads old `s_flashLoanFee` slot = **3e15** (not a mapping!) |
| N+4 | *(orphaned)* | — | V1's `s_currentlyFlashLoaning` data — **V2 cannot access** |

### Collision #1 — Fee becomes 100%

After upgrade, V2 reads `s_flashLoanFee` from slot N+2, which holds V1's old `s_feePrecision` value of `1e18`.

V2's `getCalculatedFee`:
```
fee = (valueOfBorrowedToken * s_flashLoanFee) / FEE_PRECISION
fee = (valueOfBorrowedToken * 1e18) / 1e18
fee = valueOfBorrowedToken  ← 100% of loan value!!
```

**Impact:** Every flash loan charges a 100% fee. The borrower must repay principal + 100% of principal as fee. This functionally **bricks the protocol** — no rational borrower will use it. LP yield source goes to zero.

### Collision #2 — Flash-loaning state becomes unreadable

After upgrade, V2's `s_currentlyFlashLoaning` mapping is at slot N+3. But slot N+3 held V1's `s_flashLoanFee` value of `3e15` — it is NOT a mapping, it's a raw uint256.

Meanwhile, V1's actual `s_currentlyFlashLoaning` data lives at slot N+4, which V2 has **no variable pointing to**. It's orphaned.

**Impact:**
- Any token that was `s_currentlyFlashLoaning[token] = true` in V1 (slot N+4) — V2 doesn't know it. The mapping at N+3 will always return `false` for any key lookup (since the base slot contains `3e15`, Solidity mapping lookups on a non-mapping slot return 0/false for most practical keys).
- `repay()` checks `s_currentlyFlashLoaning[token]` — will revert with `ThunderLoan__NotCurrentlyFlashLoaning()`.
- Borrower cannot repay. Loan cannot be settled. Funds are stuck.
- Even for new flash loans: V2 sets `s_currentlyFlashLoaning[token] = true` at slot N+3, overwriting `3e15`. After `s_currentlyFlashLoaning[token] = false`, the base slot is zeroed. This means the raw value at N+3 is corrupted further — it was never meant to be a mapping base slot.

---

## 3. Initialization Risks

### Can `initialize` be called twice?

V1's `initialize` is guarded by the `initializer` modifier from OpenZeppelin's `Initializable`. This sets a boolean flag in the proxy's storage that prevents re-execution. ✅ Cannot be called twice on the proxy.

### Is the implementation contract initialized?

V1's constructor calls `_disableInitializers()`. This sets a flag on the **implementation contract itself** (not the proxy) that prevents anyone from calling `initialize` on the implementation directly. ✅ Implementation is protected.

**BUT — important nuance:** `_disableInitializers()` only prevents future calls to `initialize`. It does NOT call `initialize`. So the implementation contract's state variables (`s_feePrecision`, `s_flashLoanFee`, etc.) are never set on the implementation — they're only set on the proxy via the proxy's `initialize`. This is correct UUPS behavior. ✅

### What about V2's `initialize`?

V2's `initialize` does NOT set `s_feePrecision` (because it's now a `constant`). It only sets `s_flashLoanFee = 3e15`. But if the owner upgrades and calls `initialize` on V2 via `upgradeToAndCall`, V2 would write `3e15` to slot N+2 (which V2 thinks is `s_flashLoanFee`). That would fix the fee collision — but it would NOT fix the mapping collision at slot N+3. And it would NOT restore the orphaned mapping data at N+4.

**Key risk:** Even a "proper" upgrade with re-initialization only partially fixes the damage. The mapping shift is irreparable without manual state migration.

---

## 4. Access Control Vulnerabilities

### `i_thunderLoan` is immutable — safe across upgrades ✅

`AssetToken` stores `i_thunderLoan` as `immutable`, set in its constructor to `address(this)` (the proxy address). Since UUPS upgrades change the implementation, NOT the proxy address, all existing `AssetToken` contracts still correctly reference the proxy. No attack vector here.

### `onlyThunderLoan` cannot be spoofed ✅

The modifier checks `msg.sender != i_thunderLoan`. Since `i_thunderLoan` is immutable, there's no way to change it after deployment. An attacker cannot deploy a fake ThunderLoan and take over existing AssetTokens.

### But — new AssetTokens after upgrade are still safe ✅

When `setAllowedToken(token, true)` is called (even after upgrade), `new AssetToken(address(this), ...)` still captures the proxy address. Safe.

### Centralization risk — owner has no timelock ⚠️

All three owner functions (`setAllowedToken`, `updateFlashLoanFee`, `_authorizeUpgrade`) have:
- No timelock
- No multi-sig requirement
- No LP governance vote
- No event-only delay period

This is a **centralization vector**. The owner can:
1. Upgrade the contract to a malicious implementation that drains all funds.
2. Set fee to 100% instantly.
3. Disallow all tokens, orphaning all LP funds.

This is consistent with findings H-1 and the fee-bricking risk.

---

## 5. Findings / Hypotheses Table

| ID | Severity | Hypothesis | Invariant Broken | Verify in Pass 2? |
|----|----------|------------|------------------|-------------------|
| H-1 | High | `setAllowedToken(token, false)` orphans LP funds | INV-5, INV-6 | ✅ existing |
| H-2 | High | `deposit()` incorrectly updates exchange rate | INV-1, INV-8 | ✅ existing |
| H-3 | High | Oracle manipulation via TSwap spot price | INV-3 | ✅ existing |
| **H-5** | **High** | **Storage layout collision: V1→V2 upgrade shifts `s_flashLoanFee` to read V1's `s_feePrecision` slot (1e18), causing 100% fee on all flash loans and bricking the protocol** | **INV-3, INV-7** | ✅ verify with PoC |
| **H-6** | **High** | **Storage layout collision: V1→V2 upgrade shifts `s_currentlyFlashLoaning` mapping to V1's `s_flashLoanFee` slot, orphaning the real flash-loaning state at N+4. Mid-loan tokens cannot be repaid. New flash loan state corrupts the slot.** | **INV-4** | ✅ verify with PoC |
| **M-1** | **Medium** | **`updateFlashLoanFee` has no lower bound — owner can set fee to 0, halting all LP yield instantly with no timelock** | **INV-7** | ✅ verify |
| **M-2** | **Medium** | **All admin functions (upgrade, setAllowedToken, updateFlashLoanFee) have no timelock — instant unilateral action by owner** | **INV-5, INV-6** | ✅ centralization risk |
| INFO-01 | Info | Unused custom error `ThunderLoan__ExhangeRateCanOnlyIncrease` | - | ✅ existing |
