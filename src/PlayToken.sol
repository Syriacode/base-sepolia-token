// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PlayToken
/// @notice A capped ERC-20 where anyone can claim a small amount once per day.
contract PlayToken is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000 ether;
    uint256 public constant CLAIM_AMOUNT = 100 ether;
    uint256 public constant CLAIM_COOLDOWN = 1 days;

    /// @notice When each account may claim next; 0 means "never claimed".
    mapping(address account => uint256 time) public nextClaimAt;

    event Claimed(address indexed account, uint256 amount);

    error CapExceeded(uint256 requested, uint256 available);
    error ClaimTooSoon(uint256 nextClaimAt);

    constructor(address initialOwner, uint256 initialMint) ERC20("PlayToken", "PLAY") Ownable(initialOwner) {
        _mintCapped(initialOwner, initialMint);
    }

    function claim() external {
        uint256 next = nextClaimAt[msg.sender];
        if (block.timestamp < next) revert ClaimTooSoon(next);
        nextClaimAt[msg.sender] = block.timestamp + CLAIM_COOLDOWN;
        _mintCapped(msg.sender, CLAIM_AMOUNT);
        emit Claimed(msg.sender, CLAIM_AMOUNT);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mintCapped(to, amount);
    }

    function _mintCapped(address to, uint256 amount) internal {
        uint256 available = MAX_SUPPLY - totalSupply();
        if (amount > available) revert CapExceeded(amount, available);
        _mint(to, amount);
    }
}
