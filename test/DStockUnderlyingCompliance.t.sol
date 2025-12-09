// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DStockUnderlyingCompliance} from "../src/DStockUnderlyingCompliance.sol";
import {IDStockUnderlyingCompliance} from "../src/interfaces/IDStockUnderlyingCompliance.sol";

contract DStockUnderlyingComplianceTest is Test {
    address public underlyingToken = address(0x100);
    address public owner = address(0x1);
    address public nonOwner = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);

    DStockUnderlyingCompliance public compliance;

    function setUp() public {
        compliance = new DStockUnderlyingCompliance(underlyingToken, owner);
    }

    // ============ Deployment Tests ============

    function test_RejectsZeroUnderlying() public {
        vm.expectRevert(DStockUnderlyingCompliance.InvalidUnderlyingToken.selector);
        new DStockUnderlyingCompliance(address(0), owner);
    }

    function test_RejectsZeroOwner() public {
        // OpenZeppelin's Ownable constructor reverts with OwnableInvalidOwner before our custom check
        // So we need to expect the OpenZeppelin error instead
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableInvalidOwner.selector,
                address(0)
            )
        );
        new DStockUnderlyingCompliance(underlyingToken, address(0));
    }

    function test_StoresImmutableReferences() public {
        assertEq(compliance.underlyingToken(), underlyingToken);
        assertEq(compliance.owner(), owner);
    }

    // ============ Access Control Tests ============

    function test_OnlyOwnerMutatesSettings() public {
        // setWhitelistRequired
        vm.prank(nonOwner);
        vm.expectRevert();
        compliance.setWhitelistRequired(true);

        // setWhitelist
        address[] memory users = new address[](1);
        users[0] = user1;
        vm.prank(nonOwner);
        vm.expectRevert();
        compliance.setWhitelist(users, true);

        // setBlacklist
        vm.prank(nonOwner);
        vm.expectRevert();
        compliance.setBlacklist(users, true);
    }

    function test_OnlyUnderlyingCanCheckCompliance() public {
        // Call from non-underlying should revert
        vm.prank(nonOwner);
        vm.expectRevert(DStockUnderlyingCompliance.NotUnderlyingCaller.selector);
        compliance.checkIsCompliant(user1);

        // Call from underlying should work (if user is compliant)
        vm.prank(underlyingToken);
        compliance.checkIsCompliant(user1); // Should not revert
    }

    // ============ Whitelist Required Flag Tests ============

    function test_ToggleEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.WhitelistRequiredSet(false, true);
        compliance.setWhitelistRequired(true);

        assertTrue(compliance.whitelistRequired());
    }

    function test_DefaultFalsePath() public {
        // Default: whitelistRequired = false
        assertFalse(compliance.whitelistRequired());

        // User not in blacklist should pass
        vm.prank(underlyingToken);
        compliance.checkIsCompliant(user1); // Should not revert

        // User in blacklist should fail
        address[] memory blacklist = new address[](1);
        blacklist[0] = user1;
        vm.prank(owner);
        compliance.setBlacklist(blacklist, true);

        vm.prank(underlyingToken);
        vm.expectRevert(
            abi.encodeWithSelector(
                DStockUnderlyingCompliance.NotCompliant.selector,
                user1
            )
        );
        compliance.checkIsCompliant(user1);
    }

    // ============ Whitelist Operations Tests ============

    function test_BulkSetSuccess() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.WhitelistUpdated(user1, true);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.WhitelistUpdated(user2, true);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.WhitelistUpdated(user3, true);
        compliance.setWhitelist(users, true);

        assertTrue(compliance.whitelisted(user1));
        assertTrue(compliance.whitelisted(user2));
        assertTrue(compliance.whitelisted(user3));
    }

    function test_EnforcementWhenRequired() public {
        // Enable whitelist required
        vm.prank(owner);
        compliance.setWhitelistRequired(true);

        // Non-whitelisted user should fail
        vm.prank(underlyingToken);
        vm.expectRevert(
            abi.encodeWithSelector(
                DStockUnderlyingCompliance.NotCompliant.selector,
                user1
            )
        );
        compliance.checkIsCompliant(user1);

        // Whitelist user1
        address[] memory users = new address[](1);
        users[0] = user1;
        vm.prank(owner);
        compliance.setWhitelist(users, true);

        // Now should pass
        vm.prank(underlyingToken);
        compliance.checkIsCompliant(user1); // Should not revert
    }

    // ============ Blacklist Operations Tests ============

    function test_BulkSetBlacklistSuccess() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.BlacklistUpdated(user1, true);
        vm.expectEmit(true, false, false, true);
        emit DStockUnderlyingCompliance.BlacklistUpdated(user2, true);
        compliance.setBlacklist(users, true);

        assertTrue(compliance.blacklisted(user1));
        assertTrue(compliance.blacklisted(user2));
    }

    function test_BlacklistPrecedence() public {
        // Whitelist user1
        address[] memory whitelist = new address[](1);
        whitelist[0] = user1;
        vm.prank(owner);
        compliance.setWhitelist(whitelist, true);

        // Also blacklist user1
        address[] memory blacklist = new address[](1);
        blacklist[0] = user1;
        vm.prank(owner);
        compliance.setBlacklist(blacklist, true);

        // Should still fail (blacklist takes precedence)
        vm.prank(underlyingToken);
        vm.expectRevert(
            abi.encodeWithSelector(
                DStockUnderlyingCompliance.NotCompliant.selector,
                user1
            )
        );
        compliance.checkIsCompliant(user1);
    }

    // ============ Miscellaneous Tests ============

    function test_NoOpComplianceReturns() public {
        // User not blacklisted and whitelist not required
        vm.prank(underlyingToken);
        compliance.checkIsCompliant(user1); // Should not revert
    }

    function test_GasSanityLargeBatch() public {
        // Test with 25 entries
        address[] memory users = new address[](25);
        for (uint256 i = 0; i < 25; i++) {
            users[i] = address(uint160(1000 + i));
        }

        vm.prank(owner);
        compliance.setWhitelist(users, true);

        // Verify all are whitelisted
        for (uint256 i = 0; i < 25; i++) {
            assertTrue(compliance.whitelisted(users[i]));
        }
    }

    function test_RemoveFromWhitelist() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        // Add to whitelist
        vm.prank(owner);
        compliance.setWhitelist(users, true);
        assertTrue(compliance.whitelisted(user1));

        // Remove from whitelist
        vm.prank(owner);
        compliance.setWhitelist(users, false);
        assertFalse(compliance.whitelisted(user1));
    }

    function test_RemoveFromBlacklist() public {
        address[] memory users = new address[](1);
        users[0] = user1;

        // Add to blacklist
        vm.prank(owner);
        compliance.setBlacklist(users, true);
        assertTrue(compliance.blacklisted(user1));

        // Remove from blacklist
        vm.prank(owner);
        compliance.setBlacklist(users, false);
        assertFalse(compliance.blacklisted(user1));
    }
}

