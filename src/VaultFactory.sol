// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
//
//
import {TelosVault} from "./TelosVault.sol";

//note the telosVault should be wrapped in a proxt state is mainly handled in db i hate solidity state so ass
contract VaultFactory {
    address factoryDelegate;
    uint256 public currentId;
    uint32 public nativeEndpointId;
    uint32 public hubEndpointId;
    IStargate public stargate;
    uint256 public protocolFee;
    modifier onlyDelegate() {
        require(msg.sender == factoryDelegate, "Not owner to call this!");
        _;
    }

    constructor(address _factoryDelegate) {
        factoryDelegate = _factoryDelegate;
    }

    function updateDelegate(address _newDelegate) public onlyDelegate(msg.sender) {
        factoryDelegate = _newDelegate;
    }

    function setNativeEndpointId(uint32 _nativeEndpointId) public onlyDelegate(msg.sender) {
        nativeEndpointId = _nativeEndpointId;
    }

    function setHubEndpointId(uint32 _hubEndpointId) public onlyDelegate(msg.sender) {
        hubEndpointId = _hubEndpointId;
    }

    function deployVaultSingle(address _creator, address _agent, uint256 _creatorFee)
        public
        payable
        returns (address vaultAddress, uint256 vaultId)
    {
        TelosVault _vaultDeployed = new TelosVault(
            endpointId, currentId, _creator, _agent, stargate, _creatorFee, _protocolFee, _hubEid
        );

        vaultAddress = address(_vaultDeployed);

        vaultId = currentId;
    }

    function increaseId() public {
        currentId++;
    }
}
