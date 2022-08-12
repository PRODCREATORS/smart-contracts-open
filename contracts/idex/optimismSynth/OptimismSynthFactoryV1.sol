// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./OptimismSynthV1.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../../PausableAccessControl.sol";

/** @dev Contract that manages synth tokens */
contract OptimismSynthFactoryV1 is AccessControlEnumerable, PausableAccessControl {
    bytes32 public constant SYNT_HASH =
        keccak256(abi.encodePacked(type(OptimismSynthV1).creationCode));
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MINT_ROLE = keccak256("MINT");

    event CreatedSynth(address synth);

    mapping(uint256 => address) public getSynth;

    constructor() {
        _setRoleAdmin(MINT_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /** @dev Creates smart contract of SynthToken and sets specific `_pid`
     *
     * Requirements:
     * - `_pid` there must be an pid of the created token
     * - the caller must have ``role``'s admin role.
     */
    function createSynth(uint256 _pid)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused 
        returns (address synth)
    {
        bytes32 salt = keccak256(abi.encodePacked(_pid));
        bytes memory bytecode = abi.encodePacked(type(OptimismSynthV1).creationCode);
        assembly {
            synth := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        OptimismSynthV1(synth).initialize(_pid);
        //save somewhere
        getSynth[_pid] = address(synth);
        emit CreatedSynth(address(synth));
    }

    /** @dev Creates `_amount` of SynthTokens with a specific id and assigns them to `_to`, increasing
     * the total supply.
     *
     * Requirements:
     *
     * - `_to` cannot be the zero address.
     * - `_pid` must be an pid of the created token
     */
    function mint(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external onlyRole(MINT_ROLE) whenNotPaused {
        address synth = getSynth[_pid];
        require(synth != address(0), "No such synth");
        OptimismSynthV1(synth).mint(_to, _amount);
    }

    /**
     * @dev Destroys `_amount` tokens from `_from`, reducing the
     * total supply.
     *
     * Requirements:
     *
     * - `_from` cannot be the zero address.
     * - `_from` must have at least `amount` tokens.
     * - `_pid` must be an pid of the created token
     */
    function burn(
        uint256 _pid,
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_ROLE) whenNotPaused {
        address synth = getSynth[_pid];
        require(synth != address(0), "No such synth");
        OptimismSynthV1(synth).burn(_from, _amount);
    }

    /**
     * @dev Grants `MINT` to `_minter`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function addMinter(address _minter) external onlyRole(ADMIN_ROLE) whenNotPaused {
        grantRole(MINT_ROLE, _minter);
    }

    /**
     * @dev Revokes `MINT` role from `_minter`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function removeMinter(address _minter) external onlyRole(ADMIN_ROLE) whenNotPaused {
        revokeRole(MINT_ROLE, _minter);
    }

    /**
     * @dev Returns addresses that control mint role
     */
    function minters() external view whenNotPaused returns (address[] memory) {
        uint256 _mintersLength = getRoleMemberCount(MINT_ROLE);
        require(_mintersLength > 0, "No minters");
        address[] memory _minters = new address[](_mintersLength);
        for (uint256 i = 0; i < _mintersLength; i++) {
            _minters[i] = getRoleMember(MINT_ROLE, i);
        }
        return _minters;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _grantRole(bytes32 role, address account) internal virtual override(AccessControlEnumerable, AccessControl) {
        return super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account) internal virtual override(AccessControlEnumerable, AccessControl) {
        return super._revokeRole(role, account);
    }
}
