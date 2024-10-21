// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/EntranceChecker.sol";

contract DeployEntranceChecker is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Address for the owner's smart wallet
        address ownerSmartWallet = 0x1234567890123456789012345678901234567890; // Replace with actual address

        // Address of the ticket contract
        address ticketAddress = 0x0987654321098765432109876543210987654321; // Replace with actual address

        // Chain ID for the network you're deploying to (e.g., Base Sepolia)
        uint256 targetChainId = 84532; // Replace with the actual chain ID you're targeting

        // Ensure we're on the correct network
        require(block.chainid == targetChainId, "Not on the correct network");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the EntranceChecker contract
        EntranceChecker entranceChecker = new EntranceChecker(
            ownerSmartWallet,
            ticketAddress,
            deployer
        );

        vm.stopBroadcast();

        console.log("EntranceChecker deployed to:", address(entranceChecker));
        console.log("Owner Smart Wallet:", ownerSmartWallet);
        console.log("Ticket Address:", ticketAddress);
        console.log("Owner:", deployer);
    }
}