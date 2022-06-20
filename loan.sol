// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

contract SmartProxy is Ownable {
    using SafeMath for uint256;

    // SynthLP token
    IERC20 public SynthLp;
    // EnUSD token
    IERC20 public EnUSD;
    // Collateral rate
    uint256 public c_r;

    constructor(address synthlpAddress, address enusdAddress) {
        setSynthLp(synthlpAddress);
        setEnUSD(enusdAddress);
    }

    
    function lendMoney(uint256 synthlpAmount) public {
        uint256 synthLpBalance = SynthLp.balanceOf(msg.sender);
        uint256 enUSDBalance = EnUSD.balanceOf(address(this));

        require(synthlpAmount > 0, "Synthlp amount should be greater than 0");
        require(synthLpBalance >= synthlpAmount, "You have not enough SynthLp");

        uint256 allowance = SynthLp.allowance(msg.sender, address(this));
        require(allowance >= synthlpAmount, "Check allowance");

        SynthLp.transferFrom(msg.sender, address(this), synthlpAmount);

        uint256 lendEnUSDAmount = synthlpAmount.div(100).mul(c_r);
        require(lendEnUSDAmount <= enUSDBalance, "There is not enough EnUSD in contract");
        EnUSD.transfer(msg.sender, lendEnUSDAmount);
    }

    function returnMoney(uint256 enUSDAmount) public {
        uint256 synthLpBalance = SynthLp.balanceOf(address(this));
        uint256 enUSDBalance = EnUSD.balanceOf(msg.sender);

        require(enUSDAmount > 0, "EnUSD amount should be greater than 0");
        require(enUSDBalance >= enUSDAmount, "You have not enough SynthLp");

        uint256 allowance = EnUSD.allowance(msg.sender, address(this));
        require(allowance >= enUSDAmount, "Check allowance");

        EnUSD.transferFrom(msg.sender, address(this), enUSDAmount);

        uint256 returnSynthLpAmount = enUSDAmount.mul(100).div(c_r);
        require(returnSynthLpAmount <= synthLpBalance, "There is not enough EnUSD in contract");
        SynthLp.transfer(msg.sender, returnSynthLpAmount);
    }

    // Owner functions
    function setCollateralRate(uint256 _newRate) public onlyOwner {
        c_r = _newRate;
    }
    function _getLatestPrice(address pairAddress, uint amount ) public view returns (int256) {
     /* IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
      * IERC20 token1 = IERC20(pair.token1);
      *(uint Res0, uint Res1,) = pair.getReserves();
    
    // decimals
    * uint res0 = Res0*(10**token1.decimals());
    * return((amount*res0)/Res1);
     */
    }
    
    function getExchangeRate() public view returns (uint256) {
   // exchange rate 
    }
     function getBalance() public view returns (uint) {
        return  SynthLp.balanceOf(msg.sender);
    }

    function setSynthLp(address _newAddress) public onlyOwner {
        SynthLp = IERC20(_newAddress);
    }

    function setEnUSD(address _newAddress) public onlyOwner {
        EnUSD = IERC20(_newAddress);
    }
}
