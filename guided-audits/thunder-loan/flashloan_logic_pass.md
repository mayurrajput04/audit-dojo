# Flash Loan Logic & Reentrancy Pass — Thunder Loan

> Day 18 scope: `flashloan()`, `repay()`, the `executeOperation` callback, `AssetToken.updateExchangeRate` / `transferUnderlyingTo` ordering.
> Cross-ref invariants: INV-2 (balance), INV-3 (fee calc), INV-4 (currentlyFlashLoaning flag), INV-8 (LP redemption).
> Rule of the day: no vague findings. Name the re-entered function, the stale state, and the broken invariant.

---

## 1. Flash Loan Execution Trace
<!-- Line-by-line execution order of flashloan() (L180-L217).
     For EACH line mark:
       - [STATE] what storage is committed at this point
       - [EXT]   does control leave ThunderLoan here? to whom?
       - [CHECK] what has NOT been verified yet -->

| # | src line | What executes | State committed so far | Control leaves? | Not-yet-checked |
|---|----------|---------------|------------------------|-----------------|-----------------|
| 1 | L181 | `assetToken = s_tokenToAssetToken[token]` | — | no | — |
| 2 | L182 | `startingBalance = IERC20(token).balanceOf(address(assetToken))`  **snapshots vault balance ONCE** (jar = e.g. 1000) | — | no | this snapshot goes stale the instant anything moves tokens |
| 3 | L184-186 | `if (amount > startingBalance) revert` --> liquidity check | — | no | — |
| 4 | L188-190 | `if (!receiverAddress.isContract()) revert` | — | no | — |
| 5 | L192 | `fee = getCalculatedFee(token, amount)` | — | no | fee value uses oracle (see H-04) |
| 6 | **L194** | `assetToken.updateExchangeRate(fee)` — **rate bumped UP**; jar now *promises* more coins than it holds | `s_exchangeRate` ↑ (inflated) | no | **fee is NOT in the vault yet** — promise is unbacked |
| 7 | L196 | `emit FlashLoan(...)` | — | no | — |
| 8 | **L198** | `s_currentlyFlashLoaning[token] = true` | flag = true | no | flag never re-checked at top of flashloan() → loans can nest |
| 9 | **L199** | `assetToken.transferUnderlyingTo(receiverAddress, amount)` — **loan sent OUT**, jar shrinks (1000 → 500) | tokens gone | no | nothing checked; INV-8 now violated *by design* (temporary) |
| 10 | **L201** | `receiverAddress.functionCall(...executeOperation...)` | rate already inflated (L194), loan already gone (L199), flag = true | **YES → attacker code runs** | **repay check (L212) has NOT run.** Attacker can re-enter `redeem`/`deposit`/`flashloan` here |
| 11 | L212 | `endingBalance = token.balanceOf(address(assetToken))` — read FRESH | — | no | compares fresh balance to the STALE L182 snapshot |
| 12 | L213-214 | `if (endingBalance < startingBalance + fee) revert ThunderLoan__NotPaidBack` | — | no | **only checks `≥ 1005`. Blind to any redeem the attacker did in the callback** |
| 13 | L216 | `s_currentlyFlashLoaning[token] = false` | flag = false | no | — |

**Key takeaway (proved by hand):** at L201 the books say each LP share is worth MORE (L194 bump) while the
vault is EMPTIER (L199 drain) and the fee that justifies the bump is NOT yet paid. The L212 check only
verifies the vault hit `startingBalance + fee` — it is blind to whether the attacker also `redeem()`-ed
at the inflated rate during the callback. That gap is the attack surface.

---

## 2. Callback Attack Surface
<!-- What can executeOperation() do while it holds the loaned tokens?
     Can it call back into ThunderLoan: deposit / redeem / flashloan / repay / setAllowedToken?
     What does each see in storage at that moment? -->

---

## 3. Reentrancy Vectors
<!-- Classic / cross-function / cross-token.
     For each: which function is re-entered, which invariant breaks (INV-2/3/4/8), concrete impact. -->

