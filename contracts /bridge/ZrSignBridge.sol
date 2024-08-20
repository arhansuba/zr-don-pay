// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IZRSign.sol";
import "./TokenLocker.sol";
import "./TokenMinter.sol";

contract ZrSignBridge {
    IZRSign public zrSign;
    TokenLocker public tokenLocker;
    TokenMinter public tokenMinter;

    constructor(address _zrSign, address _tokenLocker, address _tokenMinter) {
        zrSign = IZRSign(_zrSign);
        tokenLocker = TokenLocker(_tokenLocker);
        tokenMinter = TokenMinter(_tokenMinter);
    }

    function signLockingTransaction(address user, uint256 amount, string memory targetChain) public returns (bytes32) {
        bytes32 dataHash = keccak256(abi.encodePacked(user, amount, targetChain));
        bytes32 signedHash = zrSign.sign(dataHash);
        return signedHash;
    }

    function verifyAndMint(address user, uint256 amount, bytes32 signedData) public {
        bytes32 dataHash = keccak256(abi.encodePacked(user, amount, "TargetChain"));
        require(zrSign.verify(signedData, dataHash), "Invalid signature");

        tokenMinter.mintTokens(user, amount);
    }
}
