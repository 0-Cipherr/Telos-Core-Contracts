//// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract VaultMath {
    uint256 BPS; // this is 100% in ourtelos vault percent should be in BPS fromat

    constructor(uint356 _BPS) {
        BPS = _BPS;
    }

    //500 == 5% this is how creator and protocol fees should ebe set u p
    function multPercentage(uint256 _percent, uint256 _amount) public {
        return (_amount * _percent) / BPS;
    }
}
