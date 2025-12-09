// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IDStockUnderlyingToken.sol";

/// @title  DStockUnderlyingFactory
/// @notice Manages an UpgradeableBeacon and deploys multiple DStockUnderlying instances
contract DStockUnderlyingFactory is  AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Beacon shared by all DStockUnderlying proxies
    UpgradeableBeacon public underlyingBeacon;

    event UnderlyingCreated(
        address indexed proxy,
        string name,
        string symbol,
        uint8 decimals,
        address admin,
        address compliance
    );

    event ImplementationUpgraded(address oldImpl, address newImpl);

    error ZeroAddress();
    error InvalidImplementation();

    /**
     * @param impl   Initial implementation contract address
     * @param admin  Admin address that will receive all roles
     */
    constructor(address impl, address admin) {
        if (impl == address(0)) revert InvalidImplementation();
        if (admin == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        // Factory is the beacon owner to enable upgradeTo calls
        underlyingBeacon = new UpgradeableBeacon(impl, address(this));
    }

    /**
     * @notice Creates a new DStockUnderlying instance (BeaconProxy)
     * @param name_       Token name
     * @param symbol_     Token symbol
     * @param decimals_   Token decimals
     * @param admin       Admin for the instance (DEFAULT_ADMIN_ROLE)
     * @param compliance  Compliance module (DStockUnderlyingCompliance, optional)
     */
    function createUnderlying(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin,
        address compliance
    ) external onlyRole(DEPLOYER_ROLE) returns (address) {
        if (admin == address(0)) revert ZeroAddress();
        bytes memory data = abi.encodeWithSelector(
            IDStockUnderlyingToken.initialize.selector,
            name_,
            symbol_,
            decimals_,
            admin,
            compliance
        );

        BeaconProxy proxy = new BeaconProxy(
            address(underlyingBeacon),
            data
        );

        emit UnderlyingCreated(
            address(proxy),
            name_,
            symbol_,
            decimals_,
            admin,
            compliance
        );

        return address(proxy);
    }

    /**
     * @notice Upgrade the DStockUnderlying implementation (affects all proxies)
     * @param newImplementation Address of the new implementation
     */
    function upgradeImplementation(address newImplementation)
        external
        onlyRole(UPGRADER_ROLE)
    {
        if (newImplementation == address(0)) revert InvalidImplementation();
        address oldImpl = underlyingBeacon.implementation();
        underlyingBeacon.upgradeTo(newImplementation);
        emit ImplementationUpgraded(oldImpl, newImplementation);
    }
}
