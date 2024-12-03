// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Base is Ownable {
    address public ownerSmartWallet;
    string public name;

    event SmartWalletUpdated(address indexed previousWallet, address indexed newWallet);

    constructor(
        address _owner,
        address _ownerSmartWallet,
        string memory _name
    ) Ownable(_owner) {
        require(_ownerSmartWallet != address(0), "Invalid wallet address");
        ownerSmartWallet = _ownerSmartWallet;
        name = _name;
    }

    function _checkOwner() internal view override {
        require(owner() == _msgSender() || ownerSmartWallet == _msgSender(), "Not owner");
    }

    function setSmartWallet(address _smartWallet) external onlyOwner {
        require(_smartWallet != address(0), "Invalid smart wallet address");
        address oldWallet = ownerSmartWallet;
        ownerSmartWallet = _smartWallet;
        emit SmartWalletUpdated(oldWallet, _smartWallet);
    }
}