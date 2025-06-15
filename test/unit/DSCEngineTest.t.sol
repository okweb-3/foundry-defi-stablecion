// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin}  from "../../src/DecentralizedStableCoin.sol";
import {Test,console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";


contract DSCEngineTest is Test{
        DeployDSC deployer;
        DecentralizedStableCoin dsc;
        DSCEngine dsce;
        address public weth;
        HelperConfig public helperConfig;
        address ethUsdPriceFeed;
        function setUp() public{
            deployer = new DeployDSC();
            (dsc,dsce,helperConfig) = deployer.run();
            (ethUsdPriceFeed,,weth,,) = helperConfig.activeNetworkConfig();
        }
        /*//////////////////////////////////////////////////////////////
                               PRICE_TEST
        //////////////////////////////////////////////////////////////*/
        function testGetUsdValue()public{
            //15e18*2000/ETH = 30000e18;
            uint256 ethAmount = 15e18;
            uint256 expectedUsd = 30_000e18;
            uint256 actualUsd = dsce.getUsdValue(weth,ethAmount);
            console.log("expectedUsd: ",expectedUsd );
            console.log("actualUsd: ",actualUsd );
            assertEq(expectedUsd,actualUsd);
        }

}