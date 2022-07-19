//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

interface IERC20 {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;

}


contract Factory is AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MINT_ROLE = keccak256("MINT");
    IERC20 public token;

    constructor(address _tokenAddress) {
        _setRoleAdmin(MINT_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        token = IERC20(_tokenAddress);
    }

    event Mint(address _wallet, uint amount);
    event Burn(address _wallet, uint amount);

    function mint(address _wallet, uint256 amount) external onlyRole(MINT_ROLE) {
        token.mint(_wallet, amount);
        emit Mint(_wallet, amount);
    }

    function burn(address _wallet, uint256 amount) external onlyRole(MINT_ROLE) {
        token.burn(_wallet, amount);
        emit Burn(_wallet, amount);
    }

    function addMinter(address _minter) external onlyRole(ADMIN_ROLE) {
        grantRole(MINT_ROLE, _minter);
    }
}