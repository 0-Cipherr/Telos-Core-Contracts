// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Same field layout as LayerZero's OFT structs, so Stargate V2 pools
///      decode these values exactly. Defined locally so the vault does not
///      depend on the LayerZero OApp package being remapped.
struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTLimit {
    uint256 minAmountLD;
    uint256 maxAmountLD;
}

struct OFTFeeDetail {
    int256 feeAmountLD;
    string description;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

/// @notice Subset of the Stargate V2 pool interface used by TelosVault.
interface IStargate {
    /// @notice Underlying token of the pool; address(0) for native ETH pools.
    function token() external view returns (address);

    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);
}
