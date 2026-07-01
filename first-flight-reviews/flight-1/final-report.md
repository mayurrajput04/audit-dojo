# Hawk High Audit Report

**Auditor:** Gintoki Sakata
**Contest:** CodeHawks First Flight - Hawk High
**Repo:** `CodeHawks-Contests/2025-05-hawk-high`
**Commit:** `3a72519`
**Contracts in scope:** `src/LevelOne.sol`, `src/LevelTwo.sol`
**Review window:** 21 Jun – 28 Jun 2026

---

## Protocol Summary

Hawk High is an upgradeable school simulation protocol built with Solidity using OpenZeppelin's UUPSUpgradeable library. The system operates in 4-week sessions where users pay tuition in USDC to enroll as students, while designated teachers assign weekly performance reviews. At the conclusion of a session, the Principal can trigger a system upgrade and distribute pooled tuition fees, routing 5% to themselves and 35% to teachers. Students who maintain a score above the cutoff set by the Principal at session start are intended to graduate and advance to LevelTwo as part of the upgrade.


## Disclaimer

The auditor makes best-effort attempts to identify vulnerabilities within the review window and holds no responsibility for issues discovered outside it. This report is not an endorsement of the underlying protocol or business.

## Risk Classification

|                        | Impact: High | Impact: Medium | Impact: Low |
|------------------------|--------------|----------------|-------------|
| **Likelihood: High**   | H            | H/M            | M           |
| **Likelihood: Medium** | H/M          | M              | M/L         |
| **Likelihood: Low**    | M            | M/L            | L           |

Severity uses the CodeHawks severity matrix.

## Audit Details

### Scope

```
./src/
├── LevelOne.sol
└── LevelTwo.sol
```

### Roles

- **Principal** : Sole `onlyPrincipal` holder. Adds/removes teachers, expels students, starts session, calls `graduateAndUpgrade()`.
- **Teacher** : Added by principal pre-session. Calls `giveReview(student, bool)`.
- **Student** : Pays `schoolFees` in USDC via `enroll()` pre-session. Starts with score `100`.

### Issues Found

| ID   | Title                                                                                                | Severity |
|------|------------------------------------------------------------------------------------------------------|----------|
| H-01 | Storage layout incompatibility corrupts LevelTwo state after upgrade                                 | High     |
| H-02 | `graduateAndUpgrade()` never performs the actual UUPS upgrade                                        | High     |
| H-03 | Teacher wage pays 35% of bursary to each teacher instead of splitting 35% among all teachers         | High     |
| M-01 | `graduateAndUpgrade()` can be called before the session ends                                         | Medium   |
| M-02 | `graduateAndUpgrade()` does not require students to complete the required number of reviews         | Medium   |
| M-03 | `graduateAndUpgrade()` does not filter students below `cutOffScore`                                  | Medium   |
| M-04 | `reviewCount` is never incremented; per-student review cap is unenforced                             | Medium   |
| M-05 | Expelled student fees remain in `bursary` and inflate later wage calculations                        | Medium   |
| L-01 | Principal can remove teachers mid-session                                                            | Low      |
| L-02 | `startSession()` accepts arbitrary, unvalidated cutoff scores                                        | Low      |
| L-03 | `giveReview()` is not bounded to the active session window                                           | Low      |
| L-04 | `Graduated` event is declared but never emitted                                                      | Low      |
| L-05 | Off-by-one review limit permits five reviews once `reviewCount` is fixed                             | Low      |
| I-01 | `expel()` uses raw `revert()` instead of a named custom error                                        | Info     |
| I-02 | `startSession()` does not require at least one teacher or student                                    | Info     |

**Totals:** 3 High · 5 Medium · 5 Low · 2 Info · **15 total**

---

# Findings

## High

### [H-01] Storage layout incompatibility corrupts LevelTwo state after upgrade

**Summary.** `LevelTwo` removes three storage variables that exist in `LevelOne` (`schoolFees`, `reviewCount`, `lastReviewTime`) without preserving layout compatibility. After a real upgrade, every slot from index 1 onward is shifted, so `LevelTwo` reads stale, wrong-typed data.

**Vulnerability Details.**

`LevelOne` layout:

