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

struct ClaimInfo {
    string provider;
    string parameters;
    string context;
}

struct Claim {
    bytes32 identifier;
    address owner;
    uint32 timestampS;
    uint32 epoch;
}

struct SignedClaim {
    Claim claim;
    bytes[] signatures;
}

struct Proof {
    ClaimInfo claimInfo;
    SignedClaim signedClaim;
}

interface IReclaimVerifier {
    function verifyProof(Proof memory proof) external view;
}

contract ReclaimBase {
    function stringToAddress(string memory _addressString) public pure returns (address) {
        bytes memory _addressBytes = bytes(_addressString);

        // Check if the string has the correct length for an Ethereum address (42 characters, including '0x')
        require(_addressBytes.length == 42, "Invalid address length");

        // Check if the string starts with '0x'
        require(_addressBytes[0] == '0' && _addressBytes[1] == 'x', "Address must start with 0x");

        // Convert the string to bytes32
        bytes32 _parsedBytes;
        assembly {
            _parsedBytes := mload(add(_addressBytes, 32))
        }

        // Convert bytes32 to address
        return address(uint160(uint256(_parsedBytes)));
    }

    function extractFieldFromContext(string memory _data, string memory target) public pure returns (string memory) {
        bytes memory dataBytes = bytes(_data);
        bytes memory targetBytes = bytes(target);

        require(
            dataBytes.length >= targetBytes.length,
            "target is longer than data"
        );

        uint256 start = 0;
        bool foundStart = false;

        for (uint256 i = 0; i <= dataBytes.length - targetBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < targetBytes.length && isMatch; j++) {
                if (dataBytes[i + j] != targetBytes[j]) {
                    isMatch = false;
                }
            }
            if (isMatch) {
                start = i + targetBytes.length;
                foundStart = true;
                break;
            }
        }

        if (!foundStart) {
            return "";
        }

        uint256 end = start;
        while (
            end < dataBytes.length &&
            !(dataBytes[end] == '"' && (end == 0 || dataBytes[end - 1] != "\\"))
        ) {
            end++;
        }

        if (end <= start) {
            return "";
        }

        bytes memory contextMessage = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            contextMessage[i - start] = dataBytes[i];
        }
        return string(contextMessage);
    }
}