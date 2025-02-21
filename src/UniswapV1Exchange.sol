//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {UniswapV1Factory} from "./UniswapV1Factory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * 交易对
 * @title  交易对
 * @notice 创建交易对
 */
contract UniswapV1Exchange is ReentrancyGuard {
    //----------------------代币变量-----------------------------
    address public immutable token; // 关联的 ERC20 代币地址
    uint256 public ethReserve; // ETH 储备量
    uint256 public tokenReserve; // ERC20 代币储备量

    // -------------------- ERC20 流动性代币逻辑 --------------------
    string public name = "Uniswap V1 Liquidity Provider";
    string public symbol = "ULP";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event RemoveLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event EthToTokenSwap(address indexed buyer, uint256 ethIn, uint256 tokenOut);
    event TokenToEthSwap(address indexed buyer, uint256 tokenIn, uint256 ethOut);

    // 初始化交易对
    constructor(address _token) {
        require(_token != address(0), "invalid token address");
        /**
         * 由于每个Exchange合约只允许使用一种代币进行交换，
         * 因此需要将代币合约地址和Exchange合约地址绑定。
         */
        token = _token;
    }

    /**
     * 足够充分的流动性才能使交易成为可能
     * 添加流动性（需同时存入 ETH 和 ERC20 代币）
     * msg.value是携带的Ether数量，maxToken是ERC20 Token数量
     * @param minLiquidity 最小流动性
     * @param maxTokens 最大流动性
     * @param deadline 时间
     */
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline)
        external
        payable
        /**
         * 将发送调用者携带的Ether添加到合约中
         */
        nonReentrant
        returns (uint256 liquidity)
    {
        require(block.timestamp <= deadline, "Expired");
        require(msg.value > 0, "ETH required");

        uint256 tokenAmount; // ERC20 代币数量
        if (totalSupply == 0) {
            //首次添加流动性，供应量为0
            tokenAmount = maxTokens; // tokenAmout 为传入的数量
            // 将调用者的代币转移给合约
            bool success = IERC20(token).transferFrom(msg.sender, address(this), tokenAmount); //执行转账
            require(success, "Transfer failed");
            // 流动性等于传入的ETH的数量
            liquidity = msg.value;
        } else {
            tokenAmount = (msg.value * tokenReserve) / ethReserve;
            require(tokenAmount <= maxTokens, "Exceeds max tokens");
            require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount), "Transfer failed");
            liquidity = (msg.value * totalSupply) / ethReserve;
        }

        require(liquidity >= minLiquidity, "Insufficient liquidity");
        // 将流动性给token，并且增加totalSupply
        _mint(msg.sender, liquidity);
        ethReserve += msg.value; // ether储备
        tokenReserve += tokenAmount; // token储备

        emit AddLiquidity(msg.sender, msg.value, tokenAmount);
    }

    // 移除流动性（销毁流动性代币，取回 ETH 和 ERC20）
    function removeLiquidity(uint256 liquidity, uint256 minEth, uint256 minTokens, uint256 deadline)
        external
        nonReentrant
        returns (uint256 ethAmount, uint256 tokenAmount)
    {
        require(block.timestamp <= deadline, "Expired");
        require(liquidity > 0, "Liquidity required");

        ethAmount = (liquidity * ethReserve) / totalSupply;
        tokenAmount = (liquidity * tokenReserve) / totalSupply;
        require(ethAmount >= minEth && tokenAmount >= minTokens, "Slippage");

        _burn(msg.sender, liquidity);
        ethReserve -= ethAmount;
        tokenReserve -= tokenAmount;

        payable(msg.sender).transfer(ethAmount);
        require(IERC20(token).transfer(msg.sender, tokenAmount), "Transfer failed");

        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    }

    // ETH 兑换 ERC20 代币
    function ethToTokenSwap(uint256 minTokens, uint256 deadline)
        external
        payable
        nonReentrant
        returns (uint256 tokenAmount)
    {
        require(block.timestamp <= deadline, "Expired");
        uint256 ethIn = msg.value;
        uint256 ethInWithFee = ethIn * 997 / 1000;
        tokenAmount = (ethInWithFee * tokenReserve) / (ethReserve + ethInWithFee);

        require(tokenAmount >= minTokens, "Slippage");
        ethReserve += ethIn;
        tokenReserve -= tokenAmount;

        require(IERC20(token).transfer(msg.sender, tokenAmount), "Transfer failed");
        emit EthToTokenSwap(msg.sender, ethIn, tokenAmount);
    }

    // ERC20 代币兑换 ETH
    function tokenToEthSwap(uint256 tokenIn, uint256 minEth, uint256 deadline)
        external
        nonReentrant
        returns (uint256 ethOut)
    {
        require(block.timestamp <= deadline, "Expired");
        uint256 tokenInWithFee = tokenIn * 997 / 1000;
        ethOut = (tokenInWithFee * ethReserve) / (tokenReserve + tokenInWithFee);

        require(ethOut >= minEth, "Slippage");
        require(IERC20(token).transferFrom(msg.sender, address(this), tokenIn), "Transfer failed");

        ethReserve -= ethOut;
        tokenReserve += tokenIn;

        payable(msg.sender).transfer(ethOut);
        emit TokenToEthSwap(msg.sender, tokenIn, ethOut);
    }

    // 计算 ETH 兑换代币的数量（输入固定 ETH）
    function getEthToTokenInputPrice(uint256 ethSold) public view returns (uint256) {
        uint256 inputAmount = ethSold * 997 / 1000; // 0.3% 手续费
        return (inputAmount * tokenReserve) / (ethReserve + inputAmount);
    }

    // 计算代币兑换 ETH 的数量（输入固定代币）
    function getTokenToEthInputPrice(uint256 tokensSold) public view returns (uint256) {
        uint256 inputAmount = tokensSold * 997 / 1000; // 0.3% 手续费
        return (inputAmount * ethReserve) / (tokenReserve + inputAmount);
    }

    // 内部ERC20逻辑
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
    }

    //返回Exchange合约代币余额
    function getReserve() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
