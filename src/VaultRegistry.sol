// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {VaultHelper} from "./VaultHelper.sol";
import {MessagingHelper} from "./MessagingHelper.sol";
import {StrategyHelper} from "./StrategyHelper.sol";
import {VaultAssets} from "../src/VaultAssets.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VaultManager} from "./VaultManager.sol";

import {VaultRegistryManager} from "./VaultRegistryManager.sol";

import {VaultRegistryMessenger} from "../src/VaultRegistryMessenger.sol";
import {VaultFactory} from "./VaultFacotry.sol";
import {IVaultFactory} from "./IVaultFactory.sol";
import {IVaultRegistryMessenger} from "./IVaultRegistryMessenger.sol";
import {VaultManager} from "./VaultManager.sol";
import {
    OptionsBuilder
} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IStrategyAdapter} from "../src/IStrategyAdapter.sol";

contract VaultRegistry is Ownable {
    using OptionsBuilder for bytes;
    address endpoint;
    uint32 endpointId;
    address delegate;
    address authorized;
    IVaultFactory factory;
    IVaultRegistryMessenger messenger;

    struct RegistryPeerInfo {
        uint32 eid;
        bytes32 peer;
    }

    RegistryPeerInfo[] public peerInfo;

    /**
     * _delegate - owner (deployer)
     * _endpoint: registry current endpoitn where  it lives
     * _endpoint id: registry current endpoint id  where it lives
     */
    modifier onlyAuhtorized(address attemptedUser) {
        require(
            attemptedUser == authorized || attemptedUser == address(this),
            "Not authrized to perform "
        );
        _;
    }

    modifier vaultExists(uint256 vaultId) {
        bool isVaultValid = factory.verifyVault(vaultId);

        require(isVaultValid, "Vault is not valid!");
        _;
    }

    //deploy factory and registry manager before deploying this we need it to pass in
    constructor(
        address _delegate,
        address _endpoint,
        uint32 _endpointId,
        IVaultFactory _factory,
        IVaultRegistryMessenger _messenger
    ) Ownable(_delegate) {
        endpoint = _endpoint;
        endpointId = _endpointId;
        delegate = _delegate;
        factory = _factory;
        messenger = _messenger;
        authorized = _delegate;
        setAddressDependencies(address(this));
    }

    function previewWithdrawRemote(
        uint256 vaultId,
        address _shareOwner,
        uint256 _shares
    ) public view vaultExists(vaultId) returns (uint256 _assetsToRecieve) {
        uint256 _sharesOwned = factory
            .getDepositorInfo(vaultId, _shareOwner)
            .shares;
        require(_shares <= _sharesOwned, "Exceeds amount you own!!");
        _assetsToRecieve = factory.previewWithdraw(vaultId, _shares);
    }

    function getDepositorInfoRemote(
        uint256 vaultId,
        address _depositor
    ) public view returns (VaultHelper.DepositorInfo memory _depositorInfo) {
        _depositorInfo = factory.getDepositorInfo(vaultId, _depositor);
    }

    function previewDepositRemote(
        uint256 vaultId,
        uint256 _assets
    ) public view vaultExists(vaultId) returns (uint256 _shares) {
        _shares = factory.previewDeposit(vaultId, _assets);
    }

    function executeBridge() public {} //exectues bridge

    function getVault(
        uint256 vaultId
    ) public view returns (VaultHelper.Vault memory) {
        return factory.getvault(vaultId);
    }

    function getVaultAddress(
        uint256 vaultId
    ) public view vaultExists(vaultId) returns (address) {
        return factory.getVaultAddress(vaultId);
    }

    function setVaultImplementation(address implementation) public {
        factory.setVaultImplementation(implementation);
    }

    //initialize each dependenc no need to use interface we create here we makign like this to save space on deployment
    //update instead of using its instances deploy before adding and just use its interfaces
    //important we need noted above to save alot of space for dpeloyment

    //sets vault address for each dependency so it can communicate with us especially the messenger
    function setAddressDependencies(address vaultAddress) public {
        factory.setVault(vaultAddress);
        messenger.setVault(vaultAddress);
    }

    //must be messenger peer address must be
    function addMessengerPeer() public {
        for (uint256 i = 0; i < peerInfo.length; i++) {
            messenger.addPeer(peerInfo[i].eid, peerInfo[i].peer);
        }
    }

    //need to add all registry peers before making
    function addRegistryPeer(uint32 eid, bytes32 msgAddr) public onlyOwner {
        peerInfo.push(RegistryPeerInfo(eid, msgAddr));
    }

    //used to get quote to deploy one vault on another chain
    function vaultDeployQuote(
        uint256 vaultId,
        MessagingHelper.ComposedMessageQuote memory _quoteParams
    )
        public
        onlyAuhtorized(msg.sender)
        vaultExists(vaultId)
        returns (MessagingHelper.ComposedMessage memory _composedMessage)
    {
        _composedMessage = messenger.textMessengerQuote(vaultId, _quoteParams);
    }

    //used to get quote to deploy multiple vaults on multiple chains

    function composeMessageQuotes(
        uint256 vaultId,
        uint32[] memory _dstEids,
        address[] memory _dstEndpoints,
        string memory _vaultName,
        string memory _vaultTicker,
        address _deployer,
        VaultAssets.FeesInfo memory _fees,
        VaultAssets.feeReceiversInfo memory _reciever
    )
        public
        view
        returns (
            MessagingHelper.ComposedMessageQuote[] memory _quoteParamsCollection
        )
    {
        require(_dstEids.length == _dstEndpoints.length, "Lengths dont match!");
        _quoteParamsCollection = new MessagingHelper.ComposedMessageQuote[](
            _dstEids.length
        );
        for (uint256 i = 0; i < _dstEids.length; i++) {
            uint32 currentId = _dstEids[i];

            (
                VaultHelper.VaultDeployParams memory _constructorArg
            ) = constructVaultDeployParams(
                    _deployer,
                    _vaultName,
                    _vaultTicker,
                    _fees,
                    _reciever,
                    _dstEndpoints[i]
                );
            bytes memory message = abi.encodeWithSignature(
                "executeCrossChainDeploy(uint256,address,bytes)",
                vaultId,
                _deployer,
                abi.encode(_constructorArg)
            );
            bytes memory options = getOptions();
            _quoteParamsCollection[i] = MessagingHelper.ComposedMessageQuote(
                currentId,
                message,
                _deployer,
                options
            );
        }
    }

    function getOptions() public pure returns (bytes memory) {
        // Now this syntax will compile perfectly
        return
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                3_000_000,
                0
            );
    }

    function constructVaultDeployParams(
        address _deployer,
        string memory _vaultName,
        string memory _vaultTicker,
        VaultAssets.FeesInfo memory _fees,
        VaultAssets.feeReceiversInfo memory _reciever,
        address _endpoint
    )
        public
        view
        returns (VaultHelper.VaultDeployParams memory _constructorArg)
    {
        address[] memory _auth = new address[](1);
        _auth[0] = _deployer;
        _constructorArg = VaultHelper.VaultDeployParams(
            _deployer,
            _auth,
            _vaultName,
            _vaultTicker,
            _deployer,
            _endpoint,
            _fees,
            _reciever
        );
    }

    // struct ComposedMessageQuote {
    //     uint32 _dstEid;
    //     bytes _message;
    //     address _refundAddress;
    //     bytes _options;
    // }
    function vaultDeploymentsQuote(
        uint256 vaultId,
        MessagingHelper.ComposedMessageQuote[] memory _quoteParamsCollection
    )
        public
        view
        onlyAuhtorized(msg.sender)
        vaultExists(vaultId)
        returns (
            MessagingHelper.ComposedMessage[] memory _composedMessage,
            uint256 total
        )
    {
        (
            MessagingHelper.ComposedMessage[] memory composedMessage,
            uint256 _total
        ) = messenger.bulkTextRegistriesQuote(vaultId, _quoteParamsCollection);
        _composedMessage = composedMessage;
        total = _total;
    }

    //deploys vault on the products hub chain

    //directyl use factry here since same chain tx
    //before making multichain vaults this must bcreate d first
    //all registries mut be deployed and added as peers before proceeding
    function deployHubVault(
        address _owner,
        bytes memory deployParams
    ) public returns (uint256) {
        (uint256 vaultCreatedId, ) = factory.deployVault(deployParams);

        return vaultCreatedId;
    }

    //important we must do after deploying vault

    //quote to deploy vaults on multlpe chains vault mst be deploye don hub first
    function deployVaultsCrossChainQuotes(
        uint256 vaultId,
        MessagingHelper.ComposedMessageQuote[] memory _composedMessages
    )
        public
        view
        vaultExists(vaultId)
        returns (
            MessagingHelper.ComposedMessage[] memory composedMessages,
            uint256 total
        )
    {
        (
            MessagingHelper.ComposedMessage[] memory __composedMessages,
            uint256 _total
        ) = messenger.bulkTextRegistriesQuote(vaultId, _composedMessages);
        composedMessages = __composedMessages;
        total = _total;
    }

    function composeCrossChainMessages(uint32[] memory _dstEids) public {}

    //should use function called textRegistry instead of vault check make sure used properly
    function deployVaultCrossChain(
        uint256 vaultId,
        MessagingHelper.ComposedMessage[] memory _composedMessages,
        uint256 _total
    ) public payable vaultExists(vaultId) {
        bool deployed = messenger.bulkText{value: _total}(
            vaultId,
            _composedMessages
        );

        require(deployed, "Cannot dpeloy vaults multichain");
    }

    // function executeCrossChainDeploy(
    //     uint256 vaultId,
    //     address _owner,
    //     bytes memory deployParams
    // ) public {
    //     factory.deployVaultCrossChain(vaultId, deployParams);
    // }

    function recieveText(
        uint256 vaultId,
        bytes memory _text
    ) public vaultExists(vaultId) {
        (bool success, ) = address(this).call(_text); //gotta pass in vault id to call try to encode as well
        require(success, "Text could not execute try again!");
    }

    function isApproved(
        IERC20 asset,
        uint256 amount,
        address _owner,
        address _spender
    ) public view returns (bool) {
        uint256 _allowance = asset.allowance(_owner, _spender);
        return amount <= _allowance;
    }

    function userHasEnough(
        IERC20 asset,
        uint256 amount,
        address _spender
    ) public view {
        uint256 _balance = asset.balanceOf(_spender);
        require(amount > _balance, "Not enough tokens to transfer");
    }

    function deposit(
        uint256 vaultId,
        uint256 assets,
        address reciever
    ) public payable {
        VaultHelper.Vault memory vaultInfo = getVault(vaultId);
        bool isApproved = assets <= msg.value;
        // IERC20 vaultAsset = vaultInfo.depositAsset;
        // bool approved = isApproved(
        //     vaultInfo.depositAsset,
        //     assets,
        //     reciever,
        //     address(this)
        // );
        if (isApproved) {
            // transferAssets(reciever, vaultId, assets);
            // approveFacotrySpending(vaultId, vaultAsset, assets, address(this)); //checks and approves spending ing beofre deposit

            factory.deposit{value: msg.value}(vaultId, assets, reciever);
        }
    }

    // function approveFacotrySpending(
    //     uint256 vaultId,
    //     IERC20 asset,
    //     uint256 _amount,
    //     address _owner
    // ) public {
    //     VaultHelper.Vault memory vault = getVault(vaultId);
    //     IERC20 vaultAsset = vault.depositAsset;

    //     vaultAsset.approve(address(factory), _amount);

    //     factory.approveVault(vaultId, asset, _amount);
    // }

    // function transferAssets(
    //     address _caller,
    //     uint256 vaultId,
    //     uint256 assets
    // ) public {
    //     VaultHelper.Vault memory vaultInfo = getVault(vaultId);
    //     vaultInfo.depositAsset.transferFrom(_caller, address(this), assets);
    // }

    function withdraw(
        uint256 _vaultId,
        uint256 _shares,
        address _reciever,
        bytes memory _callBackStrategy
    ) public {
        factory.withdraw(_vaultId, _shares, _reciever, _callBackStrategy);
    }

    function setStrategy() public {}

    function stopVault() public onlyAuhtorized(msg.sender) {}

    //flushes vault and returns funds to users immediatley this happens when vault is paused stopped or any sort of hack
    function SOSVault() public onlyAuhtorized(msg.sender) {}
}
