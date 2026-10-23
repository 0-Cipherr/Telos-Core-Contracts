// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultHelper} from "../src/VaultHelper.sol";
// Minimal interface declarations required for function signatures
import {IVaultManager} from "../src/IVaultManager.sol";

interface IVaultFactory {
    // Custom Errors
    error NotApproved(uint256 amount, uint256 vaultId);

    // External Views & Pure Functions
    function previewDeposit(uint256 vaultId, uint256 amount) external view returns (uint256 shares);

    function previewWithdraw(uint256 vaultId, uint256 shares) external view returns (uint256 assets);

    function getDepositorInfo(uint256 vaultId, address depositorInfo)
        external
        view
        returns (VaultHelper.DepositorInfo memory depositor);
    function getvault(uint256 vaultId) external view returns (VaultHelper.Vault memory vault);

    function getVaultAddress(uint256 vaultId) external view returns (address);

    function verifyVault(uint256 vaultId) external view returns (bool isValid);

    function isApproved(IERC20 asset, address owner, address spender, uint256 amount) external view returns (bool);

    // State Mutating Functions
    function setVaultImplementation(address vault) external;

    function setVaultAddress(uint256 vaultId, address vault) external;

    function setVault(address vaultRegistry) external;

    function approveVault(uint256 vaultId, IERC20 asset, uint256 amount) external;

    function approveVault(uint256 vaultId, uint256 amount) external;

    function setVaultsDeployed(uint256 vaultId, VaultHelper.Vault calldata vaultInfo) external;

    function setStrategyId(uint256 vaultId, uint256 strategyId, bytes calldata depositCallback) external;

    function updateVaultTVL(uint256 vaultId, uint256 value, bool isDeduction) external;

    function updateVaultallTimeVolume(uint256 vaultId, uint256 amount) external;

    function updateAuthorized(uint256 vaultId, address user, bool shouldAppend) external;

    function transferFromRegistry(IERC20 asset, address from, address to, uint256 amount) external;

    function deposit(uint256 vaultId, uint256 assets, address receiver) external payable;

    function withdraw(uint256 vaultId, uint256 shares, address receiver, bytes calldata callBackStrategy) external;

    function deployVaultCrossChain(uint256 vaultId, bytes calldata deployVaultParams) external;

    function intializeVault(address vault, VaultHelper.VaultDeployParams calldata deployParams) external;

    function setupVault(uint256 vaultId, address vault, bytes calldata deployParams, address[] calldata vaultAuthorized)
        external;

    function deployVault(bytes calldata deployVaultParams)
        external
        returns (uint256 vaultId, IVaultManager vaultDeployed);
}
