// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./BaseSynthChef.sol";


interface CErc20 {

    function mint(uint256 mintAmount) external returns(uint256);

    function redeem(uint256 redeemAmount) external returns(uint256);

    function exchangeRateStored() external view returns(uint256);

    function balanceOf(address account) external view returns(uint256);
}

interface CurveCompoundPool {
  function add_liquidity ( uint256[2] memory amounts, uint256 min_mint_amount ) external;
  function remove_liquidity ( uint256 _amount, uint256[2] memory min_amounts ) external;

  function coins ( int128 arg0 ) external view returns ( address out );
  function underlying_coins ( int128 arg0 ) external view returns ( address out );
  function balances ( int128 arg0 ) external view returns ( uint256 out );
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

contract ExpMath {

    uint256 constant expScale = 1e18;

    struct Exp {
        uint256 mantissa;
    }

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp memory exp) pure internal returns (uint256) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return exp.mantissa / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, returning a new Exp.
     */
    function mulScalar(Exp memory a, uint256 scalar) pure internal returns (Exp memory) {
        uint256 scaledMantissa = a.mantissa * scalar;

        return Exp({mantissa: scaledMantissa});
    }
    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mulScalarTruncate(Exp memory a, uint256 scalar) pure internal returns (uint256) {
        Exp memory product = mulScalar(a, scalar);

        return truncate(product);
    }
}

