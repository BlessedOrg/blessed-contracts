// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "./Base.sol";
import "./vendor/Library.sol";
import "forge-std/console.sol";

contract Ticket is Base, ERC1155, ERC1155Burnable, ERC1155Supply {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;

    address public eventAddress;
    address public erc20Address;
    IERC20 public erc20Token;
    string public symbol;
    uint256 public initialSupply;
    uint256 public maxSupply;
    uint256 public currentSupply;
    bool public transferable;
    bool public whitelistOnly;
    uint256 public nextTokenId = 1;
    uint256 public price = 0;
    mapping(address => EnumerableSet.UintSet) private userTokens;
    EnumerableSet.AddressSet private ticketHolders;
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

    constructor
    (Library.TicketConstructor memory config)
    Base(config._owner, config._ownerSmartWallet, config._name)
    ERC1155(config._baseURI) {
        require(config._initialSupply <= config._maxSupply, "Initial supply exceeds max supply");
        ownerSmartWallet = config._ownerSmartWallet;
        name = config._name;
        symbol = config._symbol;
        eventAddress = config._eventAddress;
        erc20Address = config._erc20Address;
        erc20Token = IERC20(config._erc20Address);
        price = config._price;
        initialSupply = config._initialSupply;
        maxSupply = config._maxSupply;
        currentSupply = config._initialSupply;
        transferable = config._transferable;
        whitelistOnly = config._whitelistOnly;
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

    function get() external {
        address caller = msg.sender;

        if (price == 0) {
            _mint(caller, nextTokenId, 1, "");
        } else {
            uint256 callerBalance = erc20Token.balanceOf(caller);
            require(callerBalance >= price, "Insufficient balance");

            uint256 allowedAmount = erc20Token.allowance(caller, address(this));
            require(allowedAmount >= price, "Insufficient allowance");

            require(erc20Token.transferFrom(caller, ownerSmartWallet, price), "Transfer failed");
            _mint(caller, nextTokenId, 1, "");
        }
        nextTokenId++;
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

    function getTicketHolders(uint256 start, uint256 pageSize) public view returns (address[] memory) {
        uint256 totalHolders = ticketHolders.length();
        uint256 end = start + pageSize;
        if (end > totalHolders) {
            end = totalHolders;
        }

        address[] memory holders = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            holders[i - start] = ticketHolders.at(i);
        }

        return holders;
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
                    if (balanceOf(from, ids[i]) == 0) {
                        userTokens[from].remove(ids[i]);
                        if (userTokens[from].length() == 0) {
                            ticketHolders.remove(from);
                        }
                    }
                }
                if (to != address(0)) {
                    userTokens[to].add(ids[i]);
                    ticketHolders.add(to);
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
}