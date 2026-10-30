// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    struct StrategyConfig {
        address asset;
        address protocol;
        address vault;
        uint256 chainId;
        uint256 allocation;
        uint256 maxDeposit;
        uint256 minDeposit;
    }

    function initialize(
        StrategyConfig calldata config,
        bytes calldata protocolConfig
    ) external;

    function deposit(uint256 amount) external returns (uint256 shares);

    function withdraw(uint256 amount) external returns (uint256 assets);

    function harvest() external returns (uint256 profit);

    function totalAssets() external view returns (uint256);

    function getAPY() external view returns (uint256);

    function getConfig() external view returns (StrategyConfig memory);

    function paused() external view returns (bool);
}
