// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Liquidation is Ownable {
    using SafeMath for uint256;

    // SynthLP token
    IERC20 public SynthLp;
    // Collateral token
    IERC20 public Token;
    // Swap rate
    uint256 public s_r;

    address borrowerAddress;

    constructor(address _synthlpAddress, address _tokenAddress, address _borrowerAddress, uint256 _swapRate) {
        setSwapRate(_swapRate);
        setBorrowerAddress(_borrowerAddress);
        setSynthLp(_synthlpAddress);
        setToken(_tokenAddress);

    }

    function swapTokenToSynthlp(uint256 amount) external {
        require(msg.sender == borrowerAddress, "You are not the borrower");
        uint256 synthLpBalance = SynthLp.balanceOf(address(this));
        uint256 tokenBalance = Token.balanceOf(msg.sender);

        require(amount > 0, "Token amount should be greater than 0");
        require(tokenBalance >= amount, "You have not enough token");

        Token.transferFrom(msg.sender, address(this), amount);

        uint256 returnSynthLpAmount = amount.div(100).mul(s_r);
        require(returnSynthLpAmount <= synthLpBalance, "There is not enough Synthlp in contract");
        SynthLp.transfer(msg.sender, returnSynthLpAmount);
    }

    function swapSynthlpToToken(uint256 amount) external {
        require(msg.sender == borrowerAddress, "You are not the borrower");
        uint256 tokenBalance = Token.balanceOf(address(this));
        uint256 synthLpBalance = SynthLp.balanceOf(msg.sender);

        require(amount > 0, "SynthLp amount should be greater than 0");
        require(synthLpBalance >= amount, "You have not enough SynthLp");

        SynthLp.transferFrom(msg.sender, address(this), amount);

        uint256 returnTokenAmount = amount.mul(100).div(s_r);
        require(returnTokenAmount <= tokenBalance, "There is not enough token in contract");
        Token.transfer(msg.sender, returnTokenAmount);
    }

    // Owner functions
     function setSwapRate(uint256 _newRate) public onlyOwner {
        s_r = _newRate;
    }

    function setSynthLp(address _newAddress) public onlyOwner {
        SynthLp = IERC20(_newAddress);
    }

    function setToken(address _newAddress) public onlyOwner {
        Token = IERC20(_newAddress);
    }

    function setBorrowerAddress(address _borrowerAddress) public onlyOwner {
        borrowerAddress = _borrowerAddress;
    }
}
