// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UniswapV1Factory} from "../src/UniswapV1Factory.sol";
import {UniswapV1Exchange} from "../src/UniswapV1Exchange.sol";
import {UniswapV1Deploy} from "../script/UniswapV1.s.sol";
import {Token} from "../src/util/Token.sol";

contract UniswapV1Test is Test {
    UniswapV1Factory factory;
    Token xghToken;
    UniswapV1Deploy deploy;
    address exchange;

    uint256 public constant XGH_AMOUNT = 1000e18;
    uint256 public constant XGH_EXCHANGE_AMOUNT = 100e18;
    uint256 public constant ETH_AMOUNT = 10e18;
    uint256 public constant ETH_EXCHANGE_AMOUNT = 10e18;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        deploy = new UniswapV1Deploy();
        (xghToken, factory, exchange) = deploy.run();
    }

    // 测试创建交易对
    function testCreateExchange() public view {
        assertEq(factory.getExchange(address(xghToken)), exchange);
        assertEq(factory.allExchanges(0), exchange);
    }

    modifier initAmmount() {
        xghToken.mint(alice, XGH_AMOUNT * 2); // 铸造1000ETH并分配给alice
        vm.deal(alice, ETH_AMOUNT * 2); // 给alice发送10ETH
        _;
    }

    // 测试添加流动性
    function testAddLiquidity() public initAmmount {
        /**
         * 首次添加流动性
         */
        vm.startPrank(alice);
        xghToken.approve(exchange, XGH_AMOUNT); //alice 授权exchange交易对 1000ETH
        // 首次添加流动性
        uint256 lp_token_f = UniswapV1Exchange(exchange).addLiquidity{value: ETH_AMOUNT}(XGH_AMOUNT);
        vm.stopPrank();
        assertEq(lp_token_f, ETH_AMOUNT);
        assertEq(UniswapV1Exchange(exchange).balanceOf(alice), ETH_AMOUNT);
        assertEq(UniswapV1Exchange(exchange).getEthReserve(), ETH_AMOUNT);
        assertEq(UniswapV1Exchange(exchange).getTokenReserve(), XGH_AMOUNT);

        vm.startPrank(alice);
        xghToken.approve(exchange, XGH_AMOUNT); //alice 授权exchange交易对 1000ETH
        // 再次添加流动性
        uint256 lp_token_s = UniswapV1Exchange(exchange).addLiquidity{value: ETH_AMOUNT}(XGH_AMOUNT);
        vm.stopPrank();
        uint256 totalSupply = UniswapV1Exchange(exchange).totalSupply();
        assertEq(lp_token_s + lp_token_f, totalSupply);
    }
}
