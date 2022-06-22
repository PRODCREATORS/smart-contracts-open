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

    // Account -> Amount
    mapping(address => uint256) public s_accountToSynthlpDeposits;
    // Account ->  Amount
    mapping(address => uint256) public s_accountToEnusdBorrows;
    // Account ->  Time
    mapping(address => uint256) public s_accountBorrowTime;

    uint256 public constant LIQUIDATION_FEE = 5;
    uint256 public constant INTEREST_RATE = 3;

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
        s_accountBorrowTime[msg.sender] = block.timestamp;
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
        if (s_accountToEnusdBorrows[account] == 0) {
            s_accountBorrowTime[msg.sender] = 0;
        }
    }

    function liquidate(address account) external nonReentrant {
        uint256 borrowAmount = getAccountToBorrowAmount(account);
        uint256 depositAmount = getAccountToDepositAmount(account);

        require(borrowAmount <= depositAmount.mul(c_r).div(100));

        uint256 liquidationFee = s_accountToEnusdBorrows[account].mul(LIQUIDATION_FEE).div(100);
        uint256 passedTime = s_accountBorrowTime[account].div(60).div(60).div(24);
        uint256 annumFee = s_accountToEnusdBorrows[account].mul(INTEREST_RATE).div(100).mul(passedTime).div(365);
        uint256 liquidationAmount = borrowAmount - liquidationFee - annumFee;
        _repay(account, liquidationAmount);
        _pullFunds(account, liquidationAmount);
    }


    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount should be bigger than zero");
        _;
    }

    // Owner functions
   
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
