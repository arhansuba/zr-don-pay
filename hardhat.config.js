/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  paths: {
    sources: "./contracts", // Default path for Solidity files
    tests: "./test", // Default path for test files
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
