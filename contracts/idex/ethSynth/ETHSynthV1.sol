// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract ETHSynthV1 is ERC20, Ownable {
    address public factory;
    uint256 public pid;

    IERC20 public token1;
    IERC20 public token2;

    IUniswapV2Pair private pair;

    uint256 private token1InitialAmount;
    uint256 private token2InitialAmount;


    /**
     * @dev Sets the values for {factory}.
     */
    constructor(IERC20 _token1, IERC20 _token2, uint256 _token1InitialAmount, uint256 _token2InitialAmount, IUniswapV2Pair _pair) ERC20("ETHSynth", "SYNTH") {
        factory = msg.sender;
        token1 = _token1;
        token2 = _token2;
        token1InitialAmount = _token1InitialAmount;
        token2InitialAmount = _token2InitialAmount;
        pair = _pair;
    }

    /**
     * @dev Returns the amounts of token1 and token2 which 1 Synth is representing at the moment
    */
    function getAmounts() public view returns(uint256 token1Amount, uint256 token2Amount) {
        (uint256 token1Reserves, uint256 token2Reserves,) = pair.getReserves();
        uint256 precision = 10 ** 10;
        uint256 price = (token1Reserves * precision) / token2Reserves; // current price (multiplied by precision)
        uint256 initialPrice = (token1InitialAmount * precision) / token2InitialAmount;
        uint256 left;
        uint256 right;
        uint256 mid;
        uint256 t1;
        uint256 t2;
        uint256 p;
        if (initialPrice < price) {
            left = 0;
            right = token2InitialAmount;
            while (right - left > 1) {
                mid = (right + left) / 2;
                t2 = token2InitialAmount - mid;
                t1 = (token1InitialAmount * token2InitialAmount) / t2;
                p = (t1 * precision) / t2;
                if (p < price) {
                    left = mid;
                }
                else {
                    right = mid;
                }
            }
            token1Amount = t1;
            token2Amount = t2;
        } else {
            left = 0;
            right = token1InitialAmount;
            while (right - left > 1) {
                mid = (right + left) / 2;
                t1 = token1InitialAmount - mid;
                t2 = (token1InitialAmount * token2InitialAmount) / t1;
                p = (t1 * precision) / t2;
                if (p < price) {
                    right = mid;
                }
                else {
                    left = mid;
                }
            }
            token1Amount = t1;
            token2Amount = t2;
        }
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
