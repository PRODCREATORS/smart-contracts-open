// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

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
}

contract OptimismSynthChef is
    BaseSynthChef
{
    IERC20 public rewardToken;
    IVelodromeRouter public velodromeRouter;

    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;
    address private stablecoin;
    Pool[] public poolsArray;

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event Compound(uint256 amountStable);

    struct Pool {
        IERC20 LPToken;
        IGauge gauge;
        IERC20 token0;
        IERC20 token1;
        bool stable;
    }

    constructor(
        IVelodromeRouter _velodromeRouter,
        address _stablecoin,
        uint256 _fee,
        address _treasury,
        address _DEXWrapper,
        IERC20 _rewardToken
    ) BaseSynthChef(_DEXWrapper) {
        velodromeRouter = _velodromeRouter;
        rewardToken = _rewardToken;
        stablecoin = _stablecoin;
        fee = _fee;
        treasury = _treasury;
    }

    receive() external payable {}

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = _addLiquidity(_amount, _token, _poolID);
        _deposit(amountLPs, _poolID);
        _compound(_poolID);
        emit Deposit(amountLPs);
    }

    function _deposit(uint256 _amount, uint256 _poolID) internal {
        Pool memory pool = poolsArray[_poolID];
        if (
            pool.LPToken.allowance(address(this), address(pool.gauge)) < _amount
        ) {
            pool.LPToken.approve(address(pool.gauge), type(uint256).max);
        }
        pool.gauge.deposit(_amount, 0);
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

    function _addLiquidity(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    ) internal returns (uint256) {
        uint256 amountLPs;
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = convertTokensToProvideLiquidity(_amount, _tokenFrom, _poolID);
        Pool memory pool = poolsArray[_poolID];

        if (
            IERC20(token0).allowance(
                address(this),
                address(velodromeRouter)
            ) < amount0
        ) {
            IERC20(token0).approve(
                address(velodromeRouter),
                type(uint256).max
            );
        }

        if (
            IERC20(token1).allowance(
                address(this),
                address(velodromeRouter)
            ) < amount1
        ) {
            IERC20(token1).approve(
                address(velodromeRouter),
                type(uint256).max
            );
        }

        (, , amountLPs) = velodromeRouter.addLiquidity(token0, 
            token1, 
            pool.stable,
            amount0, 
            amount1,
            1,
            1,
            address(this),
            block.timestamp
        );
        return amountLPs;
    }

    function _harvest(uint256 _poolID) internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(rewardToken);
        poolsArray[_poolID].gauge.getReward(address(this), tokens);
    }

    function compound(uint256 _pid)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        _harvest(_pid);
        _compound(_pid);
    }

    function _compound(uint256 _pid) internal {
        uint256 amountToken = rewardToken.balanceOf(address(this));
        if (amountToken > 0) {
            uint256 amountTokenFee = amountToken * fee / feeRate;
            uint256 amountwithfee = amountToken - amountTokenFee;
            uint256 amountLPs = _addLiquidity(
                amountwithfee,
                address(rewardToken),
                _pid
            );
            _deposit(amountLPs, _pid);
            emit Compound(getBalanceOnFarms(_pid));
            if (amountTokenFee > 0) {
                rewardToken.transfer(treasury, amountTokenFee);
            }
        }
    }

    function removeLiquidity(
        uint256 _amount,
        uint256 _poolID
    )
        internal
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        Pool memory pool = poolsArray[_poolID];
        token0 = address(pool.token0);
        token1 = address(pool.token1);

        if (pool.LPToken.allowance(address(this), address(velodromeRouter)) < _amount) {
            pool.LPToken.approve(address(velodromeRouter), type(uint256).max);
        }
        uint256[2] memory t;
        t[0] = 0;
        t[1] = 0;
        (amount0, amount1) = velodromeRouter.removeLiquidity(token0, 
            token1, 
            pool.stable,
            _amount,
            amount0, 
            amount1,
            address(this),
            block.timestamp
        );
    }

    function withdraw(
        uint256 _amount,
        address _toToken,
        address _to,
        uint256 _poolID
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        Pool memory pool = poolsArray[_poolID];
        pool.gauge.withdraw(_amount);
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
        Pool memory pool = poolsArray[_pid];
        token0 = address(pool.token0);
        token1 = address(pool.token1);
        uint256 amountLP = pool.gauge.balanceOf(address(this));
        (amount0, amount1) = velodromeRouter.quoteRemoveLiquidity(address(token0), address(token1), pool.stable, amountLP);
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
        public
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
        totalAmount += convertTokenToStablecoin(token0, amount0); //convert token's price to stablecoin price
        totalAmount += convertTokenToStablecoin(token1, amount1); //convert token's price to stablecoin price
    }

    function setFee(uint256 _fee, uint256 _feeRate)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        fee = _fee;
        feeRate = _feeRate;
    }

    function setRewardToken(IERC20 _newToken)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(address(_newToken) != address(0), "Invalid address");
        rewardToken = _newToken;
    }

    function setTreasury(address _treasury)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    function addPool(
        IERC20 LPToken,
        IGauge gauge,
        IERC20 token0,
        IERC20 token1,
        bool stable
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        poolsArray.push(
            Pool(
                LPToken,
                gauge,
                token0,
                token1,
                stable
            )
        );
    }
}
