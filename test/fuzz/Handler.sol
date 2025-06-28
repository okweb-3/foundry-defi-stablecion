// SPDX-License-Identifier: SEE LICENSE IN LICENSE
//Handler is going to narrow down the way we call function
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE=type(uint96).max; 
    uint256 public timesMintIsCalled;
    address[] usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine,DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }
    //redeem collateral <-

    function depositCollateral( uint256  collateralSeed, uint256 amountCollateral)public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral,1,MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender,amountCollateral);
        collateral.approve(address(dsce),amountCollateral);
        dsce.depositCollateral(address(collateral),amountCollateral);
        vm.stopPrank();
        // dsce.depositCollateral(collateral, amountCollateral);
        usersWithCollateralDeposited.push(msg.sender);
        
    }
    //Helper Functions
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if(collateralSeed%2==0){
            return weth;
        }
        return wbtc;
    }
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral)public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem =  dsce.getCollateralBalanceOfUser(address(collateral),msg.sender);
        amountCollateral = bound(amountCollateral,0,maxCollateralToRedeem);
        if(amountCollateral == 0){
            return;
        }
        dsce.redeemCollateral(address(collateral),amountCollateral);
    }

    function mintDsc(uint256 amount,uint256 addressSeed) public{
        if(usersWithCollateralDeposited.length ==0){
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);

        uint256 maxDscToMint = (collateralValueInUsd/2)-totalDscMinted;
        if(maxDscToMint < 0){
            return;
        }
        amount = bound(amount,0,maxDscToMint);
        if(amount <=0){
            return;
        }

        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        timesMintIsCalled++;
    }
}