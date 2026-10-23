// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {console} from "forge-std/console.sol";
// import {VaultRegistry} from "../src/VaultRegistry.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {Script} from "forge-std/Script.sol";
// import {IVaultFactory} from "../src/IVaultFactory.sol";
// import {IVaultRegistryMessenger} from "../src/IVaultRegistryMessenger.sol";
// import {VaultFactory} from "../src/VaultFacotry.sol";
// import {VaultRegistryMessenger} from "../src/VaultRegistryMessenger.sol";
// import {StrategyAdapter} from "../src/StrategyAdapter.sol";
// import {IStrategyAdapter} from "../src/IStrategyAdapter.sol";
// import {VaultHelper} from "../src/VaultHelper.sol";
// import {VaultAssets} from "../src/VaultAssets.sol";
// import {TokenDeployer} from "../src/TokenDeployer.sol";
// import {VaultManager} from "../src/VaultManager.sol";
// import {VaultImplementation} from "../src/VaultImplementation.sol";

// contract VaultInteractionScript is Script {
//     VaultRegistry registry;
//     address _enpoint;
//     uint32 _endpointId;
//     IStrategyAdapter adapter;

//     function run() external {
//         vm.startBroadcast();

//         // deployment code here
//         setUp();

//         vm.stopBroadcast();
//     }

//     function setUp() public {
//         testDeployRegistry();
//         address implementation = deployVaultImplementation(_enpoint);
//         setVaultImplementation(implementation);
//     }

//     function testDeployRegistry()
//         public
//         returns (StrategyAdapter strategyAdapter, IVaultFactory _factory, IVaultRegistryMessenger _messenger)
//     {
//         address _delegate = 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d;
//         _enpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
//         _endpointId = block.chainid == 84532 ? 40245 : 40231;
//         strategyAdapter = deployStrategyAdapter(0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);
//         adapter = IStrategyAdapter(address(strategyAdapter));
//         _factory = deployFacotry(tx.origin, strategyAdapter);
//         ConfigDVN memory _options = getDvnConfig();
//         _messenger = deployMessenger(_enpoint, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d, _options);
//         address[] memory authorized = new address[](1);
//         authorized[0] = 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d;

//         deployRegistry(_delegate, _enpoint, _endpointId, _factory, _messenger);

//         testDeployRegistryOutput(_factory, _messenger, strategyAdapter);
//     }

//     struct ConfigDVN {
//         uint32 dstEid;
//         address sendLibrary;
//         address executor;
//         uint32 maxMessageSize;
//         uint64 confirmations;
//         address requiredDvn;
//     }

//     // For `configureSendPath(...)`:

//     // - `dstEid`: LayerZero ID of the **destination chain**. For your Base Sepolia → Arbitrum Sepolia route, that’s `40231`.
//     // - `sendLibrary`: The LayerZero send library used on the **source chain** for this route. Get the correct address from LayerZero’s deployment info; don’t guess.
//     // - `executor`: The Executor address for the route. It handles delivering the message on the destination chain.
//     // - `maxMessageSize`: Maximum message size the Executor allows, in bytes. Use the supported route’s recommended value.
//     // - `confirmations`: How many source-chain block confirmations the DVN should wait for before verifying the message.
//     // - `requiredDvn`: The DVN that must verify the message. The example requires one DVN.

//     // Inside the function:

//     // - `address(this)`: This `VaultOApp`—the app being configured.
//     // - `configType: 1`: This config entry is for the Executor.
//     // - `configType: 2`: This entry is for ULN/DVN security settings.
//     // - `requiredDVNCount: 1`: Exactly one required DVN is supplied.
//     // - `optionalDVNCount: type(uint8).max` and `optionalDVNThreshold: 0`: Explicitly say there are no optional DVNs.
//     // - `requiredDVNs` and `optionalDVNs`: The lists of required and optional DVN addresses.

//     // The destination’s receive config is similar, but uses the **source EID** (`40245` for Base Sepolia) and the destination OApp’s receive library. The OApp’s Messenger owner/delegate must make these calls.
//     function getDvnConfig() public view returns (ConfigDVN memory) {
//         uint32 _dstEid = block.chainid == 84532 ? 40231 : 40245;
//         address sendLibrary = block.chainid == 84532
//             ? 0xC1868e054425D378095A003EcbA3823a5D0135C9
//             : 0x4f7cd4DA19ABB31b0eC98b9066B9e857B1bf9C0E;
//         address executor = block.chainid == 84532
//             ? 0x8A3D588D9f6AC041476b094f97FF94ec30169d3D
//             : 0x5Df3a1cEbBD9c8BA7F8dF51Fd632A9aef8308897;
//         uint32 maxMessageSize = 10_000;
//         uint64 confirmations = 5;
//         address requiredDvn = block.chainid == 84532
//             ? 0xe1a12515F9AB2764b887bF60B923Ca494EBbB2d6
//             : 0x53f488E93b4f1b60E8E83aa374dBe1780A1EE8a8;

