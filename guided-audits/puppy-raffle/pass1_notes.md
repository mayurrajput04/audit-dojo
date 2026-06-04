# Puppy Raffle - Pass 1: Access Control, External Calls, State Updates

Date: 2 Jun 2026
Auditor: Gintoki Sakata
Contract: src/PuppyRaffle.sol (Solidity ^0.7.6)
Focus: Who can call it? What changes? What goes out? What smells?

---

## 1. enterRaffle(address[] memory newPlayers) - public payable

### Who can call it?
- Anyone. No modifier, no access control.
- Only requirement is msg.value == entranceFee * newPlayers.length.

### What state changes?
- New addresses get pushed into the players[] storage array.
- Emits RaffleEnter(newPlayers).

### Any external calls?
- None. Only receives ETH via msg.value.

### What could be abused?
- SUSPICIOUS - DoS / Gas griefing: The duplicate check is a nested for loop over
  the entire players array. Thats O(n^2) complexity. As the array grows the gas cost
  grows quadratically. Large enough array could make future enterRaffle calls exceed
  block gas limit. Denial of Service.
- TODO - Check order of operations: Players are pushed before the duplicate check runs.
  Duplicates within the same batch are caught but the whole array gets scanned every time.
- TODO - address(0) collision: If multiple players refund (their slot becomes address(0))
  the duplicate check could see two address(0) entries and revert. That would block
  all new entries. Need to verify this.

---

## 2. refund(uint256 playerIndex) - public

### Who can call it?
- Only the player at that index. Checked by require(playerAddress == msg.sender).
- Player index is findable via getActivePlayerIndex.

### What state changes?
- players[playerIndex] gets set to address(0).
- Emits RaffleRefunded(playerAddress).

### Any external calls?
- Yes. payable(msg.sender).sendValue(entranceFee). Thats OpenZeppelins Address.sendValue
  which uses low level .call{value: ...}("") and forwards all remaining gas.

### What could be abused?
- SUSPICIOUS - Reentrancy (CEI violation):
  - Order is Check then Interaction then Effect. Should be Check Effect Interaction.
  - sendValue (external call) happens before players[playerIndex] = address(0) (state update).
  - Malicious contracts receive() can reenter refund with the same index. On reentry
    players[playerIndex] still holds the attackers address so the require passes again.
    Attacker drains entranceFee over and over.
  - sendValue forwards all gas which makes reentrancy fully exploitable. Unlike .transfer
    which caps at 2300 gas.

---

## 3. getActivePlayerIndex(address player) - external view

### Who can call it?
- Anyone. Its a view function.

### What state changes?
- None. Pure read.

### Any external calls?
- None.

### What could be abused?
- SUSPICIOUS - Ambiguous return value: Returns 0 when player is at index 0 (legit first entry)
  and also returns 0 when player is not in the array at all. No revert, no sentinel value.
- Player at index 0 cant tell if they are active or not found.
- Any contract or UI relying on this could misinterpret the result. Could lead to wrong
  refund calls or false assumptions about raffle status.
- Should revert for not found or return something distinct like type(uint256).max.

---

## 4. selectWinner() - external

### Who can call it?
- Anyone. No modifier. Only guarded by two requires:
  block.timestamp >= raffleStartTime + raffleDuration and players.length >= 4.
- Not really an access control issue since raffles need a public trigger. But msg.sender
  feeds into the randomness so the caller can pick when and who calls it to influence
  the outcome. Ties to weak RNG below.

### What state changes?
- totalFees gets updated with the fee amount.
- tokenIdToRarity[tokenId] set for the minted NFT.
- players array deleted.
- raffleStartTime reset to block.timestamp.
- previousWinner set to winners address.

### Any external calls?
- Two:
  1. winner.call{value: prizePool}("") - low level call, forwards all gas.
  2. _safeMint(winner, tokenId) - calls onERC721Received on the recipient if its
     a contract. Another external call to an untrusted address.

### What could be abused?
- SUSPICIOUS - Weak randomness: winnerIndex comes from
  keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty)).
  All inputs are predictable or controllable. msg.sender is chosen by caller,
  block.timestamp and block.difficulty are known to miners. Need Chainlink VRF
  or similar for real randomness.
