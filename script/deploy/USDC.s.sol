// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/USDC.sol";
import "forge-std/Script.sol";

contract DeployUSDC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address recipientAddress = vm.envAddress("USDC_RECIPIENT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        USDC usdc = new USDC(
            "USD Coin",
            "USDC",
            6,
            1_000_000_000 * 10**6, // 1 billion USDC cap
            10_000_000 * 10**6     // 10 million USDC initial supply
        );

        usdc.transfer(recipientAddress, 10_000_000 * 10**6); // Transfer 10 million USDC

        vm.stopBroadcast();

        console.log("USDC deployed at:", address(usdc));
        console.log("10,000,000 USDC sent to:", recipientAddress);
    }
}