// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.24;

// import {console} from "forge-std/console.sol";
// import {Script} from "forge-std/Script.sol";
// import {VaultRegistry} from "../src/VaultRegistry.sol";
// import {VaultAssets} from "../src/VaultAssets.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {VaultHelper} from "../src/VaultHelper.sol";
// import {TokenDeployer} from "../src/TokenDeployer.sol";
// import {MessagingHelper} from "../src/MessagingHelper.sol";
// import {IVaultRegistryMessenger} from "../src/IVaultRegistryMessenger.sol";

// contract VaultRegistryTest is Script {
//     address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
//     uint32 peerEndpointId = block.chainid == 84532 ? 40231 : 40245;

//     VaultRegistry registry = block.chainid == 84532
//         ? VaultRegistry(0xdC4A27216d63c105253fb6133798B81177bfA65d)
//         : VaultRegistry(0xE30b8793ec6120Ea3eDa6654A1Bdcb651B72a48c);
//     bytes32 msgrPeerAddr = block.chainid == 84532
//         ? addressToBytes32(0x1638C457E47F20B398147C632B41be5c9e2aB7c7)
//         : addressToBytes32(0x909f3F0563564896d53EFB2D11ED95d549b19ef7);

//     //////non changable
//     address messengerFactory = block.chainid == 84532
//         ? 0x909f3F0563564896d53EFB2D11ED95d549b19ef7
//         : 0x1638C457E47F20B398147C632B41be5c9e2aB7c7;

//     address peerEndpoint = block.chainid == 84532
//         ? 0xdc36AFad9ca9C30371c4cB8446e7F84a41735bab
//         : 0x207b52c4B6803B2D756A32D1222590b52EADaE44;

//     address[] authorized = new address[](1);

//     function run() external {
//         vm.startBroadcast();
//         uint32[] memory dstEids = new uint32[](1);
//         address[] memory peers = new address[](1);
//         peers[0] = peerEndpoint;
//         dstEids[0] = peerEndpointId;

//         authorized[0] = (0x14A32192CAc22C5C89611c292e0FF8A21eb18671);

//         // setNewMessengerOwner(messengerFactory, address(registry));
//         // addRegistryPeer(peerEndpointId, msgrPeerAddr);
//         // addMessengerPee();

//         (uint256 vaultId, IERC20 deployedToken,) = testVaultCreationNative(
//             0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d,
//             authorized,
//             "TEST",
//             "TST",
//             0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d,
//             endpoint,
//             VaultAssets.FeesInfo(0, 0),
//             VaultAssets.feeReceiversInfo(address(0), address(0))
//         );

//         crossChainDeployTest(
//             vaultId,
//             dstEids,
//             peers,
//             "String Cheese",
//             "CHS",
//             IERC20(address(0)),
//             0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d,
//             VaultAssets.FeesInfo(0, 0),
//             VaultAssets.feeReceiversInfo(address(0), address(0))
//         );

//         // inAndOutNativeTest(vaultId, deployedToken);

//         //step 3 cross chain deploy

//         vm.stopBroadcast();
//     }

//     function setNewMessengerOwner(address messenger, address owner) public {
//         IVaultRegistryMessenger(messenger).newOwner(owner);
//     }

//     function addMessengerPeer() public {}

//     function crossChainDeployTest(
//         uint256 _vaultId,
//         uint32[] memory _dstEids,
//         address[] memory _dstEndpoints,
//         string memory _vaultName,
//         string memory _vaultTicker,
//         IERC20 hubAsset,
//         address _deployer,
//         VaultAssets.FeesInfo memory _fees,
//         VaultAssets.feeReceiversInfo memory _reciever
//     ) public {
//         (MessagingHelper.ComposedMessageQuote[] memory _quoteParamsCollection) = composeMessageQuotes(
//             _vaultId, _dstEids, _dstEndpoints, _vaultName, _vaultTicker, hubAsset, _deployer, _fees, _reciever
//         );
//         (MessagingHelper.ComposedMessage[] memory _composedMessage, uint256 total) =
//             registry.vaultDeploymentsQuote(_vaultId, _quoteParamsCollection);
//         outputComposedMessages(_composedMessage);
//         deployVaultCrossChain(_vaultId, _composedMessage, total);
//     }

