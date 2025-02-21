// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Factory} from "../src/UniswapV1Factory.sol";
import {UniswapV1Exchange} from "../src/UniswapV1Exchange.sol";
import {XGHToken} from "./ERC20Token.sol";
import {XXXToken} from "./ERC20Token.sol";

contract UniswapV1Test is Test {
    UniswapV1Factory factory;
    XGHToken xghToken;
    address exchange;

    uint256 public constant XGH_AMOUNT = 1000e18;
    uint256 public constant XGH_EXCHANGE_AMOUNT = 100e18;
    uint256 public constant ETH_AMOUNT = 10e18;
    uint256 public constant ETH_EXCHANGE_AMOUNT = 10e18;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        factory = new UniswapV1Factory(); // 创建一个工厂
        xghToken = new XGHToken(); // 创建一个erc 20的代币
        exchange = factory.createExchange(address(xghToken));
    }

    // 测试创建交易对
    function testCreateExchange() public view {
        assertEq(factory.getExchange(address(xghToken)), exchange);
        assertEq(factory.allExchanges(0), exchange);
    }

    modifier initAmmount() {
        xghToken.mint(alice, XGH_AMOUNT); // 铸造1000ETH并分配给alice
        vm.deal(alice, ETH_AMOUNT); // 给alice发送10ETH
        _;
    }

    // 测试添加流动性
    function testAddLiquidity() public initAmmount {
        vm.startPrank(alice);
        xghToken.approve(exchange, XGH_AMOUNT); //alice 授权exchange交易对 1000ETH
        // 添加流动性
        UniswapV1Exchange(exchange).addLiquidity{value: ETH_AMOUNT}(0, XGH_AMOUNT, block.timestamp + 1000);
        vm.stopPrank();

        assertEq(UniswapV1Exchange(exchange).balanceOf(alice), ETH_AMOUNT);
        assertEq(UniswapV1Exchange(exchange).ethReserve(), ETH_AMOUNT);
        assertEq(UniswapV1Exchange(exchange).tokenReserve(), XGH_AMOUNT);
    }

    // 测试ETH兑换代币
    function testEthToTokenSwap() public initAmmount {
        vm.startPrank(alice);
        xghToken.approve(exchange, XGH_AMOUNT);

        UniswapV1Exchange(exchange).addLiquidity{value: ETH_AMOUNT}(0, XGH_AMOUNT, block.timestamp + 1000);
        vm.stopPrank();

        vm.deal(bob, ETH_EXCHANGE_AMOUNT);
        vm.startPrank(bob);
        uint256 tokensOut =
            UniswapV1Exchange(exchange).ethToTokenSwap{value: ETH_EXCHANGE_AMOUNT}(0, block.timestamp + 1000);
        vm.stopPrank();

        assertGt(tokensOut, 0);
        assertEq(xghToken.balanceOf(bob), tokensOut);
    }

    // 测试代币兑换ETH
    function testTokenToEthSwap() public initAmmount {
        vm.startPrank(alice);
        xghToken.approve(exchange, XGH_AMOUNT);
        UniswapV1Exchange(exchange).addLiquidity{value: 10e18}(0, XGH_AMOUNT, block.timestamp + 1000);
        vm.stopPrank();

        xghToken.mint(bob, XGH_EXCHANGE_AMOUNT);
        vm.startPrank(bob);
        xghToken.approve(exchange, XGH_EXCHANGE_AMOUNT);
        uint256 ethOut = UniswapV1Exchange(exchange).tokenToEthSwap(XGH_EXCHANGE_AMOUNT, 0, block.timestamp + 1000);
        vm.stopPrank();

        assertGt(ethOut, 0);
        assertEq(bob.balance, ethOut);
    }
}
