// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../src/Forwarder.sol";
import "forge-std/Script.sol";

contract DeployForwarder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BlessedERC2771Forwarder forwarder = new BlessedERC2771Forwarder();

        console.log("ERC2771Forwarder deployed at:", address(forwarder));

        vm.stopBroadcast();
    }
}