//         ConfigDVN memory _config = ConfigDVN(_dstEid, sendLibrary, executor, maxMessageSize, confirmations, requiredDvn);
//         return _config;
//     }

//     function testVaultDeploymentOutput() public {}

//     function testDeployRegistryOutput(
//         IVaultFactory factory,
//         IVaultRegistryMessenger messenger,
//         StrategyAdapter _adapter
//     ) public view {
//         console.log("STEP ONE: Strategy Adapter deployed: ");
//         console.logAddress(address(_adapter));
//         console.log("STEP TWO: Facotry Deployed: ");
//         console.log(address(factory));
//         console.log("STEP THREE: Messenger Deployed: ");
//         console.log(address(messenger));
//         console.log("REGISTRY DEPLOYED:");
//         console.logAddress(address(registry));
//     }

//     //next step
//     function testVaultDeposit() public {}

//     function mintERC20Tokens(IERC20 asset) public {}

//     function addRegistryPeer(uint32 endpointId, bytes32 peer) public {
//         registry.addRegistryPeer(endpointId, peer);
//     }

//     function deployStrategyAdapter(address _delegate) public returns (StrategyAdapter _adapter) {
//         _adapter = new StrategyAdapter(_delegate);
//     }

//     function deployFacotry(address _authorized, StrategyAdapter _adapter) public returns (IVaultFactory factory) {
//         factory = IVaultFactory(address(new VaultFactory(_authorized, IStrategyAdapter(address(_adapter)))));
//     }

//     function deployMessenger(address endpoint, address delegate, ConfigDVN memory _options)
//         public
//         returns (IVaultRegistryMessenger messenger)
//     {
//         messenger = IVaultRegistryMessenger(
//             address(
//                 new VaultRegistryMessenger(
//                     endpoint,
//                     delegate,
//                     _options.maxMessageSize,
//                     _options.confirmations,
//                     _options.sendLibrary,
//                     _options.requiredDvn,
//                     _options.executor
//                 )
//             )
//         );
//     }

//     function deployRegistry(
//         address _delegate,
//         address __endpoint,
//         uint32 __endpointId,
//         IVaultFactory _factory,
//         IVaultRegistryMessenger _messenger
//     ) public {
//         registry = new VaultRegistry(_delegate, __endpoint, __endpointId, _delegate, _factory, _messenger);
//     }

//     function constructDeployParams(
//         address deployer,
//         address[] memory authorizedVip,
//         string memory vaultName,
//         string memory vaultTicker,
//         IERC20 vaultAsset,
//         address creator,
//         address vaultEndpoint,
//         VaultAssets.FeesInfo memory fees,
//         VaultAssets.feeReceiversInfo memory feeReceivers
//     ) public pure returns (VaultHelper.VaultDeployParams memory params) {
//         params = VaultHelper.VaultDeployParams(
//             deployer, authorizedVip, vaultName, vaultTicker, vaultAsset, creator, vaultEndpoint, fees, feeReceivers
//         );
//     }

//     function deployVaultImplementation(address _endpoint) public returns (address implementation) {
//         VaultManager implementationDeployed = new VaultImplementation(_endpoint);
//         implementation = address(implementationDeployed);
//     }

//     function constructVaultDeployParamsImplementation()
//         public
//         view
//         returns (VaultHelper.VaultDeployParams memory _deployParams)
//     {
//         address[] memory authorized = new address[](1);
//         authorized[0] = 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d;
//         _deployParams = VaultHelper.VaultDeployParams(
//             0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d,
//             authorized,
//             "Mock",
//             "MCK",
//             IERC20(address(0)),
//             0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d,
//             _enpoint,
//             VaultAssets.FeesInfo(0, 0),
//             VaultAssets.feeReceiversInfo(address(0), address(0))
//         );
//     }

//     function setVaultImplementation(address implementation) public {
//         registry.setVaultImplementation(implementation);
//     }
// }