| Slot | Variable                | Type                          |
|------|-------------------------|-------------------------------|
| 0    | `principal` + `inSession` | address + bool (packed)     |
| 1    | `schoolFees`            | uint256                       |
| 2    | `sessionEnd`            | uint256                       |
| 3    | `bursary`               | uint256                       |
| 4    | `cutOffScore`           | uint256                       |
| 5–9  | mappings                | ...                           |
| 10   | `listOfStudents`        | address[]                     |
| 11   | `listOfTeachers`        | address[]                     |
| 12   | `usdc`                  | IERC20                        |

`LevelTwo` layout:

| Slot | Variable                | Type                          |
|------|-------------------------|-------------------------------|
| 0    | `principal` + `inSession` | address + bool (packed)     |
| 1    | `sessionEnd`            | uint256                       |
| 2    | `bursary`               | uint256                       |
| 3    | `cutOffScore`           | uint256                       |
| 4–6  | mappings                | ...                           |
| 7    | `listOfStudents`        | address[]                     |
| 8    | `listOfTeachers`        | address[]                     |
| 9    | `usdc`                  | IERC20                        |

After upgrade, `LevelTwo.sessionEnd` reads slot 1 (`schoolFees`), `LevelTwo.bursary` reads slot 2 (`sessionEnd`), `LevelTwo.cutOffScore` reads slot 3 (`bursary`), and every mapping/array seed is off by 1–3 slots.

**Impact.** Permanent state corruption after upgrade. `sessionEnd` becomes a fees amount, `bursary` becomes a timestamp, mappings/arrays point to wrong slots, and the `usdc` address slot is unrelated bytes. Any post-graduation logic acting on these values will misbehave. Only exploitable once H-02 is fixed — but the fix for H-02 is trivial, so this must be fixed in the same release.

**Proof of Concept.**

Because `graduateAndUpgrade()` never actually upgrades the proxy (see H-02), the PoC simulates the upgrade with `vm.etch` and reads through the `LevelTwo` interface.

```solidity
// test/poc/H01_StorageCollision.t.sol
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
    address alice; address bob;

    uint256 schoolFeesBefore; uint256 sessionEndBefore; uint256 bursaryBefore;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);
        usdc = deployBot.getUSDC();
        principal = deployBot.principal();

        alice = makeAddr("teacher_alice");
        bob = makeAddr("teacher_bob");

        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        _enrollStudents();

        vm.prank(principal);
        levelOneProxy.startSession(70);
    }

    function _enrollStudents() internal {
        address[3] memory students = [
            makeAddr("student_clara"),
            makeAddr("student_dan"),
            makeAddr("student_ella")
        ];
        for (uint256 i = 0; i < 3; i++) {
            uint256 fees = levelOneProxy.getSchoolFeesCost();
            vm.startPrank(students[i]);
            usdc.mint(students[i], fees);
            usdc.approve(address(levelOneProxy), fees);
            levelOneProxy.enroll();
            vm.stopPrank();
        }
    }

    function test_storageCollisionAfterUpgrade() public {
        schoolFeesBefore = levelOneProxy.getSchoolFeesCost();
        sessionEndBefore = levelOneProxy.getSessionEnd();
        bursaryBefore = levelOneProxy.bursary();

        console2.log("schoolFeesBefore:", schoolFeesBefore);
        console2.log("sessionEndBefore:", sessionEndBefore);
        console2.log("bursaryBefore:", bursaryBefore);

        levelTwoImplementation = new LevelTwo();
        vm.etch(proxyAddress, address(levelTwoImplementation).code);

        LevelTwo levelTwoProxy = LevelTwo(proxyAddress);
        console2.log("LevelTwo.sessionEnd():", levelTwoProxy.sessionEnd());
        console2.log("LevelTwo.bursary():", levelTwoProxy.bursary());
        console2.log("LevelTwo.cutOffScore():", levelTwoProxy.cutOffScore());

        // sessionEnd (slot 1 in L2) now reads schoolFees (slot 1 in L1) — identical byte pattern
        assertEq(levelTwoProxy.sessionEnd(), schoolFeesBefore);
        // bursary (slot 2 in L2) now reads sessionEnd (slot 2 in L1)
        assertEq(levelTwoProxy.bursary(), sessionEndBefore);
        // cutOffScore (slot 3 in L2) now reads bursary (slot 3 in L1)
        assertEq(levelTwoProxy.cutOffScore(), bursaryBefore);
    }
}
```

