// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
     function _getLatestPrice() public view returns (int256) {
  // price of synthlp with oracle
    }
    
    function getExchangeRate() public view returns (uint256) {
   // exchange rate 
    }

    function setSynthLp(address _newAddress) public onlyOwner {
        SynthLp = IERC20(_newAddress);
    }

    function setEnUSD(address _newAddress) public onlyOwner {
        EnUSD = IERC20(_newAddress);
    }
}
