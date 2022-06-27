pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IWitnetPriceFeed.sol";    
// import "hardhat/console.sol";

error TransferFailed();
error TokenNotAllowed(address token);
error NeedsMoreThanZero();

contract Lending is ReentrancyGuard, Ownable {
    mapping(address => address) public PriceFeedAddress;
    mapping(address => int256) public lastValue;

    // Account -> Token -> Amount
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
   
    uint256 public constant LIQUIDATION_FEE=5;
  
    uint256 public constant LIQUIDATION_THRESHOLD = 90;
    uint256 public constant MINIMUM_HEALH_FACTOR = 1e16;

    event AllowedTokenSet(address indexed token, address indexed priceFeed);
    event Deposit(address indexed account, address indexed token, uint256 indexed amount);
    event Borrow(address indexed account, address indexed token, uint256 indexed amount);
    event Withdraw(address indexed account, address indexed token, uint256 indexed amount);
    event Repay(address indexed account, address indexed token, uint256 indexed amount);
    event Liquidate(
        address indexed account,
        address indexed repayToken,
        address indexed rewardToken,
        uint256 DebtInEnUSD,
        address liquidator
    );      

    function deposit(address token, uint256 amount)
        external
        nonReentrant
        isAllowedToken(token)
        moreThanZero(amount)
    {
        emit Deposit(msg.sender, token, amount);
        s_accountToSynthlpDeposits[msg.sender] += amount;
        SynthLp.transferFrom(msg.sender, address(this), amount);
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function withdraw(address token, uint256 amount) external nonReentrant moreThanZero(amount) {
        require(s_accountToTokenDeposits[msg.sender][token] >= amount, "Not enough funds");
        emit Withdraw(msg.sender, token, amount);
        _pullFunds(msg.sender, token, amount);
        require(healthFactor(msg.sender) >= MIN_HEALH_FACTOR, "Unable to withdraw due to Health Factor ");
    }
   
    function _pullFunds(
        address account,
        address token,
        uint256 amount
    ) private {
        require(s_accountToTokenDeposits[account][token] >= amount, "Not enough funds to withdraw");
        s_accountToTokenDeposits[account][token] -= amount;
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    function borrow(address token, uint256 amount)
        external
        nonReentrant
        isAllowedToken(token)
        moreThanZero(amount)
    {
        require(EnUSD.balanceOf(address(this)) >= amount, "Not enough tokens to borrow");
        emit Borrow(msg.sender, token, amount);
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
        require(healthFactor(msg.sender) >= MIN_HEALH_FACTOR, "Platform will go insolvent!");
    }

    function liquidate(
        address account,
        address repayToken
    ) external nonReentrant {
        require(healthFactor(account) < MIN_HEALH_FACTOR, "Account can't be liquidated!");
        uint256 liquidationAmount = s_accountToTokenBorrows[account] - liquidationFee - annumFee;
        uint256 passedTime = s_accountBorrowTime[account].div(60).div(60).div(24);
        uint256 annumFee = s_accountToEnusdBorrows[account].mul(INTEREST_RATE).div(100).mul(passedTime).div(365);
        require(DebtInUSD > 0, "Choose a different repayToken!");

        emit Liquidate(account, lquidationAmount, msg.sender);
        _repay(account, liquidationAmount);
        _pullFunds(account,liquidationAmount);
    }

    function repay(address token, uint256 amount)
        external
        nonReentrant
        isAllowedToken(token)
        moreThanZero(amount)
    {
        emit Repay(msg.sender, token, amount);
        _repay(msg.sender, token, amount);
    }

    function _repay(
        address account,
        address token,
        uint256 amount
    ) private {
        EnUSD.transferFrom(msg.sender, address(this), amount);
        SynthLp.transfer(msg.sender, amount.mul(c_r).div(100));
         if (s_accountToEnusdBorrows[msg.sender] == 0) {
            s_accountBorrowTime[msg.sender] = 0;
        }
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 borrowedValueInEnUSD, uint256 collateralValueInUSD)
    {
        borrowedValueInEnUSD = getAccountBorrowedValue(user);
        collateralValueInEnUSD = getAccountCollateralValue(user);
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 totalCollateralValueInUSD = 0;
        for (uint256 index = 0; index < s_allowedTokens.length; index++) {
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenDeposits[user][token];
            uint256 valueInEnUSD = getEnUSDValue(token, amount);
            totalCollateralValueInEnUSD += valueInEnUSD;
        }
        return totalCollateralValueInUSD;
    }

    function getAccountBorrowedValue(address user) public view returns (uint256) {
        uint256 totalBorrowsValueInUSD = 0;
        for (uint256 index = 0; index < s_allowedTokens.length; index++) {
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenBorrows[user][token];
            uint256 valueInEnUSD = getEnUSDValue(token, amount);
            totalBorrowsValueInEnUSD += valueInEnUSD;
        }
        return totalBorrowsValueInEnUSD;
    }
     
    function getEnUSDValue(address token, uint256 amount) public view returns (uint256) {
        IWitnetPriceFeed PriceFeed;
        address pair = PriceFeedAddress[token];
        int256 _lastPrice;
        PriceFeed = IWitnetPriceFeed(pair);
        _lastPrice = PriceFeed.lastPrice();
        return (uint256(_lastPrice) * amount) / 1e18;
    }

    function getTokenValueFromEnUSD(address token, uint256 amountinusd) public view returns (uint256) {
        IWitnetPriceFeed PriceFeed;
        address pair = PriceFeedAddress[token];
        int256 price;
        PriceFeed = IWitnetPriceFeed(pair);
        price = PriceFeed.lastPrice();
        return (amountinusd * 1e18) / (uint256(price)/1e6);
    }
    
    

    function healthFactor(address account) public view returns (uint256) {
        (uint256 borrowedValueInEnUSD, uint256 collateralValueEnInUSD) = getAccountInformation(account);
        uint256 collateralAdjustedForThreshold = (collateralValueInEnUSD * LIQUIDATION_THRESHOLD) /
          borrowedValueInEnUSD;
        if (borrowedValueInEnUSD == 0) return 100e18;
        return collateralAdjustedForThreshold;
    }

      modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount should be bigger than zero");
        _;
    }
}
