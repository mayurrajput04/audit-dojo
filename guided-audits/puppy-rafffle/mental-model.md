# Mental Model — Puppy Raffle

## 1. System Goal
- Run a raffle where players pay an entrance fee
- a random winner gets an NFT and 80 % of the pot
- 20 % goes to a fee address.
 
## 2. Actors 
- Owner (admin)
- players (entrants)
- Anyone (caller of `selectWinner` and `withdrawFees`)
- fee Recipient (`feeAddress`)

## 3. Functions
- enterRaffle : players enters the Raffle
- refund : opt for refunds before raffle ends and getting out of raffle.
- selectWinner : uses randomness for selecting a winner among entered user.
- withdrawFees : withdraw fees amount to `feeAddress`
- admintFunctions (owner can..)
    - changeFeeAddress - change fees address which receive all fees for raffle entrance,
    - changeRaffleDuration -change raffle duration,
    - changeEntranceFee - change entrance fees in wei.
## 4. Assets at Risk
- Eth in contract (both prize pool and fees)
- minted NFT (could be stolen if winner selection is manupilated)

## 5. Trust Assumptions
- Randomness : relioes on `mmsg.sender` & block properties.
- owner is trusted to set fees/duration .
- `feeAddress` is trusted to be not a malicious contract (although it is set by owner)
- No Oracle, ChainlinkVrf.

## 6. Invariants
- Within a single raffle round, an address can appear in the players array at most once.
- After `selectWinner`, the sum of ETH sent to the winner plus `totalFees` must equal `entranceFee * players.length`.
- selectWinner may only be called after the raffle has ended AND at least 4 players have entered.
- The winner must be unpredictable by any participant, including the caller of `selectWinner`.
- The `withdrawFees` function must send exactly `totalFees` to `feeAddress` and must never transfer funds to any other address.
- Only the owner can change `raffleDuration`, `entranceFee`, `feeAddress`.
- After a successful `refund`, the refunded player must not be in the `players` array and `_isActivePlayer[player]` must be false.
- After a round ends, the `_isActivePlayer` mapping must be completely cleared.
- The contract must ensure that `totalFees + fee` never exceeds `type(uint64).max`.


<!-- # my observations 
 - totalFees is stored as uint64  - might be a integer overflow bug here 
 - Reentrancy in `refund` function 
 -->