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
import "./vendor/Base.sol";
import "./vendor/Library.sol";
import "./vendor/ReclaimBase.sol";
import "forge-std/console.sol";

contract Ticket is Base, ERC1155, ERC1155Burnable, ERC1155Supply, ReclaimBase {
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

    Library.Stakeholder[] public stakeholders;
    uint256 public totalFeePercentage;
    bool public stakeholdersLocked;
    uint256 public stakeholdersCounter;

    event SupplyUpdated(uint256 newSupply);
    event StakeholderAdded(address wallet, uint256 feePercentage);
    event StakeholderUpdated(address wallet, uint256 feePercentage);
    event StakeholderRemoved(address wallet);
    event StakeholdersLocked();
    event MintedFromProof(uint256 timestamp, address userSmartWalletAddress, string context, string userSmartWalletAddressFromContext);

    constructor(Library.TicketConstructor memory config)
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

        for (uint i = 0; i < config._stakeholders.length; i++) {
            _addStakeholder(
                config._stakeholders[i].wallet,
                config._stakeholders[i].feePercentage
            );
        }

        stakeholdersCounter = config._stakeholders.length;
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

    function _addStakeholder(address payable _wallet, uint256 _feePercentage) internal {
        require(_feePercentage > 0 && _feePercentage <= 10000, "Invalid fee percentage");
        require(totalFeePercentage + _feePercentage <= 10000, "Total fee percentage exceeds 100%");

        for (uint i = 0; i < stakeholders.length; i++) {
            require(stakeholders[i].wallet != _wallet, "Stakeholder already exists");
        }

        stakeholders.push(Library.Stakeholder(_wallet, _feePercentage));
        totalFeePercentage += _feePercentage;
        emit StakeholderAdded(_wallet, _feePercentage);
    }

    function addStakeholder(address payable _wallet, uint256 _feePercentage) public onlyOwner {
        require(!stakeholdersLocked, "Stakeholders are locked");
        _addStakeholder(_wallet, _feePercentage);
    }

    function updateStakeholder(uint256 _index, uint256 _feePercentage) public onlyOwner {
        require(!stakeholdersLocked, "Stakeholders are locked");
        require(_index < stakeholders.length, "Invalid stakeholder index");
        require(_feePercentage > 0 && _feePercentage <= 10000, "Invalid fee percentage");

        uint256 oldFeePercentage = stakeholders[_index].feePercentage;
        require(totalFeePercentage - oldFeePercentage + _feePercentage <= 10000, "Total fee percentage exceeds 100%");

        stakeholders[_index].feePercentage = _feePercentage;
        totalFeePercentage = totalFeePercentage - oldFeePercentage + _feePercentage;
        emit StakeholderUpdated(stakeholders[_index].wallet, _feePercentage);
    }

    function removeStakeholder(uint256 _index) public onlyOwner {
        require(!stakeholdersLocked, "Stakeholders are locked");
        require(_index < stakeholders.length, "Invalid stakeholder index");

        totalFeePercentage -= stakeholders[_index].feePercentage;
        emit StakeholderRemoved(stakeholders[_index].wallet);

        stakeholders[_index] = stakeholders[stakeholders.length - 1];
        stakeholders.pop();
    }

    function _checkWhitelist(address recipient) internal view {
        if (whitelistOnly) {
            require(isWhitelisted[recipient], "Recipient not whitelisted");
        }
    }

    function _checkSupply(uint256 amount) internal view {
        require(currentSupply >= amount, "Exceeds current supply");
        require(currentSupply + amount <= maxSupply, "Exceeds max supply");
    }

    function get() external {
        if (!stakeholdersLocked && nextTokenId > 1) {
            stakeholdersLocked = true;
            emit StakeholdersLocked();
        }
        _checkWhitelist(msg.sender);
        _checkSupply(1);

        if (price == 0) {
            mint(msg.sender);
        } else {
            uint256 callerBalance = erc20Token.balanceOf(msg.sender);
            require(callerBalance >= price, "Insufficient balance");

            uint256 allowedAmount = erc20Token.allowance(msg.sender, address(this));
            require(allowedAmount >= price, "Insufficient allowance");

            require(erc20Token.transferFrom(msg.sender, address(this), price), "Transfer failed");

            uint256 remainingAmount = price;
            for (uint i = 0; i < stakeholders.length; i++) {
                uint256 stakeholderFee = (price * stakeholders[i].feePercentage) / 10000;
                if (stakeholderFee > 0) {
                    require(erc20Token.transfer(stakeholders[i].wallet, stakeholderFee), "Stakeholder fee transfer failed");
                    remainingAmount -= stakeholderFee;
                }
            }

            if (remainingAmount > 0) {
                require(erc20Token.transfer(ownerSmartWallet, remainingAmount), "Owner transfer failed");
            }

            mint(msg.sender);
        }
        nextTokenId++;
    }

    function mint(address recipient) internal {
        if (!stakeholdersLocked && nextTokenId > 1) {
            stakeholdersLocked = true;
            emit StakeholdersLocked();
        }
        _mint(recipient, nextTokenId, 1, "");
        nextTokenId++;
    }

    function verifyProofAndMint(Proof memory proof) public {
        try IReclaimVerifier(0xF90085f5Fd1a3bEb8678623409b3811eCeC5f6A5).verifyProof(proof) {
            string memory context = proof.claimInfo.context;
            string memory userSmartWalletAddressString = extractFieldFromContext(context, '"userSmartWalletAddress":"');
            address userSmartWalletAddress = stringToAddress(userSmartWalletAddressString);
            _checkWhitelist(userSmartWalletAddress);
            _checkSupply(1);
            mint(userSmartWalletAddress);
            emit MintedFromProof(block.timestamp, userSmartWalletAddress, context, userSmartWalletAddressString);
        } catch {
            revert("Proof verification failed");
        }
    }

    function distribute(Distribution[] memory _distributions) public onlyOwner {
        uint256 amountToBeDistributed = 0;
        for (uint256 i = 0; i < _distributions.length; i++) {
            Distribution memory dist = _distributions[i];
            _checkWhitelist(dist.recipient);
            amountToBeDistributed += dist.amount;
        }
        _checkSupply(amountToBeDistributed);

        for (uint256 i = 0; i < _distributions.length; i++) {
            Distribution memory dist = _distributions[i];
            _mintSequential(dist.recipient, dist.amount);
        }
        currentSupply -= amountToBeDistributed;
    }

    function _mintSequential(address recipient, uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            mint(recipient);
            console.log("Minted token ID", nextTokenId, "to", recipient);
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