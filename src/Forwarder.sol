// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Forwarder.sol";

contract BlessedERC2771Forwarder is ERC2771Forwarder {
    constructor() ERC2771Forwarder("Blessed ERC2771 Forwarder") {}
}