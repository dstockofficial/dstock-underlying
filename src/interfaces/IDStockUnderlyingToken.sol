// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title  IDStockUnderlyingToken
 * @notice Minimal interface for DStockUnderlying, used by the factory
 * @dev    Exposes only the initialize function required for proxy deployment
 */
interface IDStockUnderlyingToken {
    /**
     * @notice Initialize the underlying token (called only once via proxy)
     * @param name_        Initial name
     * @param symbol_      Initial symbol
     * @param decimals_    Token decimals
     * @param admin        Default admin (multisig / Safe)
     * @param compliance_  Compliance contract (optional; zero disables compliance)
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin,
        address compliance_
    ) external;
}
