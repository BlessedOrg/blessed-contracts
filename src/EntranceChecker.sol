// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";

contract EntranceChecker is Ownable {
    address public ownerSmartWallet;
    address public ticketAddress;
    bool public isEventFinished;
    mapping(address => bool) private hasEntered;
    mapping(uint256 => bool) private usedTickets;

    struct Entry {
        address wallet;
        uint256 timestamp;
        uint256 ticketId;
    }

    Entry[] public entries;

    event Entrance  (address indexed sender, uint256 timestamp, uint256 ticketId);

    constructor(
        address _owner,
        address _ownerSmartWallet,
        address _ticketAddress
    ) Ownable(_owner) {
        ticketAddress = _ticketAddress;
        ownerSmartWallet = _ownerSmartWallet;
    }

    function _checkOwner() internal view override {
        require(owner() == _msgSender() || ownerSmartWallet == _msgSender(), "Not owner");
    }

    function setSmartWallet(address _smartWallet) external onlyOwner {
        ownerSmartWallet = _smartWallet;
    }

    function entry(uint256 _ticketId) external {
        address sender = _msgSender();
        require(!isEventFinished, "Event has finished");
        require(!hasEntered[sender], "Address has already entered");
        require(!usedTickets[_ticketId], "This ticket has been already used");

        IERC1155 nftContract = IERC1155(ticketAddress);
        require(nftContract.balanceOf(sender, _ticketId) > 0, "Caller does not own this ticket");

        entries.push(Entry(sender, block.timestamp, _ticketId));
        hasEntered[sender] = true;
        usedTickets[_ticketId] = true;
        emit Entrance   (sender, block.timestamp, _ticketId);
    }

    function hasEntry(address _address) external view returns (bool) {
        return hasEntered[_address];
    }

    function finishEvent() public onlyOwner {
        isEventFinished = true;
    }

    function getEntries() external view returns (Entry[] memory) {
        return entries;
    }

    function getTicketAddress() external view returns (address) {
        return ticketAddress;
    }
}