//     function outputComposedMessages(MessagingHelper.ComposedMessage[] memory composedMessage) public pure {
//         for (uint256 i = 0; i < composedMessage.length; i++) {
//             console.log("dstEid:", composedMessage[i]._dstEid);
//             console.log("fee.nativeFee:", composedMessage[i]._fee.nativeFee);
//             console.log("fee.lzTokenFee:", composedMessage[i]._fee.lzTokenFee);
//             console.logBytes(composedMessage[i]._message);
//             console.logBytes(composedMessage[i]._options);
//             console.log("payInLzToken:", composedMessage[i].payInLzToken);
//             console.log("refundAddress:", composedMessage[i]._refundAddress);
//         }
//     }

//     function deployVaultCrossChain(
//         uint256 vaultId,
//         MessagingHelper.ComposedMessage[] memory _composedMessages,
//         uint256 _total
//     ) public {
//         registry.deployVaultCrossChain{value: _total}(vaultId, _composedMessages, _total);
//     }

//     function composeMessageQuotes(
//         uint256 vaultId,
//         uint32[] memory _dstEids,
//         address[] memory _dstEndpoints,
//         string memory _vaultName,
//         string memory _vaultTicker,
//         IERC20 hubAsset,
//         address _deployer,
//         VaultAssets.FeesInfo memory _fees,
//         VaultAssets.feeReceiversInfo memory _reciever
//     ) public returns (MessagingHelper.ComposedMessageQuote[] memory _quoteParamsCollection) {
//         _quoteParamsCollection = registry.composeMessageQuotes(
//             vaultId, _dstEids, _dstEndpoints, _vaultName, _vaultTicker, hubAsset, _deployer, _fees, _reciever
//         );
//     }

//     function inAndOutNativeTest(uint256 vaultId, IERC20 deployedToken) public {
//         uint256 approveAmount = 10000;
//         uint256 depositAmount = 1000;
//         uint256 _shares = 20;

//         approveAssets(deployedToken, address(registry), approveAmount); //approve rregistry before depositing

//         testDeposit(vaultId, depositAmount, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);
//         getDepositorInfo(vaultId, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);
//         // approveAssets(deployedToken, address(vaultInfo.vault), 100000000);
//         getERC20Balance(deployedToken, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);

//         uint256 _sharesOwned = getDepositorInfo(vaultId, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d).shares;

//         testWithdraw(vaultId, _sharesOwned - 1, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);

//         getERC20Balance(deployedToken, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);
//         getDepositorInfo(vaultId, 0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d);
//     }

//     function crossChainDeposit() public {}

//     function getDepostor() public returns (VaultHelper.DepositorInfo memory _depositor) {}

//     function previewWithdraw(uint256 vaultId, address _sharesOwner, uint256 _shares)
//         public
//         view
//         returns (uint256 _assetsToRecieve)
//     {
//         _assetsToRecieve = registry.previewWithdrawRemote(vaultId, _sharesOwner, _shares);
//         console.log("previewWithdraw():");
//         console.logUint(_assetsToRecieve);
//     }

//     function previewDeposit(uint256 vaultId, uint256 _assets) public view returns (uint256 _sharesToRecieve) {
//         _sharesToRecieve = registry.previewDepositRemote(vaultId, _assets);
//         console.log("previewDeposit():");
//         console.logUint(_sharesToRecieve);
//     }

//     function addressToBytes32(address _addr) public pure returns (bytes32) {
//         return bytes32(uint256(uint160(_addr)));
//     }

//     /// @notice Transforms a zero-left-padded bytes32 structure back into a usable address
//     function bytes32ToAddress(bytes32 _b32) public pure returns (address) {
//         return address(uint160(uint256(_b32)));
//     }

//     function addRegistryPeer(uint32 endpointId, bytes32 peer) public {
//         registry.addRegistryPeer(endpointId, peer);
//     }

//     function setRegistry(address _registry) public {
//         registry = VaultRegistry(_registry);
//     }

//     function addMessengerPee() public {
//         registry.addMessengerPeer();
//     }

