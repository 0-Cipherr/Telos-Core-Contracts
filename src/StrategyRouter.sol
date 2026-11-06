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
}
