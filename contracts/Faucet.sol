// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract FaucetContract is Ownable, Pausable {
    using SafeMath for uint256;
    uint256 public retrievalAmount = 1*10**17;
    uint256 public retrievalLimit = 1*10**18;

    event Received(address sender, uint256 amount);
    event Funded(address sender, uint256 amount);
    event ChangedRetrievalParameters(uint256 newRetrievalAmount, uint256 newNumberOfTimes);
    event ContractDestroyed(string message);

    // Pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    // Unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    mapping (address => uint256) public amountRetrieved;

    // Receive funds
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Change the retrieval parameters
    function changeRetrievalAmounts(uint256 newRetrievalAmount, uint256 newNumberOfTimes) public onlyOwner() returns(bool) {
        require(newRetrievalAmount > 0, "Retrieval amount must be positive");
        require(newNumberOfTimes > 0, "Number of times must be positive");
        retrievalAmount = newRetrievalAmount;
        retrievalLimit = retrievalAmount.mul(newNumberOfTimes);
        emit ChangedRetrievalParameters(newRetrievalAmount, newNumberOfTimes);
        return true;
    }

    // Send money to message sender
    function sendFunds() public whenNotPaused() {
        address payable retriever = payable(msg.sender);
        amountRetrieved[retriever] = amountRetrieved[retriever].add(retrievalAmount);
        require(amountRetrieved[retriever] <= retrievalLimit, "You have reached the retrieval limit");
        require(address(this).balance >= retrievalAmount, "Reserves insufficient");
        retriever.transfer(retrievalAmount);
        emit Funded(retriever, retrievalAmount);
    }

    // Send money to specific address
    function sendToFunds(address payable retriever) public whenNotPaused() {
        amountRetrieved[retriever] = amountRetrieved[retriever].add(retrievalAmount);
        require(amountRetrieved[retriever] <= retrievalLimit, "You have reached the retrieval limit");
        require(address(this).balance >= retrievalAmount, "Reserves insufficient");
        retriever.transfer(retrievalAmount);
        emit Funded(retriever, retrievalAmount);
    }

    // Destroy the faucet
    function closeFaucet(address payable payoutAddress) public onlyOwner() {
        payoutAddress.transfer(address(this).balance);
        selfdestruct(payoutAddress);
        emit ContractDestroyed("Contract was successfully self-destructed");
    }
}
