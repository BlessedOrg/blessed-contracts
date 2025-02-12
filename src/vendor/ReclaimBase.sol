// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
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
    function stringToAddress(string memory _address) public pure returns (address) {
        bytes memory tempBytes = bytes(_address);
        require(tempBytes.length == 42, "Invalid address length");

        bytes20 addrBytes;
        for (uint i = 2; i < 42; i++) {
            uint8 digit = uint8(tempBytes[i]);
            if (digit >= 48 && digit <= 57) {
                digit -= 48;
            } else if (digit >= 65 && digit <= 70) {
                digit -= 55;
            } else if (digit >= 97 && digit <= 102) {
                digit -= 87;
            } else {
                revert("Invalid address character");
            }
            addrBytes |= bytes20(uint160(digit) << (4 * uint160(41 - i)));
        }

        return address(uint160(addrBytes));
    }

    function extractFieldFromContext(
        string memory data,
        string memory target
    ) public pure returns (string memory) {
        bytes memory dataBytes = bytes(data);
        bytes memory targetBytes = bytes(target);

        require(dataBytes.length >= targetBytes.length, "target is longer than data");
        uint start = 0;
        bool foundStart = false;

        for (uint i = 0; i <= dataBytes.length - targetBytes.length; i++) {
            bool isMatch = true;

            for (uint j = 0; j < targetBytes.length && isMatch; j++) {
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

        uint end = start;
        while (
            end < dataBytes.length &&
            !(dataBytes[end] == '"' && dataBytes[end - 1] != "\\")
        ) {
            end++;
        }

        if (end <= start || !(dataBytes[end] == '"' && dataBytes[end - 1] != "\\")) {
            return "";
        }

        bytes memory contextMessage = new bytes(end - start);
        for (uint i = start; i < end; i++) {
            contextMessage[i - start] = dataBytes[i];
        }
        return string(contextMessage);
    }
}