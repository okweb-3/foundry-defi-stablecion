// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions


pragma solidity ^0.8.18;
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title Decentralized StableCoin
 * @author okweb3
 * Collateral:Exogenous (ETH&BTC)
 * Minting: Algorithmic
 * Relative Stability :pegged to USD
 * 
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stablecoin system.
 */

 contract DecentralizedStableCoin is ERC20Burnable,Ownable{
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();
    
    //satisfy the standard ERC20 constructor parameters within our contracts constructor
    //set the name and symbol
    // constructor ()ERC20 ("DecentralizedStableCoin","DSC"){}
   constructor() ERC20("DecentralizedStableCoin", "DSC")Ownable(address(msg.sender)) {}
   //Our burn function
   //The amount burnt must not be less than zero
   //The amount burnt must not be more than user's balance
   function burn (uint256 _amount) public override  onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(_amount<=0){
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if(_amount >balance){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
   } 
    function mint(address _to, uint256 _amount)external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DecentralizedStableCoin__NotZeroAddress();
        }
         if(_amount <=0){
        revert DecentralizedStableCoin__MustBeMoreThanZero();
    }
    _mint(_to, _amount);
    return true;
    }  
    
}