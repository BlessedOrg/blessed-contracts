// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/Event.sol";

contract DeployEvent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

//        Library.Stakeholder[] memory initialStakeholders = new Library.Stakeholder[](1);
//        initialStakeholders[0] = Library.Stakeholder(payable(deployer), 10000); // 100% fee to start
//
//        Library.StakeholdersConstructor memory stakeholdersConfig = Library.StakeholdersConstructor(initialStakeholders);


        Event eventContract = new Event(
            deployer,
            deployer,
            "Event",
            "https://blessed.fan/example"
//            stakeholdersConfig
        );

        vm.stopBroadcast();

        console.log("USDC deployed at:", address(eventContract));
    }
}