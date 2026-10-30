// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    IStargate,
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "./interfaces/IStargate.sol";

/// @title TelosVault
/// @notice Native ETH vault. Depositors receive share tokens; the creator and
///         agent can bridge idle ETH out through Stargate and run strategies.
///         Deployed directly (no factory).
contract TelosVault is ERC20, ReentrancyGuard {
    uint256 public constant PROTOCOL_FEE_BPS = 400; // 4%
    uint256 public constant BPS = 10_000;
    uint256 private constant VIRTUAL_SHARES = 1e3; // 3 virtual decimals
    uint256 private constant VIRTUAL_ASSETS = 1;

    IStargate public immutable stargate;
    address public immutable creator;
    address public immutable agent;
    address public immutable protocolTreasury;
    uint256 public immutable creatorFeeBps;
    uint256 public immutable vaultId;

    /// @notice ETH the creator/agent reports as currently deployed outside the vault.
    uint256 public deployedValue;
    uint256 public creatorFees;
    uint256 public protocolFees;

    event Deposited(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);
    event Withdrawn(address indexed owner, address indexed receiver, uint256 shares, uint256 netAssets);
    event BridgedOut(uint32 indexed dstEid, address indexed to, uint256 amount, bytes32 guid);
    event DeployedValueUpdated(uint256 value);
    event CreatorFeesClaimed(uint256 amount);
    event ProtocolFeesClaimed(uint256 amount);

    modifier onlyOperator() {
        require(msg.sender == creator || msg.sender == agent, "Unauthorized");
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 vaultId_,
        address creator_,
        address agent_,
        address stargate_,
        address protocolTreasury_,
        uint256 creatorFeeBps_
    ) ERC20(name_, symbol_) {
        require(creator_ != address(0) && protocolTreasury_ != address(0), "Zero address");
        require(creatorFeeBps_ <= BPS - PROTOCOL_FEE_BPS, "Creator fee too high");

        stargate = IStargate(stargate_);
        require(stargate.token() == address(0), "Not native ETH pool");

        vaultId = vaultId_;
        creator = creator_;
        agent = agent_;
        protocolTreasury = protocolTreasury_;
        creatorFeeBps = creatorFeeBps_;
    }

    function decimals() public pure override returns (uint8) {
        return 21; // 18 (ETH) + 3 virtual decimals
    }

    /// @notice ETH the vault accounts for: idle balance plus value deployed outside,
    ///         excluding fees that are owed to the creator and protocol.
    function totalAssets() public view returns (uint256) {
        return address(this).balance - creatorFees - protocolFees + deployedValue;
    }

    function deposit(address receiver) public payable nonReentrant returns (uint256 shares) {
        require(msg.value > 0, "Zero deposit");
        require(receiver != address(0), "Zero address");

        uint256 assetsBefore = totalAssets() - msg.value;
        shares = (msg.value * (totalSupply() + VIRTUAL_SHARES)) / (assetsBefore + VIRTUAL_ASSETS);
        require(shares > 0, "Deposit too small");

        _mint(receiver, shares);
        emit Deposited(msg.sender, receiver, msg.value, shares);
    }

    /// @notice Net ETH a holder receives for `shares` right now, after fees.
    function previewWithdraw(uint256 shares) public view returns (uint256 netAssets) {
        (uint256 gross, uint256 creatorFee, uint256 creatorShare, uint256 protocolShare) = _quoteWithdraw(shares);
        netAssets = gross - creatorFee - creatorShare - protocolShare;
    }

    function withdraw(uint256 shares, address receiver) public nonReentrant returns (uint256 netAssets) {
        require(shares > 0, "Zero shares");
        require(receiver != address(0), "Zero address");

        (uint256 gross, uint256 creatorFee, uint256 creatorShare, uint256 protocolShare) = _quoteWithdraw(shares);
        netAssets = gross - creatorFee - creatorShare - protocolShare;

        uint256 idle = address(this).balance - creatorFees - protocolFees;
        require(gross <= idle, "Insufficient liquidity");

        _burn(msg.sender, shares);
        creatorFees += creatorFee + creatorShare;
        protocolFees += protocolShare;

        (bool success, ) = payable(receiver).call{value: netAssets}("");
        require(success, "Withdrawal failed");
        emit Withdrawn(msg.sender, receiver, shares, netAssets);
    }

    /// @notice Creator marks ETH deployed outside the vault (e.g. bridged and in strategies).
    function setDeployedValue(uint256 value) external onlyOperator {
        deployedValue = value;
        emit DeployedValueUpdated(value);
    }

    function claimCreatorFees() external nonReentrant {
        require(msg.sender == creator, "Unauthorized");
        uint256 amount = creatorFees;
        creatorFees = 0;
        (bool success, ) = payable(creator).call{value: amount}("");
        require(success, "Claim failed");
        emit CreatorFeesClaimed(amount);
    }

    function claimProtocolFees() external nonReentrant {
        require(msg.sender == protocolTreasury, "Unauthorized");
        uint256 amount = protocolFees;
        protocolFees = 0;
        (bool success, ) = payable(protocolTreasury).call{value: amount}("");
        require(success, "Claim failed");
        emit ProtocolFeesClaimed(amount);
    }

    /// @notice Stargate fee and the amount the destination receives for `amount`.
    function quoteBridgeOut(
        uint32 dstEid,
        address to,
        uint256 amount
    ) public view returns (uint256 nativeFee, uint256 amountReceived) {
        SendParam memory sendParam = _sendParam(dstEid, to, amount, 0);
        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;
        MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        return (fee.nativeFee, receipt.amountReceivedLD);
    }

    /// @notice Bridges `amount` ETH from the vault. The Stargate fee is paid by msg.value.
    function bridgeOut(
        uint32 dstEid,
        address to,
        uint256 amount,
        uint256 minAmountReceived
    ) external payable onlyOperator nonReentrant returns (bytes32 guid) {
        require(amount > 0, "Zero amount");
        uint256 idle = address(this).balance - creatorFees - protocolFees;
        require(amount <= idle, "Insufficient assets");

        SendParam memory sendParam = _sendParam(dstEid, to, amount, minAmountReceived);
        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        require(receipt.amountReceivedLD >= minAmountReceived, "Slippage");
        MessagingFee memory fee = stargate.quoteSend(sendParam, false);
        require(msg.value == fee.nativeFee, "Wrong bridge fee");

        MessagingReceipt memory messaging;
        (messaging, ) = stargate.sendToken{value: amount + fee.nativeFee}(sendParam, fee, msg.sender);
        guid = messaging.guid;
        emit BridgedOut(dstEid, to, amount, guid);
    }

    function _sendParam(
        uint32 dstEid,
        address to,
        uint256 amount,
        uint256 minAmount
    ) private pure returns (SendParam memory) {
        return SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(to))),
            amountLD: amount,
            minAmountLD: minAmount,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
    }

    /// @dev Splits a gross withdrawal into the creator fee, the creator's half of the
    ///      protocol fee, and the treasury's half. The remainder is the net payout.
    function _quoteWithdraw(
        uint256 shares
    ) private view returns (uint256 gross, uint256 creatorFee, uint256 creatorShare, uint256 protocolShare) {
        gross = (shares * (totalAssets() + VIRTUAL_ASSETS)) / (totalSupply() + VIRTUAL_SHARES);
        creatorFee = (gross * creatorFeeBps) / BPS;
        uint256 protocolTotal = (gross * PROTOCOL_FEE_BPS) / BPS;
        creatorShare = protocolTotal / 2;
        protocolShare = protocolTotal - creatorShare;
    }

    receive() external payable {}
}
