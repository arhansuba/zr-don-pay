// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLocker is ReentrancyGuard, Ownable {
    event TokensLocked(address indexed user, uint256 amount, string targetChain);
    
    IERC20 public token;
    mapping(address => uint256) public lockedTokens;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function lockTokens(uint256 amount, string memory targetChain) public nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        lockedTokens[msg.sender] += amount;
        emit TokensLocked(msg.sender, amount, targetChain);
    }

    function unlockTokens(uint256 amount) public nonReentrant {
        require(lockedTokens[msg.sender] >= amount, "Insufficient locked tokens");
        
        lockedTokens[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Token transfer failed");
    }
}
