# Guided Audit 2: Thunder Loan Takeaways

> Drafting rule: these must be my words. No polished coach-speak. If it sounds too smart, rewrite it until it sounds like something I would actually say after staring at storage slots too long.

## 1. What I learned in Thunder Loan that I did not catch in Puppy Raffle

Chosen direction: **Upgradeable storage/layout risk**

My reflection:

- upgradable contracts doesn't just work on assumptions , if a tiny storage slot is replaced the whole protocol gets bricked.

- the executeOperation function call can be dangerous for protocol health if there is no cross function reeentrancy protection mindmap.

- In Puppy Raffle, there was normal single function reentrancy bug, but in ThunderLoan there was cross function Reentrancy Bug which affected how an attacker can cash out with phantom amount updated fee, and resulting in LP deposits gets stolen from totalSupply of vault Contract.

- In ThunderLoan , the storage layout was mismatched when upgraded from v1 to v2. Resulting in whole protocol to be useless, as whole system variable mapping to storage was mismatched and protocol was basically malfunctioning.

## 2. Hardest finding to understand

Chosen finding: **H-4 Storage layout collision**

My reflection:

- Storage layout collision was hard to get because you need core solidity knowledge and you should be educated with contract upgradation effects.

- The storage layout collision at plain sight seems normal , just using constant variable in new v2 contract for a variable which has storage slot in v1. As the constant variable does not occupy / has storage slot in solidity. hence breaking the storage slot mappings of variables.

## 3. One auditing habit I want to cement

Chosen habit: **Trace real assets vs accounting claims**

My reflection:

- The `exchangeRate` calculation made me think that how come the spike in rate makes it easier for attacker to claim the hyped amount and cash out at higher price than deserved.

- vault balance hypothetically seems correct but the math says otherwise, after the attacker cash outs , the vault balance is less that what it supposed to be. Meaning the hyped amount was compensated via other LP assets which was present in vault balance.

- In future audits , I should more ask following question: Does the claimed value matches the actual value of assets after transfer?

## 4. Puppy Raffle vs Thunder Loan comparison

| Question | Puppy Raffle | Thunder Loan | Habit change |
|---|---|---|---|
| Main accounting risk | The accounting risk was more direct: `players.length` was treated like real active paid players, even after refunds. So the contract thought it had more valid entries / money logic than it actually had. | The accounting risk was more layered: exchange rate, AssetToken supply, vault balance, fee calculation, and flashloan repayment all looked connected but were not properly backed by real assets. A small fake rate increase could steal from other LPs. | I should not trust accounting variables just because they are updated. I need to compare the claimed value against real token balance and ask who is paying for the difference. |
| Main hidden assumption | The hidden assumption was: every player slot in the array still represents a real paid entrant. Refund broke that assumption silently. | The hidden assumption was: storage layout stays compatible after upgrade, exchange rate only increases because real fees came in, and callbacks will not mess with protocol state mid-flow. All three were dangerous assumptions. | When I see an assumption, I should try to break it with weird ordering: refund before winner selection, deposit then redeem, upgrade V1 to V2, flashloan callback then re-enter. |
| Hardest mental model | The hardest part was understanding how one stale array length can mess up winner payout and fee withdrawal together. It was still mostly one-contract accounting. | The hardest part was storage layout collision because the code looked normal at first sight, but one `constant` replacing a storage variable shifted the whole storage meaning. The protocol was reading old values as new variables. Milk-brain slot hell. | I need to slow down on upgradeable contracts and literally compare storage slots, not just read the new code like it is a fresh deployment. |
| Best checklist lesson | Do not use one structure as both user registry and money accounting source unless every state transition keeps it synced. | For upgradeable / oracle / flashloan systems, check storage layout, real asset backing, oracle manipulation, and callback reentrancy as separate passes. | My checklist should become more attack-flow based: what changes, what assets move, what external call happens, and what assumption can become false before the function ends. |

## 5. Closing note

- I feel like I am much confident in starting an audit all by myself, and might find a good vulnerability.

- I have got better mental model , checklists, past audit experience.

- I believe even if I don't find a bug, I can explain how protocol works, where is money flow, how it is flowing throughout the protocol, can sense where it looks phishy even if I can't explain the bug. The intuition is there, even if I lack the knowledge of wide range of bugs.
