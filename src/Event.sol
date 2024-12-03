// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "./vendor/Base.sol";

contract Event is Base {
    string public uri;
    mapping(address => bool) public tickets;
    uint256 public ticketCounter;
    bool public isEventFinished;
    mapping(address => mapping(uint256 => bool)) private usedTickets;
    mapping(address => bool) public bouncers;

    struct Entry {
        address wallet;
        uint256 timestamp;
        uint256 ticketId;
        address ticketAddress;
    }

    Entry[] public entries;

    event Entrance(address indexed attendeeAddress, uint256 timestamp, uint256 ticketId, address ticketAddress);
    event TicketAdded(address indexed ticketAddress);
    event EventFinished(uint256 indexed timestamp);
    event BouncerAdded(address indexed bouncer);
    event BouncerRemoved(address indexed bouncer);

    constructor(
        address _owner,
        address _ownerSmartWallet,
        string memory _name,
        string memory _uri,
        address[] memory _initialBouncers
    ) Base(_owner, _ownerSmartWallet, _name) {
        uri = _uri;
        for (uint i = 0; i < _initialBouncers.length; i++) {
            bouncers[_initialBouncers[i]] = true;
            emit BouncerAdded(_initialBouncers[i]);
        }
    }

    modifier onlyBouncer() {
        require(bouncers[msg.sender], "Caller is not a bouncer");
        _;
    }

    function setURI(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    function addTicket(address ticket) public onlyOwner {
        require(!tickets[ticket], "Ticket already added");
        tickets[ticket] = true;
        ticketCounter++;
        emit TicketAdded(ticket);
    }

    function addBouncer(address _bouncer) public onlyOwner {
        require(!bouncers[_bouncer], "Address is already a bouncer");
        bouncers[_bouncer] = true;
        emit BouncerAdded(_bouncer);
    }

    function removeBouncer(address _bouncer) public onlyOwner {
        require(bouncers[_bouncer], "Address is not a bouncer");
        bouncers[_bouncer] = false;
        emit BouncerRemoved(_bouncer);
    }

    function entry(uint256 _ticketId, address _ticketAddress, address _attendeeAddress) external onlyBouncer {
        require(!isEventFinished, "Event has finished");
        require(!usedTickets[_ticketAddress][_ticketId], "This ticket has been already used");
        require(tickets[_ticketAddress], "Invalid ticket address");

        IERC1155 nftContract = IERC1155(_ticketAddress);
        require(nftContract.balanceOf(_attendeeAddress, _ticketId) > 0, "Attendee does not own this ticket");

        entries.push(Entry(_attendeeAddress, block.timestamp, _ticketId, _ticketAddress));
        usedTickets[_ticketAddress][_ticketId] = true;
        emit Entrance(_attendeeAddress, block.timestamp, _ticketId, _ticketAddress);
    }

    function isTicketUsed(address _ticketAddress, uint256 _ticketId) external view returns (bool) {
        return usedTickets[_ticketAddress][_ticketId];
    }

    function finishEvent() external onlyOwner {
        isEventFinished = true;
        emit EventFinished(block.timestamp);
    }

    function getEntries() external view returns (Entry[] memory) {
        return entries;
    }
}
