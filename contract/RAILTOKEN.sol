// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Railix Token
/// @notice Reward token for Railix minters on BNB Chain.
/// Minted ONLY by the Railix NFT contract: 1,000 RAIL per NFT minted,
/// up to a hard cap of 4,444,000 RAIL (4,444 NFTs x 1,000 RAIL).
/// No pre-mint, no owner mint, no tax, no further minting beyond the cap.
/// The minter (NFT contract address) is set exactly once by the owner
/// after the NFT contract is deployed, then it can never be changed.
contract RAILTOKEN is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 4444000 ether;

    address public minter;

    event MinterSet(address minter);

    constructor() ERC20("Railix Token", "RAIL") Ownable(msg.sender) {}

    function setMinter(address m) external onlyOwner {
        require(minter == address(0), "Minter already set");
        require(m != address(0), "Zero address");
        minter = m;
        emit MinterSet(m);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "Not minter");
        require(totalSupply() + amount <= MAX_SUPPLY, "Cap exceeded");
        _mint(to, amount);
    }
}
