// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    struct StrategyConfig {
        address asset; // accepted asset, address(0) = native ETH
        address protocol; // external protocol this strategy deploys into
        address vault; // vault that owns this strategy
        uint256 chainId; // chain this strategy runs on
        uint256 allocation; // share of vault funds in basis points (10000 = 100%)
        uint256 maxDeposit; // max amount per deposit, in asset units
        uint256 minDeposit; // min amount per deposit, in asset units
    }

    event Deposited(address indexed caller, uint256 amount, uint256 shares);
    event Withdrawn(address indexed caller, uint256 requested, uint256 assets);
    event Harvested(uint256 profit);

    error StrategyPaused();
    error InvalidAmount(uint256 amount, uint256 min, uint256 max);
    error InsufficientAssets(uint256 requested, uint256 available);

    function initialize(StrategyConfig calldata config) external;

    /// @notice Deposits `amount` of the configured asset. Native ETH is sent as msg.value.
    /// @return shares Shares minted for the deposit
    function deposit(uint256 amount) external payable returns (uint256 shares);

    /// @notice Withdraws `amount` and sends the assets to msg.sender.
    /// @return assets Assets actually returned (can differ from `amount` due to fees or slippage)
    function withdraw(uint256 amount) external returns (uint256 assets);

    /// @notice Collects yield and reinvests it.
    /// @return profit Yield collected, in asset units
    function harvest() external returns (uint256 profit);

    /// @return Total assets held by the strategy, in asset units
    function totalAssets() external view returns (uint256);

    /// @return APY in basis points (10000 = 100%)
    function getAPY() external view returns (uint256);

    function getConfig() external view returns (StrategyConfig memory);

    function paused() external view returns (bool);
}