`flashloan()` (L180-186) never checks `s_currentlyFlashLoaning[token]` at the top. The flag is SET at
L198 and READ by `repay()` (L220), but `flashloan()` itself does not guard against re-entry. Combined
with `redeem()`/`deposit()` having no reentrancy guard, this opens three vectors:

### V1 --> Classic / cross-function reentrancy (→ H-7)
- **Re-entered:** `redeem()` from inside `executeOperation` (L201 callback).
- **Stale state:** `s_exchangeRate` inflated at L194 before the fee is in the vault.
- **Invariant broken:** INV-8. Attacker redeems at the inflated rate and pulls out underlying that
  belongs to other LPs' principal. The L212 check (stale L182 snapshot) is blind to the redeem.
- **Impact:** direct loss of other LPs' funds, per pool.

### V2 --> Same-token nested flashloan (→ H-8, state-machine break)
- **Re-entered:** `flashloan()` for the SAME token from inside the callback.
- **Mechanism:** the inner loan reaches L216 and sets `s_currentlyFlashLoaning[token] = false` while
  the OUTER loan is still live. The flag is now false mid-outer-loan.
- **Invariant broken:** INV-4 (flag must be true for the entire duration of a single loan).
- **Concrete impact:** when the outer borrower calls `repay()` (L220), the flag is already false →
  reverts with `ThunderLoan__NotCurrentlyFlashLoaning()` → outer repay bricked → whole outer tx
  reverts. By itself this is a self-bricking DoS, but more importantly it corrupts the state machine
  that both `repay()` and the H-7 trick rely on.

### V3 --> Cross-token nesting amplifies H-7 (→ the Critical)
- Nothing prevents opening a flashloan for token B while token A's loan is still open (different
  mapping key, no global lock). The attacker holds borrowed A and B at once, with BOTH L194 rate
  inflations live.
- Nothing stops the H-7 redeem trick from being run on BOTH tokens in the same nested transaction.
- **Impact:** the per-pool H-7 theft can be STACKED across every allowed token atomically in one tx.
  This is what pushes the combined severity from High to Critical.

---

# Flash Loan Logic & Reentrancy Pass — Thunder Loan

> Day 18 — scope: `flashloan()`, `repay()`, the `executeOperation` callback, `AssetToken.updateExchangeRate` / `transferUnderlyingTo` ordering.
> Cross-ref invariants: INV-2 (balance), INV-3 (fee calc), INV-4 (currentlyFlashLoaning flag), INV-8 (LP redemption).
> Rule of the day: no vague findings. Name the re-entered function, the stale state, and the broken invariant.

---

## 1. Flash Loan Execution Trace
<!-- Line-by-line execution order of flashloan() (L180-L217).
     For EACH line mark:
       - [STATE] what storage is committed at this point
       - [EXT]   does control leave ThunderLoan here? to whom?
       - [CHECK] what has NOT been verified yet -->

| # | src line | What executes | State committed so far | Control leaves? | Not-yet-checked |
|---|----------|---------------|------------------------|-----------------|-----------------|
| 1 | L181 | `assetToken = s_tokenToAssetToken[token]` | — | no | — |
| 2 | L182 | `startingBalance = IERC20(token).balanceOf(address(assetToken))` — **snapshots vault balance ONCE** (jar = e.g. 1000) | — | no | this snapshot goes stale the instant anything moves tokens |
| 3 | L184-186 | `if (amount > startingBalance) revert` — liquidity check | — | no | — |
| 4 | L188-190 | `if (!receiverAddress.isContract()) revert` | — | no | — |
| 5 | L192 | `fee = getCalculatedFee(token, amount)` | — | no | fee value uses oracle (see H-04) |
| 6 | **L194** | `assetToken.updateExchangeRate(fee)` — **rate bumped UP**; jar now *promises* more coins than it holds | `s_exchangeRate` ↑ (inflated) | no | **fee is NOT in the vault yet** — promise is unbacked |
| 7 | L196 | `emit FlashLoan(...)` | — | no | — |
| 8 | **L198** | `s_currentlyFlashLoaning[token] = true` | flag = true | no | flag never re-checked at top of flashloan() → loans can nest |
| 9 | **L199** | `assetToken.transferUnderlyingTo(receiverAddress, amount)` — **loan sent OUT**, jar shrinks (1000 → 500) | tokens gone | no | nothing checked; INV-8 now violated *by design* (temporary) |
| 10 | **L201** | `receiverAddress.functionCall(...executeOperation...)` | rate already inflated (L194), loan already gone (L199), flag = true | **YES → attacker code runs** | **repay check (L212) has NOT run.** Attacker can re-enter `redeem`/`deposit`/`flashloan` here |
| 11 | L212 | `endingBalance = token.balanceOf(address(assetToken))` — read FRESH | — | no | compares fresh balance to the STALE L182 snapshot |
| 12 | L213-214 | `if (endingBalance < startingBalance + fee) revert ThunderLoan__NotPaidBack` | — | no | **only checks `≥ 1005`. Blind to any redeem the attacker did in the callback** |
| 13 | L216 | `s_currentlyFlashLoaning[token] = false` | flag = false | no | — |

