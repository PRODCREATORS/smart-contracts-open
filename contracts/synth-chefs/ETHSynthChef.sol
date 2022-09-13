// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./BaseSynthChef.sol";

interface Curve {
    function calc_token_amount(uint256[2] memory, bool is_deposit)
        external
        view
        returns (uint256);

    function add_liquidity(
        uint256[2] memory,
        uint256 _min_mint_amount,
        bool is_deposit
    ) external returns (uint256);

    function remove_liquidity(
        uint256 amount,
        uint256[2] memory _min_amounts,
        bool _use_underlying
    ) external returns (uint256[2] memory);

    function calc_withdraw_one_coin(uint256 _token_amount, int128 i)
        external
        view
        returns (uint256);
}

interface Convex {
    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _stake
    ) external returns (bool);

    function withdrawAll(uint256 _pid) external returns (bool);
}

interface ConvexReward {
    function withdrawAndUnwrap(uint256 amount, bool claim)
        external
        returns (bool);

    function getReward() external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract ETHSynthChef is BaseSynthChef {
    using SafeERC20 for IERC20;

    Convex public convex;
    Pool[] public poolsArray;

    struct Pool {
        address lp;
        uint256 convexID;
        address token0;
        address token1;
        Curve curvePool;
        ConvexReward convexreward;
    }

    constructor(
        Convex _convex,
        address _DEXWrapper,
        address _stablecoin,
        address[] memory _rewardTokens,
        uint256 _fee,
        address _feeCollector
    )
        BaseSynthChef(
            _DEXWrapper,
            _stablecoin,
            _rewardTokens,
            _fee,
            _feeCollector
        )
    {
        convex = _convex;
    }

    function _depositToFarm(uint256 _pid, uint256 _amount) internal override {
        Pool memory pool = poolsArray[_pid];
        if (IERC20(pool.lp).allowance(address(this), address(convex)) < _amount) {
            IERC20(pool.lp).safeIncreaseAllowance(
                address(convex),
                type(uint256).max
            );
        }
        convex.deposit(pool.convexID, _amount, true);
    }

    function _withdrawFromFarm(uint256 _pid, uint256 _amount)
        internal
        override
    {
        Pool memory pool = poolsArray[_pid];
        pool.convexreward.withdrawAndUnwrap(_amount, false);
    }

    function _convertTokensToProvideLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    )
        internal
        whenNotPaused
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        Pool memory pool = poolsArray[_pid];
        token0 = address(pool.token0);
        token1 = address(pool.token1);
        amount0 = _convertTokens(_tokenFrom, token0, _amount / 2);
        amount1 = _convertTokens(_tokenFrom, token1, _amount / 2);
    }

    function _addLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    ) internal override returns (uint256 amountLPs) {
        Pool memory pool = poolsArray[_pid];
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = _convertTokensToProvideLiquidity(_pid, _tokenFrom, _amount);

        if (
            IERC20(token0).allowance(
                address(this),
                address(pool.curvePool)
            ) == 0
        ) {
            IERC20(token0).safeIncreaseAllowance(
                address(pool.curvePool),
                type(uint256).max
            );
        }

        if (
            IERC20(token1).allowance(
                address(this),
                address(pool.curvePool)
            ) == 0
        ) {
            IERC20(token1).safeIncreaseAllowance(
                address(pool.curvePool),
                type(uint256).max
            );
        }

        amountLPs = pool.curvePool.add_liquidity(
            [amount0, amount1],
            0,
            true
        );
    }

    function _harvest(uint256 _pid) internal override {
        Pool memory pool = poolsArray[_pid];
        pool.convexreward.getReward();
    }

    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        Pool memory pool = poolsArray[_pid];
        tokenAmounts = new TokenAmount[](2);

        uint256[2] memory amounts = pool.curvePool.remove_liquidity(
            _amount,
            [uint256(0), uint256(0)],
            true
        );

        tokenAmounts[0] = TokenAmount({token: pool.token0, amount: amounts[0]});
        tokenAmounts[1] = TokenAmount({token: pool.token1, amount: amounts[1]});
    }

    function _getTokensInLP(uint256 _pid)
        internal
        view
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        Pool memory pool = poolsArray[_pid];
        tokenAmounts = new TokenAmount[](2);
        uint256 amountLP = getLPAmountOnFarm(_pid);
        uint256 amount0 = pool.curvePool.calc_withdraw_one_coin(
            amountLP,
            int128(0)
        );
        uint256 amount1 = pool.curvePool.calc_withdraw_one_coin(
            amountLP,
            int128(1)
        );
        tokenAmounts[0] = TokenAmount({token: pool.token0, amount: amount0});
        tokenAmounts[1] = TokenAmount({token: pool.token1, amount: amount1});
    }

    function getLPAmountOnFarm(uint256 _pid)
        public
        view
        override
        returns (uint256 amount)
    {
        Pool memory pool = poolsArray[_pid];
        amount = pool.convexreward.balanceOf(address(this));
    }

    function addPool(
        address _lp,
        uint256 _convexID,
        address _token0,
        address _token1,
        Curve _curvePool,
        ConvexReward _convexreward
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        poolsArray.push(
            Pool(_lp, _convexID, _token0, _token1, _curvePool, _convexreward)
        );
    }
}
