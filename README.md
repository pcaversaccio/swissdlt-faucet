# An Ether Faucet for the Swiss DLT Blockchain

## Possible Design Approach
Let's assume that Awl is running a validator node on the Swiss DLT blockchain (this assumption is already met today). We could then deploy a simple smart contract and set the contract address to be the `coinbase` for mining rewards. After the smart contract is deployed, we could configure our validator client to award the block rewards to the contract itself. That way, the faucet contract will always have a steady supply of funds, Awl is funding the faucet automatically, and we have a clean audit trail back to the genesis block.
> A coinbase transaction is the first transaction in a block. It is a unique type of transaction that can be created by a miner. The miners use it to collect the block reward for their work and any other transaction fees collected by the miner are also sent in this transaction.

This simple contract has no protection from malicious or greedy users but such precautions shouldn't be necessary on the Swiss DLT private network:
```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract FaucetContract is Ownable, Pausable {
    using SafeMath for uint256;
    uint256 public retrievalAmount = 0.1 ether;
    uint256 public retrievalLimit = 5;

    event Received(address, uint);

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    mapping (address => uint256) public amountRetrieved;

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function changeRetrievalAmounts(uint256 newRetrievalAmount, uint256 newNumberOfTimes) public onlyOwner() returns(bool) {
        require(newRetrievalAmount > 0, "Retrieval amount must be positive");
        require(newNumberOfTimes > 0, "Number of times must be positive");
        retrievalAmount = newRetrievalAmount;
        retrievalLimit = retrievalAmount.mul(newNumberOfTimes);
        return true;
    }

    // Send money to message sender
    function sendFunds() public {
        address payable retriever = payable(msg.sender);
        amountRetrieved[retriever] = amountRetrieved[retriever].add(retrievalAmount);
        require(amountRetrieved[retriever] <= retrievalLimit, "You have reached the retrieval limit");
        require(address(this).balance >= retrievalAmount, "Reserves insufficient");
        retriever.transfer(retrievalAmount);
    }

    // Send money to specific address
    function sendToFunds(address payable retriever) public {
        amountRetrieved[retriever] = amountRetrieved[retriever].add(retrievalAmount);
        require(amountRetrieved[retriever] <= retrievalLimit, "You have reached the retrieval limit");
        require(address(this).balance >= retrievalAmount, "Reserves insufficient");
        retriever.transfer(retrievalAmount);
    }

    // Destroy the faucet
    function closeFaucet(address payable payoutAddress) public onlyOwner() {
        payoutAddress.transfer(address(this).balance);
        selfdestruct(payoutAddress); 
    }
}
```