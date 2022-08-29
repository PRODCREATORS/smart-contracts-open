// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";
import "./interfaces/IEntangleDEXWrapper.sol";

contract EntangleSynth is ERC20, Ownable {
    using PRBMathUD60x18 for uint256;

    address public factory;
    uint256 public pid;

    IERC20 public token1;
    IERC20 public token2;
    IERC20 public opToken;

    IUniswapV2Pair private pair;
    IUniswapV2Router01 private router;

    uint256 private token1AmountIn;
    uint256 private token2AmountIn;

    uint256 private totalLPSupply; // multiplied by 10**18
    uint256 private totalSynthSupply;

    IEntangleDEXWrapper public DEXWrapper;

    /**
     * @dev Sets the values for {factory}.
     */
    constructor(
        IERC20 _token1,
        IERC20 _token2,
        uint256 _token1AmountIn,
        uint256 _token2AmountIn,
        uint256 _totalSynthSupply,
        uint256 _totalLPSupply,
        IUniswapV2Pair _pair,
        IUniswapV2Router01 _router,
        IERC20 _opToken,
        IEntangleDEXWrapper _DEXWrapper
    ) ERC20("ETHSynth", "SYNTH") {
        factory = msg.sender;
        token1 = _token1;
        token2 = _token2;
        token1AmountIn = _token1AmountIn;
        token2AmountIn = _token2AmountIn;
        totalSynthSupply = _totalSynthSupply;
        totalLPSupply = _totalLPSupply;
        pair = _pair;
        router = _router;
        opToken = _opToken;
        DEXWrapper = _DEXWrapper;
    }

    /**
     * @dev Returns the amounts of token1 and token2 which are right now on the farm behind this Synth
     */
    function getAmounts()
        public
        view
        returns (uint256 token1Amount, uint256 token2Amount)
    {
        token1Amount = uint256(
            (token1AmountIn * DEXWrapper.previewConvert(address(token2), address(token1), token2AmountIn))
        ).sqrt();
        token2Amount = uint256(
            (token2AmountIn * DEXWrapper.previewConvert(address(token1), address(token2), token1AmountIn))
        ).sqrt();
    }

    function getPriceFor1LP() public view returns (uint256 price) {
        (uint256 token1Amount, uint256 token2Amount) = getAmounts();
        price = DEXWrapper.previewConvert(address(token1), address(opToken), token1Amount);
        price += DEXWrapper.previewConvert(address(token2), address(opToken), token2Amount);
    }

    function convertSynthAmountToOpAmount(uint256 synthAmount) public view returns (uint256 opAmount) {
        uint256 price = getPriceFor1LP();
        opAmount = price * totalLPSupply * synthAmount;
        opAmount /= totalSynthSupply * 10**18;
    }

    function convertOpAmountToSynthAmount(uint256 opAmount) public view returns (uint256 synthAmount) {
        uint256 price = getPriceFor1LP();
        synthAmount = opAmount * totalSynthSupply * (10**18);
        synthAmount /= price * totalLPSupply;
    }

    /**
     * @dev This function should be called when we add liquidity
     */
    function addSupply(uint256 _addedLPSupply, uint256 _addedSynthSupply)
        external
        onlyOwner
    {
        totalLPSupply += _addedLPSupply;
        totalSynthSupply += _addedSynthSupply;
    }

    /**
     * @dev Sets the value for {pid}.
     */
    function initialize(uint256 _pid) external onlyOwner {
        require(pid == 0, "Already initialized");
        pid = _pid;
    }

    /** @dev Creates `_amount` SynthTokens and assigns them to `_to`, increasing
     * the total supply.
     *
     * Requirements:
     *
     * - `_to` cannot be the zero address.
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /**
     * @dev Destroys `_amount` tokens from `_from`, reducing the
     * total supply.
     *
     * Requirements:
     *
     * - `_from` cannot be the zero address.
     * - `_from` must have at least `amount` tokens.
     */
    function burn(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }
}