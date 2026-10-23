// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IVaultManager} from "./IVaultManager.sol";
import {VaultManager} from "../src/VaultManager.sol";
import {VaultHelper} from "../src/VaultHelper.sol";
import {MessagingHelper} from "./MessagingHelper.sol";
import {IStrategyAdapter} from "./IStrategyAdapter.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {VaultImplementation} from "./VaultImplementation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultFactory {
    //accounting hld in the manager
    uint256 currentVaultId;
    address authroized;
    address vaultRegistry;
    uint256 changeOwnerMax = 3;
    IStrategyAdapter strategyAdapter;
    address private vaultImplementation;
    address vaultManager;

    mapping(address => uint256) changeOwnerChances;
    mapping(uint256 => VaultHelper.Vault) vaultsDeployed;
    mapping(uint256 => address) vaultAddress;

    //authorized shold only be the registry
    constructor(address _authorized, IStrategyAdapter _strategyAdapter) {
        currentVaultId = 0;
        authroized = _authorized;
        strategyAdapter = _strategyAdapter;
    }

    modifier onlyAUhtorized(address attemptedUser) {
        require(attemptedUser == authroized || attemptedUser == vaultRegistry, "Not authrized to perform ");
        _;
    }

    function previewDeposit(uint256 vaultId, uint256 _amount) public view returns (uint256 _shares) {
        _shares = vaultsDeployed[vaultId].vault.previewDeposit(_amount);
    }

    function previewWithdraw(uint256 _vaultId, uint256 _shares) public view returns (uint256 _assets) {
        _assets = vaultsDeployed[_vaultId].vault.previewWithdraw(_shares);
    }

    function getDepositorInfo(uint256 _vaultId, address _depositorInfo)
        public
        view
        returns (VaultHelper.DepositorInfo memory _depositor)
    {
        _depositor = vaultsDeployed[_vaultId].vault.getDepositorInfo(_depositorInfo);
    }

    function setVaultImplementation(address vault) public {
        vaultImplementation = vault;
    }

    function setVaultAddress(uint256 vaultId, address vault) public {
        vaultAddress[vaultId] = vault;
    }

    function getVaultAddress(uint256 vaultId) public view returns (address) {
        return vaultAddress[vaultId];
    }

    function setVault(address _vaultRegistry) public {
        vaultRegistry = _vaultRegistry;
    }

    function verifyVault(uint256 vaultId) public view returns (bool isValid) {
        isValid = false;

        for (uint256 i = 0; i < currentVaultId; i++) {
            bool isVaultInitiated = vaultsDeployed[i].creator != address(0); //if doesnt exist defauts to zeor adress
            if (isVaultInitiated && vaultId == i) {
                isValid = true;
                break;
            }
        }
    }

    function approveVault(uint256 vaultId, IERC20 asset, uint256 _amount) public {
        //
        address vault = getVaultAddress(vaultId); //spender is the vault address
        asset.approve(vault, _amount);
    }

    function setVaultsDeployed(uint256 vaultId, VaultHelper.Vault memory vaultInfo) public onlyAUhtorized(msg.sender) {
        vaultsDeployed[vaultId] = vaultInfo;
    }

    function setStrategyId(uint256 vaultId, uint256 strategyId, bytes memory depositCallback) public {
        vaultsDeployed[vaultId].vault.setStrategy(strategyId, depositCallback);
        //witdraw fromcurrent deposits into next
    }

    function updateVaultTVL(uint256 vaultId, uint256 value, bool isDeduction) public {
        if (isDeduction == false) {
            vaultsDeployed[vaultId].tvl += value;
        } else {
            uint256 TVL = vaultsDeployed[vaultId].tvl;
            require(TVL - value > 0, "LESS THAN ZERO UNDERFLOW");
            vaultsDeployed[vaultId].tvl -= value;
        }
    }

    function updateVaultallTimeVolume(uint256 vaultId, uint256 amount) public {
        //only arriba
        vaultsDeployed[vaultId].allTimeVolume += amount;
    }

    function updateAuthorized(uint256 vaultId, address user, bool shouldAppend) public {
        if (shouldAppend) {
            vaultsDeployed[vaultId].authorized.push(user);
        } else {
            //add logic to remove be cautious and shift the indexes
        }
    }

    function transferFromRegistry(IERC20 asset, address _from, address _to, uint256 _amount) public {
        asset.transferFrom(_from, _to, _amount);
    }

    function isApproved(IERC20 _asset, address _owner, address _spender, uint256 _amount) public view returns (bool) {
        uint256 allowance = _asset.allowance(_owner, _spender);
        return _amount <= allowance;
    }

    error NotApproved(uint256 _amount, uint256 vaultId);

    function deposit(uint256 vaultId, uint256 assets, address receiver) public payable {
        // vaultsDeployed[vaultId].depositAsset.transferFrom(address(vaultRegistry), address(this), assets); depreceated
        vaultsDeployed[vaultId].vault.depositAssets{value: msg.value}(assets, receiver, bytes(""));
        updateVaultTVL(vaultId, assets, false);
        updateVaultallTimeVolume(vaultId, assets);
    }

    // function approveVault(uint256 vaultId, uint256 _amount) public {
    //     address _vaultAddress = getVaultAddress(vaultId);
    //     IERC20 vaultAsset = vaultsDeployed[vaultId].depositAsset;
    //     bool approved = isApproved(
    //         vaultAsset,
    //         address(this),
    //         _vaultAddress,
    //         _amount
    //     );
    //     if (!approved) {
    //         vaultAsset.approve(_vaultAddress, _amount);
    //     }
    // }

    function withdraw(uint256 vaultId, uint256 _shares, address receiver, bytes calldata callBackStrategy) public {
        vaultsDeployed[vaultId].vault.withdrawAssets(_shares, receiver, callBackStrategy);
    }

    function deployVaultCrossChain(uint256 _vaultId, IERC20 vaultAsset, bytes memory deployVaultParams) public {
        require(vaultImplementation != address(0), "No implementation set");
        VaultHelper.VaultDeployParams memory deployParams =
            abi.decode(deployVaultParams, (VaultHelper.VaultDeployParams));
        // /eip1167 impelementation upgradable contract save space
        //good standard for factories

        address vault = clonseImplementation();

        intializeVault(vault, vaultAsset, deployParams);

        address[] memory vaultAuthorized = new address[](1);
        vaultAuthorized[0] = deployParams.creator;
        setupVault(_vaultId, vault, abi.encode(deployParams), vaultAuthorized);
        currentVaultId = _vaultId + 1;
    }

    function intializeVault(address vault, IERC20 vaultAsset, VaultHelper.VaultDeployParams memory deployParams)
        public
    {
        VaultManager(payable(vault)).__initialize_vault_(deployParams, vaultAsset, strategyAdapter);
        (deployParams, strategyAdapter);
    }

    function setupVault(uint256 _vaultId, address vault, bytes memory deployParams, address[] memory vaultAuthorized)
        public
    {
        VaultHelper.VaultDeployParams memory vaultDeployParams =
            abi.decode(deployParams, (VaultHelper.VaultDeployParams));
        setVaultAddress(_vaultId, vault);
        registerVault(vaultDeployParams, IVaultManager(vault), vaultAuthorized);
    }

    function deployVault(bytes memory deployVaultParams) public returns (uint256 vaultId, IVaultManager vaultDeployed) {
        require(vaultImplementation != address(0), "No implementation set");
        (IERC20 vaultAsset, VaultHelper.VaultDeployParams memory deployParams) =
            abi.decode(deployVaultParams, (IERC20, VaultHelper.VaultDeployParams));

        address vault = clonseImplementation();

        intializeVault(vault, vaultAsset, deployParams);

        vaultDeployed = IVaultManager(vault);
        vaultId = currentVaultId;

        address[] memory vaultAuthorized = new address[](1);
        vaultAuthorized[0] = deployParams.creator;
        setupVault(vaultId, vault, abi.encode((deployParams)), vaultAuthorized);
    }

    function clonseImplementation() public returns (address clone) {
        clone = Clones.clone(address((vaultImplementation)));
    }

    function registerVault(
        VaultHelper.VaultDeployParams memory deployParams,
        IVaultManager vaultDeployed,
        address[] memory _vaultAuthorized
    ) public onlyAUhtorized(msg.sender) {
        setVaultsDeployed(
            currentVaultId,
            VaultHelper.Vault(
                deployParams.creator, //creator
                0, //tvl
                0, //alltimevolume
                vaultDeployed, //vault deployed
                deployParams.vaultName, //vault name
                deployParams.vaultTicker, //vault ticker
                // deployParams.vaultAsset, //vaultAsset
                _vaultAuthorized // authorized users of the vault
            )
        );

        increaseVaultId(); // upthe vualt id evety time
    }

    function getDepositor(uint256 vaultId, address _user)
        public
        view
        returns (VaultHelper.DepositorInfo memory _depositor)
    {
        _depositor = vaultsDeployed[vaultId].vault.getDepositorInfo(_user);
    }

    function increaseVaultId() public onlyAUhtorized(msg.sender) {
        ++currentVaultId;
    }

    function getvault(uint256 vaultId) public view onlyAUhtorized(msg.sender) returns (VaultHelper.Vault memory vault) {
        vault = vaultsDeployed[vaultId];
    }

    function verifyChances(address _owner) public view onlyAUhtorized(msg.sender) {
        uint256 chance = getOwnerChangeChances(_owner);
        require(chance < changeOwnerMax, "You ran out of vault owner canges ");
    } //emergency use case one time use

    function changeVaultOwner(uint256 vaultId) public onlyAUhtorized(msg.sender) {
        VaultHelper.Vault memory userVault = vaultsDeployed[vaultId];
        incrementChangeOwnerChances(userVault.creator);
    }

    function getOwnerChangeChances(address _owner) public view onlyAUhtorized(msg.sender) returns (uint256) {
        return changeOwnerChances[_owner];
    }

    function incrementChangeOwnerChances(address _owner) public onlyAUhtorized(msg.sender) {
        changeOwnerChances[_owner] += 1;
    }

    function getVaultTotalAssets(uint256 vaultId) public {}
}
// initializeVault()
// configureVault()
// validateDeployParams()
//migrate these fucntions from registry tosave space wont deploy cuz of space

