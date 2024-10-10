// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "forge-std/console.sol";

contract FreeTicket is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply, ERC2771Context {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for uint256;

    string public name;
    string public symbol;
    uint256 public initialSupply;
    uint256 public maxSupply;
    uint256 public currentSupply;
    bool public transferable;
    bool public whitelistOnly;
    uint256 public nextTokenId = 1;
    mapping(address => EnumerableSet.UintSet) private userTokens;
    mapping(address => bool) public isWhitelisted;

    struct Distribution {
        address recipient;
        uint256 amount;
    }

    struct Whitelist {
        address user;
        bool status;
    }

    event SupplyUpdated(uint256 newSupply);

    constructor(
        address owner,
        string memory baseURI,
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _maxSupply,
        bool _transferable,
        bool _whitelistOnly
    ) ERC1155(baseURI) Ownable(owner) ERC2771Context(0x839320b787DbB268dCF0170302b16b25168B6bA7) {
        require(_initialSupply <= _maxSupply, "Initial supply exceeds max supply");
        name = _name;
        symbol = _symbol;
        initialSupply = _initialSupply;
        maxSupply = _maxSupply;
        currentSupply = _initialSupply;
        transferable = _transferable;
        whitelistOnly = _whitelistOnly;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        return string(abi.encodePacked(uri(_tokenId), _tokenId.toString()));
    }

    function updateSupply(uint256 _additionalSupply) public onlyOwner {
        require(currentSupply + _additionalSupply <= maxSupply, "Exceeds max supply");
        uint256 newSupply = currentSupply + _additionalSupply;
        currentSupply = newSupply;
        emit SupplyUpdated(newSupply);
    }

    function updateWhitelist(Whitelist[] memory _whitelistUpdates) public onlyOwner {
        for (uint256 i = 0; i < _whitelistUpdates.length; i++) {
            Whitelist memory update = _whitelistUpdates[i];
            isWhitelisted[update.user] = update.status;
        }
    }

    function setTransferable(bool _transferable) public onlyOwner {
        transferable = _transferable;
    }

    function distribute(Distribution[] memory _distributions) public onlyOwner {
        uint256 amountToBeDistributed = 0;
        for (uint256 i = 0; i < _distributions.length; i++) {
            Distribution memory dist = _distributions[i];
            if (whitelistOnly) {
                require(isWhitelisted[dist.recipient], "Recipient not whitelisted");
            }
            amountToBeDistributed += dist.amount;
        }
        require(currentSupply >= amountToBeDistributed, "Exceeds current supply");
        require(currentSupply + amountToBeDistributed <= maxSupply, "Exceeds max supply");

        for (uint256 i = 0; i < _distributions.length; i++) {
            Distribution memory dist = _distributions[i];
            _mintSequential(dist.recipient, dist.amount);
        }
        currentSupply -= amountToBeDistributed;
    }

    function _mintSequential(address to, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            _mint(to, nextTokenId, 1, "");
            console.log("Minted token ID", nextTokenId, "to", to);
            nextTokenId++;
        }
    }

    function getTokensByUser(address user) public view returns (uint256[] memory) {
        return userTokens[user].values();
    }

    function userHasToken(address user, uint256 tokenId) public view returns (bool) {
        return userTokens[user].contains(tokenId);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);

        for (uint256 i = 0; i < ids.length; i++) {
            if (values[i] > 0) {
                if (from != address(0)) {
                    if (balanceOf(from, ids[i]) == values[i]) {
                        userTokens[from].remove(ids[i]);
                    }
                }
                if (to != address(0)) {
                    userTokens[to].add(ids[i]);
                }
            }
        }

        if (from == address(0) || to == address(0)) {
            return;
        }

        if (!transferable) {
            revert("Transfers are not allowed");
        }

        if (whitelistOnly) {
            require(isWhitelisted[_msgSender()], "Sender not whitelisted");
            require(isWhitelisted[to], "Recipient not whitelisted");
        }
    }

    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}