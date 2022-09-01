// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./BaseSynthChef.sol";

interface IMasterChef {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    function CAKE() external returns (IERC20);

    function lpToken(uint256 pid) external view returns (address);

    function userInfo(uint256 pid, address user) external view returns (IMasterChef.UserInfo memory);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 pid, uint256 amount) external;
}

interface ISpiritRouter {
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
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
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function totalSupply() external view returns (uint);
}

contract BSCSynthChef is BaseSynthChef {

    IMasterChef public chef;
    ISpiritRouter public router;
    address public factory;
    address public WETH;

    uint256 public fee;
    uint256 public feeRate = 1e4;
    address public treasury;

    /**
     * @dev Sets the values for `chef`, `router`,`factory`,`rewatdToken`,`WETH`,`fee` and `treasury`.
     */
    constructor(
        IMasterChef _chef,
        ISpiritRouter _router,
        address _factory,
        uint256 _fee,
        address _treasury,
        address _DEXWrapper,
        address _stablecoin,
        address[] memory _rewardTokens
    ) BaseSynthChef(_DEXWrapper, _stablecoin, _rewardTokens){
        chef = _chef;
        router = _router;
        factory = _factory;
        WETH = router.WETH();
        fee = _fee;
        treasury = _treasury;
    }

    function _depositToFarm(uint256 _pid, uint256 _amount) internal override {
        address lpPair = chef.lpToken(_pid);
        if (IERC20(lpPair).allowance(address(this), address(chef)) < _amount) {
            IERC20(lpPair).approve(address(chef), type(uint256).max);
        }
        chef.deposit(_pid, _amount);
    }

    function _withdrawFromFarm(uint256 _pid, uint256 _amount) internal override {
        chef.withdraw(_pid, _amount);
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
        address lpPair = chef.lpToken(_pid);
        token0 = IPair(lpPair).token0();
        token1 = IPair(lpPair).token1();

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
        (
            address token0,
            address token1,
            uint256 amount0,
            uint256 amount1
        ) = _convertTokensToProvideLiquidity(_pid, _tokenFrom, _amount);

        if (IERC20(token0).allowance(address(this), address(router)) == 0) {
            IERC20(token0).approve(address(router), type(uint256).max);
        }

        if (IERC20(token1).allowance(address(this), address(router)) == 0) {
            IERC20(token1).approve(address(router), type(uint256).max);
        }

        (, , amountLPs) = router.addLiquidity(
            token0,
            token1,
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
        _depositToFarm(_pid, 0);
    }


    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        override
        returns (TokenAmount[] memory tokenAmounts)
    {
        tokenAmounts = new TokenAmount[](2);
        address lpPair = chef.lpToken(_pid);
        address token0 = IPair(lpPair).token0();
        address token1 = IPair(lpPair).token1();

        if (IERC20(lpPair).allowance(address(this), address(router)) < _amount) {
            IERC20(lpPair).approve(address(router), type(uint256).max);
        }

        (uint256 amount0, uint256 amount1) = router.removeLiquidity(
            token0,
            token1,
            _amount,
            1,
            1,
            address(this),
            block.timestamp
        );
        tokenAmounts[0] = TokenAmount({amount: amount0, token: token0});
        tokenAmounts[1] = TokenAmount({amount: amount1, token: token1});
    }

    /**
     * @dev function for removing LP token
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function _getTokensInLP(uint256 _pid)
        internal
        view
        override
        returns (
            TokenAmount[] memory tokenAmounts
        )
    {
        tokenAmounts = new TokenAmount[](2);
        IMasterChef.UserInfo memory user = chef.userInfo(
            _pid,
            address(this)
        );
        address lpPair = IMasterChef(chef).lpToken(_pid);
        address token0 = IPair(lpPair).token0();
        address token1 = IPair(lpPair).token1();
        (uint256 reserve0, uint256 reserve1, ) = IPair(lpPair).getReserves();
        uint256 totalSupply = IPair(lpPair).totalSupply();
        uint256 amountLP = user.amount;
        uint256 amount0 = amountLP * reserve0 / totalSupply;
        uint256 amount1 = amountLP * reserve1 / totalSupply;
        tokenAmounts[0] = TokenAmount({token: token0, amount: amount0});
        tokenAmounts[1] = TokenAmount({token: token1, amount: amount1});
    }

    /**
     * @dev function for setting fee
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setFee(uint256 _fee, uint256 _feeRate) external onlyRole(ADMIN_ROLE) {
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
    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
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
        address lpPair = chef.lpToken(_pid);
        address token0 = IPair(lpPair).token0();
        address token1 = IPair(lpPair).token1();
        (uint112 _reserve0, uint112 _reserve1, ) = IPair(lpPair).getReserves();
        uint256 amount0 = convertStablecoinToToken(token0, _amount / 2);
        uint256 amount1 = convertStablecoinToToken(token1, _amount / 2);
        uint256 _totalSupply = IPair(lpPair).totalSupply();

        uint256 liquidity = Math.min(
            amount0 * _totalSupply / _reserve0,
            amount1 * _totalSupply / _reserve1
        );

        return liquidity;
    }
}