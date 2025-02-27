//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

import {Token} from "../src/util/Token.sol";
import {UniswapV1Factory} from "../src/UniswapV1Factory.sol";
import {UniswapV1Exchange} from "../src/UniswapV1Exchange.sol";

contract UniswapV1Deploy is Script {
    Token xghToken;
    UniswapV1Factory factory;
    address exchange;

    function run() external returns (Token, UniswapV1Factory, address) {
        vm.startBroadcast();
        xghToken = new Token();
        factory = new UniswapV1Factory();
        exchange = factory.createExchange(address(xghToken));
        vm.stopBroadcast();
        return (xghToken, factory, exchange); // 返回交易对exchange;
    }
}
