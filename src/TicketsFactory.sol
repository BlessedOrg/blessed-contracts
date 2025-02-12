// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Ticket.sol";
import "./vendor/Library.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TicketsFactory is Ownable(msg.sender) {
    event NewTicketDeployed(address ticketAddress, address ownerSmartWallet);

    function deployTicket(Library.TicketConstructor memory config) external onlyOwner returns (address) {
        Ticket newTicket = new Ticket(config);

        emit NewTicketDeployed(address(newTicket), config._ownerSmartWallet);
        return address(newTicket);
    }
}