**Key takeaway (proved by hand):** at L201 the books say each LP share is worth MORE (L194 bump) while the
vault is EMPTIER (L199 drain) and the fee that justifies the bump is NOT yet paid. The L212 check only
verifies the vault hit `startingBalance + fee` — it is blind to whether the attacker also `redeem()`-ed
at the inflated rate during the callback. That gap is the attack surface.

---

## 2. Callback Attack Surface

At L201, `executeOperation` is **arbitrary attacker code** running while: (a) it holds the loaned
tokens, (b) `s_exchangeRate` is already inflated (L194), (c) `s_currentlyFlashLoaning[token] == true`,
and (d) the repay check (L212) has NOT run. Every external ThunderLoan function is reachable from here.
What each one sees / allows at that moment:

| Function called in callback | Guarded against re-entry? | What it sees / what it enables |
|----------------------------|---------------------------|--------------------------------|
| `redeem()` (L161) | ❌ No flag check, no `nonReentrant` | Reads the **inflated** rate (L170). Attacker-LP cashes out at inflated rate → pulls other LPs' principal. **→ H-7** |
| `deposit()` (L147) | ❌ No flag check | Mints shares (L150) using current rate; also bumps rate again (L153-154, the H-3 phantom-fee path). Can be paired with redeem to game share price. |
| `flashloan()` (L180) | ❌ **No `s_currentlyFlashLoaning` check at top** | Allows nesting. Same-token nest flips the flag false early at L216 (**→ H-8**). Different-token nest holds two loans + two rate inflations at once (**→ cross-token amplification of H-7**). |
| `repay()` (L219) | flag-gated (sound), but `public` + no debt tracking | Anyone can repay; can be called multiple times; only the final L212 balance matters. The flag it reads is corruptible (see H-8). |
| `setAllowedToken()` (L227) | `onlyOwner` | Not attacker-reachable (out of scope for this vector). |

**Bottom line:** the callback can re-enter `redeem`, `deposit`, and `flashloan` with no guard, against
stale/inflated state. That is the entire reentrancy attack surface — vectors enumerated in Section 3.

---

## 3. Reentrancy Vectors
<!-- Classic / cross-function / cross-token.
     For each: which function is re-entered, which invariant breaks (INV-2/3/4/8), concrete impact. -->

`flashloan()` (L180-186) never checks `s_currentlyFlashLoaning[token]` at the top. The flag is SET at
L198 and READ by `repay()` (L220), but `flashloan()` itself does not guard against re-entry. Combined
with `redeem()`/`deposit()` having no reentrancy guard, this opens three vectors:

### V1 — Classic / cross-function reentrancy (→ H-7)
- **Re-entered:** `redeem()` from inside `executeOperation` (L201 callback).
- **Stale state:** `s_exchangeRate` inflated at L194 before the fee is in the vault.
- **Invariant broken:** INV-8. Attacker redeems at the inflated rate and pulls out underlying that
  belongs to other LPs' principal. The L212 check (stale L182 snapshot) is blind to the redeem.
