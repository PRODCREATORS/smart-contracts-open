// SPDX-License-Identifier: GPL-2
pragma solidity >=0.8.9;


import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BaseSynthChef.sol";

interface IStargate {
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) external returns (bool);

    function emergencyWithdraw(uint256 _pid) external;

    function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IStargateRouter {
    function addLiquidity(uint _poolId, uint256 _amountLD, address _to) external;

    function instantRedeemLocal(uint16 _srcPoolId, uint256 _amountLP, address _to) external returns(uint256 amountSD);
}

interface IStargatePool {
    function balanceOf(address _user) external view returns(uint256);
    
}
interface IGauge {
    function deposit(uint amount, uint tokenId) external;

    function getReward(address account, address[] memory tokens) external;

    function withdraw(uint amount) external;

    function balanceOf(address user) external view returns (uint);
}


interface IVelodromeFactory {
    function getPair(address tokenA, address token, bool stable) external view returns (address);
}

interface IPair {
    function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
}

contract OptimismSynthChef is
    BaseSynthChef
{
    using SafeMath for uint256;

    IVelodromeFactory public  factory;
    IERC20 public rewardToken;
    address public WETH;
    IStargateRouter public StargateRouter;

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
        IStargate stargate;
        IStargatePool stargatePool;
        IERC20 token;
        uint256 stargateID;
        uint24 feeUniswapPool;
        bool stable;
    }

    constructor(
        IStargateRouter _stargateRouter,
        address _WETH,
        address _stablecoin,
        IVelodromeFactory _factory,
        uint256 _fee,
        address _treasury,
        address _DEXWrapper,
        IERC20 _rewardToken
    ) BaseSynthChef(_DEXWrapper) {
        StargateRouter = _stargateRouter;
        factory = _factory;
        rewardToken = _rewardToken;
        WETH = _WETH;
        stablecoin = _stablecoin;
        fee = _fee;
        treasury = _treasury;
    }

    receive() external payable {}

    function setFactory(IVelodromeFactory _factory)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        factory = _factory;
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

    function _deposit(uint256 _amount, uint256 _poolID) internal {
        Pool memory pool = poolsArray[_poolID];
        if (
            pool.LPToken.allowance(address(this), address( pool.stargate)) < _amount
        ) {
            pool.LPToken.approve(address(pool.stargate), type(uint256).max);
        }
        pool.stargate.deposit(pool.stargateID, _amount);
    }

    function convertTokensToProvideLiquidity(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    )
        public
        whenNotPaused
        returns (
            address token,
            uint256 amount
        )
    {
        Pool memory pool = poolsArray[_poolID];
        token = address(poolsArray[_poolID].token);
        amount = token != _tokenFrom ? _convertTokens(_tokenFrom, token, amount, pool.feeUniswapPool) : _amount;
    }

    function _addLiquidity(
        uint256 _amount,
        address _tokenFrom,
        uint256 _poolID
    ) internal returns (uint256) {
        uint256 amountLPs;
        (
            address token,
            uint256 amount
        ) = convertTokensToProvideLiquidity(_amount, _tokenFrom, _poolID);
        Pool memory pool = poolsArray[_poolID];

        if (
            IERC20(token).allowance(
                address(this),
                address(StargateRouter)
            ) < amount
        ) {
            IERC20(token).approve(
                address(StargateRouter),
                type(uint256).max
            );
        }
        uint256 amountLiquidity = pool.stargatePool.balanceOf(address(this));
           StargateRouter.addLiquidity(
                _poolID,
                _amount,
                address(this)
            );
        amountLPs = pool.stargatePool.balanceOf(address(this)) - amountLiquidity;
        return amountLPs;
    }

    function _harvest(uint256 _poolID) internal {
        _deposit(_poolID, 0);
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
        returns (
            address token,
            uint256 amount
        )
    {
        Pool memory pool = poolsArray[_poolID];
        token = address(pool.token);

        if (pool.LPToken.allowance(address(this), address(StargateRouter)) < _amount) {
            pool.LPToken.approve(address(StargateRouter), type(uint256).max);
        }
        (amount) = StargateRouter.instantRedeemLocal(uint16(pool.stargateID),
         _amount, 
         address(this)

        );
    }

    function withdraw(
        uint256 _amount,
        address _toToken,
        address _to,
        uint256 _poolID
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        Pool memory pool = poolsArray[_poolID];
        pool.stargate.withdraw(pool.stargateID, _amount);
        (
            address token,
            uint256 amount
        ) = removeLiquidity(_amount, _poolID);

        uint256 amountToken = 0;
        amountToken += token != _toToken ? _convertTokens(token, _toToken, amount, pool.feeUniswapPool) : amount;

        IERC20(_toToken).transfer(_to, amountToken);
        emit Withdraw(_amount);
    }

    function getAmountsTokensInLP(uint256 _pid)
        public
        view
        whenNotPaused
        returns (
            uint256 amount,
            address token
        )
    {
        Pool memory pool = poolsArray[_pid];
        token = address(pool.token);
        amount = pool.stargatePool.balanceOf(address(this));
    }

    function convertTokenToStablecoin(address _tokenAddress, uint256 _amount, uint24 _fee)
        public
        whenNotPaused
        returns (uint256 amountStable)
    {
        if (_tokenAddress == stablecoin)
            return _amount;
        return _previewConvertTokens(_tokenAddress, stablecoin, _amount, _fee);
    }

    function convertStablecoinToToken(address _tokenAddress, uint256 _amountStablecoin, uint24 _fee)
        internal
        returns (uint256 amountToken)
    {
        if (_tokenAddress == stablecoin)
            return _amountStablecoin;
        return _previewConvertTokens(stablecoin, _tokenAddress, _amountStablecoin, _fee);
    }

    function getBalanceOnFarms(uint256 _pid)
        public
        whenNotPaused
        returns (uint256 totalAmount)
    {
        (
            uint256 amount,
            address token
        ) = getAmountsTokensInLP(_pid); //convert amount lps to two token amounts
        Pool memory pool = poolsArray[_pid];
        totalAmount += convertTokenToStablecoin(token, amount, pool.feeUniswapPool); //convert token's price to stablecoin price
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
        IStargate stargate,
        IStargatePool stargatePool,
        IERC20 token,
        uint256 stargateID,
        uint24 _fee,
        bool stable
    ) external onlyRole(ADMIN_ROLE) whenNotPaused {
        poolsArray.push(
            Pool(
                LPToken,
                stargate,
                stargatePool,
                token,
                stargateID,
                _fee,
                stable
            )
        );
    }
}