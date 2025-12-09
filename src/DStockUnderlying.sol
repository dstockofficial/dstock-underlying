// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {IDStockUnderlyingToken} from "./interfaces/IDStockUnderlyingToken.sol";
import {IDStockUnderlyingCompliance} from "./interfaces/IDStockUnderlyingCompliance.sol";

/**
 * @title  DStockUnderlying
 * @notice ERC20 underlying asset token implementation (to be used via BeaconProxy)
 *         - Role-based access: CONFIGURER / MINTER / BURNER / PAUSER
 *         - Works with a dedicated compliance module (IDStockUnderlyingCompliance)
 */
contract DStockUnderlying is
    Initializable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    IDStockUnderlyingToken
{
    /// @notice Allowed to change name/symbol/decimals and compliance settings
    bytes32 public constant CONFIGURER_ROLE = keccak256("CONFIGURER_ROLE");
    /// @notice Minting role, typically assigned to DStockWrapper or an ops multisig
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Burning role, typically assigned to DStockWrapper or an ops multisig
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    /// @notice Controls pausing / unpausing the token
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    string private _nameOverride;
    string private _symbolOverride;
    uint8 private _decimalsOverride;

    /// @notice Optional compliance module; no compliance checks if unset
    IDStockUnderlyingCompliance public compliance;

    event NameChanged(string oldName, string newName);
    event SymbolChanged(string oldSymbol, string newSymbol);
    event DecimalsChanged(uint8 oldDecimals, uint8 newDecimals);
    event ComplianceChanged(address oldCompliance, address newCompliance);

    error TokenPaused();
    error ValueUnchanged();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialization logic, executed once via BeaconProxy
     * @param name_        Initial name
     * @param symbol_      Initial symbol
     * @param decimals_    Token decimals
     * @param admin        Default admin (multisig / Safe)
     * @param compliance_  Compliance contract (optional; zero to disable)
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin,
        address compliance_
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();

        _nameOverride = name_;
        _symbolOverride = symbol_;
        _decimalsOverride = decimals_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIGURER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        if (compliance_ != address(0)) {
            compliance = IDStockUnderlyingCompliance(compliance_);
            emit ComplianceChanged(address(0), compliance_);
        }
    }

    function name() public view virtual override returns (string memory) {
        return _nameOverride;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbolOverride;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimalsOverride;
    }

    /// @notice Update the token name
    function setName(string calldata newName) external onlyRole(CONFIGURER_ROLE) {
        if (keccak256(bytes(newName)) == keccak256(bytes(_nameOverride))) {
            revert ValueUnchanged();
        }
        emit NameChanged(_nameOverride, newName);
        _nameOverride = newName;
    }

    /// @notice Update the token symbol
    function setSymbol(string calldata newSymbol) external onlyRole(CONFIGURER_ROLE) {
        if (keccak256(bytes(newSymbol)) == keccak256(bytes(_symbolOverride))) {
            revert ValueUnchanged();
        }
        emit SymbolChanged(_symbolOverride, newSymbol);
        _symbolOverride = newSymbol;
    }

    /// @notice Update token decimals
    /// @dev    Should only be changed when safe for existing holders
    function setDecimals(uint8 newDecimals) external onlyRole(CONFIGURER_ROLE) {
        if (newDecimals == _decimalsOverride) {
            revert ValueUnchanged();
        }
        emit DecimalsChanged(_decimalsOverride, newDecimals);
        _decimalsOverride = newDecimals;
    }

    /// @notice Set or update the compliance contract
    function setCompliance(address newCompliance) external onlyRole(CONFIGURER_ROLE) {
        if (newCompliance == address(compliance)) {
            revert ValueUnchanged();
        }
        emit ComplianceChanged(address(compliance), newCompliance);
        compliance = IDStockUnderlyingCompliance(newCompliance);
    }

    /// @notice Pause all token transfers
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Resume token transfers
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Mint tokens, typically called by higher-level contracts
    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
    {
        _mint(to, amount);
    }

    /// @notice Admin-driven burn, typically called by higher-level contracts
    function burn(address from, uint256 amount)
        external
        onlyRole(BURNER_ROLE)
    {
        _burn(from, amount);
    }

    /// @dev Check compliance for an account, reverts if non-compliant
    function _checkCompliance(address account) internal view {
        if (address(compliance) == address(0)) {
            return;
        }
        compliance.checkIsCompliant(account);
    }

    /**
     * @dev Override ERC20Upgradeable._update to add pause and compliance checks.
     *      Called on all token transfers (mint, burn, transfer, transferFrom).
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (paused()) {
            revert TokenPaused();
        }

        if (from != address(0)) {
            _checkCompliance(from);
        }
        if (to != address(0)) {
            _checkCompliance(to);
        }
        if (from != msg.sender && to != msg.sender && msg.sender != address(0)) {
            _checkCompliance(msg.sender);
        }

        super._update(from, to, value);
    }
}
