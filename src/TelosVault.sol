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

    function deposit(uint256 _amount) public payable {
        require(_amount == msg.value, "Incorrect ETH amount");

        totalAssets += _amount;
    }

    function addAuhtorizd(address _newAuth) public onlyAuthorized {
        authorized.push(_newAuth);
    }

    function isInStrategy() {}

    function vaulthasEnough() public view returns (bool) {
        return true;
    }

    function splitFees(uint256 _amount) public {
        require(totalAssets > _amount, "Not enough to withdraw");
        uint256 creatorCharge = multPercentage(creatorFee, _amount);

        uint256 protocolCharge = multPercentage(protocolFee, _amount);
        (uint256 nativeFeeCreator, uint256 amountCreatorRecieved) = bridgeQuote(totalAssets - creatorCharge);

        (uint256 nativeFeeProtocol, uint256 amountProtocolRecieved) = bridgeQuote(totalAssets - creatorCharge);

        bridge(totalAssets - creatorCharge, creator);
        bridge(totalAssets - protocolCharge, protocol);
    }

    function withdraw(address payable _receiver, uint256 _amount) public onlyAuthorized {
        require(_amount <= totalAssets, "Insufficient assets");

        totalAssets -= _amount;

        (bool success,) = _receiver.call{value: _amount}("");
        require(success, "Withdrawal failed");
    }

    // Get Stargate bridge fee and estimated destination amount
    function bridgeQuote(uint256 _amount, address _receiver)
        public
        view
        returns (uint256 nativeFee, uint256 amountReceived)
    {
        SendParam memory sendParam = SendParam({
            dstEid: endpointId,
            to: bytes32(uint256(uint160(_receiver))),
            amountLD: _amount,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        (,, OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);

        sendParam.minAmountLD = receipt.amountReceivedLD;

        MessagingFee memory fee = stargate.quoteSend(sendParam, false);

        return (fee.nativeFee, receipt.amountReceivedLD);
    }

    // Bridge native ETH held by this vault to another chain
    function bridge(uint256 _amount, address _receiver) public onlyAuthorized {
        require(_amount <= totalAssets, "Insufficient assets");

        SendParam memory sendParam = SendParam({
            dstEid: endpointId,
            to: bytes32(uint256(uint160(_receiver))),
            amountLD: _amount,
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
