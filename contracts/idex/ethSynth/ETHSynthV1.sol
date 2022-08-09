// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";

contract ETHSynthV1 is ERC20, Ownable {
    using PRBMathUD60x18 for uint256;

    address public factory;
    uint256 public pid;

    IERC20 public token1;
    IERC20 public token2;
    IERC20 public opToken;

    IUniswapV2Pair private pair;
    IUniswapV2Router01 private router;

    uint256 private token1InitialAmount;
    uint256 private token2InitialAmount;

    uint256 private totalSynthSupply;


    /**
     * @dev Sets the values for {factory}.
     */
    constructor(IERC20 _token1, IERC20 _token2, uint256 _token1InitialAmount, uint256 _token2InitialAmount, uint256 _totalSynthSupply, IUniswapV2Pair _pair, IUniswapV2Router01 _router, IERC20 _opToken) ERC20("ETHSynth", "SYNTH") {
        factory = msg.sender;
        token1 = _token1;
        token2 = _token2;
        token1InitialAmount = _token1InitialAmount;
        token2InitialAmount = _token2InitialAmount;
        totalSynthSupply = _totalSynthSupply;
        pair = _pair;
        router = _router;
        opToken = _opToken;
    }

    /**
     * @dev Returns the amounts of token1 and token2 which 1 Synth is representing at the moment
    */
    function getAmounts() public view returns(uint256 token1Amount, uint256 token2Amount) {
        (uint256 token1Reserves, uint256 token2Reserves,) = pair.getReserves();
        token2Amount = uint256((token1InitialAmount * token2InitialAmount * token2Reserves) / token1Reserves).sqrt();
        token1Amount = uint256((token1InitialAmount * token2InitialAmount * token1Reserves) / token2Reserves).sqrt();
    }
    
    function getPrice() public view returns(uint256 price) {
        (uint256 token1Amount, uint256 token2Amount,) = pair.getReserves();
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(opToken);
        price = router.getAmountsOut(token1Amount, path)[0];
        path = new address[](2);
        path[0] = address(token2);
        path[1] = address(opToken);
        price += router.getAmountsOut(token2Amount, path)[0];
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
