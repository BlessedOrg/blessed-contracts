// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/Event.sol";

contract DeployEvent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Event eventContract = new Event(
            deployer,
            deployer,
            "Event",
            "https://blessed.fan/example"
        );

        vm.stopBroadcast();

        console.log("USDC deployed at:", address(eventContract));
    }
}