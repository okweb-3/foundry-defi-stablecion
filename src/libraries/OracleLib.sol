// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author okweb3
 * @notice This library is used to check the Chainlink Oracle for stale data
 *
 * If a price is stale, function will revert, and render the DSCEngine unsable this is by design
 * We want the DSCEngine to freeze if prices become stale.
 * So if the Chainlink network explodes and you have a lot of money locked in the protocol ... too bad  *
 */

library OracleLib {
    error Oracle__StablePrice();
    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(
        AggregatorV3Interface priceFeed
    ) public view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updateAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updateAt;
        if (secondsSince > TIMEOUT) {
            revert Oracle__StablePrice();
        }
        return (roundId, answer, startedAt, updateAt, answeredInRound);
    }
}
