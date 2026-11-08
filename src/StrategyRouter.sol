// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStrategy} from "./IStrategy.sol";

contract StrategyManager {
    Strategy[] strategies;

    //optional strategy seed upon chain deployment maybe flow to pree seeed the router
    ////before becoming available to users
    constructor(Strategy[] memory _strategies) {
        if (_strategies.length > 0) {
            strategies = _strategies;
        }
    }

    struct Strategy {
        IStrategy strategy;
        address creator;
        string name;
    }

    //manage the data in db better less tedious i hate state in solidity :()

    function addStrategy(IStrategy strategy, string memory name, address creator) public {
        strategies.push(Strategy(strategy, creator, name));
    }

    //optinal nitialize function

    function initializeVault(uint256 _strategyIndex, IStrategy.StrategyConfig calldata strategyConfig) public {
        strategies[_strategyIndex].strategy.initialize(strategyConfig);
    }

    function enterStrategy(uint256 _strategyIndex, uint256 _amountETH) public payable {
        strategies[_strategyIndex].strategy.deposit(_amountETH);
    }

    function getTotalAssets(uint256 _strategyIndex) public view returns (uint256) {
        return strategies[_strategyIndex].strategy.totalAssets();
    }

    function getConfig(uint256 _strategyIndex) public view returns (IStrategy.StrategyConfig memory _strategyConfig) {
        _strategyConfig = strategies[_strategyIndex].strategy.getConfig();
    }

    function isStratPaused(uint256 _strategyIndex) public view returns (bool) {
        return strategies[_strategyIndex].strategy.paused();
    }

    function exitStrategy(uint256 _strategyIndex, uint256 _ETHAmountRequested) public {
        strategies[_strategyIndex].strategy.withdraw(_ETHAmountRequested);
    }

    function harvestStrategy(uint256 _strategyIndex) public {}

    function getAPY(uint256 _strategyIndex) public view returns (uint256) {
        return strategies[_strategyIndex].strategy.getAPY();
    }

    function getStrategyAPR() public view returns (uint256) {
        return 100;
    }

    function predictReturns() public view returns (uint256) {
        return 100;
    }

    function payWallet(address _reciever, uint256 _ETHAmountToPay) public {
        (bool _success,) = address(_reciever).call{value: _ETHAmountToPay}("");
        require(_success, "Wallet wasnot paid!");
    }

    function recieve() external payable {}
}