// I’ll interpret the deployment-size change and identify why adding the concrete vault-manager setup increased the factory bytecode, while preserving your existing code.

// Searched for regex `VaultFactory|VaultManager|Clones|deployVaultImplementation` (`**/Avenor/src/**`), 40 results

// Read , lines 1 to 155

// Read

// Read
// //solution for vault deployment for setting the vault implementations thats all we gotta fix
// The +176-byte increase is consistent with adding the concrete implementation deployment path to the factory: the factory now includes the VaultImplementation constructor and its inheritance/runtime code, while the previous factory only referenced the manager interface and clone mechanism. I’m checking which references can be moved out without changing behavior.

// Read , lines 1 to 120

// ## Cause of the size increase

// The direct deployment in VaultFacoty.sol includes the creation code of VaultImplementation inside the factory:

//     new VaultImplementation(_endpoint)

// Therefore, the factory must carry that implementation’s bytecode, increasing its deployed size by roughly 176 bytes.

// ## Best option without changing the code yet

// Deploy the concrete implementation separately, then call the existing setVaultImplementation function in VaultFacoty.sol.

// Recommended sequence:

// 1. Deploy VaultImplementation with its endpoint.
// 2. Call factory.setVaultImplementation(addressOfImplementation).
// 3. Deploy vaults through the existing Clones flow.
// 4. Avoid calling factory.deployVaultImplementation during factory initialization.

// This keeps the implementation out of the factory’s bytecode and uses the existing setter.

// ## Alternative

// Move the implementation deployment into a separate helper contract:

// - Helper deploys VaultImplementation.
// - Helper returns its address.
// - Factory receives only the implementation address.
// - Factory performs Clones cloning.

// This is cleaner if you want to keep the factory small and make deployment responsibilities explicit.

// ## Important observation

// The factory currently has two ways to configure the implementation:

// - setVaultImplementation(address)
// - deployVaultImplementation(address)

// The first stores an already deployed implementation. The second embeds the implementation creation code into the factory.

// Therefore, the size problem is caused mainly by using deployVaultImplementation rather than the existing address-based setter.

// > The permanent solution is to deploy VaultImplementation separately and pass its address into setVaultImplementation. This avoids changing the current vault deployment behavior while reducing the factory’s deployed bytecode.
