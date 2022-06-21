// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SilentLoan is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    // SynthLP token
    IERC20 public SynthLp;
    // EnUSD token
    IERC20 public EnUSD;
    // Collateral rate
    uint256 public c_r;

    // Account -> Token -> Amount
    mapping(address => uint256) public s_accountToSynthlpDeposits;
    // Account -> Token -> Amount
    mapping(address => uint256) public s_accountToEnusdBorrows;

    constructor(address _synthlpAddress, address _enusdAddress, uint256 _collateralRate) {
        c_r = _collateralRate;
        SynthLp = IERC20(_synthlpAddress);
        EnUSD = IERC20(_enusdAddress);
    }

    function deposit(uint256 amount)
        external
        nonReentrant
        moreThanZero(amount)
    {
        s_accountToSynthlpDeposits[msg.sender] += amount;
        SynthLp.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external nonReentrant moreThanZero(amount) {
        _pullFunds(msg.sender, amount);
    }

    function _pullFunds(
        address account,
        uint256 amount
    ) private {
        require(s_accountToSynthlpDeposits[account] >= amount, "Not enough funds to withdraw");
        s_accountToSynthlpDeposits[account] -= amount;
        SynthLp.transfer(msg.sender, amount);
    }

    function borrow(uint256 amount)
        external
        nonReentrant
        moreThanZero(amount)
    {
        require(EnUSD.balanceOf(address(this)) >= amount, "Not enough tokens to borrow");
        require(s_accountToSynthlpDeposits[msg.sender] > amount.div(c_r).mul(100), "Amount is exceeds the ltv");
        s_accountToEnusdBorrows[msg.sender] += amount;
    }


    function repay(uint256 amount)
        external
        nonReentrant
        moreThanZero(amount)
    {
        _repay(msg.sender, amount);
    }

    function _repay(
        address account,
        uint256 amount
    ) private {
        s_accountToEnusdBorrows[account] -= amount;
        EnUSD.transferFrom(msg.sender, address(this), amount);
        SynthLp.transfer(msg.sender, amount.mul(c_r).div(100));

    }


    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount should be bigger than zero");
        _;
    }

    // Owner functions
     function setCollateralRate(uint256 _newRate) external onlyOwner {
        c_r = _newRate;
    }

    function setSynthLp(address _newAddress) external onlyOwner {
        SynthLp = IERC20(_newAddress);
    }

    function setEnUSD(address _newAddress) external onlyOwner {
        EnUSD = IERC20(_newAddress);
    }

    function getAccountToDepositAmount(address _account) public view returns(uint256) {
        return s_accountToSynthlpDeposits[_account];
    }

    function getAccountToBorrowAmount(address _account) public view returns(uint256) {
        return s_accountToEnusdBorrows[_account];
    }

}
