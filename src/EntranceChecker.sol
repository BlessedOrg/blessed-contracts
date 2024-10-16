// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

contract EntranceChecker is Ownable {
    address public ticketAddress;
    bool public isEventFinished;

    struct Entry {
        address wallet;
        uint256 timestamp;
        uint256 ticketId;
    }

    Entry[] public entries;
    mapping(address => bool) private hasEntered;
    mapping(uint256 => bool) private usedTickets;

    event EntryRegistered(address indexed sender, uint256 timestamp, uint256 ticketId);


    constructor(address _ticketAddress, address _owner) Ownable(_owner){
        ticketAddress = _ticketAddress;
    }

    function entry(uint256 _ticketId) external {
        require(!isEventFinished, "Event has finished");
        require(!hasEntered[msg.sender], "Address has already entered");
        require(!usedTickets[_ticketId], "This ticket has been already used");

        IERC1155 nftContract = IERC1155(ticketAddress);
        require(nftContract.balanceOf(msg.sender, _ticketId) > 0, "Caller does not own this ticket");

        entries.push(Entry(msg.sender, block.timestamp, _ticketId));
        hasEntered[msg.sender] = true;
        usedTickets[_ticketId] = true;
        emit EntryRegistered(msg.sender, block.timestamp, _ticketId);
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