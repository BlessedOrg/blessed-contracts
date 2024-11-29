// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Library {
    struct Stakeholder {
        address payable wallet;
        uint256 feePercentage;
    }

    struct StakeholdersConstructor {
        Stakeholder[] _stakeholders;
    }

    struct TicketConstructor {
        address _owner;
        address _ownerSmartWallet;
        address _eventAddress;
        string _baseURI;
        string _name;
        string _symbol;
        address _erc20Address;
        uint256 _price;
        uint256 _initialSupply;
        uint256 _maxSupply;
        bool _transferable;
        bool _whitelistOnly;
        Stakeholder[] _stakeholders;
    }
}