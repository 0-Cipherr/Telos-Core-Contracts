// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStargate} from "./interfaces/IStargate.sol";
import {SendParam, MessagingFee, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {VaultMath} from "./VaultMath.sol";

contract TelosVault is VaultMath {
    uint256 public totalAssets;
    address[] public authorized;

    uint32 public endpointId;
    uint256 public vaultId;

    IStargate public immutable stargate;

    uint256 creatorFee;

    uint256 protocolFee;

    uint32 hubEid;
    address creator;
    address protocol;

    modifier onlyAuthorized() {
        bool allowed;

        for (uint256 i = 0; i < authorized.length; i++) {
            if (authorized[i] == msg.sender) {
                allowed = true;
                break;
            }
        }

        require(allowed, "Unauthorized");
        _;
    }

    constructor(
        uint32 _endpointId,
        uint256 _vaultId,
        address _creator,
        address _agent,
        address _stargate,
        uint256 _creatorFee,
        uint256 _protocolFee,
        uint32 _hubEid
    ) VaultMath(10000) {
        creator = _creator;
        endpointId = _endpointId;
        vaultId = _vaultId;
        stargate = IStargate(_stargate);

        authorized.push(_creator);
        authorized.push(_agent);
        authorized.push(msg.sender);

        creatorFee = _creatorFee;
        protocolFee = _protocolFee;
        hubEid = _hubEid;

        require(stargate.token() == address(0), "Not native ETH pool");
    }

    function deposit(uint256 _amountETH) public payable {
        require(_amountETH == msg.value, "Incorrect ETH amount");

        totalAssets += _amountETH;
    }

    function addAuhtorizd(address _newAuth) public onlyAuthorized {
        authorized.push(_newAuth);
    }

    function vaulthasEnough(uint256 _ETHAmountRequested) public view returns (bool) {
        return totalAssets > _ETHAmountRequested;
    }

    function calculateFees(uint256 _ETHAmountRequested)
        public
        view
        returns (uint256 _amountLeft, uint256 creatorCharge, uint256 protoclCharge)
    {
        require(totalAssets > _ETHAmountRequested, "Not enough to withdraw");
        uint256 creatorCharge = multPercentage(creatorFee, _ETHAmountRequested);

        uint256 protocolCharge = multPercentage(protocolFee, _ETHAmountRequested);

        return totalAssets - ((totalAssets - creatorCharge) + (totalAssets - protocolCharge));
    }

    function splitFees(uint256 creatorCharge, uint256 protocolCharge) public {
        (bool success,) = address(creator).call{value: creatorCharge}("");

        (bool success,) = address(creator).call{value: protocolCharge}("");
    }

    function splitFeesCrossChain(
        address _withdrawer,
        uint256 _ETHToRecieve,
        uint256 creatorCharge,
        uint256 protocolCharge
    ) public {
        (uint256 creatorBridgeFee, uint256 amountCreatorRecieved) = bridgeQuote(totalAssets - creatorCharge);

        (uint256 protocolBridgeFee, uint256 amountProtocolRecieved) = bridgeQuote(protocolCharge, protocol);
        (uint256 withdrawerFee, uint256 amountWithdrawerRecieved) = bridgeQuote(_ETHToRecieve, _withdrawer);
        bridge(amountCreatorRecieved + withdrawerFee, creator);
        bridge(protocolCharge + amountProtocolRecieved, protocol);
        bridge(_ETHToRecieve, _withdrawer);
    }

    function withdraw(address payable _receiver, uint256 _ETHAmountRequested) public onlyAuthorized {
        require(_amount <= totalAssets, "Insufficient assets");
        (uint256 _amountLeft, uint256 creatorCharge, uint256 protocolCharge) = calculateFees(_ETHAmountRequested);
        totalAssets -= _ETHAmountRequested;

        if (isVaultHub()) {
            splitFeesCrossChain(_reciever, _amountLeft, creatorCharge, protocolCharge);
        } else {
            splitFees(creatorCharge, protocolCharge);
            payWallet(_receiver, _amountLeft);
        }
    }

    function payWallet(address _reciever, uint256 _ETHAmountToPay) {
        (bool success,) = address(_reciever){value: _ETHAmountToPay}("");
    }

    function isVaultHub() public returns (bool) {
        return endpointId == hubEid;
    }

    function genOptions() public view returns (bytes memory) {
        return bytes(0);
    }

    // Get Stargate bridge fee and estimated destination amount
    function bridgeQuote(uint256 _ETHAmountToBridge, address _receiver)
        public
        view
        returns (uint256 nativeFee, uint256 amountReceived)
    {
        bytes memory _generatedOptions = genOptions();
        SendParam memory sendParam = SendParam({
            dstEid: endpointId,
            to: bytes32(uint256(uint160(_receiver))),
            amountLD: _ETHAmountToBridge,
            minAmountLD: 0,
            extraOptions: _generatedOptions,
            composeMsg: "",
            oftCmd: ""
        });

        (,, OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);

        sendParam.minAmountLD = receipt.amountReceivedLD;

        MessagingFee memory fee = stargate.quoteSend(sendParam, false);

        return (fee.nativeFee, receipt.amountReceivedLD);
    }

    function composeMessage() public view returns (bytes memory) {
        return bytes(0);
    }

    function generateOFTCmd() public view returns (bytes memory) {
        return bytes(0);
    }

    // Bridge native ETH held by this vault to another chain
    function bridge(uint256 _ETHAmountToBridge, address _receiver) public onlyAuthorized {
        require(_amount <= totalAssets, "Insufficient assets");

        SendParam memory sendParam = SendParam({
            dstEid: endpointId,
            to: bytes32(uint256(uint160(_receiver))),
            amountLD: _ETHAmountToBridge,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (,, OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);

        sendParam.minAmountLD = receipt.amountReceivedLD;

        MessagingFee memory fee = stargate.quoteSend(sendParam, false);

        require(address(this).balance >= _amount + fee.nativeFee, "Insufficient ETH for bridge and fee");

        totalAssets -= _amount;

        stargate.sendToken{value: _amount + fee.nativeFee}(sendParam, fee, msg.sender);
    }

    receive() external payable {}
}
