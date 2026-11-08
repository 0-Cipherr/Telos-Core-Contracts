// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
//
//
import {TelosVault} from "./TelosVault.sol";

contract VaultFactory {
    address factoryDelegate;

    modifier onlyDelegate() {
        require(msg.sender == factoryDelegate, "Not owner to call this!");
        _;
    }

    constructor(address _factoryDelegate) {
        factoryDelegate = _factoryDelegate;
    }

    function updateDelegate(address _newDelegate) public {
        factoryDelegate = _newDelegate;
    }

    function deployVaultSingle() public payable returns (address vaultAddress, uint256 vaultId) {
        TelosVault _vaultDeployed =
            new TelosVault(_endpointId, _vaultId, _creator, _agent, _stargate, _creatorFee, _protocolFee, _hubEid);
    }

    function deployVaultMultiChains() public payable returns (uint256 vaultId) {}
}
