// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TelosVault} from "../src/TelosVault.sol";
import {
    IStargate,
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTLimit,
    OFTFeeDetail,
    OFTReceipt
} from "../src/interfaces/IStargate.sol";

contract MockStargate is IStargate {
    address public immutable underlying;
    uint256 public constant FEE = 0.001 ether;
    uint256 public lastValue;
    uint256 public lastAmount;

    constructor(address token_) {
        underlying = token_;
    }

    function token() external view returns (address) {
        return underlying;
    }

    function quoteOFT(SendParam calldata p)
        external
        pure
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        return (OFTLimit(0, type(uint256).max), new OFTFeeDetail[](0), OFTReceipt(p.amountLD, p.amountLD));
    }

    function quoteSend(SendParam calldata, bool) external pure returns (MessagingFee memory) {
        return MessagingFee(FEE, 0);
    }

    function sendToken(SendParam calldata p, MessagingFee calldata, address)
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        lastValue = msg.value;
        lastAmount = p.amountLD;
        return (MessagingReceipt(keccak256("guid"), 1, MessagingFee(FEE, 0)), OFTReceipt(p.amountLD, p.amountLD));
    }
}

contract TelosVaultTest is Test {
    TelosVault vault;
    MockStargate stargate;

    address creator = makeAddr("creator");
    address agent = makeAddr("agent");
    address treasury = makeAddr("treasury");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address to = makeAddr("to");
    uint256 constant FEE = 0.001 ether;

    function setUp() public {
        stargate = new MockStargate(address(0));
        vault = new TelosVault("Telos ETH", "tETH", 42, creator, agent, address(stargate), treasury, 100);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(creator, 1 ether);
        vm.deal(agent, 1 ether);
    }

    function test_rejectsErc20Pool() public {
        MockStargate erc20Pool = new MockStargate(makeAddr("usdc"));
        vm.expectRevert("Not native ETH pool");
        new TelosVault("x", "x", 1, creator, agent, address(erc20Pool), treasury, 0);
    }

    function test_metadata() public view {
        assertEq(vault.decimals(), 21);
        assertEq(vault.vaultId(), 42);
        assertEq(vault.creator(), creator);
    }

    function test_depositMintsSharesAndTracksAssets() public {
        vm.prank(alice);
        uint256 shares = vault.deposit{value: 1 ether}(alice);
        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), 1 ether);
    }

    function test_withdrawAppliesFeesAndPaysNet() public {
        vm.prank(alice);
        uint256 shares = vault.deposit{value: 10 ether}(alice);

        uint256 quoted = vault.previewWithdraw(shares);
        uint256 before = alice.balance;
        vm.prank(alice);
        uint256 net = vault.withdraw(shares, alice);

        assertEq(net, quoted);
        assertEq(alice.balance - before, net);
        // 10 ETH gross less 1% creator fee and 4% protocol fee.
        assertApproxEqAbs(net, 10 ether * 95 / 100, 1e12);
        assertEq(vault.balanceOf(alice), 0);
        assertGt(vault.creatorFees(), 0);
        assertGt(vault.protocolFees(), 0);
    }

    function test_creatorAndTreasuryClaimFees() public {
        vm.prank(alice);
        uint256 shares = vault.deposit{value: 10 ether}(alice);
        vm.prank(alice);
        vault.withdraw(shares, alice);

        uint256 creatorBefore = creator.balance;
        vm.prank(creator);
        vault.claimCreatorFees();
        assertGt(creator.balance, creatorBefore);

        uint256 treasuryBefore = treasury.balance;
        vm.prank(treasury);
        vault.claimProtocolFees();
        assertGt(treasury.balance, treasuryBefore);
    }

    function test_withdrawBlockedWhenFundsAreDeployed() public {
        vm.prank(alice);
        uint256 shares = vault.deposit{value: 10 ether}(alice);
        vm.prank(creator);
        vault.bridgeOut{value: FEE}(30110, to, 9.5 ether, 0);
        vm.prank(creator);
        vault.setDeployedValue(9.5 ether);

        vm.prank(alice);
        vm.expectRevert("Insufficient liquidity");
        vault.withdraw(shares, alice);
    }

    function test_onlyOperatorsBridge() public {
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectRevert("Unauthorized");
        vault.bridgeOut{value: FEE}(30110, to, 1 ether, 0);
    }

    function test_bridgeRequiresExactFee() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}(alice);
        vm.prank(agent);
        vm.expectRevert("Wrong bridge fee");
        vault.bridgeOut{value: 1}(30110, to, 1 ether, 0);
    }

    function test_bridgeSendsAmountPlusFee() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}(alice);
        vm.prank(agent);
        vault.bridgeOut{value: FEE}(30110, to, 1 ether, 0);
        assertEq(stargate.lastAmount(), 1 ether);
        assertEq(stargate.lastValue(), 1 ether + FEE);
    }

    function test_setDeployedValueCountsInNav() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}(alice);
        vm.prank(creator);
        vault.setDeployedValue(4 ether);
        assertEq(vault.totalAssets(), 5 ether);
    }
}