// this contract not for mainnet deploying
// realy needs to be optimized
contract ETHSynthChef is BaseSynthChef, ExpMath {
    using SafeERC20 for IERC20;

    Convex public convex;
    Pool[] public poolsArray;

    struct Pool {
        address lp;
        uint256 convexID;
        address underlyingToken0;
        address underlyingToken1;
        CurveCompoundPool curvePool;
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
        // convert stable to underlying tokens
        uint256 underlyingAmount0 = _convertTokens(_tokenFrom, pool.underlyingToken0, _amount / 2);
        uint256 underlyingAmount1 = _convertTokens(_tokenFrom, pool.underlyingToken1, _amount / 2);
        // mint cTokens
        CErc20 cToken0 = CErc20(pool.curvePool.coins(0));
        CErc20 cToken1 = CErc20(pool.curvePool.coins(1));

        uint256 cToken0BalanceBefore = cToken0.balanceOf(address(this));
        uint256 cToken1BalanceBefore = cToken1.balanceOf(address(this));

        if (
            IERC20(pool.underlyingToken0).allowance(
                address(this),
                address(cToken0)
            ) < underlyingAmount0
        ) {
            IERC20(pool.underlyingToken0).safeIncreaseAllowance(
                address(cToken0),
                type(uint256).max
            );
        }

        if (
            IERC20(pool.underlyingToken1).allowance(
                address(this),
                address(cToken1)
            ) < underlyingAmount1
        ) {
            IERC20(pool.underlyingToken1).safeIncreaseAllowance(
                address(cToken1),
                type(uint256).max
            );
        }

        require(cToken0.mint(underlyingAmount0) == 0, "Error when minting cToken0");
        require(cToken1.mint(underlyingAmount1) == 0, "Error when minting cToken1");

        amount0 = cToken0.balanceOf(address(this)) - cToken0BalanceBefore;
        amount1 = cToken1.balanceOf(address(this)) - cToken1BalanceBefore;

        token0 = address(cToken0);
        token1 = address(cToken1);
    }

    function _addLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    ) internal override returns (uint256 amountLPs) {
        Pool memory pool = poolsArray[_pid];
        (
            address cToken0,
            address cToken1,
            uint256 amount0,
            uint256 amount1
        ) = _convertTokensToProvideLiquidity(_pid, _tokenFrom, _amount);

        if (
            IERC20(cToken0).allowance(
                address(this),
                address(pool.curvePool)
            ) < amount0
        ) {
            IERC20(cToken0).safeIncreaseAllowance(
                address(pool.curvePool),
                type(uint256).max
            );
        }

        if (
            IERC20(cToken1).allowance(
                address(this),
                address(pool.curvePool)
            ) < amount1
        ) {
            IERC20(cToken1).safeIncreaseAllowance(
                address(pool.curvePool),
                type(uint256).max
            );
        }

        uint256 balanceBefore = IERC20(pool.lp).balanceOf(address(this));

        pool.curvePool.add_liquidity(
            [amount0, amount1],
            0
        );

        amountLPs = IERC20(pool.lp).balanceOf(address(this)) - balanceBefore;
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

        CErc20 cToken0 = CErc20(pool.curvePool.coins(0));
        CErc20 cToken1 = CErc20(pool.curvePool.coins(1));

        uint256 cToken0AmountBefore = cToken0.balanceOf(address(this));
        uint256 cToken1AmountBefore = cToken1.balanceOf(address(this));

        // remove cTokens from pool
        pool.curvePool.remove_liquidity(
            _amount,
            [uint256(0), uint256(0)]
        );

        uint256 cToken0Amount = cToken0.balanceOf(address(this)) - cToken0AmountBefore;
        uint256 cToken1Amount = cToken1.balanceOf(address(this)) - cToken1AmountBefore;

        // redeem cTokens to underlying tokens
        uint256 uToken0AmountBefore = IERC20(pool.underlyingToken0).balanceOf(address(this));
        uint256 uToken1AmountBefore = IERC20(pool.underlyingToken1).balanceOf(address(this));

        require(cToken0.redeem(cToken0Amount) == 0, "Error when redeeming uToken0");
        require(cToken1.redeem(cToken1Amount) == 0, "Error when redeeming uToken1");

        tokenAmounts[0] = TokenAmount(
            {
                token: pool.underlyingToken0,
                amount: IERC20(pool.underlyingToken0).balanceOf(address(this)) - uToken0AmountBefore
            });
        tokenAmounts[1] = TokenAmount(
            {
                token: pool.underlyingToken1,
                amount: IERC20(pool.underlyingToken1).balanceOf(address(this)) - uToken1AmountBefore
            });
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

        // preview convert lps to cTokens
        uint256 lpTotalSupply = IERC20(pool.lp).totalSupply();
        uint256 cToken0Amount = pool.curvePool.balances(0) * amountLP / lpTotalSupply;
        uint256 cToken1Amount = pool.curvePool.balances(1) * amountLP / lpTotalSupply;

        // preview convert cTokens to underlying tokens
        CErc20 cToken0 = CErc20(pool.curvePool.coins(0));
        CErc20 cToken1 = CErc20(pool.curvePool.coins(1));
        uint256 cToken0ExchangeRateMantissa = cToken0.exchangeRateStored();
        uint256 cToken1ExchangeRateMantissa = cToken1.exchangeRateStored();
        uint256 uToken0Amount = mulScalarTruncate(Exp({mantissa: cToken0ExchangeRateMantissa}), cToken0Amount);
        uint256 uToken1Amount = mulScalarTruncate(Exp({mantissa: cToken1ExchangeRateMantissa}), cToken1Amount);

        tokenAmounts[0] = TokenAmount(
            {
                token: pool.underlyingToken0,
                amount: uToken0Amount
            });
        tokenAmounts[1] = TokenAmount(
            {
                token: pool.underlyingToken1,
                amount: uToken1Amount
            });

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

    function testGetUnderlyingToken(CurveCompoundPool curvePool, int128 i) public view returns(address token) {
        token = curvePool.underlying_coins(i);
    }

    function testGetCoin(CurveCompoundPool curvePool, int128 i) public view returns(address token) {
        token = curvePool.coins(i);
    }

    function addPool(
        address _lp,
        uint256 _convexID, // PID
        address _underlyingToken0,
        address _underlyingToken1,
        CurveCompoundPool _curvePool,
        ConvexReward _convexreward
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_curvePool.underlying_coins(0) == _underlyingToken0, "Token0 is not eq to pool's underlying token");
        require(_curvePool.underlying_coins(1) == _underlyingToken1, "Token1 is not eq to pool's underlying token");
        poolsArray.push(
            Pool(_lp, _convexID, _underlyingToken0, _underlyingToken1, _curvePool, _convexreward)
        );
    }
}
