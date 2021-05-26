# An Ether Faucet for the Swiss DLT Blockchain

## Possible Design Approach
Let's assume that Awl is running a validator node on the Swiss DLT blockchain (this assumption is already met today). We could then deploy a simple smart contract and set the contract address to be the `coinbase`/`etherbase` for mining/validator rewards. After the smart contract is deployed, we could configure our validator Geth client to award the block rewards to the contract itself. We can set our `etherbase` from the command line in the Geth client by running (see [here](https://geth.ethereum.org/docs/interface/mining)):
```
geth --miner.etherbase <'ADDRESS'> --mine 2>> geth.log
```
That way, the faucet contract will always have a steady supply of funds, Awl is funding the faucet automatically, and we have a clean audit trail back to the genesis block.
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
    uint256 public retrievalAmount = 1*10**17;
    uint256 public retrievalLimit = 1*10**18;

    event Received(address sender, uint256 amount);
    event Funded(address sender, uint256 amount);
    event ChangedRetrievalParameters(uint256 newRetrievalAmount, uint256 newNumberOfTimes);
    event contractDestroyed(string message);

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
        emit contractDestroyed("Contract was successfully self-destructed");
    }
}
```

### A Note on Gas Usage
Since the user still has to interact with a smart contract, a tiny amount of gas is needed to exist on the user's wallet. I would recommend solving this problem in a simple way:
- When the user sets up the wallet for the first time, a small amount of ETH is allocated to the wallet by Awl (or another service provider);
- When the available ETH drops below a certain threshold, he/she has to request additional money via the faucet before he/she can transact again. Since the entire user flow is controlled by an app, the risk of a user interacting directly with the blockchain to bypass this backup function is very low;

### Test Deployments
The smart contract `Faucet.sol` has been deployed to the following test networks:
- **Rinkeby:** [0xeaBf236272A02c9587634261AF526EdacE27eb85](https://rinkeby.etherscan.io/address/0xeaBf236272A02c9587634261AF526EdacE27eb85)
- **Kovan:** [0x627e63b8c43195Bde17186651caD87f7f1dBAfEC](https://kovan.etherscan.io/address/0x627e63b8c43195bde17186651cad87f7f1dbafec)
