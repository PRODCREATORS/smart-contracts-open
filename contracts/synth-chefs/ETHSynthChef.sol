// SPDX-License-Identifier: BSL 1.1
pragma solidity >=0.8.9;


import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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
    
    using SafeMath for uint256;

    address public router;
    address public factory;
    address public rewardToken;
    address public WETH;
    address public convex;
    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;
    address private stablecoin;
    Pool[] public poolsArray;

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event Compound(uint256 amountStable);

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
        uint256 _fee,
        address _treasury,
        address _rewardToken,
        address _stablecoin,
        address _DEXWrapper
    ) BaseSynthChef(_DEXWrapper) {
        convex = _convex;
        router = _router;
        factory = _factory;
        rewardToken = _rewardToken;
        stablecoin = _stablecoin;
        
        WETH = IUniswapV2Router02(router).WETH();
        fee = _fee;
        treasury = _treasury;
    }

    receive() external payable {}

    function setFactory(address _factory) external onlyRole(ADMIN_ROLE) whenNotPaused {
        factory = _factory;
    }

    function setRouter(address _router) external onlyRole(ADMIN_ROLE) whenNotPaused {
        router = _router;
    }

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = addLiquidity(_amount, _token, _poolID);
        _deposit(amountLPs, _poolID);
        _compound(_poolID);
        emit Deposit(amountLPs);
    }

    function _deposit(uint256 _amount, uint256 _poolID) internal whenNotPaused {
        if (
            IERC20(poolsArray[_poolID].lp).allowance(address(this), convex) == 0
        ) {
            IERC20(poolsArray[_poolID].lp).approve(convex, type(uint256).max);
        }
        Convex(convex).deposit(poolsArray[_poolID].convexID, _amount, true);
    }

    function convertTokensToProvideLiquidity(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    )
        public
        whenNotPaused
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        token0 = address(poolsArray[_poolID].token0);
        token1 = address(poolsArray[_poolID].token1);
        amount0 = token0 != _tokenFrom ? _convertTokens(_tokenFrom, token0, amount0) : _amount / 2;
        amount1 = token1 != _tokenFrom ? _convertTokens(_tokenFrom, token1, amount1) : _amount / 2;
    }

    function addLiquidity(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    ) internal whenNotPaused returns (uint256) {
        uint256 amountLPs;
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = convertTokensToProvideLiquidity(_amount, _tokenFrom, _poolID);
        address lpPair = poolsArray[_poolID].lp;

        if (
            IERC20(token0).allowance(
                address(this),
                poolsArray[_poolID].curvePool
            ) == 0
        ) {
            IERC20(token0).approve(
                poolsArray[_poolID].curvePool,
                type(uint256).max
            );
        }

        if (
            IERC20(token1).allowance(
                address(this),
                poolsArray[_poolID].curvePool
            ) == 0
        ) {
            IERC20(token1).approve(
                poolsArray[_poolID].curvePool,
                type(uint256).max
            );
        }

        amountLPs = Curve(poolsArray[_poolID].curvePool).add_liquidity(
            [amount0, amount1],
            0,
            true
        );

        if (IERC20(lpPair).allowance(address(this), convex) < amountLPs) {
            IERC20(lpPair).approve(convex, type(uint256).max);
        }
        return amountLPs;
    }

    function harvest(uint256 _pid) internal whenNotPaused {
        ConvexReward(poolsArray[_pid].convexreward).getReward();
    }

    function compound(uint256 _pid) external onlyRole(ADMIN_ROLE) whenNotPaused  {
        harvest(_pid);
        _compound(_pid);
    }

    function _compound(uint256 _pid) internal whenNotPaused {
        uint256 amountToken = IERC20(rewardToken).balanceOf(address(this));
        if (amountToken > 0) {
            uint256 amountTokenFee = amountToken.mul(fee).div(feeRate);
            uint256 amountwithfee = amountToken - amountTokenFee;
            uint256 amountLPs = addLiquidity(amountwithfee, rewardToken, _pid);
            _deposit(amountLPs, _pid);
            emit Compound(getBalanceOnFarms(_pid));
            if (amountTokenFee > 0) {
                IERC20(rewardToken).transfer(treasury, amountTokenFee);
            }
        }
    }

    function removeLiquidity(
        uint256 _amount,
        uint256 _poolID
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
        token0 = poolsArray[_poolID].token0;
        token1 = poolsArray[_poolID].token1;

        uint256[2] memory t;
        t[0] = 0;
        t[1] = 0;
        uint256[2] memory amounts = Curve(poolsArray[_poolID].curvePool)
            .remove_liquidity(_amount, t, true);
        amount0 = amounts[0];
        amount1 = amounts[1];
    }

    function withdraw(
        uint256 _amount,
        address _toToken,
        address _to,
        uint256 _poolID
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        ConvexReward(poolsArray[_poolID].convexreward).withdrawAndUnwrap(
            _amount,
            true
        );
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = removeLiquidity(_amount, _poolID);
        uint256 amountToken = 0;
        amountToken += token0 != _toToken ? _convertTokens(token0, _toToken, amount0) : amount0;
        amountToken += token1 != _toToken ? _convertTokens(token1, _toToken, amount1) : amount1;

        IERC20(_toToken).transfer(_to, amountToken);
        uint256 rewards = IERC20(rewardToken).balanceOf(address(this));
        if (rewards > 0) {
            IERC20(rewardToken).transfer(msg.sender, rewards);
        }

        emit Withdraw(_amount);
    }

    function getAmountsTokensInLP(uint256 _pid)
        public
        view
        whenNotPaused 
        returns (
            uint256 amount0,
            uint256 amount1,
            address token0,
            address token1
        )
    {
        token0 = poolsArray[_pid].token0;
        token1 = poolsArray[_pid].token1;
        uint256 amountLP = ConvexReward(poolsArray[_pid].convexreward)
            .balanceOf(address(this));
        amount0 = Curve(poolsArray[_pid].curvePool).calc_withdraw_one_coin(
            amountLP,
            int128(0)
        );
        amount1 = Curve(poolsArray[_pid].curvePool).calc_withdraw_one_coin(
            amountLP,
            int128(1)
        );
    }

    function convertTokenToStablecoin(address _tokenAddress, uint256 _amount)
        public
        view
        whenNotPaused
        returns (uint256 amountStable)
    {
        if (_tokenAddress == stablecoin)
            return _amount;
        return _previewConvertTokens(_tokenAddress, stablecoin, _amount);
    }

    function convertStablecoinToToken(address _tokenAddress, uint256 _amountStablecoin)
        internal
        view
        returns (uint256 amountToken)
    {
        if (_tokenAddress == stablecoin)
            return _amountStablecoin;
        return _previewConvertTokens(stablecoin, _tokenAddress, _amountStablecoin);
    }

    function getBalanceOnFarms(uint256 _pid)
        internal
        view
        whenNotPaused 
        returns (uint256 totalAmount)
    {
        (
            uint256 amount0,
            uint256 amount1,
            address token0,
            address token1
        ) = getAmountsTokensInLP(_pid); //convert amount lps to two token amounts
        totalAmount += convertTokenToStablecoin(token0, amount0); //convert token's price to stablecoins price
        totalAmount += convertTokenToStablecoin(token1, amount1); //convert token's price to stablecoins price
    }

    function setFee(uint256 _fee, uint256 _feeRate) external onlyRole(ADMIN_ROLE) whenNotPaused {
        fee = _fee;
        feeRate = _feeRate;
    }

    function setRewardToken(address _newToken) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_newToken != address(0), "Invalid address");
        rewardToken = _newToken;
    }

    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
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
