// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenMinter is ReentrancyGuard, Ownable {
    event TokensMinted(address indexed user, uint256 amount);

    IERC20 public token;
    mapping(address => uint256) public mintedTokens;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function mintTokens(address user, uint256 amount) public onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        mintedTokens[user] += amount;
        require(token.transfer(user, amount), "Token transfer failed");
        emit TokensMinted(user, amount);
    }
}
