// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Ticket.sol";

contract TicketTest is Test {
    Ticket public ticket;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        owner = vm.addr(1);  // Create a valid address for the owner
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);

        vm.startPrank(owner);  // Set msg.sender to owner for the next calls

        address wallet1 = 0x1234567890123456789012345678901234567890;
        address wallet2 = 0x0987654321098765432109876543210987654321;
        Library.Stakeholder[] memory initialStakeholders = new Library.Stakeholder[](2);
        initialStakeholders[0] = Library.Stakeholder(payable(wallet1), 500); // 5% fee
        initialStakeholders[1] = Library.Stakeholder(payable(wallet2), 300); // 3% fee

        Library.TicketConstructor memory config = Library.TicketConstructor({
            _owner: owner,
            _ownerSmartWallet: owner,
            _eventAddress: owner,
            _baseURI: "https://ipfs.io/ipfs/",
            _name: "Base Sepolia Ticket",
            _symbol: "BST",
            _erc20Address: 0xbF57aEA664aEAf70C9C82fF1355739CDf917119d,
            _price: 1000,
            _initialSupply: 0,  // Set initialSupply to 0 for this test
            _maxSupply: 10000,
            _transferable: true,  // Set transferable to true
            _whitelistOnly: true,   // Set whitelistOnly to true
            _stakeholders: initialStakeholders
        });

        // Deploy the contract with the config struct
        ticket = new Ticket(config);

        vm.stopPrank();
    }

    function testDeployAndDistribute() public {
        vm.startPrank(owner);  // Set msg.sender to owner for the next calls

        // Add three wallets to whitelist
        Ticket.Whitelist[] memory whitelistUpdates = new Ticket.Whitelist[](3);
        whitelistUpdates[0] = Ticket.Whitelist(user1, true);
        whitelistUpdates[1] = Ticket.Whitelist(user2, true);
        whitelistUpdates[2] = Ticket.Whitelist(user3, true);
        ticket.updateWhitelist(whitelistUpdates);

        // Prepare distribution data
        Ticket.Distribution[] memory distributions = new Ticket.Distribution[](3);
        distributions[0] = Ticket.Distribution(user1, 1);
        distributions[1] = Ticket.Distribution(user2, 2);
        distributions[2] = Ticket.Distribution(user3, 3);

        // Call distribute
        ticket.distribute(distributions);

        vm.stopPrank();

        // Check balances and calculate totals
        uint256 user1Total = 0;
        uint256 user2Total = 0;
        uint256 user3Total = 0;

        // User1 checks
        assertEq(ticket.balanceOf(user1, 1), 1, "User1 should have 1 ticket with ID 1");
        user1Total += ticket.balanceOf(user1, 1);

        // User2 checks
        assertEq(ticket.balanceOf(user2, 2), 1, "User2 should have 1 ticket with ID 2");
        assertEq(ticket.balanceOf(user2, 3), 1, "User2 should have 1 ticket with ID 3");
        user2Total += ticket.balanceOf(user2, 2);
        user2Total += ticket.balanceOf(user2, 3);

        // User3 checks
        assertEq(ticket.balanceOf(user3, 4), 1, "User3 should have 1 ticket with ID 4");
        assertEq(ticket.balanceOf(user3, 5), 1, "User3 should have 1 ticket with ID 5");
        assertEq(ticket.balanceOf(user3, 6), 1, "User3 should have 1 ticket with ID 6");
        user3Total += ticket.balanceOf(user3, 4);
        user3Total += ticket.balanceOf(user3, 5);
        user3Total += ticket.balanceOf(user3, 6);

        // Assert that users don't have tokens they shouldn't have
        assertEq(ticket.balanceOf(user1, 2), 0, "User1 should not have a ticket with ID 2");
        assertEq(ticket.balanceOf(user2, 1), 0, "User2 should not have a ticket with ID 1");
        assertEq(ticket.balanceOf(user2, 4), 0, "User2 should not have a ticket with ID 4");
        assertEq(ticket.balanceOf(user3, 1), 0, "User3 should not have a ticket with ID 1");
        assertEq(ticket.balanceOf(user3, 3), 0, "User3 should not have a ticket with ID 3");

        // Assert total balances
        assertEq(user1Total, 1, "User1 should have 1 ticket in total");
        assertEq(user2Total, 2, "User2 should have 2 tickets in total");
        assertEq(user3Total, 3, "User3 should have 3 tickets in total");

        // Assert next token ID
        assertEq(ticket.nextTokenId(), 7, "Next token ID should be 7");

        // Assert current supply
        assertEq(ticket.currentSupply(), 6, "Current supply should be 6");
    }
}