- **Impact:** direct loss of other LPs' funds, per pool.

### V2 — Same-token nested flashloan (→ H-8, state-machine break)
- **Re-entered:** `flashloan()` for the SAME token from inside the callback.
- **Mechanism:** the inner loan reaches L216 and sets `s_currentlyFlashLoaning[token] = false` while
  the OUTER loan is still live. The flag is now false mid-outer-loan.
- **Invariant broken:** INV-4 (flag must be true for the entire duration of a single loan).
- **Concrete impact:** when the outer borrower calls `repay()` (L220), the flag is already false →
  reverts with `ThunderLoan__NotCurrentlyFlashLoaning()` → outer repay bricked → whole outer tx
  reverts. By itself this is a self-bricking DoS, but more importantly it corrupts the state machine
  that both `repay()` and the H-7 trick rely on.

### V3 — Cross-token nesting amplifies H-7 (→ the Critical)
- Nothing prevents opening a flashloan for token B while token A's loan is still open (different
  mapping key, no global lock). The attacker holds borrowed A and B at once, with BOTH L194 rate
  inflations live.
- Nothing stops the H-7 redeem trick from being run on BOTH tokens in the same nested transaction.
- **Impact:** the per-pool H-7 theft can be STACKED across every allowed token atomically in one tx.
  This is what pushes the combined severity from High to Critical.

---

## 4. Repay Flow Analysis
<!-- repay() L219-L225. Who can call it? public vs external? Multiple times? Without a flash loan?
     Can token.balanceOf(assetToken) be gamed during the callback? -->

`repay()` is L219-225:
```solidity
function repay(IERC20 token, uint256 amount) public {
    if (!s_currentlyFlashLoaning[token]) {
        revert ThunderLoan__NotCurrentlyFlashLoaning();
    }
    AssetToken assetToken = s_tokenToAssetToken[IERC20(token)];
    token.safeTransferFrom(msg.sender, address(assetToken), amount);
}
```

1. **Who can call it?** `public`, no `onlyX`, no access control. **Anyone** can call `repay()` and push
   tokens into the AssetToken on a borrower's behalf. The protocol only cares about the final balance,
   not who paid. Not a bug by itself (common flash-loan pattern), but the contract trusts the sender.

2. **Multiple times?** Yes. There is no debt tracking, no decrement, no "amount remaining." `repay()`
   can be called any number of times with any amounts; the protocol only enforces that the L212 check
   (`endingBalance >= startingBalance + fee`) holds when the outer `flashloan()` returns. Paying in
   one call or many is identical from the protocol's view.

3. **Repay without a flash loan?** **No — it is blocked.** The guard `if (!s_currentlyFlashLoaning[token])
   revert ThunderLoan__NotCurrentlyFlashLoaning()` reverts when no loan is active (flag is false).
   IMPORTANT NUANCE: the guard itself is *sound*. The danger is that the FLAG it reads can be made
   stale — see H-8, where a nested same-token loan flips the flag to false early (L216) while the outer
   loan is still live, causing the LEGITIMATE outer borrower's `repay()` to wrongly revert. So the
   problem is the corruptible state (INV-4), not a missing check in `repay()`.

4. **Can `token.balanceOf(address(assetToken))` be gamed during the callback?** Yes — this is the root
   of H-7. The L212 repayment check reads a FRESH balance and compares it to the STALE L182 snapshot
   (`startingBalance + fee`). It does not detect that, during the callback, the attacker also `redeem`-ed
   shares at the inflated rate and pulled underlying out. So the balance check can be "satisfied" while
   the vault has actually been drained of other LPs' principal.

---

## 5. Findings / Hypotheses Table

