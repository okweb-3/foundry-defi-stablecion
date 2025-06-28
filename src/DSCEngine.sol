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
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    //keep track of collateral deposited by each user.
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited;
    //reflect the amount being minted in our function
    mapping(address user => uint amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATTION_THRESHOLD = 50;
    uint256 private constant LIQUIDATTION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BOUNS = 10;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDesposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed redeemCollateral,
        address indexed redeemedTo,
        address indexed token,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //Initialize this mapping in our contract's constructor
    constructor(
        address[] memory tokenAddress,
        address[] memory priceFeedAddress,
        address dscAddress
    ) {
        if (tokenAddress.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            s_priceFeeds[tokenAddress[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddress[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /**
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        //add the deposited collateral to user's balance
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDesposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                      Private & Internal View Functions 
    //////////////////////////////////////////////////////////////*/
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);

        uint256 collateralAdjustedForThreForThreshold = (collateralValueInUsd *
            LIQUIDATTION_THRESHOLD) / LIQUIDATTION_PRECISION;

        return
            (collateralAdjustedForThreForThreshold * PRECISION) /
            totalDscMinted;
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInusd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInusd = getAccountCollateralValue(user);
    }

    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;

        emit CollateralRedeemed(
            from,
            to,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transfer(
            to,
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }
    function getUsdValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) public {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }
    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) public moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(
            tokenCollateralAddress,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] -= amountCollateral;
        bool success = IERC20(tokenCollateralAddress).transfer(
            msg.sender,
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    function _burnDsc(
        uint256 amountDscToBurn,
        address OnBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinted[OnBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }
    function redeemCollateralForDes(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external {
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    // @param collateral : The ERC20 token address of the collateral you're using to make the protocol solvent again
    // This is collateral that you're going to take from the user who is insolvent
    // In return, you hafe to burn your DSC to pay off their debt ,but you don't pay off your own
    // @param user: The user who is insolvent, They have to  have a _healthFactor  below MIN_HEALTH_FACTOR
    // @param debtToCover: The amount of DSC you want to burn to cover the user's debt
    // @notice: You can partially liquidate a user.
    // @notice: You will get a 10% LIQUIDATION_BOUNS for taking the users funds
    // @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work
    // @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
    // For example, if the price of the collateral plummeted before anyone could be liquidated.

    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor > MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }

        uint256 tokenAmountFromDebtCoverd = getTokenAmountFromUsd(
            collateral,
            debtToCover
        );
        uint256 bounsCollateral = (tokenAmountFromDebtCoverd *
            LIQUIDATION_BOUNS) / LIQUIDATTION_PRECISION;
        uint256 totalCollateralRedeemed = tokenAmountFromDebtCoverd +
            bounsCollateral;
        _redeemCollateral(
            collateral,
            totalCollateralRedeemed,
            user,
            msg.sender
        );
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHeathFactor() external view {}

    //////////////////////////////////////////
    //   Public & External View Functions   //
    //////////////////////////////////////////

    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInwei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            (usdAmountInwei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 CollateralValueInUsd)
    {
        (totalDscMinted, CollateralValueInUsd) = _getAccountInformation(user);
    }

    function getCollateralTokens()external view returns(address[] memory){
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns(uint256){
        return s_collateralDeposited[user][token];
    }
    function getCollateralTokenPriceFeed(address token) external view returns(address){
        return s_priceFeeds[token];
    }

}
