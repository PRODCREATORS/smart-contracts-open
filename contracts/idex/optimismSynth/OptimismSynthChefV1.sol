// SPDX-License-Identifier: GPL-2
pragma solidity >=0.8.9;

import "./utils/IBooster.sol";
import "../../Lender.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../PausableAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

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

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);
}

contract OptimismSynthChefV1 is
    AccessControlEnumerable,
    PausableAccessControl,
    Lender
{
    using SafeMath for uint256;

    IUniswapV2Router02 public router;
    address public factory;
    IERC20 public rewardToken;
    address public WETH;
    IVelodromeRouter public velodromeRouter;

    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;
    address[] private stablecoins;
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

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    constructor(
        IUniswapV2Router02 _router,
        IVelodromeRouter _velodromeRouter,
        address _factory,
        uint256 _fee,
        address _treasury,
        IERC20 _rewardToken
    ) {
        router = _router;
        velodromeRouter = _velodromeRouter;
        factory = _factory;
        rewardToken = _rewardToken;
        WETH = router.WETH();
        fee = _fee;
        treasury = _treasury;

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);
    }

    receive() external payable {}

    function setFactory(address _factory)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        factory = _factory;
    }

    function setRouter(IUniswapV2Router02 _router)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        router = _router;
    }

    function deposit(uint256 _poolID)
        external
        payable
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        uint256 amountLPs = _addLiquidity(msg.value, WETH, _poolID);
        _deposit(amountLPs, _poolID);
        _compound(_poolID);
        emit Deposit(amountLPs);
    }

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = _addLiquidity(_amount, _token, _poolID);
        _deposit(amountLPs, _poolID);
        _compound(_poolID);
        emit Deposit(amountLPs);
    }

    function _deposit(uint256 _amount, uint256 _poolID) internal whenNotPaused {
        Pool memory pool = poolsArray[_poolID];
        if (
            pool.LPToken.allowance(address(this), address(pool.gauge)) < _amount
        ) {
            pool.LPToken.approve(address(pool.gauge), type(uint256).max);
        }
        pool.gauge.deposit(_amount, 0);
    }

    function getSwapPath(address _tokenFrom, address _tokenTo)
        internal
        view
        whenNotPaused
        returns (address[] memory path)
    {
        address lpPair = IUniswapV2Factory(factory).getPair(
            _tokenFrom,
            _tokenTo
        );

        if (lpPair != address(0)) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else {
            path = new address[](3);
            path[0] = _tokenFrom;
            path[1] = WETH;
            path[2] = _tokenTo;
        }

        return path;
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
        if (_tokenFrom == WETH) {
            amount0 = swapETH(_amount / 2, token0);
            amount1 = swapETH(_amount / 2, token1);
        } else
            amount0 = token0 != _tokenFrom
                ? _swapTokens(_amount / 2, getSwapPath(_tokenFrom, token0))
                : _amount / 2;
        amount1 = token1 != _tokenFrom
            ? _swapTokens(_amount / 2, getSwapPath(_tokenFrom, token1))
            : _amount / 2;
    }

    function _addLiquidity(
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

        if (token0 != WETH && token1 != WETH) {
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
        } else if (token0 == WETH) {
            (, , amountLPs) = velodromeRouter.addLiquidityETH{
                value: amount0
            }(token1, pool.stable, amount1, 1, 1, address(this), block.timestamp);
        } else {
            (, , amountLPs) = velodromeRouter.addLiquidityETH{
                value: amount1
            }(token0, pool.stable, amount0,  1, 1, address(this), block.timestamp);
        }
        return amountLPs;
    }

    function swapETH(uint256 _amount, address _tokenTo)
        internal
        whenNotPaused
        returns (uint256)
    {
        if (_tokenTo == router.WETH()) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router02(router).WETH();
        path[1] = _tokenTo;
        uint256[] memory amountLPs = IUniswapV2Router02(router)
            .swapExactETHForTokens{value: _amount}(
            0,
            path,
            address(this),
            block.timestamp
        );

        return amountLPs[1];
    }

    function swapToETH(uint256 _amount, address _fromToken)
        internal
        whenNotPaused
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = router.WETH();
        uint256[] memory amounts = router.swapExactTokensForETH(
            _amount,
            1,
            path,
            address(this),
            block.timestamp
        );
        return amounts[1];
    }

    function _swapTokens(uint256 _amount, address[] memory path)
        internal
        whenNotPaused
        returns (uint256)
    {
        if (IERC20(path[0]).allowance(address(this), address(router)) == 0) {
            IERC20(path[0]).approve(address(router), type(uint256).max);
        }

        uint256[] memory amounts = router.swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    function _harvest(uint256 _poolID) internal whenNotPaused {
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

    function _compound(uint256 _pid) internal whenNotPaused {
        uint256 amountToken = rewardToken.balanceOf(address(this));
        if (amountToken > 0) {
            uint256 amountTokenFee = amountToken.mul(fee).div(feeRate);
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
        whenNotPaused
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

        if (pool.LPToken.allowance(address(this), address(router)) < _amount) {
            pool.LPToken.approve(address(router), type(uint256).max);
        }

        if (token0 != WETH && token1 != WETH) {
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
        } else if (token0 == WETH) {
            (amount1, amount0) = velodromeRouter.removeLiquidityETH(
                token1, 
                pool.stable,
                _amount,
                1, 
                1,
                address(this),
                block.timestamp
            );
        } else {
            (amount0, amount1) = velodromeRouter.removeLiquidityETH(
                token0, 
                pool.stable,
                _amount,
                1, 
                1,
                address(this),
                block.timestamp
            );
        }
    }

    function withdraw(
        uint256 _amount,
        address _toToken,
        address payable _to,
        uint256 _poolID
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        Pool memory pool = poolsArray[_poolID];
        pool.gauge.withdraw(_amount);
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = removeLiquidity(_amount, _poolID);
        if (_toToken != WETH) {
            uint256 amountToken = 0;
            amountToken += token0 != _toToken
                ? token0 != WETH
                    ? _swapTokens(amount0, getSwapPath(token0, _toToken))
                    : swapETH(amount0, _toToken)
                : amount0;

            amountToken += token1 != _toToken
                ? token1 != WETH
                    ? _swapTokens(amount1, getSwapPath(token1, _toToken))
                    : swapETH(amount1, _toToken)
                : amount1;

            IERC20(_toToken).transfer(_to, amountToken);
        } else {
            uint256 amountETH = 0;

            amountETH += token0 != WETH ? swapToETH(amount0, token0) : amount0;
            amountETH += token1 != WETH ? swapToETH(amount1, token1) : amount1;

            _to.transfer(amountETH);
        }
        uint256 rewards = rewardToken.balanceOf(address(this));
        if (rewards > 0) {
            rewardToken.transfer(msg.sender, rewards);
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
        Pool memory pool = poolsArray[_pid];
        token0 = address(pool.token0);
        token1 = address(pool.token1);
        uint256 amountLP = pool.gauge.balanceOf(address(this));
        (amount0, amount1) = velodromeRouter.quoteRemoveLiquidity(address(token0), address(token1), pool.stable, amountLP);
    }

    function getTokenAmount(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal view whenNotPaused returns (uint256) {
        uint256 expectedReturn = _amount;
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        expectedReturn = IUniswapV2Router02(router).getAmountsOut(
            _amount,
            path
        )[1];
        return expectedReturn;
    }

    function convertTokenToStable(address _tokenAddress, uint256 _amount)
        internal
        view
        whenNotPaused
        returns (uint256 amountStable)
    {
        bool flag = false;
        for (uint256 i = 0; i < stablecoins.length; i++) {
            if (_tokenAddress == stablecoins[i]) {
                amountStable += _amount;
                flag = true;
                break;
            }
        }
        if (!flag) {
            if (_tokenAddress != WETH) {
                uint256 amountWETH = getTokenAmount(
                    _amount,
                    _tokenAddress,
                    WETH
                );
                amountStable += getTokenAmount(
                    amountWETH,
                    WETH,
                    stablecoins[0]
                );
            } else {
                amountStable += getTokenAmount(_amount, WETH, stablecoins[0]);
            }
        }
    }

    function convertStableToToken(address _tokenAddress, uint256 _amountStable)
        internal
        view
        whenNotPaused
        returns (uint256 amountToken)
    {
        if (_tokenAddress != WETH) {
            uint256 amountWETH = getTokenAmount(
                _amountStable,
                stablecoins[0],
                WETH
            );
            amountToken += getTokenAmount(amountWETH, WETH, _tokenAddress);
        } else {
            amountToken += getTokenAmount(_amountStable, stablecoins[0], WETH);
        }
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
        totalAmount += convertTokenToStable(token0, amount0); //convert token's price to stablecoins price
        totalAmount += convertTokenToStable(token1, amount1); //convert token's price to stablecoins price
    }

    function addStablecoin(address coin)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(coin != address(0), "Bad address");
        stablecoins.push(coin);
    }

    function cleanStablecoins() external onlyRole(ADMIN_ROLE) whenNotPaused {
        for (uint256 i = 0; i < stablecoins.length; i++) {
            delete stablecoins[i];
        }
    }

    function getStablecoin(uint256 pid)
        external
        view
        whenNotPaused
        returns (address stable)
    {
        stable = stablecoins[pid];
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


    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _grantRole(bytes32 role, address account)
        internal
        virtual
        override(AccessControlEnumerable, AccessControl)
    {
        return super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account)
        internal
        virtual
        override(AccessControlEnumerable, AccessControl)
    {
        return super._revokeRole(role, account);
    }
}
