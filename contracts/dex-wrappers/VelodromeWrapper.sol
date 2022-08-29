// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../interfaces/IEntangleDEXWrapper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVelodromeRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    function factory() external view returns(address);
    function weth() external view returns(address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, route[] memory routes) external view returns (uint[] memory amounts);
}

interface IVelodromeFactory {
    function getPair(address tokenA, address token, bool stable) external view returns (address);
}

interface IPair {
    function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
}

contract VelodromeWrapper is IEntangleDEXWrapper {
    IVelodromeRouter public router;
    IVelodromeFactory public factory;
    address public WETH;

    constructor(IVelodromeRouter _router) {
        router = _router;
        factory = IVelodromeFactory(router.factory());
        WETH = router.weth();
    }

    function _getBetterPair(address _tokenFrom, address _tokenTo) internal view returns(address pair, bool stable) {
        address stableLpPair = factory.getPair(_tokenFrom, _tokenTo, true);
        address notStableLpPair = factory.getPair(_tokenFrom, _tokenTo, false);
        if (stableLpPair == address(0)) 
            return (notStableLpPair, false);
        if (notStableLpPair == address(0))
            return (stableLpPair, true);
        (uint256 amount0Stable , ,) = IPair(stableLpPair).getReserves();
        (uint256 amount0NotStable , ,) = IPair(notStableLpPair).getReserves();
        if (amount0Stable > amount0NotStable)
            return (stableLpPair, true);
        else
            return (notStableLpPair, false);
    }

    function _getSwapRoutes(address _tokenFrom, address _tokenTo)
        internal
        view
        returns (IVelodromeRouter.route[] memory routes)
    {
        (address pair, bool stable) = _getBetterPair(_tokenFrom, _tokenTo);
        if (pair != address(0)) {
            routes = new IVelodromeRouter.route[](1);
            routes[0] = IVelodromeRouter.route({from: _tokenFrom, to: _tokenTo, stable: stable});
        } else {
            routes = new IVelodromeRouter.route[](2);
            routes[0] = IVelodromeRouter.route({from: _tokenFrom, to: WETH, stable: false});
            routes[1] = IVelodromeRouter.route({from: WETH, to: _tokenTo, stable: false});
        }
    }

    function convert(address from, address to, uint256 amount) external returns(uint256 receivedAmount) {
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        if (IERC20(from).allowance(address(this), address(router)) < amount) {
            IERC20(from).approve(address(router), type(uint256).max);
        }
        uint256[] memory amounts = router.swapExactTokensForTokens(amount, 1, _getSwapRoutes(from, to), msg.sender, block.timestamp);
        receivedAmount = amounts[amounts.length - 1];
    }

    function previewConvert(address from, address to, uint256 amount) external view returns(uint256 amountToReceive) {
        uint256[] memory amounts = router.getAmountsOut(amount, _getSwapRoutes(from, to));
        amountToReceive = amounts[amounts.length - 1];
    }
}