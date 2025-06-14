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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
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


     /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed(address token);
    error DSCEngine__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping (address token  => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    //keep track of collateral deposited by each user. 
    mapping (address user => mapping(address token => uint256 amount))private s_collateralDeposited;
    //reflect the amount being minted in our function
    mapping (address user => uint amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION=1e10;
    uint256 private constant PRECISION = 1e18;
     /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDesposited(address indexed user, address indexed token, uint256 indexed amount);

     /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 amount) {
        if(amount <=0){
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)){
            revert DSCEngine__TokenNotAllowed(token); 
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    

    //Initialize this mapping in our contract's constructor 
    constructor(address[] memory tokenAddress,address[] memory priceFeedAddress,address dscAddress){
        if(tokenAddress.length != priceFeedAddress.length){
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for(uint256 i=0;i<tokenAddress.length;i++){
            s_priceFeeds[tokenAddress[i]=priceFeedAddress[i]];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }


    function depositCollateralAndMintDsc()external{}

   /**
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing  
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant{
        //add the deposited collateral to user's balance
        s_collateralDeposited[msg.sender][tokenCollateralAddress]+=amountCollateral;
        emit CollateralDesposited(msg.sender,tokenCollateralAddress,amountCollateral);
        bool success =  IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
        if (!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDes() external{}

    function redeemCollateral() external{}

    function mintDsc() external{}

    function burnDsc() external{}

    function liquidate() external{}

    function getHeathFactor() external view{}

    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant{
        s_DSCMinted[msg.sender] +=amountDscToMint;
    }

    /*//////////////////////////////////////////////////////////////
                      PRIVATEINTERNALVIEWFUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _revertIfHealthFactorIsBroken(address user)internal view{}

    function _healthFactor(address user) private view returns(uint256){
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
    }

    function _getAccountInformation(address user)private view returns(uint256 totalDscMinted, uint256 collateralValueInusd){
        totalDscMinted = s_DSCMinted[user];
        collateralValueInusd = getAccountCollateralValue(user);
    }
    function getAccountCollateralValue(address user) public  view returns(uint256 totalCollateralValueInUsd){
        for(uint256 i = 0; i<s_collateralTokens.length;i++){
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token,amount);
        }
        return totalCollateralValueInUsd;
    }
    function getUsdValue(address token, uint256 amount) public view returns(uint256){
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,)=priceFeed.latestRoundData();
        return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION;
    }
    
}