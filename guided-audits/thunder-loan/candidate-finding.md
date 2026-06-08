# Candidate Findings — Thunder Loan

## [H-1] `setAllowedToken(token, false)` orphans LP funds

**Location:** `src/protocol/ThunderLoan.sol#L237-L243`

**Description:**
When the owner disallows a previously-allowed token, `setAllowedToken` calls
`delete s_tokenToAssetToken[token]`, which sets the mapping entry to `address(0)`.
The AssetToken contract itself is NOT destroyed and still holds the LP's
underlying tokens. However, all redemption paths in `ThunderLoan` look up the
AssetToken via `s_tokenToAssetToken[token]`, which now returns `address(0)`,
bricking redemption.

**Impact:** LP funds become inaccessible through normal protocol entry points
after a token is disallowed. Requires owner re-allow (which `revert`s with
`ThunderLoan__AlreadyAllowed` if mapping logic isn't carefully reset).

**Severity (tentative):** High — direct loss of access to user funds via single
admin call. Centralization risk borderline → could be Medium depending on
trust model.

**Status:** Hypothesis from mental-model phase. Verify in pass 2 with PoC
attempting redeem after disallow.


## [INFO-01] Unused custom error `ThunderLoan__ExhangeRateCanOnlyIncrease`

**Location:**
- `src/protocol/ThunderLoan.sol#L83`
- `src/upgradedProtocol/ThunderLoanUpgraded.sol#L83`

**Description:**
The error `ThunderLoan__ExhangeRateCanOnlyIncrease()` is declared in both
`ThunderLoan.sol` and `ThunderLoanUpgraded.sol`, but is never reverted anywhere
in scope. The actual exchange-rate-monotonicity check is enforced in
`AssetToken.sol#L91` via a *different* error: `AssetToken__ExhangeRateCanOnlyIncrease`.

**Impact:** Informational. Dead code. No security impact directly, but:
- Suggests incomplete refactor — possibly the check was intended at the ThunderLoan
  level (e.g., as a safety net) and never wired up.
- Typo in error name ("Exhange" instead of "Exchange") is propagated across files.

**Recommendation:** Remove the unused error, OR if the intent was to enforce the
invariant at the ThunderLoan layer, add the missing check. Also fix the typo.

**Status:** Hypothesis — verify in pass 2 whether removal vs. wiring-up is correct.

