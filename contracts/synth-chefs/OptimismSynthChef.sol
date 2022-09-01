// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BaseSynthChef.sol";

interface IGauge {
    function deposit(uint amount, uint tokenId) external;

    function getReward(address account, address[] memory tokens) external;

    function withdraw(uint amount) external;

    function balanceOf(address user) external view returns (uint);
}

interface IVelodromeRouter {
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
    )
        external
        returns (
            uint amountA,
            uint amountB,
            uint liquidity
        );

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
}

contract OptimismSynthChef is BaseSynthChef {
    IVelodromeRouter public velodromeRouter;
    Pool[] public poolsArray;

    struct Pool {
        IERC20 LPToken;
        IGauge gauge;
        IERC20 token0;
        IERC20 token1;
        bool stable;
    }

    constructor(
        IVelodromeRouter _velodromeRouter,
        address _DEXWrapper,
        address _stablecoin,
        address[] memory _rewardTokens
    ) BaseSynthChef(_DEXWrapper, _stablecoin, _rewardTokens) {
        velodromeRouter = _velodromeRouter;
    }

    function _depositToFarm(uint256 _pid, uint256 _amount) internal override {
        Pool memory pool = poolsArray[_pid];
        if (
            pool.LPToken.allowance(address(this), address(pool.gauge)) < _amount
        ) {
            pool.LPToken.approve(address(pool.gauge), type(uint256).max);
        }
        pool.gauge.deposit(_amount, 0);
    }

    function _withdrawFromFarm(uint256 _pid, uint256 _amount)
        internal
        override
    {
        Pool memory pool = poolsArray[_pid];
        pool.gauge.withdraw(_amount);
    }

    function _convertTokensToProvideLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    )
        internal
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        token0 = address(poolsArray[_pid].token0);
        token1 = address(poolsArray[_pid].token1);
        amount0 = _convertTokens(_tokenFrom, token0, _amount / 2);
        amount1 = _convertTokens(_tokenFrom, token1, _amount / 2);
    }

    function _addLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    ) internal override returns (uint256 amountLPs) {
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = _convertTokensToProvideLiquidity(_pid, _tokenFrom, _amount);
        Pool memory pool = poolsArray[_pid];

        if (
            IERC20(token0).allowance(address(this), address(velodromeRouter)) <
            amount0
        ) {
            IERC20(token0).approve(address(velodromeRouter), type(uint256).max);
        }

        if (
            IERC20(token1).allowance(address(this), address(velodromeRouter)) <
            amount1
        ) {
            IERC20(token1).approve(address(velodromeRouter), type(uint256).max);
        }

        (, , amountLPs) = velodromeRouter.addLiquidity(
            token0,
            token1,
            pool.stable,
            amount0,
            amount1,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _harvest(uint256 _pid) internal override {
        poolsArray[_pid].gauge.getReward(address(this), rewardTokens);
    }

    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        tokenAmounts = new TokenAmount[](2);
        Pool memory pool = poolsArray[_pid];
        address token0 = address(pool.token0);
        address token1 = address(pool.token1);

        if (
            pool.LPToken.allowance(address(this), address(velodromeRouter)) <
            _amount
        ) {
            pool.LPToken.approve(address(velodromeRouter), type(uint256).max);
        }
        uint256[2] memory t;
        t[0] = 0;
        t[1] = 0;
        (uint256 amount0, uint256 amount1) = velodromeRouter.removeLiquidity(
            token0,
            token1,
            pool.stable,
            _amount,
            0,
            0,
            address(this),
            block.timestamp
        );
        tokenAmounts[0] = TokenAmount({token: token0, amount: amount0});
        tokenAmounts[1] = TokenAmount({token: token1, amount: amount1});
    }

    function _getTokensInLP(uint256 _pid)
        internal
        view
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        tokenAmounts = new TokenAmount[](2);
        Pool memory pool = poolsArray[_pid];
        address token0 = address(pool.token0);
        address token1 = address(pool.token1);
        uint256 amountLP = pool.gauge.balanceOf(address(this));
        (uint256 amount0, uint256 amount1) = velodromeRouter
            .quoteRemoveLiquidity(
                address(token0),
                address(token1),
                pool.stable,
                amountLP
            );
        tokenAmounts[0] = TokenAmount({token: token0, amount: amount0});
        tokenAmounts[1] = TokenAmount({token: token1, amount: amount1});
    }

    function addPool(
        IERC20 LPToken,
        IGauge gauge,
        IERC20 token0,
        IERC20 token1,
        bool stable
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        poolsArray.push(Pool(LPToken, gauge, token0, token1, stable));
    }
}
