// SPDX-License-Identifier: GPL-2
pragma solidity 0.8.12;

import "./utils/IMasterChef.sol";
import "./utils/IJoeRouter02.sol";
import "./utils/IJoePair.sol";
import "./utils/IJoeFactory.sol";
import "./BaseSynthChef.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract AvaxSynthChefV2 is BaseSynthChef {
    using SafeMath for uint256;

    address public chef;
    address public router;
    address public factory;
    address public rewardToken;
    address public WAVAX;
    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;

    event Deposit(uint256 pid, uint256 amount);
    event Withdraw(uint256 pid, uint256 amount);
    event Compound(uint256 amountStable);

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    /**
     * @dev Sets the values for `chef`, `router`,`factory`,`rewatdToken`,`WETH`,`fee` and `treasury`.
     */
    constructor(
        address _chef,
        address _router,
        address _factory,
        uint256 _fee,
        address _treasury,
        address _DEXWrapper
    ) BaseSynthChef(_DEXWrapper) {
        chef = _chef;
        router = _router;
        factory = _factory;
        rewardToken = address(IMasterChef(chef).JOE());
        WAVAX = IJoeRouter02(router).WAVAX();
        fee = _fee;
        treasury = _treasury;

        _setRoleAdmin(ADMIN, OWNER);
        _setupRole(OWNER, msg.sender);
    }

    receive() external payable {}

    /**
     * @dev function to set Synth Factory address
     * @param _factory SynthFactory address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setFactory(address _factory) external onlyRole(ADMIN) {
        factory = _factory;
    }

    /**
     * @dev function to set Synth Chef address
     * @param _chef SynthChef address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setChef(address _chef) external onlyRole(ADMIN) {
        chef = _chef;
    }

    /**
     * @dev function to set Synth Chef address
     * @param _router router address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setRouter(address _router) external onlyRole(ADMIN) {
        router = _router;
    }

    /**
     * @dev function to deposit crypto to a pool with pid = _pid
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    // function deposit(uint256 _pid) external payable onlyRole(ADMIN) {
    //     uint256 amountLPs = addLiquidity(_pid, msg.value, WAVAX);
    //     _deposit(_pid, amountLPs);
    //     _compound(_pid);
    //     emit Deposit(_pid, amountLPs);
    // }

    /**
     * @dev function to deposit token to a pool with pid = _pid
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _token
    ) public override onlyRole(ADMIN) whenNotPaused {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = addLiquidity(_pid, _amount, _token);
        _deposit(_pid, amountLPs);
        _compound(_pid);
        emit Deposit(_pid, amountLPs);
    }

    function _deposit(uint256 _pid, uint256 _amount) internal whenNotPaused {
        IMasterChef(chef).deposit(_pid, _amount);
    }

    /**
     * @dev A read-only function that shows the path of tokens swap
     */
    function getSwapPath(address _tokenFrom, address _tokenTo)
        internal
        view
        returns (address[] memory path)
    {
        address lpPair = IJoeFactory(factory).getPair(_tokenFrom, _tokenTo);

        if (lpPair != address(0)) {
            path = new address[](2);
            path[0] = _tokenFrom;
            path[1] = _tokenTo;
        } else {
            path = new address[](3);
            path[0] = _tokenFrom;
            path[1] = WAVAX;
            path[2] = _tokenTo;
        }

        return path;
    }

    /**
     * @dev function that convert tokens in lp token
     */
    function convertTokens(
        address _lpPair,
        uint256 _amount,
        address _tokenFrom
    )
        internal
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        token0 = IJoePair(_lpPair).token0();
        token1 = IJoePair(_lpPair).token1();

        if (_tokenFrom == WAVAX) {
            amount0 = swapAVAX(_amount / 2, token0);
            amount1 = swapAVAX(_amount / 2, token1);
        } else {
            amount0 = token0 != _tokenFrom
                ? swapTokens(_amount / 2, getSwapPath(_tokenFrom, token0))
                : _amount / 2;
            amount1 = token1 != _tokenFrom
                ? swapTokens(_amount / 2, getSwapPath(_tokenFrom, token1))
                : _amount / 2;
        }
    }

    /**
     * @dev function to add liquidity in current lp pool
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function addLiquidity(
        uint256 _pid,
        uint256 _amount,
        address _tokenFrom
    ) internal returns (uint256 amountLPs) {
        IMasterChef.PoolInfo memory farm = IMasterChef(chef).poolInfo(_pid);
        address lpPair = address(farm.lpToken);

        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = convertTokens(lpPair, _amount, _tokenFrom);

        if (IERC20(token0).allowance(address(this), router) == 0) {
            IERC20(token0).approve(router, type(uint256).max);
        }

        if (IERC20(token1).allowance(address(this), router) == 0) {
            IERC20(token1).approve(router, type(uint256).max);
        }

        if (token0 != WAVAX && token1 != WAVAX) {
            (, , amountLPs) = IJoeRouter02(router).addLiquidity(
                token0,
                token1,
                amount0,
                amount1,
                0,
                0,
                address(this),
                block.timestamp
            );
        } else if (token0 == WAVAX) {
            (, , amountLPs) = IJoeRouter02(router).addLiquidityAVAX{
                value: amount0
            }(token1, amount1, 1, 1, address(this), block.timestamp);
        } else {
            (, , amountLPs) = IJoeRouter02(router).addLiquidityAVAX{
                value: amount1
            }(token0, amount0, 1, 1, address(this), block.timestamp);
        }

        if (IERC20(lpPair).allowance(address(this), chef) < amountLPs) {
            IERC20(lpPair).approve(chef, type(uint256).max);
        }
    }

    /**
     * @dev function to swap crypto for current token
     */
    function swapAVAX(uint256 _amount, address _tokenTo)
        internal
        returns (uint256)
    {
        if (_tokenTo == IJoeRouter02(router).WAVAX()) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = IJoeRouter02(router).WAVAX();
        path[1] = _tokenTo;
        uint256[] memory amountLPs = IJoeRouter02(router)
            .swapExactAVAXForTokens{value: _amount}(
            0,
            path,
            address(this),
            block.timestamp
        );

        return amountLPs[1];
    }

    /**
     * @dev function to swap token for crypto
     */
    function swapToAVAX(uint256 _amount, address _fromToken)
        internal
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = IJoeRouter02(router).WAVAX();
        uint256[] memory amounts = IJoeRouter02(router).swapExactTokensForAVAX(
            _amount,
            1,
            path,
            address(this),
            block.timestamp
        );
        return amounts[1];
    }

    /**
     * @dev function to swap token for tokens
     */
    function swapTokens(uint256 _amount, address[] memory path)
        internal
        returns (uint256)
    {
        if (IERC20(path[0]).allowance(address(this), router) == 0) {
            IERC20(path[0]).approve(router, type(uint256).max);
        }

        uint256[] memory amountLPs = IJoeRouter02(router)
            .swapExactTokensForTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp
            );

        return amountLPs[amountLPs.length - 1];
    }

    /**
     * @dev function for collecting rewards
     */
    function harvest(uint256 _pid) internal {
        _deposit(_pid, 0);
    }

    /**
     * @dev function for rewards reinvesting
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function compound(uint256 _pid) external onlyRole(ADMIN) {
        harvest(_pid);
        _compound(_pid);
    }

    function _compound(uint256 _pid) internal {
        uint256 amountToken = IERC20(rewardToken).balanceOf(address(this));
        if (amountToken > 0) {
            uint256 amountTokenFee = (amountToken * fee) / feeRate;
            uint256 amountLPs = addLiquidity(
                _pid,
                amountToken - amountTokenFee,
                rewardToken
            );
            // uint256 totalDepositAmount = IMasterChef(chef)
            //     .userInfo(_pid, address(this))
            //     .amount;
            _deposit(_pid, amountLPs);
            emit Compound(getBalanceOnFarms(_pid));
            if (amountTokenFee > 0) {
                IERC20(rewardToken).transfer(treasury, amountTokenFee);
            }
        }
    }

    /**
     * @dev function for removing LP token
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        returns (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        )
    {
        IMasterChef.PoolInfo memory farm = IMasterChef(chef).poolInfo(_pid);
        address lpPair = address(farm.lpToken);
        token0 = IJoePair(lpPair).token0();
        token1 = IJoePair(lpPair).token1();

        if (IERC20(lpPair).allowance(address(this), router) < _amount) {
            IERC20(lpPair).approve(router, type(uint256).max);
        }

        if (token0 != WAVAX && token1 != WAVAX) {
            (amount0, amount1) = IJoeRouter02(router).removeLiquidity(
                token0,
                token1,
                _amount,
                1,
                1,
                address(this),
                block.timestamp
            );
        } else if (token0 == WAVAX) {
            (amount1, amount0) = IJoeRouter02(router).removeLiquidityAVAX(
                token1,
                _amount,
                1,
                1,
                address(this),
                block.timestamp
            );
        } else {
            (amount0, amount1) = IJoeRouter02(router).removeLiquidityAVAX(
                token0,
                _amount,
                1,
                1,
                address(this),
                block.timestamp
            );
        }
    }

    /**
     * @dev function for removing tokens from the deposit
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function withdraw(
        uint256 _pid,
        uint256 _amount,
        address _toToken,
        address payable _to
    ) public override onlyRole(ADMIN) {
        require(
            IMasterChef(chef).userInfo(_pid, address(this)).amount >= _amount,
            "Insufficient amount"
        );
        IMasterChef(chef).withdraw(_pid, _amount);
        _compound(_pid);
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = removeLiquidity(_pid, _amount);
        if (_toToken != WAVAX) {
            uint256 amountToken = 0;
            amountToken += token0 != _toToken
                ? token0 != WAVAX
                    ? swapTokens(amount0, getSwapPath(token0, _toToken))
                    : swapAVAX(amount0, _toToken)
                : amount0;

            amountToken += token1 != _toToken
                ? token1 != WAVAX
                    ? swapTokens(amount1, getSwapPath(token1, _toToken))
                    : swapAVAX(amount1, _toToken)
                : amount1;

            IERC20(_toToken).transfer(_to, amountToken);
        } else {
            uint256 amountAVAX = 0;

            amountAVAX += token0 != WAVAX
                ? swapToAVAX(amount0, token0)
                : amount0;
            amountAVAX += token1 != WAVAX
                ? swapToAVAX(amount1, token1)
                : amount1;

            _to.transfer(amountAVAX);
        }

        emit Withdraw(_pid, _amount);
    }

    /**
     * @dev A read-only function that calculates how many lp tokens will user get
     */
    function getAmountsTokensInLP(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            address token0,
            address token1
        )
    {
        IMasterChef.PoolInfo memory farm = IMasterChef(chef).poolInfo(_pid);
        IMasterChef.UserInfo memory user = IMasterChef(chef).userInfo(
            _pid,
            _user
        );

        address lpPair = address(farm.lpToken);
        token0 = IJoePair(lpPair).token0();
        token1 = IJoePair(lpPair).token1();
        uint256 balance0 = ERC20(token0).balanceOf(lpPair);
        uint256 balance1 = ERC20(token1).balanceOf(lpPair);
        uint256 totalSupply = IJoePair(lpPair).totalSupply();
        uint256 amountLP = user.amount;
        amount0 = amountLP.mul(balance0).div(totalSupply);
        amount1 = amountLP.mul(balance1).div(totalSupply);
    }

    /**
     * @dev A read-only function that calculates how many tokens will user get for another token
     */
    function getTokenAmount(
        uint256 _amount,
        address _fromToken,
        address _toToken
    ) internal view returns (uint256) {
        uint256 expectedReturn = _amount;
        address[] memory path = new address[](2);
        path[0] = _fromToken;
        path[1] = _toToken;
        expectedReturn = IJoeRouter02(router).getAmountsOut(_amount, path)[1];
        return expectedReturn;
    }

    /**
     * @dev A read-only function to get tokens price in usd
     */
    function convertTokenToStable(address _tokenAddress, uint256 _amount)
        internal
        view
        returns (uint256 amountStable)
    {
        bool flag = false;
        if (!flag) {
            if (_tokenAddress != WAVAX) {
                uint256 amountWAVAX = getTokenAmount(
                    _amount,
                    _tokenAddress,
                    WAVAX
                );
                amountStable += getTokenAmount(
                    amountWAVAX,
                    WAVAX,
                    _tokenAddress
                );
            } else {
                amountStable += getTokenAmount(_amount, WAVAX, _tokenAddress);
            }
        }
    }

    /**
     * @dev A read-only function that calculates how many tokens will user get for usd
     */
    function convertStableToToken(address _tokenAddress, uint256 _amountStable)
        internal
        view
        returns (uint256 amountToken)
    {
        if (_tokenAddress != WAVAX) {
            uint256 amountWAVAX = getTokenAmount(
                _amountStable,
                _tokenAddress,
                WAVAX
            );
            amountToken += getTokenAmount(amountWAVAX, WAVAX, _tokenAddress);
        } else {
            amountToken += getTokenAmount(_amountStable, _tokenAddress, WAVAX);
        }
    }

    /**
     * @dev A read-only function that calculates Farms balance in usd
     */
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
        ) = this.getAmountsTokensInLP(_pid, address(this)); //convert amount lps to two token amounts
        totalAmount += convertTokenToStable(token0, amount0); //convert token's price to stablecoins price
        totalAmount += convertTokenToStable(token1, amount1); //convert token's price to stablecoins price
    }

    /**
     * @dev function for setting fee
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setFee(uint256 _fee, uint256 _feeRate) external onlyRole(ADMIN) {
        fee = _fee;
        feeRate = _feeRate;
    }

    /**
     * @dev function for setting treasury
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setTreasury(address _treasury) external onlyRole(ADMIN) {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }

    /**
     * @dev A read-only function that calculates how many lp tokens will user get for usd
     */
    function convertStableToLp(uint256 _pid, uint256 _amount)
        external
        view
        returns (uint256)
    {
        IMasterChef.PoolInfo memory farm = IMasterChef(chef).poolInfo(_pid);

        address lpPair = address(farm.lpToken);
        address token0 = IJoePair(lpPair).token0();
        address token1 = IJoePair(lpPair).token1();
        (uint112 _reserve0, uint112 _reserve1, ) = IJoePair(lpPair)
            .getReserves();
        uint256 amount0 = convertStableToToken(token0, _amount.div(2));
        uint256 amount1 = convertStableToToken(token1, _amount.div(2));
        uint256 _totalSupply = IJoePair(lpPair).totalSupply();

        uint256 liquidity = Math.min(
            amount0.mul(_totalSupply) / _reserve0,
            amount1.mul(_totalSupply) / _reserve1
        );

        return liquidity;
    }
}
