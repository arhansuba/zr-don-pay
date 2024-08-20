// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../wallets/ZrWallet.sol";
import "../interfaces/IWalletManager.sol";
import "../wallets/ZrWalletManager.sol";

/**
 * @title ZrTransactionManager
 * @dev Manages transactions between ZrWallet instances.
 */
contract ZrTransactionManager {
    // Events
    event TransactionSubmitted(address indexed walletAddress, uint256 indexed txIndex, address destination, uint256 value, bytes data);
    event TransactionConfirmed(address indexed walletAddress, uint256 indexed txIndex, address indexed confirmer);
    event TransactionExecuted(address indexed walletAddress, uint256 indexed txIndex, bool success);
    event TransactionRevoked(address indexed walletAddress, uint256 indexed txIndex, address indexed revoker);

    // State variables
    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        mapping(address => bool) confirmations;
    }

    mapping(address => Transaction[]) public transactions;
    mapping(address => uint256) public requiredConfirmations;
    mapping(address => address[]) public walletOwners;
    address[] public deployedWallets;

    // Modifiers
    modifier onlyWalletOwner(address walletAddress) {
        require(ZrWallet(payable(walletAddress)).isOwner(msg.sender), "Not authorized: Caller is not an owner");
        _;
    }

    modifier transactionExists(address walletAddress, uint256 txIndex) {
        require(txIndex < transactions[walletAddress].length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(address walletAddress, uint256 txIndex) {
        require(!transactions[walletAddress][txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(address walletAddress, uint256 txIndex) {
        require(!transactions[walletAddress][txIndex].confirmations[msg.sender], "Transaction already confirmed by caller");
        _;
    }

    /**
     * @notice Submit a new transaction for a wallet.
     * @param walletAddress Address of the wallet.
     * @param destination Address to send funds to.
     * @param value Amount of funds to send.
     * @param data Additional data for the transaction.
     */
    function submitTransaction(address walletAddress, address destination, uint256 value, bytes memory data) external onlyWalletOwner(walletAddress) {
        Transaction storage newTx = transactions[walletAddress].push();
        newTx.destination = destination;
        newTx.value = value;
        newTx.data = data;

        emit TransactionSubmitted(walletAddress, transactions[walletAddress].length - 1, destination, value, data);
    }

    /**
     * @notice Confirm a transaction.
     * @param walletAddress Address of the wallet.
     * @param txIndex Index of the transaction to confirm.
     */
    function confirmTransaction(address walletAddress, uint256 txIndex) 
        external 
        onlyWalletOwner(walletAddress) 
        transactionExists(walletAddress, txIndex) 
        notConfirmed(walletAddress, txIndex) 
        notExecuted(walletAddress, txIndex)
    {
        Transaction storage transaction = transactions[walletAddress][txIndex];
        transaction.confirmations[msg.sender] = true;

        emit TransactionConfirmed(walletAddress, txIndex, msg.sender);

        if (_isConfirmed(walletAddress, txIndex)) {
            _executeTransaction(walletAddress, txIndex);
        }
    }

    /**
     * @notice Revoke a confirmation for a transaction.
     * @param walletAddress Address of the wallet.
     * @param txIndex Index of the transaction to revoke.
     */
    function revokeConfirmation(address walletAddress, uint256 txIndex) 
        external 
        onlyWalletOwner(walletAddress) 
        transactionExists(walletAddress, txIndex) 
        notExecuted(walletAddress, txIndex)
    {
        Transaction storage transaction = transactions[walletAddress][txIndex];
        require(transaction.confirmations[msg.sender], "Transaction not confirmed by caller");
        
        transaction.confirmations[msg.sender] = false;

        emit TransactionRevoked(walletAddress, txIndex, msg.sender);
    }

    /**
     * @notice Execute a confirmed transaction.
     * @param walletAddress Address of the wallet.
     * @param txIndex Index of the transaction to execute.
     */
    function _executeTransaction(address walletAddress, uint256 txIndex) 
        private 
        transactionExists(walletAddress, txIndex) 
        notExecuted(walletAddress, txIndex)
    {
        Transaction storage transaction = transactions[walletAddress][txIndex];
        require(_isConfirmed(walletAddress, txIndex), "Transaction not fully confirmed");

        (bool success, ) = transaction.destination.call{value: transaction.value}(transaction.data);
        transaction.executed = true;

        emit TransactionExecuted(walletAddress, txIndex, success);
    }

    /**
     * @notice Set the wallet owners for a specific wallet.
     * @param walletAddress Address of the wallet.
     * @param owners Array of owner addresses.
     */
    function setWalletOwners(address walletAddress, address[] memory owners) external {
        // Add appropriate access control here
        walletOwners[walletAddress] = owners;
    }

    /**
     * @notice Check if a transaction is fully confirmed.
     * @param walletAddress Address of the wallet.
     * @param txIndex Index of the transaction.
     * @return True if the transaction is confirmed by the required number of owners, false otherwise.
     */
    function _isConfirmed(address walletAddress, uint256 txIndex) private view returns (bool) {
        uint256 count = 0;
        Transaction storage transaction = transactions[walletAddress][txIndex];
        address[] storage owners = walletOwners[walletAddress];

        for (uint256 i = 0; i < owners.length; i++) {
            if (transaction.confirmations[owners[i]]) {
                count++;
            }
        }

        return count >= requiredConfirmations[walletAddress];
    }

    /**
     * @notice Set the required confirmations for a wallet.
     * @param walletAddress Address of the wallet.
     * @param _requiredConfirmations Number of confirmations required.
     */
    function setRequiredConfirmations(address walletAddress, uint256 _requiredConfirmations) external onlyWalletOwner(walletAddress) {
        require(_requiredConfirmations > 0, "Invalid number of required confirmations");
        requiredConfirmations[walletAddress] = _requiredConfirmations;
    }

    /**
     * @notice Get the details of a transaction.
     * @param walletAddress Address of the wallet.
     * @param txIndex Index of the transaction.
     * @return destination Address of the transaction destination.
     * @return value Amount of funds to be sent.
     * @return data Additional data for the transaction.
     * @return executed Whether the transaction has been executed.
     * @return confirmations Array of addresses that have confirmed the transaction.
     */
    function getTransactionDetails(address walletAddress, uint256 txIndex) 
        external 
        view 
        transactionExists(walletAddress, txIndex)
        returns (address destination, uint256 value, bytes memory data, bool executed, address[] memory confirmations)
    {
        Transaction storage transaction = transactions[walletAddress][txIndex];
        destination = transaction.destination;
        value = transaction.value;
        data = transaction.data;
        executed = transaction.executed;

        uint256 confirmationsCount = 0;
        address[] storage owners = walletOwners[walletAddress];
        confirmations = new address[](owners.length);

        for (uint256 i = 0; i < owners.length; i++) {
            if (transaction.confirmations[owners[i]]) {
                confirmations[confirmationsCount] = owners[i];
                confirmationsCount++;
            }
        }

        // Resize the confirmations array to the actual count
        assembly {
            mstore(confirmations, confirmationsCount)
        }
    }

    /**
     * @notice Get all deployed wallet addresses.
     * @return Array of wallet addresses.
     */
    function getDeployedWallets() external view returns (address[] memory) {
        return deployedWallets;
    }
}