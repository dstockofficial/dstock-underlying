// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDStockUnderlyingCompliance} from "./interfaces/IDStockUnderlyingCompliance.sol";

/**
 * @title  DStockUnderlyingCompliance
 * @notice Compliance module dedicated to DStockUnderlying:
 *         - Binds to a single underlyingToken
 *         - Supports whitelist / blacklist controls
 *         - Can require users to be on the whitelist before transferring
 */
contract DStockUnderlyingCompliance is IDStockUnderlyingCompliance, Ownable {
    /// @notice Underlying asset token (usually the DStockUnderlying proxy)
    address public immutable underlyingToken;

    /// @notice Whether whitelist mode is enforced:
    ///         - false: default allow, blacklist users are blocked
    ///         - true: only whitelisted users are allowed, everyone else blocked
    bool public whitelistRequired;

    /// @notice Whitelist mapping; true means the user is allowed
    mapping(address => bool) public whitelisted;

    /// @notice Blacklist mapping; true means the user is blocked
    mapping(address => bool) public blacklisted;

    event WhitelistRequiredSet(bool oldValue, bool newValue);
    event WhitelistUpdated(address indexed user, bool allowed);
    event BlacklistUpdated(address indexed user, bool blocked);

    error NotUnderlyingCaller();
    error NotCompliant(address user);
    error InvalidUnderlyingToken();
    error InvalidOwner();

    /**
     * @param _underlyingToken DStockUnderlying proxy address
     * @param _owner           Owner of the compliance module (ideally a Safe multisig)
     */
    constructor(address _underlyingToken, address _owner) Ownable(_owner) {
        if (_underlyingToken == address(0)) {
            revert InvalidUnderlyingToken();
        }
        if (_owner == address(0)) {
            revert InvalidOwner();
        }

        underlyingToken = _underlyingToken;
    }

    modifier onlyUnderlying() {
        if (msg.sender != underlyingToken) {
            revert NotUnderlyingCaller();
        }
        _;
    }

    /// @notice Toggle whether whitelist is mandatory
    function setWhitelistRequired(bool required) external onlyOwner {
        emit WhitelistRequiredSet(whitelistRequired, required);
        whitelistRequired = required;
    }

    /// @notice Batch update whitelist entries
    function setWhitelist(address[] calldata users, bool allowed) external onlyOwner {
        uint256 len = users.length;
        for (uint256 i = 0; i < len; ) {
            whitelisted[users[i]] = allowed;
            // If adding to whitelist, automatically remove from blacklist
            if (allowed) {
                delete blacklisted[users[i]];
            }
            emit WhitelistUpdated(users[i], allowed);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Batch update blacklist entries
    function setBlacklist(address[] calldata users, bool blocked) external onlyOwner {
        uint256 len = users.length;
        for (uint256 i = 0; i < len; ) {
            blacklisted[users[i]] = blocked;
            // If adding to blacklist, automatically remove from whitelist
            if (blocked) {
                delete whitelisted[users[i]];
            }
            emit BlacklistUpdated(users[i], blocked);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Compliance entry point callable by DStockUnderlying
     * @dev    Restricted to the underlyingToken. Reverts if user is non-compliant.
     * @param  user Address to check compliance for
     */
    function checkIsCompliant(address user) external view override onlyUnderlying {
        if (blacklisted[user]) {
            revert NotCompliant(user);
        }

        if (whitelistRequired && !whitelisted[user]) {
            revert NotCompliant(user);
        }
    }
}