**Output:**

```text
Ran 1 test for test/poc/H01_StorageCollision.t.sol:H01_StorageCollisionPoC
[PASS] test_storageCollisionAfterUpgrade() (gas: 600606)
Logs:
  schoolFeesBefore:      5000000000000000000000
  sessionEndBefore:      2419201
  bursaryBefore:         15000000000000000000000
  LevelTwo.sessionEnd():   5000000000000000000000   ← reads L1.schoolFees
  LevelTwo.bursary():      2419201                  ← reads L1.sessionEnd
  LevelTwo.cutOffScore():  15000000000000000000000  ← reads L1.bursary

Suite result: ok. 1 passed; 0 failed; 0 skipped
```

The assertions use `assertEq` (not `assertNotEq`), which makes the corruption *provable slot-for-slot*, not merely "different from expected".

**Recommended Mitigation.**

1. Never remove or reorder storage variables between upgradeable versions. Keep deprecated slots as reserved fields.
2. Add a storage gap to `LevelOne`:
   ```solidity
   uint256[50] private __gap;
   ```
3. In `LevelTwo`, declare every `LevelOne` variable in the same order (rename unused ones to `_deprecated_X`) before adding new state.
4. Fix H-02 in the same release; H-01 is dormant without it.

---

### [H-02] `graduateAndUpgrade()` never performs the actual UUPS upgrade

**Summary.** `graduateAndUpgrade()` calls the internal `_authorizeUpgrade()` hook directly. The hook is only an authorization guard; it does not write to the ERC-1967 implementation slot. The proxy therefore keeps executing `LevelOne` after graduation "succeeds".

**Vulnerability Details.**

At `LevelOne.sol:305`, inside `graduateAndUpgrade()`:

```solidity
_authorizeUpgrade(_levelTwo);
```

`_authorizeUpgrade` is defined at `LevelOne.sol:314`:

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyPrincipal {}
```

This hook does not delegate-call, does not write the implementation slot, and does not execute `LevelTwo.graduate()`. The correct UUPS path is `upgradeToAndCall(newImplementation, data)`, which `graduateAndUpgrade()` never invokes. The `bytes memory` second parameter of `graduateAndUpgrade()` is unnamed and unused, further confirming the intended calldata pathway was left unimplemented.

**Impact.** The graduation flow completes and pays wages, but the proxy stays on `LevelOne` forever. `LevelTwo.graduate()`, `LevelTwo` wage constants (`TEACHER_WAGE_L2 = 40`), and the reinitializer are unreachable through the intended public path. Off-chain systems will see a "successful" tx that produced no upgrade.

**Proof of Concept.**

```solidity
// test/poc/H02_NoActualUpgrade.t.sol
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
    address alice; address bob; address clara; address dan;

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function _getImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);
        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();
        levelOneImplementationAddress = deployBot.getImplementationAddress();

        alice = makeAddr("teacher_alice"); bob = makeAddr("teacher_bob");
        clara = makeAddr("student_clara"); dan = makeAddr("student_dan");
        usdc.mint(clara, schoolFees); usdc.mint(dan, schoolFees);
    }

    function test_graduateAndUpgrade_doesNotChangeProxyImplementation() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        vm.startPrank(clara); usdc.approve(address(levelOneProxy), schoolFees); levelOneProxy.enroll(); vm.stopPrank();
        vm.startPrank(dan);   usdc.approve(address(levelOneProxy), schoolFees); levelOneProxy.enroll(); vm.stopPrank();

        vm.prank(principal);
        levelOneProxy.startSession(70);

        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        address implBefore = _getImplementation(proxyAddress);
        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        address implAfter = _getImplementation(proxyAddress);

        assertEq(implBefore, levelOneImplementationAddress, "proxy did not start at LevelOne");
        assertEq(implAfter,  implBefore,                    "implementation slot changed but shouldn't have");
        assertNotEq(implAfter, levelTwoImplementationAddress, "proxy erroneously points to LevelTwo");
    }
}
```

**Output:**

```text
Ran 1 test for test/poc/H02_NoActualUpgrade.t.sol:H02_NoActualUpgradePoC
[PASS] test_graduateAndUpgrade_doesNotChangeProxyImplementation() (gas: 1063927)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

