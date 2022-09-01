// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
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
    address public router;
    address public factory;
    address public convex;
    Pool[] public poolsArray;

    struct Pool {
        address lp;
        uint256 convexID;
        address token0;
        address token1;
        address curvePool;
        address convexreward;
        address wtoken0;
        address wtoken1;
    }

    constructor(
        address _router,
        address _factory,
        address _convex,
        address _DEXWrapper,
        address _stablecoin,
        address[] memory _rewardTokens
    ) BaseSynthChef(_DEXWrapper, _stablecoin, _rewardTokens) {
        convex = _convex;
        router = _router;
        factory = _factory;
    }

    receive() external payable {}

    function setFactory(address _factory)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        factory = _factory;
    }

    function setRouter(address _router)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        router = _router;
    }

    function _depositToFarm(uint256 _pid, uint256 _amount) internal override {
        if (IERC20(poolsArray[_pid].lp).allowance(address(this), convex) == 0) {
            IERC20(poolsArray[_pid].lp).approve(convex, type(uint256).max);
        }
        Convex(convex).deposit(poolsArray[_pid].convexID, _amount, true);
    }

    function _withdrawFromFarm(uint256 _pid, uint256 _amount)
        internal
        override
    {
        ConvexReward(poolsArray[_pid].convexreward).withdrawAndUnwrap(
            _amount,
            false
        );
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

        if (
            IERC20(token0).allowance(
                address(this),
                poolsArray[_pid].curvePool
            ) == 0
        ) {
            IERC20(token0).approve(
                poolsArray[_pid].curvePool,
                type(uint256).max
            );
        }

        if (
            IERC20(token1).allowance(
                address(this),
                poolsArray[_pid].curvePool
            ) == 0
        ) {
            IERC20(token1).approve(
                poolsArray[_pid].curvePool,
                type(uint256).max
            );
        }

        amountLPs = Curve(poolsArray[_pid].curvePool).add_liquidity(
            [amount0, amount1],
            0,
            true
        );
    }

    function _harvest(uint256 _pid) internal override {
        ConvexReward(poolsArray[_pid].convexreward).getReward();
    }

    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        tokenAmounts = new TokenAmount[](2);
        address token0 = poolsArray[_pid].token0;
        address token1 = poolsArray[_pid].token1;

        uint256[2] memory amounts = Curve(poolsArray[_pid].curvePool)
            .remove_liquidity(_amount, [uint256(0), uint256(0)], true);

        tokenAmounts[0] = TokenAmount({token: token0, amount: amounts[0]});
        tokenAmounts[1] = TokenAmount({token: token1, amount: amounts[1]});
    }

    function _getTokensInLP(uint256 _pid)
        internal
        view
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        tokenAmounts = new TokenAmount[](2);
        address token0 = poolsArray[_pid].token0;
        address token1 = poolsArray[_pid].token1;
        uint256 amountLP = ConvexReward(poolsArray[_pid].convexreward)
            .balanceOf(address(this));
        uint256 amount0 = Curve(poolsArray[_pid].curvePool)
            .calc_withdraw_one_coin(amountLP, int128(0));
        uint256 amount1 = Curve(poolsArray[_pid].curvePool)
            .calc_withdraw_one_coin(amountLP, int128(1));
        tokenAmounts[0] = TokenAmount({token: token0, amount: amount0});
        tokenAmounts[1] = TokenAmount({token: token1, amount: amount1});
    }

    function addPool(
        address _pool,
        uint256 _convexID,
        address _token0,
        address _token1,
        address _curvePool,
        address _convexreward,
        address _wtoken0,
        address _wtoken1
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        poolsArray.push(
            Pool(
                _pool,
                _convexID,
                _token0,
                _token1,
                _curvePool,
                _convexreward,
                _wtoken0,
                _wtoken1
            )
        );
    }
}
