// SPDX-License-Identifier: GPL-2
pragma solidity >=0.8.9;

import "../../Lender.sol";
import "../../PausableAccessControl.sol";
import "../interfaces/IEntangleDEXWrapper.sol";

contract BaseSynthChef is PausableAccessControl, Lender {
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

    function _convertTokens(address from, address to, uint256 amount, uint24 _fee) internal returns(uint256) {
        if (IERC20(from).allowance(address(this), address(DEXWrapper)) < amount) {
            IERC20(from).approve(address(DEXWrapper), type(uint256).max);
        }
        return DEXWrapper.convert(from, to, amount, _fee);
    }

    function _previewConvertTokens(address from, address to, uint256 amount, uint24 _fee) internal returns(uint256) {
        return DEXWrapper.previewConvert(from, to, amount, _fee);
    }
}