// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/Event.sol";

contract DeployEvent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Generate a random address for the initial bouncer
        uint256 randomPrivateKey = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        address randomBouncer = vm.addr(randomPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        address[] memory initialBouncers = new address[](1);
        initialBouncers[0] = randomBouncer; // Use the random address as the initial bouncer

        Event eventContract = new Event(
            deployer,
            deployer,
            "Event",
            "https://blessed.fan/example",
            initialBouncers
        );

        vm.stopBroadcast();

        console.log("Event contract deployed at:", address(eventContract));
        console.log("Initial bouncer address:", randomBouncer);
    }
}