//     function testVaultCreationNative(
//         address deployer,
//         address[] memory authorizedVip,
//         string memory vaultName,
//         string memory vaultTicker,
//         address creator,
//         address vaultEndpoint,
//         VaultAssets.FeesInfo memory fees,
//         VaultAssets.feeReceiversInfo memory feeReceivers
//     ) public returns (uint256 vaultId, IERC20 deployedToken, address vaultAddress) {
//         console.log("Deploying Vault!");
//         deployedToken = testDeployERC20("Gecko Coin", "GECKO");
//         approveAssets(deployedToken, address(registry), 100000000);
//         VaultHelper.VaultDeployParams memory deployParams = constructDeployParams(
//             deployer, authorizedVip, vaultName, vaultTicker, deployedToken, creator, vaultEndpoint, fees, feeReceivers
//         );

//         vaultId = registry.deployHubVault(creator, abi.encode(deployParams));
//         getVaultInfo(vaultId);

//         vaultAddress = getVaultAddress(vaultId);
//         console.log("Vault Deployed!");
//     }

//     function getVaultAddress(uint256 vaultId) public view returns (address) {
//         return registry.getVaultAddress(vaultId);
//     }

//     function getERC20Balance(IERC20 token, address user) public view {
//         console.log("ERC20 BALNCE:");
//         console.logUint(token.balanceOf(user));
//     }

//     function testDeposit(uint256 vaultId, uint256 assets, address reciever) public {
//         console.log("Depositing...");

//         // asset.approve();
//         // /we neeed to get the vaults address and set its allowance not towards the registry beofr edoing anything
//         console.log("previewDEposit() deposit:");
//         console.logUint(registry.previewDepositRemote(vaultId, assets));
//         registry.deposit(vaultId, assets, reciever);
//         getVaultInfo(vaultId);

//         console.log("Deposit complete!");
//     }

//     //api should logically verify actual users alre calling the function
//     function testWithdraw(uint256 vaultId, uint256 _shares, address reciever) public {
//         console.log("Withdrawing...");

//         registry.withdraw(vaultId, _shares, reciever, bytes(""));
//         getVaultInfo(vaultId);
//         console.log("Withdraw Complete");
//     }

//     function testVaultDeploymentOutput(VaultHelper.Vault memory _vault, uint256 vaultId, address vaultAddress)
//         public
//         pure
//     {
//         console.log("VAULT ID: ");
//         console.logUint(vaultId);
//         outputVaultInfo(_vault);
//         console.log("Vault Address:");
//         console.logAddress(vaultAddress);
//     }

//     function outputVaultInfo(VaultHelper.Vault memory _vault) public pure {
//         console.log("Creator:          ", _vault.creator);
//         console.log("TVL:              ", _vault.tvl);
//         console.log("All-Time Volume:  ", _vault.allTimeVolume);
//         console.log("Vault Factory:    ", address(_vault.vault));
//         console.log("Name:             ", _vault.name);
//         console.log("Ticker:           ", _vault.ticker);
//         console.log("Deposit Asset:    ", address(_vault.depositAsset));
//     }

//     function getVaultInfo(uint256 vaultId) public view returns (VaultHelper.Vault memory) {
//         VaultHelper.Vault memory vaultInfo = registry.getVault(vaultId);
//         outputVaultInfo(vaultInfo);
//         return vaultInfo;
//     }

//     function getDepositorInfo(uint256 vaultId, address _depositor) public returns (VaultHelper.DepositorInfo memory) {
//         VaultHelper.DepositorInfo memory depositor = registry.getDepositorInfoRemote(vaultId, _depositor);
//         outputDepositorInfo(depositor);
//         return depositor;
//     }

//     function outputDepositorInfo(VaultHelper.DepositorInfo memory _info) internal view {
//         console.log("--- Depositor Info ---");
//         console.log("Depositor Address:", _info.depositor);
//         console.log("Assets           :", _info.assets);
//         console.log("Shares           :", _info.shares);
//         console.log("Asset Volume     :", _info.assetVolume);
//     }

//     function testDeployERC20(string memory name, string memory ticker) public returns (IERC20) {
//         TokenDeployer deployed = new TokenDeployer(name, ticker);
//         deployed.mintTokens(0xa24e1426Bc37d0D1a9e7037f5De3322E800F2D7d, 100000);
//         console.log("miinted 100,000 tokens for deposit on your wallet ");
//         IERC20 tokenDeployed = IERC20(address(deployed));

//         return tokenDeployed;
//     }

//     function approveAssets(IERC20 asset, address spender, uint256 value) public {
//         asset.approve(spender, value);
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
// }