**Recommended Mitigation.** Replace the direct hook call with the real UUPS entry point and use the `bytes memory` parameter:

```solidity
function graduateAndUpgrade(address _levelTwo, bytes memory data) public onlyPrincipal {
    if (_levelTwo == address(0)) revert HH__ZeroAddress();
    // ... preconditions (see M-01/M-02/M-03) ...
    // ... wage payouts ...
    upgradeToAndCall(_levelTwo, data);   // e.g. data = abi.encodeCall(LevelTwo.graduate, ())
    emit Graduated(_levelTwo);           // fixes L-04 too
}
```

Add a regression test that asserts `implBefore != implAfter && implAfter == _levelTwo` after graduation. Fix H-01 first so the real upgrade does not corrupt state.

---

### [H-03] Teacher wage pays 35% of bursary to each teacher instead of splitting 35% among all teachers

**Summary.** `payPerTeacher` is computed as `(bursary * 35) / 100` and then paid to *every* teacher in a loop. `totalTeachers` is read but not used to divide the pool. Two teachers → 70% paid out. Three teachers → `graduateAndUpgrade()` reverts on insufficient balance.

**Vulnerability Details.**

`LevelOne.sol:300–309`:

```solidity
uint256 totalTeachers = listOfTeachers.length;
uint256 payPerTeacher = (bursary * TEACHER_WAGE) / PRECISION;   // ← full 35%
uint256 principalPay  = (bursary * PRINCIPAL_WAGE) / PRECISION;

_authorizeUpgrade(_levelTwo);

for (uint256 n = 0; n < totalTeachers; n++) {
    usdc.safeTransfer(listOfTeachers[n], payPerTeacher);         // ← paid in full to each
}
```

`totalTeachers` is captured but never used in the arithmetic. This breaks invariant INV-1 (total teacher payout = 35% of bursary).

**Impact.**

| Teacher count | Teacher payout | Principal payout | Total  | Result                    |
|---------------|----------------|------------------|--------|---------------------------|
| 1             | 35%            | 5%               | 40%    | Coincidentally correct    |
| 2             | 70%            | 5%               | 75%    | Over-pays teachers by 35% |
| 3             | 105%           | 5%               | 110%   | **Reverts** — bursary insufficient, graduation permanently blocked |

**Proof of Concept.**

```solidity
// test/poc/H03_TeacherWagePerTeacher.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DeployLevelOne} from "../../script/DeployLevelOne.s.sol";
import {LevelOne} from "../../src/LevelOne.sol";
import {LevelTwo} from "../../src/LevelTwo.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract H03_TeacherWagePerTeacherPoC is Test {
    DeployLevelOne deployBot;
    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;
    MockUSDC usdc;

    address proxyAddress; address principal; uint256 schoolFees;
    address alice; address bob; address clara; address dan;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);
        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();

        alice = makeAddr("teacher_alice"); bob = makeAddr("teacher_bob");
        clara = makeAddr("student_clara"); dan = makeAddr("student_dan");
        usdc.mint(clara, schoolFees); usdc.mint(dan, schoolFees);
    }

    function test_graduateAndUpgrade_paysEachTeacher35Percent() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        vm.startPrank(clara); usdc.approve(address(levelOneProxy), schoolFees); levelOneProxy.enroll(); vm.stopPrank();
        vm.startPrank(dan);   usdc.approve(address(levelOneProxy), schoolFees); levelOneProxy.enroll(); vm.stopPrank();

        vm.prank(principal);
        levelOneProxy.startSession(70);

        levelTwoImplementation = new LevelTwo();
        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        uint256 bursaryBefore     = usdc.balanceOf(address(levelOneProxy));
        uint256 aliceBefore       = usdc.balanceOf(alice);
        uint256 bobBefore         = usdc.balanceOf(bob);

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(address(levelTwoImplementation), data);

        uint256 aliceDelta = usdc.balanceOf(alice) - aliceBefore;
        uint256 bobDelta   = usdc.balanceOf(bob)   - bobBefore;

        assertEq(aliceDelta, (bursaryBefore * 35) / 100, "alice did not receive full 35%");
        assertEq(bobDelta,   (bursaryBefore * 35) / 100, "bob did not receive full 35%");
        assertEq(aliceDelta + bobDelta, (bursaryBefore * 70) / 100, "total should be 70%, invariant broken");
    }
}
```

