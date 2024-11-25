// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Base.sol";

contract Event is Base {
    string public uri;
    address[] public tickets;
    uint256 public ticketCounter;

    constructor(
        address _owner,
        address _ownerSmartWallet,
        string memory _name,
        string memory _uri
    ) Base(_owner, _ownerSmartWallet, _name) {
        uri = _uri;
    }

    function setURI(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    function addTicket(address ticket) public onlyOwner {
        tickets.push(ticket);
        ticketCounter++;
    }
}