- SUSPICIOUS - Integer overflow on totalFees: totalFees is uint64 but fee is uint256.
  The cast uint64(fee) silently truncates if fee is bigger than what uint64 can hold.
  Solidity 0.7.6 has no built in overflow checks. Fees can wrap around to zero.
  Protocol loses revenue. Need SafeMath or upgrade to 0.8.0+.
- SUSPICIOUS - address(0) winner: Refunded players are address(0) in the array.
  If address(0) gets selected as winner, _safeMint to address(0) reverts because
  ERC721 doesnt allow it. Whole tx reverts, no winner selected, no fees collected,
  raffle could get stuck.
- SUSPICIOUS - Reentrancy via _safeMint: _safeMint triggers onERC721Received on the
  winner if its a contract. State changes like delete players and raffleStartTime reset
  happen before the mint but a malicious callback could still mess with the contract.
- winner.call happens before _safeMint. If prize transfer works but _safeMint reverts
  the whole thing reverts atomically. But a malicious winner contract could use the
  _safeMint callback to reenter.

---

## 5. withdrawFees() - external

### Who can call it?
- Anyone. No modifier, no access control.

### What state changes?
- totalFees set to 0 after withdrawal.

### Any external calls?
- Yes. feeAddress.call{value: feesToWithdraw}("") - low level call, forwards all gas.

### What could be abused?
- SUSPICIOUS - Strict equality bricks fee withdrawal:
  require(address(this).balance == uint256(totalFees)) uses strict ==.
  If someone forcefully sends ETH to the contract (like via selfdestruct from another
  contract) then address(this).balance becomes bigger than totalFees and the require
  permanently fails. Fees locked forever.
- totalFees is uint64 cast to uint256. If totalFees already overflowed from the
  selectWinner issue the comparison is against the wrong value. Makes the bricking
  problem even worse.
- No access control means anyone can trigger fee withdrawal to feeAddress. Not
  necessarily a bug since fees go to the right address but worth noting.

---

## 6. changeFeeAddress(address newFeeAddress) - external onlyOwner

### Who can call it?
- Only the owner. Protected by onlyOwner modifier.

### What state changes?
- feeAddress updated to newFeeAddress.
- Emits FeeAddressChanged(newFeeAddress).

### Any external calls?
- None.

### What could be abused?
- If owner is trusted then no issue.
- If owner is compromised or malicious they can redirect all protocol fees to whatever
  address they want. Standard centralization risk.
- No check for address(0). Owner could accidentally set fee address to zero which
  would brick fee withdrawals.

---

## 7. tokenURI(uint256 tokenId) - public view override

### Who can call it?
- Anyone. View function, standard ERC721 override.

### What state changes?
- None. Pure read.

### Any external calls?
- None.

### What could be abused?
- Nothing significant. Builds JSON metadata from on chain storage (rarity, image URI, name)
  and Base64 encodes it. Standard pattern.
- virtual override is normal, just overrides parent ERC721 tokenURI.
- Did not fully understand the NFT/URI encoding logic yet. Flagging for later review.

---

## Raw Flags Summary

| # | Function | Flag | Severity Guess |
|---|----------|------|----------------|
| 1 | enterRaffle | DoS from O(n^2) duplicate check, gas griefing | High |
| 2 | enterRaffle | address(0) collision after refunds blocks new entries | Medium |
| 3 | refund | Reentrancy, CEI violation, sendValue forwards all gas | High |
| 4 | getActivePlayerIndex | Ambiguous return value, index 0 vs not found | Low |
| 5 | selectWinner | Weak RNG, predictable/manipulable inputs | High |
| 6 | selectWinner | Integer overflow, uint256 to uint64 truncation on fees | High |
| 7 | selectWinner | address(0) can win, tx reverts, raffle stuck | Medium |
| 8 | selectWinner | Reentrancy surface via _safeMint callback | Medium |
| 9 | withdrawFees | Strict equality bricked by forced ETH (selfdestruct) | High |
| 10 | changeFeeAddress | No address(0) check, centralization risk | Low |

Total flags: 10 across 7 functions.
Pass 1 complete.
