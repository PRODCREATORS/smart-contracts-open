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

contract ETHSynthChefV1 is AccessControlEnumerable, Lender {
    
    using SafeMath for uint256;

    address public router;
    address public factory;
    address public rewardToken;
    address public WETH;
    address public convex;
    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;
    address[] private stablecoins;
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

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    constructor(
        address _router,
        address _factory,
        address _convex,
        uint256 _fee,
        address _treasury,
        address _rewardToken
    ) {
        convex = _convex;
        router = _router;
        factory = _factory;
        rewardToken = _rewardToken;
        WETH = IUniswapV2Router02(router).WETH();
        fee = _fee;
        treasury = _treasury;

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);
    }

    receive() external payable {}

    function setFactory(address _factory) external onlyRole(ADMIN_ROLE) {
        factory = _factory;
    }

    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
        router = _router;
    }

    function deposit(uint256 _pid) external payable onlyRole(ADMIN_ROLE) {
        uint256 amountLPs = addLiquidity(msg.value, WETH, _pid);
        _deposit(amountLPs, _pid);
        _compound(_pid);
        emit Deposit(amountLPs);
    }

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) external onlyRole(ADMIN_ROLE) {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = addLiquidity(_amount, _token, _poolID);
        _deposit(amountLPs, _poolID);
        _compound(_poolID);
        emit Deposit(amountLPs);
    }

    function _deposit(uint256 _amount, uint256 _poolID) internal {
        if (
            IERC20(poolsArray[_poolID].lp).allowance(address(this), convex) == 0
        ) {
            IERC20(poolsArray[_poolID].lp).approve(convex, type(uint256).max);
        }
        Convex(convex).deposit(poolsArray[_poolID].convexID, _amount, true);
    }

    function getSwapPath(address _tokenFrom, address _tokenTo)
        internal
        view
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

    function convertTokens(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    )
        public
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        token0 = poolsArray[_poolID].token0;
        token1 = poolsArray[_poolID].token1;
        if (_tokenFrom == WETH) {
            amount0 = swapETH(_amount / 2, token0);
            amount1 = swapETH(_amount / 2, token1);
        } else
            amount0 = token0 != _tokenFrom
                ? swapTokens(_amount / 2, getSwapPath(_tokenFrom, token0))
                : _amount / 2;
        amount1 = token1 != _tokenFrom
            ? swapTokens(_amount / 2, getSwapPath(_tokenFrom, token1))
            : _amount / 2;
    }

    function addLiquidity(
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
        ) = convertTokens(_amount, _tokenFrom, _poolID);
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

        if (token0 != WETH && token1 != WETH) {
            amountLPs = Curve(poolsArray[_poolID].curvePool).add_liquidity(
                [amount0, amount1],
                0,
                true
            );
        } else if (token0 == WETH) {
            (, , amountLPs) = IUniswapV2Router02(router).addLiquidityETH{
                value: amount0
            }(token1, amount1, 1, 1, address(this), block.timestamp);
        } else {
            (, , amountLPs) = IUniswapV2Router02(router).addLiquidityETH{
                value: amount1
            }(token0, amount0, 1, 1, address(this), block.timestamp);
        }

        if (IERC20(lpPair).allowance(address(this), convex) < amountLPs) {
            IERC20(lpPair).approve(convex, type(uint256).max);
        }
        return amountLPs;
    }

    function swapETH(uint256 _amount, address _tokenTo)
        internal
        returns (uint256)
    {
        if (_tokenTo == IUniswapV2Router02(router).WETH()) {
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
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = IUniswapV2Router02(router).WETH();
        uint256[] memory amounts = IUniswapV2Router02(router)
            .swapExactTokensForETH(
                _amount,
                1,
                path,
                address(this),
                block.timestamp
            );
        return amounts[1];
    }

    function swapTokens(uint256 _amount, address[] memory path)
        internal
        returns (uint256)
    {
        if (IERC20(path[0]).allowance(address(this), router) == 0) {
            IERC20(path[0]).approve(router, type(uint256).max);
        }

        uint256[] memory amountLPs = IUniswapV2Router02(router)
            .swapExactTokensForTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp
            );

        return amountLPs[amountLPs.length - 1];
    }

    function harvest(uint256 _pid) internal {
        ConvexReward(poolsArray[_pid].convexreward).getReward();
    }

    function compound(uint256 _pid) external onlyRole(ADMIN_ROLE) {
        harvest(_pid);
        _compound(_pid);
    }

    function _compound(uint256 _pid) internal {
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
        uint256 _poolID /// убрал uint256 _pid,
    )
        internal
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        address lpPair = poolsArray[_poolID].lp;
        token0 = poolsArray[_poolID].token0;
        token1 = poolsArray[_poolID].token1;

        if (IERC20(lpPair).allowance(address(this), router) < _amount) {
            IERC20(lpPair).approve(router, type(uint256).max);
        }

        if (token0 != WETH && token1 != WETH) {
            uint256[2] memory t;
            t[0] = 0;
            t[1] = 0;
            uint256[2] memory amounts = Curve(poolsArray[_poolID].curvePool)
                .remove_liquidity(_amount, t, true);
            amount0 = amounts[0];
            amount1 = amounts[1];
        } else if (token0 == WETH) {
            (amount1, amount0) = IUniswapV2Router02(router).removeLiquidityETH(
                token1,
                _amount,
                1,
                1,
                address(this),
                block.timestamp
            );
        } else {
            (amount0, amount1) = IUniswapV2Router02(router).removeLiquidityETH(
                token0,
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
    ) external onlyRole(ADMIN_ROLE) {
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
        if (_toToken != WETH) {
            uint256 amountToken = 0;
            amountToken += token0 != _toToken
                ? token0 != WETH
                    ? swapTokens(amount0, getSwapPath(token0, _toToken))
                    : swapETH(amount0, _toToken)
                : amount0;

            amountToken += token1 != _toToken
                ? token1 != WETH
                    ? swapTokens(amount1, getSwapPath(token1, _toToken))
                    : swapETH(amount1, _toToken)
                : amount1;

            IERC20(_toToken).transfer(_to, amountToken);
        } else {
            uint256 amountETH = 0;

            amountETH += token0 != WETH ? swapToETH(amount0, token0) : amount0;
            amountETH += token1 != WETH ? swapToETH(amount1, token1) : amount1;

            _to.transfer(amountETH);
        }
        uint256 rewards = IERC20(rewardToken).balanceOf(address(this));
        if (rewards > 0) {
            IERC20(rewardToken).transfer(msg.sender, rewards);
        }

        emit Withdraw(_amount);
    }

    function getAmountsTokensInLP(uint256 _pid)
        public
        view
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

    function getTokenAmount(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal view returns (uint256) {
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

    function addStablecoin(address coin) external onlyRole(ADMIN_ROLE) {
        require(coin != address(0), "Bad address");
        stablecoins.push(coin);
    }

    function cleanStablecoins() external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < stablecoins.length; i++) {
            delete stablecoins[i];
        }
    }

    function getStablecoin(uint256 pid) external view returns (address stable) {
        stable = stablecoins[pid];
    }

    function setFee(uint256 _fee, uint256 _feeRate) external onlyRole(ADMIN_ROLE) {
        fee = _fee;
        feeRate = _feeRate;
    }

    function setRewardToken(address _newToken) external onlyRole(ADMIN_ROLE) {
        require(_newToken != address(0), "Invalid address");
        rewardToken = _newToken;
    }

    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
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
    ) external onlyRole(ADMIN_ROLE) {
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

    function convertStableToLp(uint256 _pid, uint256 _amount)
        external
        view
        returns (uint256)
    {
        address token0 = poolsArray[_pid].token0;
        address token1 = poolsArray[_pid].token1;
        uint256 amount0 = convertStableToToken(token0, _amount.div(2));
        uint256 amount1 = convertStableToToken(token1, _amount.div(2));
        uint256 liquidity = Curve(poolsArray[_pid].curvePool).calc_token_amount(
            [amount0, amount1],
            true
        );
        return liquidity;
    }
}
