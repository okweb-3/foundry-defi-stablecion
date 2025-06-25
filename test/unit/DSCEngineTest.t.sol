// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {AttackDSCEngine} from "./AttackDSCEngine.sol";
import {FakeStableCoin} from "./FakeStableCoin.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig helperConfig;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_MINT = 5 ether;

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, , ) = helperConfig
            .activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }
    //编写合约的思路
    //1.理解业务逻辑：知道函数要干嘛，依赖哪些状态
    //2.分类测试：正常路径+异常路径+边界条件
    //3.状态验证：不仅要看函数有没有成功，还要看状态有没有更新
    //4.模拟依赖（mock）合约：可控外部行为（返回false、模拟失败）
    //5.使用工具:如vm.expecRevert()测试回退

    ////////////////////////////////////
    ///        MintDsc  Test       /////
    ////////////////////////////////////
    /*
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
    if (!minted) {
        revert DSCEngine__MintFailed();
        }
    }
    1.功能总结
     - moreThanZero: 检查amountDscToMint是否大于0
     - nonReentrant: 防止重入攻击
     - 更新用户的铸币记录
     - 检查健康因子
     - 调用i_dsc.mint铸造代币
     - mint失败回退 
    2.分类测试
    - 用amountDscToMint=0测试 预期结果
    - 连续调用mint 测试noReetrant
    - 健康因子不达标 revert触发_ DSCEngine__BreaksHealthFactor()
    - mint 失败 i_dsc.mint(msg.sender, amountDscToMint) 返回fasle 触发 DSCEngine__MintFailed()
    - mint 成功（健康因子良好）	正常铸造，余额变化，映射更新
     */
    function testMintDscmoreThanZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.mintDsc(0);
        vm.stopPrank();
    }
    //virtual方式测试重入
    // function testMintDscRevertNoReentrant() public depositedCollateral {
    //     //构造部署Reentrant模拟合约
    //     address[] memory tokens = new address[](1);

    //     tokens[0] = weth;
    //     address[] memory priceFeeds = new address[](1);
    //     priceFeeds[0] = ethUsdPriceFeed;

    //     //部署模拟攻击版本的dscengine
    //     ReentrantDSCEngine reentrantEngine = new ReentrantDSCEngine(
    //         tokens,
    //         priceFeeds,
    //         address(dsc)
    //     );
    //     //给USER铸造并授权抵押品
    //     ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    //     vm.startPrank(USER);
    //     ERC20Mock(weth).approve(
    //         address(reentrantEngine),
    //         STARTING_ERC20_BALANCE
    //     );

    //     reentrantEngine.depositCollateral(weth, AMOUNT_COLLATERAL);

    //     vm.expectRevert();
    //     reentrantEngine.mintDsc(1 ether);
    //     vm.stopPrank();
    // }
    //不改主函数
    function test_RevertsOnReentrancy_WithoutOverride() public {
        // 1. 部署攻击者和假 DSC 合约
        AttackDSCEngine attacker;
        FakeStableCoin fakeDsc;

        address[] memory tokens = new address[](1);
        tokens[0] = weth;

        address[] memory priceFeeds = new address[](1);
        priceFeeds[0] = ethUsdPriceFeed;

        // 2. 部署攻击者合约（先部署空）
        attacker = new AttackDSCEngine(address(0));

        // 3. 部署假 DSC 合约，传入攻击者地址
        fakeDsc = new FakeStableCoin(address(attacker));

        // 4. 部署新的 DSCEngine，使用假 DSC 地址
        DSCEngine newEngine = new DSCEngine(
            tokens,
            priceFeeds,
            address(fakeDsc)
        );

        // 5. 更新攻击者合约中 DSCEngine 地址
        attacker = new AttackDSCEngine(address(newEngine));

        // 6. 准备攻击：给攻击者一些 WETH
        address attackerAddr = address(attacker);
        ERC20Mock(weth).mint(attackerAddr, 10 ether);
        vm.prank(attackerAddr);
        ERC20Mock(weth).approve(address(newEngine), 10 ether);

        // 7. 存入抵押品
        vm.prank(attackerAddr);
        newEngine.depositCollateral(weth, 10 ether);

        // 8. 触发攻击，预期重入时回退
        vm.expectRevert("Reentrancy attack failed");
        vm.prank(attackerAddr);
        attacker.startAttack();
    }

    ////////////////////////////////////
    /// depositCollateralAndMintDsc/////
    ////////////////////////////////////
    function testDespositeCollateralAndMintDsc_Success()
        public
        depositedCollateral
    {}
    ////////////////////////////
    /// More Than Zero Test/////
    ////////////////////////////
    function testDespositeCollateralRevertIfAmountZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }
    function testDespositeCollateralSuccessIfMoreThanZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    ////////////////////////////
    /// Constructor Test   /////
    ////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddress;
    function testRevertIfTokenLengthDoesntMatchPrriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddress.push(ethUsdPriceFeed);
        priceFeedAddress.push(btcUsdPriceFeed);
        vm.expectRevert(
            DSCEngine
                .DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength
                .selector
        );
        new DSCEngine(tokenAddresses, priceFeedAddress, address(dsc));
    }

    ////////////////////////////
    ////// Price  Test  ///////
    ////////////////////////////

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    /*//////////////////////////////////////////////////////////////
                               PRICE_TEST
        //////////////////////////////////////////////////////////////*/
    function testGetUsdValue() public view {
        //15e18*2000/ETH = 30000e18;
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        console.log("expectedUsd: ", expectedUsd);
        console.log("actualUsd: ", actualUsd);
        assertEq(expectedUsd, actualUsd);
    }
    /*//////////////////////////////////////////////////////////////
                        DEPOSITCOLLATERAL_TESTS
        //////////////////////////////////////////////////////////////*/
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositeCollateralAndGetAccountInfo()
        public
        depositedCollateral
    {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce
            .getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDespositAmount = dsce.getTokenAmountFromUsd(
            weth,
            collateralValueInUsd
        );
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDespositAmount);
    }
}
// contract ReentrantDSCEngine is DSCEngine {
//     bool public alreadyCalled = false;
//     constructor(
//         address[] memory tokenAddresses,
//         address[] memory priceFeedAddresses,
//         address dscAddress
//     ) DSCEngine(tokenAddresses, priceFeedAddresses, dscAddress) {}
//     function mintDsc(uint amount) public override nonReentrant {
//         if (!alreadyCalled) {
//             alreadyCalled = true;

//             //第一次调用正常
//             super.mintDsc(amount);
//             //第二次调用重入调用 触发回退
//             super.mintDsc(amount);
//         }
//     }
// }