| ID | Severity (guess) | Function re-entered / abused | Stale state | Invariant broken | Verify in pass 2? |
|----|------------------|-----------------------------|-------------|------------------|-------------------|
| H-7 | High → likely Critical | `redeem()` re-entered from inside `executeOperation` callback (no flashloaning-guard, no reentrancy guard on L161-178) | `s_exchangeRate` — inflated at L194 *before* the fee is actually in the vault | INV-8 (vault balance no longer backs LP claims) | ✅ PoC: deposit → flashloan → inside callback repay loan+fee then `redeem()` at inflated rate → assert other LPs left short |
| H-8 | Medium (DoS alone) → Critical when combined with H-7 across tokens | `flashloan()` re-entered (no `s_currentlyFlashLoaning` check at L180-186); nested loan flips flag early at L216 | `s_currentlyFlashLoaning[token]` — set false by inner loan while outer loan still live | INV-4 (flag must hold for full single-loan duration) | ✅ PoC: flashloan → inside callback flashloan same token → outer `repay()` reverts `ThunderLoan__NotCurrentlyFlashLoaning()` |

### H-7 — plain-language statement (derived, not copied)

The piggy-bank version we proved by hand:

- Jar holds **1000** coins. Attacker-LP is owed **100**, other LPs are owed **900**. Balanced.
- Flashloan starts. **L194** bumps the exchange rate UP *before* the fee is real, so the attacker's
  shares now claim **~105** instead of 100.
- `redeem()` (L161) has **no guard** stopping it during a flashloan, so the attacker cashes out
  *inside the callback* at the inflated rate and walks away with **105**.
- Jar now holds **895**. Other LPs are still owed **900**. → **They are short 5 coins they can never
  redeem.** The extra 5 came from *their* deposited principal, not from any fee (the fee is only ~5
  total and isn't even guaranteed in the vault at that instant).
- The L212 repayment check is fooled: it only verifies the vault ≥ `startingBalance + fee` (the stale
  L182 snapshot), so as long as the loan is repaid it passes — completely blind to the redeem.

**Why it matters:** direct loss of other LPs' funds, triggerable by any user (no privileged role),
with no large capital requirement. That is the profile of a Critical, pending PoC confirmation.


## 5. Findings / Hypotheses Table

| ID | Severity (guess) | Function re-entered / abused | Stale state | Invariant broken | Verify in pass 2? |
|----|------------------|-----------------------------|-------------|------------------|-------------------|
| H-7 | High → likely Critical | `redeem()` re-entered from inside `executeOperation` callback (no flashloaning-guard, no reentrancy guard on L161-178) | `s_exchangeRate` — inflated at L194 *before* the fee is actually in the vault | INV-8 (vault balance no longer backs LP claims) | ✅ PoC: deposit → flashloan → inside callback repay loan+fee then `redeem()` at inflated rate → assert other LPs left short |
| H-8 | Medium (DoS alone) → Critical when combined with H-7 across tokens | `flashloan()` re-entered (no `s_currentlyFlashLoaning` check at L180-186); nested loan flips flag early at L216 | `s_currentlyFlashLoaning[token]`  set false by inner loan while outer loan still live | INV-4 (flag must hold for full single-loan duration) | ✅ PoC: flashloan → inside callback flashloan same token → outer `repay()` reverts `ThunderLoan__NotCurrentlyFlashLoaning()` |



### H-7 — plain-language statement (derived, not copied)

The piggy-bank version we proved by hand:

- Jar holds **1000** coins. Attacker-LP is owed **100**, other LPs are owed **900**. Balanced.
- Flashloan starts. **L194** bumps the exchange rate UP *before* the fee is real, so the attacker's
  shares now claim **~105** instead of 100.
- `redeem()` (L161) has **no guard** stopping it during a flashloan, so the attacker cashes out
  *inside the callback* at the inflated rate and walks away with **105**.
- Jar now holds **895**. Other LPs are still owed **900**. → **They are short 5 coins they can never
  redeem.** The extra 5 came from *their* deposited principal, not from any fee (the fee is only ~5
  total and isn't even guaranteed in the vault at that instant).
- The L212 repayment check is fooled: it only verifies the vault ≥ `startingBalance + fee` (the stale
  L182 snapshot), so as long as the loan is repaid it passes — completely blind to the redeem.

**Why it matters:** direct loss of other LPs' funds, triggerable by any user (no privileged role),
with no large capital requirement. That is the profile of a Critical, pending PoC confirmation.
