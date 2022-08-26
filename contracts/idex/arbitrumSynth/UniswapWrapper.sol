// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../interfaces/IEntangleDEXWrapper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapWrapper is IEntangleDEXWrapper {
    ISwapRouter public router;
    IQuoterV2 public qouter;
    address public WETH;

    constructor(address _router, address _qouter) {
        router = ISwapRouter(_router);
        qouter = IQuoterV2(_qouter);
    }

    function convert(address from, address to, uint256 amount, uint24 _fee) external returns(uint256 receivedAmount) { 

        IERC20(from).transferFrom(msg.sender, address(this), amount);
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: from, 
                tokenOut: to, 
                fee: _fee, 
                recipient: msg.sender, 
                deadline: block.timestamp, 
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            receivedAmount = router.exactInputSingle(params);
    }

    function previewConvert(address from, address to, uint256 amount, uint24 _fee) external  returns(uint256 amountToReceive) {
        IQuoterV2.QuoteExactInputSingleParams  memory params =
            IQuoterV2.QuoteExactInputSingleParams ({
                tokenIn: from, 
                tokenOut: to, 
                fee: _fee, 
                amountIn: amount,
                sqrtPriceLimitX96: 0
        });
        (amountToReceive, , , ) = qouter.quoteExactInputSingle(params);
    }
}