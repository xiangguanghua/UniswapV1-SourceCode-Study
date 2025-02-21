# 代码介绍

1、该代码用 solidity 实现 uniswap v1  
2、部署在本地 anvil 环境
3、制作了 html 代码使用 ether.js 与合约交互

# Uniswap v1 介绍

Uniswap v1 是一个以太坊链上智能合约系统，实现了基于 𝑥⋅𝑦=𝑘 的 AMM（自动做市）协议。每一个 Uniswap v1 交易对池子包含两种代币，在提供流动性的过程中保证两种代币余额的乘积无法减少。交易者为每次交易支付 0.3%的手续费给流动性 提供者。v1 的合约不可升级。  
![alt text](images/uniswapV1.png)
![alt text](images/front.png)
