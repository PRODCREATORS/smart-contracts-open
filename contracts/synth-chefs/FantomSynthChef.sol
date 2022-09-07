// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseSynthChef.sol";

interface ISpiritRouter {
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
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);
}

interface IGauge {
    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function balanceOf(address account) external view returns (uint256);
}

contract FantomSynthChef is BaseSynthChef {
    using SafeERC20 for IERC20;

    ISpiritRouter public router;

    Pool[] public poolsArray;

    struct Pool {
        IERC20 LPToken;
        IGauge gauge;
        IERC20 token0;
        IERC20 token1;
        bool stable;
    }

    constructor(
        ISpiritRouter _router,
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
        router = _router;
    }

    function _depositToFarm(uint256 _pid, uint256 _amount) internal override {
        Pool memory pool = poolsArray[_pid];
        if (pool.LPToken.allowance(address(this), address(pool.gauge)) < _amount) {
            pool.LPToken.safeIncreaseAllowance(
                address(pool.gauge),
                type(uint256).max
            );
        }
        pool.gauge.deposit(_amount);
    }

    function _withdrawFromFarm(uint256 _pid, uint256 _amount)
        internal
        override
    {
        Pool memory pool = poolsArray[_pid];
        pool.gauge.withdraw(_amount);
    }

    /**
     * @dev function that convert tokens in lp token
     */
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
        Pool memory pool = poolsArray[_pid];
        token0 = address(pool.token0);
        token1 = address(pool.token1);
        amount0 = _convertTokens(_tokenFrom, token0, _amount / 2);
        amount1 = _convertTokens(_tokenFrom, token1, _amount / 2);
    }

    /**
     * @dev function to add liquidity in current lp pool
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
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

        if (IERC20(token0).allowance(address(this), address(router)) == 0) {
            IERC20(token0).safeIncreaseAllowance(
                address(router),
                type(uint256).max
            );
        }

        if (IERC20(token1).allowance(address(this), address(router)) == 0) {
            IERC20(token1).safeIncreaseAllowance(
                address(router),
                type(uint256).max
            );
        }

        (, , amountLPs) = router.addLiquidity(
            token0,
            token1,
            pool.stable,
            amount0,
            amount1,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev function for collecting rewards
     */
    function _harvest(uint256 _pid) internal override {
        Pool memory pool = poolsArray[_pid];
        pool.gauge.getReward();
    }

    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        Pool memory pool = poolsArray[_pid];
        tokenAmounts = new TokenAmount[](2);

        if (pool.LPToken.allowance(address(this), address(router)) < _amount) {
            pool.LPToken.safeIncreaseAllowance(
                address(router),
                type(uint256).max
            );
        }

        (uint256 amount0, uint256 amount1) = router.removeLiquidity(
            address(pool.token0),
            address(pool.token1),
            pool.stable,
            _amount,
            1,
            1,
            address(this),
            block.timestamp
        );
        tokenAmounts[0] = TokenAmount({amount: amount0, token: address(pool.token0)});
        tokenAmounts[1] = TokenAmount({amount: amount1, token: address(pool.token1)});
    }

    function _getTokensInLP(uint256 _pid)
        internal
        view
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        Pool memory pool = poolsArray[_pid];
        tokenAmounts = new TokenAmount[](2);
        uint256 amountLP = pool.gauge.balanceOf(address(this));
        (uint256 amount0, uint256 amount1) = router.quoteRemoveLiquidity(
            address(pool.token0),
            address(pool.token1),
            pool.stable,
            amountLP
        );
        tokenAmounts[0] = TokenAmount({
            token: address(pool.token0),
            amount: amount0
        });
        tokenAmounts[1] = TokenAmount({
            token: address(pool.token1),
            amount: amount1
        });
    }

    function getLPAmountOnFarm(uint256 _pid)
        public
        view
        override
        returns (uint256 amount)
    {
        Pool memory pool = poolsArray[_pid];
        amount = pool.gauge.balanceOf(address(this));
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