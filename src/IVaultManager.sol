// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultHelper} from "./VaultHelper.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";

interface IVaultManager {
    // --- Events ---
    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // --- Initialization ---
    function __initialize_vault_(
        VaultHelper.VaultDeployParams calldata _deployParams,
        IStrategyAdapter _strategyAdapter
    ) external;

    // --- ERC4626 Accounting & Preview Overrides (from VaultAssets) ---
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);

    // --- Strategy Management ---
    function setStrategy(
        uint256 strategyId,
        bytes calldata depositCallback
    ) external;
    function enterStrategy(
        address _user,
        uint256 strategyId,
        uint256 assets,
        bytes calldata params
    ) external;
    function activateStrategy(uint256 strategyId) external;
    function deactivateStrategy() external;
    function exitStrategy(
        uint256 strategyId,
        uint256 assets,
        bytes calldata params
    ) external;
    function emergencyExit(uint256 strategyId, bytes calldata params) external;
    function checkStrategyCurrent(
        address _user,
        uint256 strategyId,
        uint256 assets,
        bytes calldata params
    ) external;
    function withdrawAssets(
        uint256 _shares,
        address receiver,
        bytes memory callBackStrategy
    ) external;
    // --- Core Operations ---
    function depositAssets(
        uint256 assets,
        address receiver,
        bytes calldata strategyParams
    ) external payable returns (uint256 _shares);
    function crossChainDeposit(
        uint32 _dstEid,
        uint256 assets,
        address receiver
    ) external;

    // --- Access Control & Management ---
    function setPeer(uint32 _eid, address _peer) external;
    function setAuthorizer(address authorized) external;
    function createDepositor(
        address _depositor,
        VaultHelper.DepositorInfo calldata _info
    ) external;

    // --- View Functions ---
    function getDepositorInfo(
        address _user
    ) external view returns (VaultHelper.DepositorInfo memory);
    function getStrategyInfo(
        uint256 _vaultId
    ) external view returns (VaultHelper.StrategyInfo memory);
    function getAsset() external view returns (IERC20);
    function getCreator() external view returns (address);
    function getAuthorizer(uint256 index) external view returns (address);
}
