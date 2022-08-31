// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../Lender.sol";
import "../PausableAccessControl.sol";
import "../interfaces/IEntangleDEXWrapper.sol";

abstract contract BaseSynthChef is PausableAccessControl, Lender {
    IEntangleDEXWrapper public DEXWrapper;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    constructor(address _DEXWrapper) {
        DEXWrapper = IEntangleDEXWrapper(_DEXWrapper);

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(OWNER_ROLE, msg.sender);
    }

    function _convertTokens(address from, address to, uint256 amount) internal returns(uint256) {
        if (IERC20(from).allowance(address(this), address(DEXWrapper)) < amount) {
            IERC20(from).approve(address(DEXWrapper), type(uint256).max);
        }
        return DEXWrapper.convert(from, to, amount);
    }

    function _previewConvertTokens(address from, address to, uint256 amount) internal view returns(uint256) {
        return DEXWrapper.previewConvert(from, to, amount);
    }

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) public virtual;

    function withdraw(
        uint256 _amount,
        address _toToken,
        address _to,
        uint256 _poolID
    ) public virtual;
}