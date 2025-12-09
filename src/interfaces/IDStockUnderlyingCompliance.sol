// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  IDStockUnderlyingCompliance
 * @notice Compliance interface for DStockUnderlying
 * @dev    Implementation reverts if user is non-compliant
 */
interface IDStockUnderlyingCompliance {
    /**
     * @notice Checks whether a user is compliant, reverting if not
     * @param user Wallet being checked
     */
    function checkIsCompliant(address user) external view;
}
