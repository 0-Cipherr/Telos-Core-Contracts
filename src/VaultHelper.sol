// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {IVaultManager as VaultFactory} from "./IVaultManager.sol";
import {
    OApp,
    Origin,
    MessagingFee
} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultAssets} from "./VaultAssets.sol";
import {VaultOApp} from "./VaultOApp.sol";

library VaultHelper {
    event Deposit(
        address indexed caller,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );

    event VaultWithdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event StrategyAdded(address indexed strategy);

    event StrategyRemoved(address indexed strategy);

    event CapitalDeployed(address indexed strategy, uint256 assets);

    event CapitalReturned(address indexed strategy, uint256 assets);

    struct VaultDeployParams {
        address deployer;
        address[] authorizedVip;
        string vaultName;
        string vaultTicker;
        IERC20 vaultAsset;
        address creator;
        address vaultEndpoint;
        VaultAssets.FeesInfo fees;
        VaultAssets.feeReceiversInfo feeReceivers;
    }

    struct Destination {
        VaultOApp oapp;
        uint256 vaultId;
        bool isActive;
    }

    struct StrategyInfo {
        uint256 totalAssets;
        address asset;
        uint256[] vaultsDeposited;
    }

    struct DepositorInfo {
        address depositor;
        uint256 assets;
        uint256 shares;
        uint256 assetVolume;
    }

    struct StrategyPosition {
        bool enabled;
        uint256 debt;
        uint256 lastReportedAssets;
    }

    struct BulkVaultDeployments {
        MessagingFee fee;
        uint32 _dstEid;
        bytes vaultConstructorParams; //encdoed then decoded
        bytes message;
        address refundAddress;
    }
    //too much values wemust compress our data for gas efficieny

    struct AvenorUser {
        address _userAdr;
        uint256 _accountCreatedAt;
        uint256 numVaultsCreated;
        uint256 _feesEarned;
        uint256 _totalVolume;
        uint256 _vaulteVolumesTotal;
        VaultFactory[] vaultsDeployed;
    }

    struct RegistryPeer {
        address _endpoint;
        uint32 endpointId;
    }

    struct Vault {
        address creator;
        uint256 tvl;
        uint256 allTimeVolume;
        VaultFactory vault;
        string name;
        string ticker;
        address[] authorized;
    }
}
