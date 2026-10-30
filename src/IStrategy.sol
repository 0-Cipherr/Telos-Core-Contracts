// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title IStrategy
/// @notice Standard interface for all vault-managed strategy adapters.
/// @dev Strategies have no constructor. They are configured once through
///      initialize(), which the vault (or factory) calls right after deployment.
/// @dev Protocol-specific implementations must follow the same
///      accounting, capital management, and reporting conventions.
interface IStrategy {
    /// @notice Configuration written once by initialize().
    struct StrategyConfig {
        address asset;
        address protocol;
        address vault;
        uint256 chainId;
        uint256 allocation;
        uint256 maxDeposit;
        uint256 minDeposit;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted once when the strategy is configured.
    event Initialized(address indexed vault, StrategyConfig config);

    /// @notice Emitted when assets are deployed into a protocol.
    event Deposited(
        address indexed vault,
        uint256 assetsRequested,
        uint256 assetsDeployed
    );

    /// @notice Emitted when assets are withdrawn and returned to the vault.
    event Withdrawn(
        address indexed vault,
        uint256 assetsRequested,
        uint256 assetsReturned
    );

    /// @notice Emitted when strategy accounting is updated.
    /// @dev profitOrLoss is the change in strategy value since the
    ///      previous harvest, adjusted for external capital flows.
    event Harvested(
        address indexed vault,
        uint256 totalAssets,
        int256 profitOrLoss
    );

    /// @notice Emitted when the strategy completes a full exit.
    event WithdrawnAll(
        address indexed vault,
        uint256 assetsReturned
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Caller is not the authorized vault.
    error Unauthorized();

    /// @notice A required address is zero.
    error ZeroAddress();

    /// @notice The requested asset amount is invalid.
    error InvalidAmount();

    /// @notice The strategy cannot fulfill the requested operation.
    error InsufficientLiquidity();

    /// @notice initialize() was called after the strategy was already configured.
    error AlreadyInitialized();

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Configures the strategy. Must be callable exactly once.
    /// @dev `protocolConfig` carries protocol-specific setup, e.g. a pool or
    ///      router address encoded with abi.encode.
    function initialize(
        StrategyConfig calldata config,
        bytes calldata protocolConfig
    ) external;

    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset accepted by this strategy.
    /// @dev All accounting values must be denominated in this asset.
    function asset() external view returns (address);

    /// @notice Returns the vault authorized to manage this strategy.
    function vault() external view returns (address);

    /// @notice Returns the configuration stored by initialize().
    function getConfig() external view returns (StrategyConfig memory);

    /*//////////////////////////////////////////////////////////////
                                ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total value of assets controlled by the strategy.
    /// @dev Must include idle underlying tokens and assets deployed into
    ///      external protocols, including accrued yield, net of any
    ///      strategy-level liabilities.
    /// @dev The result must be denominated in units of asset().
    function totalAssets() external view returns (uint256);

    /// @notice Returns the strategy's current annualised yield in basis points.
    function getAPY() external view returns (uint256);

    /// @notice Returns true while deposits and withdrawals are paused.
    function paused() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                           CAPITAL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys underlying assets into the external protocol.
    /// @dev The vault must transfer `assets` to the strategy before
    ///      calling this function.
    /// @dev `data` contains optional protocol-specific instructions.
    /// @dev Only the authorized vault may call this function.
    /// @param assets Amount of underlying assets to deploy.
    /// @param data Protocol-specific instructions.
    /// @return assetsDeployed Actual amount deployed into the protocol.
    function deposit(
        uint256 assets,
        bytes calldata data
    ) external returns (uint256 assetsDeployed);

    /// @notice Withdraws underlying assets and returns them to the vault.
    /// @dev The returned assets must be transferred to the vault before
    ///      this function completes.
    /// @dev Implementations may return less than requested if the
    ///      underlying protocol imposes liquidity constraints.
    /// @dev Only the authorized vault may call this function.
    /// @param assets Amount of underlying assets requested.
    /// @param data Protocol-specific instructions.
    /// @return assetsReturned Actual amount transferred to the vault.
    function withdraw(
        uint256 assets,
        bytes calldata data
    ) external returns (uint256 assetsReturned);

    /// @notice Withdraws all recoverable assets and returns them to the vault.
    /// @dev Must attempt to exit all positions controlled by the strategy.
    /// @dev Illiquid positions may prevent a complete exit; implementations
    ///      must report the actual amount returned.
    /// @dev Only the authorized vault may call this function.
    /// @param data Protocol-specific instructions.
    /// @return assetsReturned Actual amount transferred to the vault.
    function withdrawAll(
        bytes calldata data
    ) external returns (uint256 assetsReturned);

    /*//////////////////////////////////////////////////////////////
                                HARVEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates strategy accounting and reports profit or loss.
    /// @dev Profit or loss must reflect the change in strategy value
    ///      since the previous harvest, adjusted for deposits and
    ///      withdrawals during that period.
    /// @dev Positive profitOrLoss indicates profit; negative indicates loss.
    /// @dev Harvesting must not count external capital flows as profit
    ///      or loss.
    /// @dev Only the authorized vault may call this function.
    /// @param data Protocol-specific instructions.
    /// @return currentAssets Current total value of the strategy.
    /// @return profitOrLoss Change in strategy value since the
    ///         previous harvest, adjusted for external capital flows.
    function harvest(
        bytes calldata data
    ) external returns (
        uint256 currentAssets,
        int256 profitOrLoss
    );
}
