// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "forge-std/console.sol";

contract FreeTicket is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply {
    using Strings for uint256;

    string public name;
    string public symbol;
    uint256 public initialSupply;
    uint256 public maxSupply;
    bool public transferable;
    bool public whitelistOnly;

    uint256 public nextTokenId = 1;
    uint256 public currentSupply;

    mapping(address => bool) public isWhitelisted;

    struct Distribution {
        address recipient;
        uint256 amount;
    }

    constructor(
        address owner,
        string memory baseURI,
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        uint256 _maxSupply,
        bool _transferable,
        bool _whitelistOnly
    ) ERC1155(baseURI) Ownable(owner) {
        name = _name;
        symbol = _symbol;
        initialSupply = _initialSupply;
        maxSupply = _maxSupply;
        transferable = _transferable;
        whitelistOnly = _whitelistOnly;
        currentSupply = 0;

        // _mintSequential(owner, _initialSupply);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        return string(abi.encodePacked(uri(_tokenId), _tokenId.toString()));
    }

    function increaseSupply(uint256 _amount) public onlyOwner {
        require(currentSupply + _amount <= maxSupply, "Exceeds max supply");
        _mintSequential(msg.sender, _amount);
    }

    function updateWhitelist(address[] memory _addresses, bool _status) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            isWhitelisted[_addresses[i]] = _status;
        }
    }

    function setTransferable(bool _transferable) public onlyOwner {
        transferable = _transferable;
    }

    function distribute(Distribution[] memory _distributions) public onlyOwner {
        for (uint256 i = 0; i < _distributions.length; i++) {
            Distribution memory dist = _distributions[i];
            if (whitelistOnly) {
                require(isWhitelisted[dist.recipient], "Recipient not whitelisted");
            }
            require(currentSupply + dist.amount <= maxSupply, "Exceeds max supply");
            _mintSequential(dist.recipient, dist.amount);
        }
    }

    function _mintSequential(address to, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            _mint(to, nextTokenId, 1, "");
            console.log("Minted token ID", nextTokenId, "to", to);
            nextTokenId++;
        }
        currentSupply += amount;
        console.log("Current supply after mint:", currentSupply);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);

        if (from == address(0) || to == address(0)) {
            return;
        }

        if (!transferable) {
            revert("Transfers are not allowed");
        }

        if (whitelistOnly) {
            require(isWhitelisted[to], "Recipient not whitelisted");
        }
    }
}