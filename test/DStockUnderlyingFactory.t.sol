// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {DStockUnderlyingFactory} from "../src/DStockUnderlyingFactory.sol";
import {DStockUnderlying} from "../src/DStockUnderlying.sol";
import {DStockUnderlyingCompliance} from "../src/DStockUnderlyingCompliance.sol";
import {IDStockUnderlyingToken} from "../src/interfaces/IDStockUnderlyingToken.sol";

contract DStockUnderlyingFactoryTest is Test {
    DStockUnderlyingFactory public factory;
    DStockUnderlying public implementation;
    DStockUnderlying public newImplementation;

    address public admin = address(0x1);
    address public deployer = address(0x2);
    address public upgrader = address(0x3);
    address public nonAuthorized = address(0x4);
    address public tokenAdmin = address(0x5);

    string public constant TOKEN_NAME = "Factory Token";
    string public constant TOKEN_SYMBOL = "FACT";
    uint8 public constant TOKEN_DECIMALS = 18;

    function setUp() public {
        // Deploy implementation
        implementation = new DStockUnderlying();

        // Deploy factory directly with constructor parameters
        factory = new DStockUnderlyingFactory(address(implementation), admin);
    }

    // ============ Initialization Tests ============

    function test_ConstructorInitializesCorrectly() public view {
        // Factory is initialized via constructor, verify it's set up correctly
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.DEPLOYER_ROLE(), admin));
        assertTrue(factory.hasRole(factory.UPGRADER_ROLE(), admin));
        assertEq(factory.underlyingBeacon().implementation(), address(implementation));
    }

    function test_GrantsExpectedRoles() public view {
        bytes32 defaultAdmin = factory.DEFAULT_ADMIN_ROLE();
        bytes32 deployerRole = factory.DEPLOYER_ROLE();
        bytes32 upgraderRole = factory.UPGRADER_ROLE();

        assertTrue(factory.hasRole(defaultAdmin, admin));
        assertTrue(factory.hasRole(deployerRole, admin));
        assertTrue(factory.hasRole(upgraderRole, admin));
    }

    function test_BeaconWiring() public view {
        UpgradeableBeacon beacon = factory.underlyingBeacon();
        assertEq(beacon.implementation(), address(implementation));
        // Factory is the owner so it can call upgradeTo
        assertEq(beacon.owner(), address(factory));
    }

    // ============ createUnderlying Tests ============

    function test_OnlyDeployerRole() public {
        vm.prank(nonAuthorized);
        vm.expectRevert();
        factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            address(0)
        );
    }

    function test_DeploysBeaconProxy() public {
        vm.prank(admin);
        address proxy = factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            address(0)
        );

        assertTrue(proxy != address(0));
        assertTrue(proxy.code.length > 0);
    }

    function test_InitializesProxy() public {
        vm.prank(admin);
        address proxy = factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            address(0)
        );

        DStockUnderlying underlying = DStockUnderlying(proxy);
        assertEq(underlying.name(), TOKEN_NAME);
        assertEq(underlying.symbol(), TOKEN_SYMBOL);
        assertEq(underlying.decimals(), TOKEN_DECIMALS);

        // Check admin has roles
        bytes32 defaultAdmin = underlying.DEFAULT_ADMIN_ROLE();
        assertTrue(underlying.hasRole(defaultAdmin, tokenAdmin));
    }

    function test_EmitsUnderlyingCreated() public {
        address compliance = address(0x100);

        vm.prank(admin);
        // Check that the event is emitted with correct parameters
        // We can't predict the exact proxy address, so we check non-indexed parameters
        vm.expectEmit(false, false, false, true);
        emit DStockUnderlyingFactory.UnderlyingCreated(
            address(0), // proxy address (indexed, will be checked separately)
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            compliance
        );
        address proxy = factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            compliance
        );
        
        // Verify the proxy address was emitted and is valid
        assertTrue(proxy != address(0));
    }

    function test_RoleSeparation() public {
        vm.prank(admin);
        address proxy = factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            address(0)
        );

        DStockUnderlying underlying = DStockUnderlying(proxy);

        // Factory should not have roles on the underlying
        bytes32 minterRole = underlying.MINTER_ROLE();
        assertFalse(underlying.hasRole(minterRole, address(factory)));

        // tokenAdmin should have roles
        assertTrue(underlying.hasRole(minterRole, tokenAdmin));
    }

    function test_CreateWithCompliance() public {
        // Deploy compliance with a valid underlying token address
        // We'll use a dummy address since compliance will be set on the proxy later
        address dummyUnderlying = address(0x100);
        DStockUnderlyingCompliance compliance = new DStockUnderlyingCompliance(dummyUnderlying, admin);

        vm.prank(admin);
        address proxy = factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            tokenAdmin,
            address(compliance)
        );

        DStockUnderlying underlying = DStockUnderlying(proxy);
        assertEq(address(underlying.compliance()), address(compliance));
    }

    // ============ upgradeImplementation Tests ============

    function test_OnlyUpgraderRole() public {
        newImplementation = new DStockUnderlying();

        vm.prank(nonAuthorized);
        vm.expectRevert();
        factory.upgradeImplementation(address(newImplementation));
    }

    function test_UpdatesBeaconImplementation() public {
        newImplementation = new DStockUnderlying();

        UpgradeableBeacon beacon = factory.underlyingBeacon();
        address oldImpl = beacon.implementation();

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingFactory.ImplementationUpgraded(oldImpl, address(newImplementation));
        factory.upgradeImplementation(address(newImplementation));

        assertEq(beacon.implementation(), address(newImplementation));
    }

    function test_AffectsExistingProxies() public {
        // Deploy a proxy
        vm.prank(admin);
        address proxy1 = factory.createUnderlying(
            "Token1",
            "T1",
            18,
            tokenAdmin,
            address(0)
        );

        // Deploy another proxy
        vm.prank(admin);
        address proxy2 = factory.createUnderlying(
            "Token2",
            "T2",
            8,
            tokenAdmin,
            address(0)
        );

        // Create new implementation with a version getter for testing
        newImplementation = new DStockUnderlying();

        // Upgrade
        vm.prank(admin);
        factory.upgradeImplementation(address(newImplementation));

        // Both proxies should now point to new implementation
        UpgradeableBeacon beacon = factory.underlyingBeacon();
        assertEq(beacon.implementation(), address(newImplementation));

        // Both proxies should still work
        DStockUnderlying underlying1 = DStockUnderlying(proxy1);
        DStockUnderlying underlying2 = DStockUnderlying(proxy2);
        assertEq(underlying1.name(), "Token1");
        assertEq(underlying2.name(), "Token2");
    }

    // ============ Security / Edge Cases Tests ============

    function test_ZeroAddressesRejectedInConstructor() public {
        // Zero implementation - constructor should revert
        vm.expectRevert();
        new DStockUnderlyingFactory(address(0), admin);

        // Zero admin - constructor should revert
        vm.expectRevert();
        new DStockUnderlyingFactory(address(implementation), address(0));
    }

    function test_ZeroAddressesRejectedInCreateUnderlying() public {
        // Zero admin
        vm.prank(admin);
        vm.expectRevert();
        factory.createUnderlying(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            address(0),
            address(0)
        );
    }

    function test_EventSequencing() public {
        newImplementation = new DStockUnderlying();
        DStockUnderlying implementation2 = new DStockUnderlying();

        UpgradeableBeacon beacon = factory.underlyingBeacon();

        // First upgrade
        vm.prank(admin);
        factory.upgradeImplementation(address(newImplementation));
        assertEq(beacon.implementation(), address(newImplementation));

        // Second upgrade
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingFactory.ImplementationUpgraded(
            address(newImplementation),
            address(implementation2)
        );
        factory.upgradeImplementation(address(implementation2));
        assertEq(beacon.implementation(), address(implementation2));
    }

    function test_FactoryRequiresConstructorParams() public view {
        // Factory must be deployed with implementation and admin
        // This is now enforced at deployment time via constructor
        // No separate initialization step needed
        assertTrue(factory.hasRole(factory.DEPLOYER_ROLE(), admin));
        assertTrue(factory.underlyingBeacon() != UpgradeableBeacon(address(0)));
    }

    function test_MultipleProxiesShareBeacon() public {
        vm.prank(admin);
        address proxy1 = factory.createUnderlying("Token1", "T1", 18, tokenAdmin, address(0));

        vm.prank(admin);
        address proxy2 = factory.createUnderlying("Token2", "T2", 8, tokenAdmin, address(0));

        // Both should be valid proxies
        DStockUnderlying underlying1 = DStockUnderlying(proxy1);
        DStockUnderlying underlying2 = DStockUnderlying(proxy2);

        assertEq(underlying1.name(), "Token1");
        assertEq(underlying2.name(), "Token2");

        // Both proxies should be valid and functional
        // They share the same beacon (verified indirectly by both working correctly)
    }
}

