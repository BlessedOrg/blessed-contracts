// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/Ticket.sol";

contract DeployTicket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Addresses to whitelist and distribute tickets to
        // address wallet1 = 0x1234567890123456789012345678901234567890; // Replace with actual address
        // address wallet2 = 0x0987654321098765432109876543210987654321; // Replace with actual address

        // Chain ID for Base Sepolia
        uint256 baseSepolia = 84532;

        // Ensure we're on the correct network
        require(block.chainid == baseSepolia, "Not on Base Sepolia");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FreeTicket contract
        Ticket freeTicket = new Ticket(
            deployer,
            deployer,
            "https://ipfs.io/ipfs/",
            "Base Sepolia Ticket",
            "A test ticket for Base Sepolia",
            0xbF57aEA664aEAf70C9C82fF1355739CDf917119d,
            1000,
            10000,
            100000,
            true,  // Set transferable to true
            true   // Set whitelistOnly to true
        );

        // Whitelist the two wallets
        // FreeTicket.Whitelist[] memory whitelistUpdates = new FreeTicket.Whitelist[](2);
        // whitelistUpdates[0] = FreeTicket.Whitelist(wallet1, true);
        // whitelistUpdates[1] = FreeTicket.Whitelist(wallet2, true);
        // freeTicket.updateWhitelist(whitelistUpdates);

        // Prepare distribution data
        //  FreeTicket.Distribution[] memory distributions = new FreeTicket.Distribution[](2);
        //  distributions[0] = FreeTicket.Distribution(wallet1, 5); // Distribute 5 tickets to wallet1
        //  distributions[1] = FreeTicket.Distribution(wallet2, 10); // Distribute 10 tickets to wallet2

        // Distribute tickets
        // freeTicket.distribute(distributions);

        vm.stopBroadcast();

        console.log("FreeTicket deployed to:", address(freeTicket));
        console.log("Tickets distributed to wallet1 and wallet2");
    }
}