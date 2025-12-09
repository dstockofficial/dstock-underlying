// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DStockUnderlying} from "../src/DStockUnderlying.sol";
import {DStockUnderlyingCompliance} from "../src/DStockUnderlyingCompliance.sol";

contract DStockUnderlyingTest is Test {
    DStockUnderlying public implementation;
    UpgradeableBeacon public beacon;
    BeaconProxy public proxy;
    DStockUnderlying public underlying;
    DStockUnderlyingCompliance public compliance;

    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public configurer = address(0x4);
    address public minter = address(0x5);
    address public burner = address(0x6);
    address public pauser = address(0x7);

    string public constant TOKEN_NAME = "Test Token";
    string public constant TOKEN_SYMBOL = "TEST";
    uint8 public constant TOKEN_DECIMALS = 18;

    function setUp() public {
        // Deploy implementation
        implementation = new DStockUnderlying();

        // Deploy beacon
        beacon = new UpgradeableBeacon(address(implementation), admin);

        // Deploy proxy with initialization (compliance will be created in specific tests if needed)
        bytes memory initData = abi.encodeWithSelector(
            DStockUnderlying.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            admin,
            address(0) // no compliance initially
        );
        proxy = new BeaconProxy(address(beacon), initData);
        underlying = DStockUnderlying(address(proxy));
    }

    // ============ Initialization Tests ============

    function test_InitializesStateViaProxyOnce() public {
        // Try to initialize again - should revert
        vm.expectRevert();
        underlying.initialize(
            "New Name",
            "NEW",
            8,
            admin,
            address(0)
        );
    }

    function test_StoresMetadataOverrides() public {
        assertEq(underlying.name(), TOKEN_NAME);
        assertEq(underlying.symbol(), TOKEN_SYMBOL);
        assertEq(underlying.decimals(), TOKEN_DECIMALS);
    }

    function test_GrantsAdminRoles() public {
        bytes32 defaultAdmin = underlying.DEFAULT_ADMIN_ROLE();
        bytes32 configurerRole = underlying.CONFIGURER_ROLE();
        bytes32 minterRole = underlying.MINTER_ROLE();
        bytes32 burnerRole = underlying.BURNER_ROLE();
        bytes32 pauserRole = underlying.PAUSER_ROLE();

        assertTrue(underlying.hasRole(defaultAdmin, admin));
        assertTrue(underlying.hasRole(configurerRole, admin));
        assertTrue(underlying.hasRole(minterRole, admin));
        assertTrue(underlying.hasRole(burnerRole, admin));
        assertTrue(underlying.hasRole(pauserRole, admin));
    }

    function test_OptionalComplianceWiring() public {
        // Deploy new proxy with compliance
        // First create a dummy proxy address for compliance to bind to
        address dummyProxy = address(0x100);
        DStockUnderlyingCompliance newCompliance = new DStockUnderlyingCompliance(dummyProxy, admin);
        
        bytes memory initData = abi.encodeWithSelector(
            DStockUnderlying.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            admin,
            address(newCompliance)
        );
        BeaconProxy newProxy = new BeaconProxy(address(beacon), initData);
        DStockUnderlying newUnderlying = DStockUnderlying(address(newProxy));

        assertEq(address(newUnderlying.compliance()), address(newCompliance));
    }

    function test_ComplianceZeroAddressLeavesUnset() public {
        assertEq(address(underlying.compliance()), address(0));
    }

    // ============ Admin Configuration Tests ============

    function test_SetNameUpdatesAndEmits() public {
        string memory newName = "Updated Token";
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlying.NameChanged(TOKEN_NAME, newName);
        underlying.setName(newName);

        assertEq(underlying.name(), newName);
    }

    function test_SetNameRevertsWhenValueUnchanged() public {
        vm.prank(admin);
        vm.expectRevert(DStockUnderlying.ValueUnchanged.selector);
        underlying.setName(TOKEN_NAME);
    }

    function test_SetNameRevertsWhenNotConfigurer() public {
        vm.prank(user1);
        vm.expectRevert();
        underlying.setName("New Name");
    }

    function test_SetSymbolUpdatesAndEmits() public {
        string memory newSymbol = "UPD";
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlying.SymbolChanged(TOKEN_SYMBOL, newSymbol);
        underlying.setSymbol(newSymbol);

        assertEq(underlying.symbol(), newSymbol);
    }

    function test_SetSymbolRevertsWhenValueUnchanged() public {
        vm.prank(admin);
        vm.expectRevert(DStockUnderlying.ValueUnchanged.selector);
        underlying.setSymbol(TOKEN_SYMBOL);
    }

    function test_SetDecimalsUpdatesAndEmits() public {
        uint8 newDecimals = 8;
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlying.DecimalsChanged(TOKEN_DECIMALS, newDecimals);
        underlying.setDecimals(newDecimals);

        assertEq(underlying.decimals(), newDecimals);
    }

    function test_SetDecimalsRevertsWhenValueUnchanged() public {
        vm.prank(admin);
        vm.expectRevert(DStockUnderlying.ValueUnchanged.selector);
        underlying.setDecimals(TOKEN_DECIMALS);
    }

    function test_SetComplianceValidatesChange() public {
        // Create compliance with a valid underlying token address
        address dummyUnderlying = address(0x100);
        DStockUnderlyingCompliance newCompliance = new DStockUnderlyingCompliance(dummyUnderlying, admin);
        
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlying.ComplianceChanged(address(0), address(newCompliance));
        underlying.setCompliance(address(newCompliance));

        assertEq(address(underlying.compliance()), address(newCompliance));
    }

    function test_SetComplianceRevertsWhenValueUnchanged() public {
        // Create compliance with a valid underlying token address
        address dummyUnderlying = address(0x100);
        DStockUnderlyingCompliance newCompliance = new DStockUnderlyingCompliance(dummyUnderlying, admin);
        
        vm.prank(admin);
        underlying.setCompliance(address(newCompliance));

        vm.prank(admin);
        vm.expectRevert(DStockUnderlying.ValueUnchanged.selector);
        underlying.setCompliance(address(newCompliance));
    }

    function test_SetComplianceRevertsWhenNotConfigurer() public {
        // Create compliance with a valid underlying token address
        address dummyUnderlying = address(0x100);
        DStockUnderlyingCompliance newCompliance = new DStockUnderlyingCompliance(dummyUnderlying, admin);
        
        vm.prank(user1);
        vm.expectRevert();
        underlying.setCompliance(address(newCompliance));
    }

    // ============ Minting & Burning Tests ============

    function test_MintRestrictedToMinterRole() public {
        uint256 amount = 1000e18;
        
        // Admin (has MINTER_ROLE) can mint
        vm.prank(admin);
        underlying.mint(user1, amount);
        assertEq(underlying.balanceOf(user1), amount);
        assertEq(underlying.totalSupply(), amount);

        // Non-minter cannot mint
        vm.prank(user1);
        vm.expectRevert();
        underlying.mint(user2, amount);
    }

    function test_BurnRestrictedToBurnerRole() public {
        uint256 mintAmount = 1000e18;
        uint256 burnAmount = 300e18;
        
        // Mint first
        vm.prank(admin);
        underlying.mint(user1, mintAmount);

        // Admin (has BURNER_ROLE) can burn
        vm.prank(admin);
        underlying.burn(user1, burnAmount);
        assertEq(underlying.balanceOf(user1), mintAmount - burnAmount);
        assertEq(underlying.totalSupply(), mintAmount - burnAmount);

        // Non-burner cannot burn
        vm.prank(user1);
        vm.expectRevert();
        underlying.burn(user1, 100e18);
    }

    // ============ Pausing Tests ============

    function test_PauseUnpauseGated() public {
        uint256 amount = 1000e18;
        
        // Mint first
        vm.prank(admin);
        underlying.mint(user1, amount);

        // Admin (has PAUSER_ROLE) can pause
        vm.prank(admin);
        underlying.pause();

        // Transfers should revert when paused
        vm.prank(user1);
        vm.expectRevert(DStockUnderlying.TokenPaused.selector);
        underlying.transfer(user2, 100e18);

        // Admin can unpause
        vm.prank(admin);
        underlying.unpause();

        // Transfers should work after unpause
        vm.prank(user1);
        underlying.transfer(user2, 100e18);
        assertEq(underlying.balanceOf(user2), 100e18);
    }

    function test_PauseRevertsWhenNotPauser() public {
        vm.prank(user1);
        vm.expectRevert();
        underlying.pause();
    }

    function test_TransfersAllowedWhenUnpaused() public {
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        underlying.mint(user1, amount);

        // Normal transfer
        vm.prank(user1);
        underlying.transfer(user2, 100e18);
        assertEq(underlying.balanceOf(user2), 100e18);

        // Mint still works
        vm.prank(admin);
        underlying.mint(user2, 200e18);
        assertEq(underlying.balanceOf(user2), 300e18);

        // Burn still works
        vm.prank(admin);
        underlying.burn(user1, 50e18);
        assertEq(underlying.balanceOf(user1), 850e18);
    }

    // ============ Compliance Hook Tests ============

    function test_ComplianceCheckedOnTransfers() public {
        // Deploy compliance and set it
        DStockUnderlyingCompliance testCompliance = new DStockUnderlyingCompliance(address(underlying), admin);
        
        vm.prank(admin);
        underlying.setCompliance(address(testCompliance));

        // Whitelist user1 and user2
        vm.prank(admin);
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        testCompliance.setWhitelist(users, true);

        // Mint to user1
        vm.prank(admin);
        underlying.mint(user1, 1000e18);

        // Transfer should work (both whitelisted)
        vm.prank(user1);
        underlying.transfer(user2, 100e18);
        assertEq(underlying.balanceOf(user2), 100e18);
    }

    function test_ComplianceBlocksBlacklistedUser() public {
        DStockUnderlyingCompliance testCompliance = new DStockUnderlyingCompliance(address(underlying), admin);
        
        vm.prank(admin);
        underlying.setCompliance(address(testCompliance));

        // Whitelist user1, blacklist user2
        vm.prank(admin);
        address[] memory whitelist = new address[](1);
        whitelist[0] = user1;
        testCompliance.setWhitelist(whitelist, true);

        vm.prank(admin);
        address[] memory blacklist = new address[](1);
        blacklist[0] = user2;
        testCompliance.setBlacklist(blacklist, true);

        vm.prank(admin);
        underlying.mint(user1, 1000e18);

        // Transfer to blacklisted user should revert
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                DStockUnderlyingCompliance.NotCompliant.selector,
                user2
            )
        );
        underlying.transfer(user2, 100e18);
    }

    function test_ComplianceBypassedWhenUnset() public {
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        underlying.mint(user1, amount);

        // Transfer should work without compliance
        vm.prank(user1);
        underlying.transfer(user2, 100e18);
        assertEq(underlying.balanceOf(user2), 100e18);
    }

    // ============ ERC20 Behavior Tests ============

    function test_TransferApproveTransferFrom() public {
        uint256 amount = 1000e18;
        uint256 transferAmount = 300e18;
        
        vm.prank(admin);
        underlying.mint(user1, amount);

        // Approve
        vm.prank(user1);
        underlying.approve(user2, transferAmount);
        assertEq(underlying.allowance(user1, user2), transferAmount);

        // TransferFrom
        vm.prank(user2);
        underlying.transferFrom(user1, user2, transferAmount);
        assertEq(underlying.balanceOf(user1), amount - transferAmount);
        assertEq(underlying.balanceOf(user2), transferAmount);
        assertEq(underlying.allowance(user1, user2), 0);
    }

    function test_MintEmitsTransfer() public {
        uint256 amount = 1000e18;
        
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), user1, amount);
        underlying.mint(user1, amount);
    }

    function test_BurnEmitsTransfer() public {
        uint256 mintAmount = 1000e18;
        uint256 burnAmount = 300e18;
        
        vm.prank(admin);
        underlying.mint(user1, mintAmount);

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(user1, address(0), burnAmount);
        underlying.burn(user1, burnAmount);
    }
}

