const Faucet = artifacts.require("FaucetContract");

module.exports = function (deployer) {
  deployer.deploy(Faucet);
};
