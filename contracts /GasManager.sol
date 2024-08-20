// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GasManager
 * @dev Manages and optimizes gas usage for transactions.
 */
contract GasManager {
    // Events
    event GasLimitUpdated(address indexed contractAddress, uint256 newGasLimit);
    event GasUsageRecorded(address indexed contractAddress, uint256 gasUsed, uint256 timestamp);

    // State variables
    mapping(address => uint256) public gasLimits;
    mapping(address => uint256[]) public gasUsageRecords;

    // Constants
    uint256 public constant DEFAULT_GAS_LIMIT = 3000000; // Example default gas limit

    /**
     * @notice Set a custom gas limit for a contract.
     * @param contractAddress Address of the contract.
     * @param newGasLimit New gas limit to set.
     */
    function setGasLimit(address contractAddress, uint256 newGasLimit) external {
        // This should be restricted to an admin or owner in a real-world scenario
        require(newGasLimit > 0, "Gas limit must be greater than zero");
        gasLimits[contractAddress] = newGasLimit;

        emit GasLimitUpdated(contractAddress, newGasLimit);
    }

    /**
     * @notice Get the gas limit for a contract.
     * @param contractAddress Address of the contract.
     * @return The gas limit for the contract.
     */
    function getGasLimit(address contractAddress) public view returns (uint256) {
        return gasLimits[contractAddress] == 0 ? DEFAULT_GAS_LIMIT : gasLimits[contractAddress];
    }

    /**
     * @notice Record gas usage for a contract.
     * @param contractAddress Address of the contract.
     * @param gasUsed Amount of gas used in a transaction.
     */
    function recordGasUsage(address contractAddress, uint256 gasUsed) external {
        // This function should be called by the contract or service managing the transactions
        gasUsageRecords[contractAddress].push(gasUsed);

        emit GasUsageRecorded(contractAddress, gasUsed, block.timestamp);
    }

    /**
     * @notice Get the recorded gas usage for a contract.
     * @param contractAddress Address of the contract.
     * @return Array of recorded gas usage values.
     */
    function getGasUsageRecords(address contractAddress) external view returns (uint256[] memory) {
        return gasUsageRecords[contractAddress];
    }

    /**
     * @notice Estimate gas usage for a transaction.
     * @param contractAddress Address of the contract.
     * @param data Call data for the transaction.
     * @return Estimated gas usage for the transaction.
     */
    function estimateGasUsage(address contractAddress, bytes calldata data) external view returns (uint256) {
        uint256 gasLimit = getGasLimit(contractAddress);
        // Using a view call to estimate gas usage
        (bool success, bytes memory result) = contractAddress.staticcall{gas: gasLimit}(data);
        require(success, "Failed to estimate gas usage");

        // Extract gas usage from result (assuming the contract returns gas usage info)
        uint256 gasUsed = abi.decode(result, (uint256));
        return gasUsed;
    }
}