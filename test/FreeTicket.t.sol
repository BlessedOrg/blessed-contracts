// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/FreeTicket.sol";

contract FreeTicketTest is Test {
    FreeTicket public freeTicket;
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
        freeTicket = new FreeTicket(
            owner,
            "https://ipfs.io/ipfs/",
            "Base Sepolia Ticket",
            "BST",
            0,  // Set initialSupply to 0 for this test
            10000,
            true,  // Set transferable to true
            true   // Set whitelistOnly to true
        );
        vm.stopPrank();
    }

    function testDeployAndDistribute() public {
        vm.startPrank(owner);  // Set msg.sender to owner for the next calls

        // Add three wallets to whitelist
        address[] memory whitelistAddresses = new address[](3);
        whitelistAddresses[0] = user1;
        whitelistAddresses[1] = user2;
        whitelistAddresses[2] = user3;
        freeTicket.updateWhitelist(whitelistAddresses, true);

        // Prepare distribution data
        FreeTicket.Distribution[] memory distributions = new FreeTicket.Distribution[](3);
        distributions[0] = FreeTicket.Distribution(user1, 1);
        distributions[1] = FreeTicket.Distribution(user2, 2);
        distributions[2] = FreeTicket.Distribution(user3, 3);

        // Call distribute
        freeTicket.distribute(distributions);

        vm.stopPrank();

        // Check balances and calculate totals
        uint256 user1Total = 0;
        uint256 user2Total = 0;
        uint256 user3Total = 0;

        // User1 checks
        assertEq(freeTicket.balanceOf(user1, 1), 1, "User1 should have 1 ticket with ID 1");
        user1Total += freeTicket.balanceOf(user1, 1);

        // User2 checks
        assertEq(freeTicket.balanceOf(user2, 2), 1, "User2 should have 1 ticket with ID 2");
        assertEq(freeTicket.balanceOf(user2, 3), 1, "User2 should have 1 ticket with ID 3");
        user2Total += freeTicket.balanceOf(user2, 2);
        user2Total += freeTicket.balanceOf(user2, 3);

        // User3 checks
        assertEq(freeTicket.balanceOf(user3, 4), 1, "User3 should have 1 ticket with ID 4");
        assertEq(freeTicket.balanceOf(user3, 5), 1, "User3 should have 1 ticket with ID 5");
        assertEq(freeTicket.balanceOf(user3, 6), 1, "User3 should have 1 ticket with ID 6");
        user3Total += freeTicket.balanceOf(user3, 4);
        user3Total += freeTicket.balanceOf(user3, 5);
        user3Total += freeTicket.balanceOf(user3, 6);

        // Assert that users don't have tokens they shouldn't have
        assertEq(freeTicket.balanceOf(user1, 2), 0, "User1 should not have a ticket with ID 2");
        assertEq(freeTicket.balanceOf(user2, 1), 0, "User2 should not have a ticket with ID 1");
        assertEq(freeTicket.balanceOf(user2, 4), 0, "User2 should not have a ticket with ID 4");
        assertEq(freeTicket.balanceOf(user3, 1), 0, "User3 should not have a ticket with ID 1");
        assertEq(freeTicket.balanceOf(user3, 3), 0, "User3 should not have a ticket with ID 3");

        // Assert total balances
        assertEq(user1Total, 1, "User1 should have 1 ticket in total");
        assertEq(user2Total, 2, "User2 should have 2 tickets in total");
        assertEq(user3Total, 3, "User3 should have 3 tickets in total");

        // Assert next token ID
        assertEq(freeTicket.nextTokenId(), 7, "Next token ID should be 7");

        // Assert current supply
        assertEq(freeTicket.currentSupply(), 6, "Current supply should be 6");
    }
}