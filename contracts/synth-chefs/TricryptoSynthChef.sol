// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity >=0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/thirdparty/ITricryptoPool.sol";
import "../interfaces/thirdparty/ILiquidityGaugeV3.sol";
import "./BaseSynthChef.sol";
import "hardhat/console.sol";

contract TricryptoSynthChef is BaseSynthChef {
  using SafeERC20 for IERC20;

  ITricryptoPool pool;
  ILiquidityGaugeV3 gauge;
  mapping(address => uint8) token2PoolIndex;
  uint8 N_TOKENS = 3;
  
  constructor(
    ITricryptoPool _pool,
    ILiquidityGaugeV3 _gauge,
    address _DEXWrapper,
    address _stablecoin,
    address[] memory _rewardTokens,
    uint256 _fee,
    address _feeCollector
  )
    BaseSynthChef(_DEXWrapper, _stablecoin, _rewardTokens, _fee, _feeCollector)
  {
    pool = _pool;
    gauge = _gauge;
    _SetupTokenIndices();
    _SetupAllowances();
    _SetupGaugeAllowance();
  }


  event ExpectLPs(uint256 amount);

  function lpToken() public view returns (address) { return pool.token(); }
  function getGauge() public view returns (ILiquidityGaugeV3) { return gauge; }

  function _depositToFarm(uint256 _pid, uint256 _amount) internal override { gauge.deposit(_amount);}

  function _harvest(uint256 _pid) internal override { gauge.claim_rewards(); }

  function _withdrawFromFarm(uint256 _pid, uint256 _amount) internal override { gauge.withdraw(_amount, true); }

  function getLPAmountOnFarm(uint256 _pid) public view override returns (uint256) { return gauge.balanceOf(address(this)); }

  function _SetupGaugeAllowance() internal { IERC20(lpToken()).safeIncreaseAllowance(address(gauge), type(uint256).max); }

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

    uint8 idx = token2PoolIndex[_tokenFrom];

    uint256[3] memory amounts = [uint(0), uint(0), uint(0)];
    amounts[idx] = _amount;

    uint256[3] memory xp = _getPoolBalances();
    uint256 fees = pool.calc_token_fee(amounts, xp);

    uint256 expected = pool.calc_token_amount(amounts, true); // This does not account for fees...

    pool.add_liquidity(amounts, expected); // Should we adjust our expectatins since it does not account for fees?
    // Emit the expected ammount of lp tokens to test is our assumptions correct
    emit ExpectLPs(expected - fees);
    return expected - fees;
  }

  function _removeLiquidity(uint256 _pid, uint256 _amount) internal override returns (TokenAmount[] memory) {

    TokenAmount[] memory tokenAmounts = new TokenAmount[](3);
    
    uint256[3] memory min_amounts = [uint(0), uint(0), uint(0)];
    uint256 totalSupply           = IERC20(lpToken()).totalSupply();
    
    address[3] memory tokens   = _getPoolTokens();
    uint256[3] memory balances = _getPoolBalances();

    for(uint8 i = 0; i < N_TOKENS; ++i) {
      min_amounts[i] = ((balances[i] * _amount) / totalSupply) - 1 ;
      tokenAmounts[i] = TokenAmount(min_amounts[i], tokens[i]);
    }

    pool.remove_liquidity(_amount, min_amounts);
    return tokenAmounts;
  }


  function _getTokensInLP(uint256 _pid) internal view override returns (TokenAmount[] memory) {
    TokenAmount[] memory tokens = new TokenAmount[](3);

    address[3] memory _tokens  = _getPoolTokens();
    uint256[3] memory reserves = _getPoolBalances();

    for(uint8 i = 0; i < N_TOKENS; ++i) {
      tokens[i] = TokenAmount({amount: reserves[i], token: _tokens[i]});
    }

    return tokens;
  }

  function _SetupTokenIndices() internal {
    for (uint8 i = 0; i < N_TOKENS; ++i) {
      address addr = pool.coins(i);
      token2PoolIndex[addr] = i;
    }
  }

  function _SetupAllowances() internal {
    for (uint8 i = 0; i < N_TOKENS; ++i) {
      address addr = pool.coins(i);
      IERC20(addr).safeIncreaseAllowance(address(pool), type(uint256).max);
    }
  }

  // I dont like hardcoded output len here...
  function _getPoolBalances() internal view returns (uint256[3] memory) {
    assert(N_TOKENS == 3); // Just to be safe
    uint256[3] memory balances;
    for (uint8 i = 0; i < N_TOKENS; ++i) {
      balances[i] = pool.balances(i);
    }
    return balances; 
  }

  function _getPoolTokens() internal view returns (address[3] memory) {
    assert(N_TOKENS == 3); // Just to be safe
    address[3] memory tokens;
    for (uint8 i = 0; i < N_TOKENS; ++i) {
      tokens[i] = pool.coins(i);
    }
    return tokens; 
  }

}
