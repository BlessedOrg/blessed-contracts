// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/TicketsFactory.sol";

contract DeployTicketsFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TicketsFactory factory = new TicketsFactory();

        vm.stopBroadcast();

        console.log("TicketFactory deployed to:", address(factory));
        console.log("Owner set to:", deployer);
    }
}
