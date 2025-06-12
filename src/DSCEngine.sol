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
/**
 * @title DSCEngine
 * @author okweb3
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stable coin with the properties
 * - Exogenous Collateralized
 * - Dollar pegged
 * - Algorithmically Stable
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 * Our DSC system should always be "overcollateralized". And no point, should the value of all collateral < the $ backed value of all the DSC.
 * 
 * @notice This contract is the core of the Decetralized Stablecoin system. It handles all the logic for minting and redeeming DSC,as well as despositing and withdrawing collateral 
 * @notice This contract is based on the MakerDAO DSS system
 */

pragma solidity ^0.8.18;

contract DSCEngine {
    /**
     * 1.Deposit collateral and mint the DSC token ： 
     *  -This is how users acquire the stablecoin , they deposit collateral grater than the value of the DSC minted
     * 2.Redeem their collateral for DSC:
     *  -User will need to be able to return DSC to the protocol in exchange for their underlying collateral.
     * 3.Burn DSC
     *  -if the value of a user's collateral quickly falls, users will need a way to qucikly rectify the collaterlization of their DSC
     * 4.The ability to liquidate an account
     *  -Because our protocol must always be over-collateralized(more collateral must be deposited then DSC is minted), if a user's collateral value falls bellow what's required to support their minted DSC they can be liquidated . 
     *  -liquidated allows other users to close an under-collateralized position
     * 5.view an account't healthFactor 
     *  - healthFactor will be defined as a certain ratio of collateralization a user has for the DSC they've minted. 
     *  - As the value of a user's collateral falls , as will their healthFactor,if no changes DSC held are made. 
     *  - if a user's healthFactor falls below a defined threshold, the user will be at risk of liqudation.
     */
    function depositCollateralAndMintDsc()external{}

    function depositCollateral() external{}

    function redeemCollateralForDes() external{}

    function redeemCollateral() external{}

    function mintDsc() external{}

    function burnDsc() external{}

    function liquidate() external{}

    function getHeathFactor() external view{}
}