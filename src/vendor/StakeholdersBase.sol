// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../../lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "./Base.sol";
import "./Library.sol";
import "forge-std/console.sol";

// 🏗️ it may be deleted or used as a replacement of our Base contract (so we can include stakeholders in the Event contract as well)
contract StakeholdersBase is Base {
    Library.Stakeholder[] public stakeholders;
    uint256 public totalFeePercentage;
    uint256 public stakeholdersCounter;

    event StakeholderAdded(address wallet, uint256 feePercentage);

    constructor(
        address _owner,
        address _ownerSmartWallet,
        string memory _name,
        Library.StakeholdersConstructor memory _stakeholdersConfig
    ) Base(_owner, _ownerSmartWallet, _name) {
        for (uint i = 0; i < _stakeholdersConfig._stakeholders.length; i++) {
            _addStakeholder(
                _stakeholdersConfig._stakeholders[i].wallet,
                _stakeholdersConfig._stakeholders[i].feePercentage
            );
        }

        stakeholdersCounter = _stakeholdersConfig._stakeholders.length;
    }

    function _addStakeholder(address payable _wallet, uint256 _feePercentage) internal {
        require(_feePercentage > 0 && _feePercentage <= 10000, "Invalid fee percentage");
        require(totalFeePercentage + _feePercentage <= 10000, "Total fee percentage exceeds 100%");

        for (uint i = 0; i < stakeholders.length; i++) {
            require(stakeholders[i].wallet != _wallet, "Stakeholder already exists");
        }

        stakeholders.push(Library.Stakeholder(_wallet, _feePercentage));
        totalFeePercentage += _feePercentage;
        emit StakeholderAdded(_wallet, _feePercentage);
    }

    function getStakeholders() public view returns (Library.Stakeholder[] memory) {
        return stakeholders;
    }
}
