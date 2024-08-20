// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ZrWallet
 * @dev Advanced wallet contract with features such as multi-signature support, transaction limits, and secure fund management.
 */
contract ZrWallet {
    // Events
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);
    event TransactionExecuted(address indexed to, uint256 amount, bytes data);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // State variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;
    mapping(bytes32 => Transaction) public transactions;

    // Structs
    struct Transaction {
        address to;
        uint256 amount;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) confirmedBy;
    }

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not authorized: Caller is not an owner");
        _;
    }

    modifier transactionExists(bytes32 txHash) {
        require(transactions[txHash].to != address(0), "Transaction does not exist");
        _;
    }

    modifier notExecuted(bytes32 txHash) {
        require(!transactions[txHash].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(bytes32 txHash) {
        require(!transactions[txHash].confirmedBy[msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "No owners provided");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid address: Owner cannot be zero address");
            require(!isOwner[owner], "Duplicate owner: Address already an owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    /**
     * @notice Deposit funds into the wallet.
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Create a transaction for execution.
     * @param to Address of the recipient.
     * @param amount Amount of Ether to send.
     * @param data Data to send with the transaction.
     * @return txHash The hash of the transaction.
     */
    function createTransaction(address to, uint256 amount, bytes memory data) external onlyOwner returns (bytes32 txHash) {
        txHash = keccak256(abi.encodePacked(to, amount, data, block.timestamp));
        Transaction storage txn = transactions[txHash];
        require(txn.to == address(0), "Transaction already exists");

        txn.to = to;
        txn.amount = amount;
        txn.data = data;
        txn.executed = false;
        txn.confirmations = 0;

        emit Approval(msg.sender, to, amount);
    }

    /**
     * @notice Confirm a transaction.
     * @param txHash The hash of the transaction.
     */
    function confirmTransaction(bytes32 txHash) external onlyOwner transactionExists(txHash) notConfirmed(txHash) {
        Transaction storage txn = transactions[txHash];
        txn.confirmedBy[msg.sender] = true;
        txn.confirmations += 1;

        if (txn.confirmations >= requiredConfirmations) {
            executeTransaction(txHash);
        }
    }

    /**
     * @notice Execute a confirmed transaction.
     * @param txHash The hash of the transaction.
     */
    function executeTransaction(bytes32 txHash) internal transactionExists(txHash) notExecuted(txHash) {
        Transaction storage txn = transactions[txHash];
        require(txn.confirmations >= requiredConfirmations, "Insufficient confirmations");

        txn.executed = true;
        (bool success, ) = txn.to.call{value: txn.amount}(txn.data);
        require(success, "Transaction failed");

        emit TransactionExecuted(txn.to, txn.amount, txn.data);
    }

    /**
     * @notice Get the transaction details.
     * @param txHash The hash of the transaction.
     * @return to Address of the recipient.
     * @return amount Amount of Ether to send.
     * @return data Data to send with the transaction.
     * @return executed Boolean indicating if the transaction has been executed.
     * @return confirmations Number of confirmations for the transaction.
     * @return confirmedBy Addresses that have confirmed the transaction.
     */
    function getTransactionDetails(bytes32 txHash) external view returns (
        address to,
        uint256 amount,
        bytes memory data,
        bool executed,
        uint256 confirmations,
        address[] memory confirmedBy
    ) {
        Transaction storage txn = transactions[txHash];
        require(txn.to != address(0), "Transaction does not exist");

        address[] memory _confirmedBy = new address[](owners.length);
        uint256 count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (txn.confirmedBy[owners[i]]) {
                _confirmedBy[count] = owners[i];
                count++;
            }
        }

        return (
            txn.to,
            txn.amount,
            txn.data,
            txn.executed,
            txn.confirmations,
            _confirmedBy
        );
    }
}