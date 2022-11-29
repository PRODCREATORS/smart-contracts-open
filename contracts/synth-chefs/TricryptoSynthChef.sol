// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/thirdparty/ITricryptoPool.sol";
import "../interfaces/thirdparty/ILiquidityGaugeV3.sol";
import "../interfaces/thirdparty/IConvexBooster.sol";
import "../interfaces/thirdparty/IBaseRewardPool.sol";
import "./BaseSynthChef.sol";
import "hardhat/console.sol";

contract TricryptoSynthChef is BaseSynthChef {
  using SafeERC20 for IERC20;
  
  /** Minter of lp token */
  ITricryptoPool m_LiqidityPool;
  IBaseRewardPool m_CrvRewards;
  ILiquidityGaugeV3 m_Gauge;
  IConvexBooster m_Booster;
  uint256 m_ConvexPoolId;
  /** Unknown */
  address m_Stash;
  IERC20 m_DepositToken;
  uint8 constant m_TokensCount = 3; 
  IERC20 m_LpToken;

  mapping(address => uint8) m_TokenToPoolIndex;

  constructor(
    IConvexBooster booster,
    uint256 poolId,
    IBaseRewardPool crvRewards,
    ILiquidityGaugeV3 gauge,
    ITricryptoPool lp,
    IERC20 lpToken,
    IERC20 depToken,
    address stash, 
    uint8 ntok,
    // Base
    address _DEXWrapper,
    address _stablecoin,
    address[] memory _rewardTokens,
    uint256 _fee,
    address _feeCollector
  )
    BaseSynthChef(_DEXWrapper, _stablecoin, _rewardTokens, _fee, _feeCollector)
  {
    m_Booster      = booster;
    m_ConvexPoolId = poolId;
    m_CrvRewards   = crvRewards;
    m_Gauge        = gauge;
    m_LiqidityPool = lp;
    m_LpToken      = lpToken;
    m_DepositToken = depToken;
    m_Stash        = stash;
    require(m_TokensCount == ntok);
    _init();
  }

  function _init() internal {
    //Setup index and allowances
    for (uint8 i = 0; i < m_TokensCount; ++i) {
      address addr = m_LiqidityPool.coins(i);
      m_TokenToPoolIndex[addr] = i;
      IERC20(addr).safeIncreaseAllowance(address(m_LiqidityPool), type(uint256).max);
    }
    m_LpToken.safeIncreaseAllowance(address(m_Booster), type(uint256).max);
  }

  event ExpectLPs(uint256 amount);


  function _depositToFarm(uint256 _pid, uint256 _amount) internal override { m_Booster.deposit(_pid, _amount, true);}

  function _harvest(uint256 _pid) internal override { m_CrvRewards.getReward(); }

  function _withdrawFromFarm(uint256 _pid, uint256 _amount) internal override { m_CrvRewards.withdrawAndUnwrap(_amount, false); }

  function getLPAmountOnFarm(uint256 _pid) public view override returns (uint256) { return m_CrvRewards.balanceOf(address(this)); }

  //function _SetupGaugeAllowance() internal { IERC20(getLpToken()).safeIncreaseAllowance(address(m_Gauge), type(uint256).max); }

  /**
   * NOTE: Currently only single pool is implemented;
   *       Instead of depoiting and combination of 3 tokens,
   *       our api basically allows adding only one token at a time; 
   *       maybe we should split input like: 
   *        -  Token From: 98%
   *        -  Rest: 2%
   * 
   *       Also returned amount of LP Tokens minted is not guranieeed
   *       to be correct, because `pool.add_liqidity` method does not
   *       return the ammmount of LP Tokens minted; We base our
   *       expectaions on the recived amount of LP Tokens from the 
   *       `pool.calc_token_amount` call which does not account for fees
   *       So... trying to be on the safe side we subtract the fees from 
   *       the result
   */
  function _addLiquidity(uint256 _pid, address _tokenFrom, uint256 _amount) internal override returns (uint256 LPAmount) {
    

    uint8 idx = m_TokenToPoolIndex[_tokenFrom];

    uint256[3] memory amounts = [uint(0), uint(0), uint(0)];
    amounts[idx] = _amount;

    uint256[3] memory xp = _getPoolBalances();
    uint256 fees = m_LiqidityPool.calc_token_fee(amounts, xp);

    uint256 expected = m_LiqidityPool.calc_token_amount(amounts, true); // This does not account for fees...

    m_LiqidityPool.add_liquidity(amounts, expected); // Should we adjust our expectatins since it does not account for fees?
    // Emit the expected ammount of lp tokens to test is our assumptions correct
    emit ExpectLPs(expected - fees);
    return expected - fees;
  }

  function _removeLiquidity(uint256 _pid, uint256 _amount) internal override returns (TokenAmount[] memory) {
    
    TokenAmount[] memory tokenAmounts = new TokenAmount[](3);
    
    uint256[3] memory min_amounts = [uint(0), uint(0), uint(0)];
    uint256 totalSupply           = m_LpToken.totalSupply();
    
    address[3] memory tokens   = _getPoolTokens();
    uint256[3] memory balances = _getPoolBalances();

    for(uint8 i = 0; i < m_TokensCount; ++i) {
      min_amounts[i] = ((balances[i] * _amount) / totalSupply) - 1 ;
      tokenAmounts[i] = TokenAmount(min_amounts[i], tokens[i]);
    }

    //m_Pool.remove_liquidity(_amount, min_amounts);
    return tokenAmounts;
  }


  function _getTokensInLP(uint256 _pid) internal view override returns (TokenAmount[] memory) {
    
    
    TokenAmount[] memory tokens = new TokenAmount[](3);

    address[3] memory _tokens  = _getPoolTokens();
    uint256[3] memory reserves = _getPoolBalances();

    for(uint8 i = 0; i < m_TokensCount; ++i) {
      tokens[i] = TokenAmount({amount: reserves[i], token: _tokens[i]});
    }

    return tokens;
  }

  function _getPoolBalances() internal view returns (uint256[m_TokensCount] memory balances) {
    for (uint8 i = 0; i < m_TokensCount; ++i) {
      balances[i] = m_LiqidityPool.balances(i);
    }
  }

  function _getPoolTokens() internal view returns (address[m_TokensCount] memory tokens) {
    for (uint8 i = 0; i < m_TokensCount; ++i) {
      tokens[i] = m_LiqidityPool.coins(i);
    }
  }
}