**Output:**

```text
Ran 1 test for test/poc/H03_TeacherWagePerTeacher.t.sol:H03_TeacherWagePerTeacherPoC
[PASS] test_graduateAndUpgrade_paysEachTeacher35Percent() (gas: 1046247)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

The 3-teacher revert case follows from the same arithmetic (`3 × 35% > 100%`) and is not separately tested; the same PoC harness with a third `addTeacher` call reverts on `safeTransfer`.

**Recommended Mitigation.**

```solidity
uint256 teacherPool  = (bursary * TEACHER_WAGE) / PRECISION;
uint256 payPerTeacher = totalTeachers > 0 ? teacherPool / totalTeachers : 0;
```

Handle `totalTeachers == 0` explicitly. Consider forwarding rounding dust to the principal or leaving it in the bursary.

---

## Medium

### [M-01] `graduateAndUpgrade()` can be called before the session ends

**Details.** `startSession()` at `LevelOne.sol:269–274` sets `sessionEnd = block.timestamp + 4 weeks`. `graduateAndUpgrade()` at `LevelOne.sol:295–312` is guarded only by `onlyPrincipal` — no `block.timestamp >= sessionEnd`, no `inSession` check, no session-close on exit.

**Impact.** Principal can graduate immediately after `startSession()`, bypassing the 4-week review window and triggering wage payout early. Breaks INV-3.

**Recommended Mitigation.**

```solidity
if (!inSession)                     revert HH__NotInSession();
if (block.timestamp < sessionEnd)   revert HH__SessionNotOver();
// ... existing logic ...
inSession = false;
```

---

### [M-02] `graduateAndUpgrade()` does not require students to complete the required number of reviews

**Details.** `graduateAndUpgrade()` never iterates `listOfStudents` and never reads `reviewCount[student]`. Independent of M-04: even if the counter were correctly incremented, this check would still be absent. Both fixes are required.

**Impact.** Students can be graduated with zero reviews. Breaks INV-4.

**Recommended Mitigation.** Inside `graduateAndUpgrade()`:

```solidity
for (uint256 i = 0; i < listOfStudents.length; i++) {
    require(reviewCount[listOfStudents[i]] >= REQUIRED_REVIEWS, "student not fully reviewed");
}
```

Pair with M-04 so the counter actually reflects reality.

---

### [M-03] `graduateAndUpgrade()` does not filter students below `cutOffScore`

**Details.** `cutOffScore` is stored at `startSession()` but never compared against `studentScore[student]` inside `graduateAndUpgrade()`. Failing students remain in `listOfStudents`.

**Impact.** Non-qualified students are carried into `LevelTwo` (once H-01/H-02 are fixed). Breaks INV-5.

**Recommended Mitigation.** In `graduateAndUpgrade()`, walk `listOfStudents` and either skip or separately mark students with `studentScore[student] < cutOffScore`. Emit distinct events for graduated vs. failed students.

---

### [M-04] `reviewCount` is never incremented; per-student review cap is unenforced

**Details.** `giveReview()` at `LevelOne.sol:277–292`:

```solidity
require(reviewCount[_student] < 5, "Student review count exceeded!!!");
```

The counter is read but never written. Only rate limit is the 1-week `lastReviewTime` gate, which is trivially bypassable via `vm.warp` / block.timestamp progress.

**Impact.** Teachers can grind bad reviews once per week indefinitely, pushing a student's score to zero. The system cannot prove any student was reviewed. Breaks INV-4 and INV-6.

**Recommended Mitigation.**

```solidity
require(reviewCount[_student] < 4, "Student review count exceeded");   // fixes L-05 too
// ...
reviewCount[_student] += 1;
```

---

### [M-05] Expelled student fees remain in `bursary` and inflate later wage calculations

**Details.**

- `enroll()` increases `bursary` by `schoolFees`.
- `expel()` at `LevelOne.sol:243–266` removes the student from `listOfStudents` and clears `isStudent[_student]` but does **not** decrement `bursary` and does **not** refund the student.
- `graduateAndUpgrade()` bases teacher and principal payouts on the unchanged `bursary`.

**Impact.** Fees from expelled (thus inactive) students are redistributed to teachers/principal. Creates a financial incentive to expel before graduation. Breaks INV-7. Combines multiplicatively with H-03.

**Recommended Mitigation.** Choose an explicit policy:

- **Refund**: `usdc.safeTransfer(_student, schoolFees); bursary -= schoolFees;`
- **Forfeit**: keep the fees but move them to a `forfeitedFees` bucket excluded from wage math.

Emit an event indicating which was applied.

---

## Low

### [L-01] Principal can remove teachers mid-session

**Details.** `removeTeacher()` at `LevelOne.sol:220–240` lacks `notYetInSession`. A teacher's reviews remain in `studentScore`, but the teacher is removed from `listOfTeachers` and skipped in wage payout.

**Impact.** Wage confiscation by principal while retaining the teacher's review effects. Breaks INV-9. Consider promoting to Medium if governance risk is in scope.

**Recommended Mitigation.** Add `notYetInSession` to `removeTeacher()`, or track per-teacher earned wages so removal cannot silently strip them.

---

### [L-02] `startSession()` accepts arbitrary, unvalidated cutoff scores

**Details.** `startSession(uint256 _cutOffScore)` at `LevelOne.sol:269–274` stores the argument with no bounds check. Student scores start at `100` and only decrease.

**Impact.** Cutoff `0` trivially passes every student. Cutoff `> 100` blocks all graduation from day one.

**Recommended Mitigation.**

```solidity
require(_cutOffScore > 0 && _cutOffScore <= 100, "invalid cutoff");
```

---

### [L-03] `giveReview()` is not bounded to the active session window

**Details.** `giveReview()` at `LevelOne.sol:277–292` does not check `inSession` or `block.timestamp <= sessionEnd`. Reviews are possible before session start and after session end.

**Impact.** Post-session score drift; unbounded review flow. Breaks INV-2/INV-3/INV-6.

**Recommended Mitigation.**

```solidity
require(inSession, "not in session");
require(block.timestamp <= sessionEnd, "session over");
```

---

### [L-04] `Graduated` event is declared but never emitted

**Details.** `event Graduated(address indexed levelTwo)` at `LevelOne.sol:70` is never emitted. `graduateAndUpgrade()` contains no `emit` for it.

**Impact.** Off-chain indexers cannot detect graduation. Reduced observability. Related to H-02 — emitting without upgrading would also be misleading; fix together.

**Recommended Mitigation.** After the real upgrade lands (per H-02), emit `Graduated(_levelTwo)` at the end of `graduateAndUpgrade()`.

---

### [L-05] Off-by-one review limit permits five reviews once `reviewCount` is fixed

**Details.** `require(reviewCount[_student] < 5, ...)` allows counts `0,1,2,3,4` — five reviews — instead of the intended four. Currently dormant because M-04 means the counter never increments; becomes active the moment M-04 is patched.

**Impact.** One extra bad review = 10 extra points off. Student starting at `100` reaches `50` instead of `60`.

**Recommended Mitigation.** Use `< 4`. Ship together with the M-04 patch.

---

## Informational

### [I-01] `expel()` uses raw `revert()` instead of a named custom error

**Details.** `expel()` at `LevelOne.sol:245–247` uses `revert()` when `inSession == false`. Every other precondition failure in the contract uses a named custom error.

**Recommended Mitigation.**

```solidity
error HH__NotInSession();
// ...
if (!inSession) revert HH__NotInSession();
```

---

### [I-02] `startSession()` does not require at least one teacher or student

**Details.** `startSession()` can be called with `listOfTeachers.length == 0` and/or `listOfStudents.length == 0`, creating meaningless sessions.

**Recommended Mitigation.**

```solidity
require(listOfTeachers.length > 0, "no teachers");
require(listOfStudents.length > 0, "no students");
```
