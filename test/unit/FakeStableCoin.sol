// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract FakeStableCoin {
    address public attacker;

    constructor(address _attacker) {
        attacker = _attacker;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        // 在 mint 过程中回调攻击者的 attack()，模拟重入
        (bool success, ) = attacker.call(abi.encodeWithSignature("attack()"));
        require(success, "Reentrancy attack failed");
        return true;
    }

    function transferFrom(address, address, uint256) external returns (bool) {
        return true;
    }

    function burn(uint256) external {}
}
