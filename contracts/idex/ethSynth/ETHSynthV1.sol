// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ETHSynthV1 is ERC20, Ownable {
    address public factory;
    uint256 public pid;

    /**
     * @dev Sets the values for {factory}.
     */
    constructor() ERC20("ETHSynth", "SYNTH") {
        factory = msg.sender;
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
