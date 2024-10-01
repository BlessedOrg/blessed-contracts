// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/FreeTicket.sol";

contract DeployFreeTicket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Addresses to whitelist and distribute tickets to
        address wallet1 = 0x1234567890123456789012345678901234567890; // Replace with actual address
        address wallet2 = 0x0987654321098765432109876543210987654321; // Replace with actual address

        // Chain ID for Base Sepolia
        uint256 baseSepolia = 84532;

        // Ensure we're on the correct network
        require(block.chainid == baseSepolia, "Not on Base Sepolia");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FreeTicket contract
        FreeTicket freeTicket = new FreeTicket(
            deployer,
            "https://ipfs.io/ipfs/",
            "Base Sepolia Ticket",
            "A test ticket for Base Sepolia",
            1000,
            10000,
            true,  // Set transferable to true
            true   // Set whitelistOnly to true
        );

        // Whitelist the two wallets
        address[] memory whitelistAddresses = new address[](2);
        whitelistAddresses[0] = wallet1;
        whitelistAddresses[1] = wallet2;
        freeTicket.updateWhitelist(whitelistAddresses, true);

        // Prepare distribution data
        FreeTicket.Distribution[] memory distributions = new FreeTicket.Distribution[](2);
        distributions[0] = FreeTicket.Distribution(wallet1, 5); // Distribute 5 tickets to wallet1
        distributions[1] = FreeTicket.Distribution(wallet2, 10); // Distribute 10 tickets to wallet2

        // Distribute tickets
        freeTicket.distribute(distributions);

        vm.stopBroadcast();

        console.log("FreeTicket deployed to:", address(freeTicket));
        console.log("Tickets distributed to wallet1 and wallet2");
    }
}