// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title Railix (new contract)
/// @notice Rail lines on BNB Chain. Supply 4,444 in one pool.
/// Phase 1: tokens minted while totalMinted < 444, FREE (0 BNB), max 3 per tx.
/// After phase 1, TWO mint options draw from the same remaining pool until sold out:
///   - mintFreeFee: free NFT + 0.0001 BNB fee per NFT, max 10 per tx.
///   - mintPaid: 0.0003 BNB per NFT, max 10 per tx.
/// Minting is sequential by token id; a pseudo-random seed is fixed on-chain
/// for each token at mint time (seedOf), so the drawing code can redraw any
/// Railix from its number. Minting works from any wallet (no contract-caller
/// block), so page, agent-wallet and CLI mints all work.
/// Mint is CLOSED at deploy (mintEnabled = false). It can only be opened later
/// when the owner wallet itself signs setMintEnabled(true). Deploying does NOT open mint.
/// All mint payments are sent to this contract and stay here until the owner
/// withdraws them. There is no treasury address.
/// tokenURI = baseURI + tokenId + ".json", matching the metadata files (1.json .. 4444.json).
contract RAILIXNEW is ERC721, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 4444;
    uint256 public constant FREE_LIMIT = 444;
    uint256 public constant FEE_FEE = 0.0001 ether;
    uint256 public constant PAID_PRICE = 0.0003 ether;
    uint256 public constant MAX_PER_TX_FREE = 3;
    uint256 public constant MAX_PER_TX_FEE = 10;
    uint256 public constant MAX_PER_TX_PAID = 10;

    uint256 public totalMinted;
    bool public mintEnabled;
    string private _baseTokenURI;
    mapping(uint256 => uint256) private _seeds;

    event MintEnabledChanged(bool enabled);
    event BaseURIChanged(string baseURI);

    constructor(string memory baseURI_) ERC721("Railix", "RAILIX") Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
    }

    function _mintNext(address to) internal {
        totalMinted += 1;
        uint256 tokenId = totalMinted;
        _seeds[tokenId] = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    tokenId,
                    to,
                    block.timestamp
                )
            )
        );
        _safeMint(to, tokenId);
    }

    function mintFree(uint256 amount) external payable {
        require(mintEnabled, "Mint closed");
        require(amount > 0 && amount <= MAX_PER_TX_FREE, "Max 3 per mint");
        require(totalMinted + amount <= FREE_LIMIT, "Free phase ended");
        require(msg.value == 0, "Free mint takes 0 BNB");
        for (uint256 i = 0; i < amount; i++) _mintNext(msg.sender);
    }

    function mintFreeFee(uint256 amount) external payable {
        require(mintEnabled, "Mint closed");
        require(amount > 0 && amount <= MAX_PER_TX_FEE, "Max 10 per mint");
        require(totalMinted >= FREE_LIMIT, "Fee phase not started");
        require(totalMinted + amount <= MAX_SUPPLY, "Sold out");
        require(msg.value == FEE_FEE * amount, "Wrong fee");
        for (uint256 i = 0; i < amount; i++) _mintNext(msg.sender);
    }

    function mintPaid(uint256 amount) external payable {
        require(mintEnabled, "Mint closed");
        require(amount > 0 && amount <= MAX_PER_TX_PAID, "Max 10 per mint");
        require(totalMinted >= FREE_LIMIT, "Paid phase not started");
        require(totalMinted + amount <= MAX_SUPPLY, "Sold out");
        require(msg.value == PAID_PRICE * amount, "Wrong price");
        for (uint256 i = 0; i < amount; i++) _mintNext(msg.sender);
    }

    function seedOf(uint256 tokenId) external view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Not minted");
        return _seeds[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(_baseURI(), tokenId.toString(), ".json"));
    }

    function setMintEnabled(bool enabled) external onlyOwner {
        mintEnabled = enabled;
        emit MintEnabledChanged(enabled);
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIChanged(baseURI_);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function withdraw() external onlyOwner {
        (bool ok, ) = owner().call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }
}
