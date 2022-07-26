// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./ETHSynthV1.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/** @dev Contract that manages synth tokens */
contract ETHSynthFactoryV1 is AccessControlEnumerable {
    bytes32 public constant SYNT_HASH =
        keccak256(abi.encodePacked(type(ETHSynthV1).creationCode));
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant MINT_ROLE = keccak256("MINT");

    event CreatedSynth(address synth);

    mapping(uint256 => address) public getSynth;

    constructor() {
        _setRoleAdmin(MINT_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    /** @dev Creates smart conract of SynthToken and sets specific `_pid`
     *
     * Requirements:
     * - `_pid` there must be an pid of the created token
     * - the caller must have ``role``'s admin role.
     */
    function createSynth(uint256 _pid)
        external
        onlyRole(ADMIN_ROLE)
        returns (address synth)
    {
        bytes32 salt = keccak256(abi.encodePacked(_pid));
        bytes memory bytecode = abi.encodePacked(type(ETHSynthV1).creationCode);
        assembly {
            synth := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ETHSynthV1(synth).initialize(_pid);
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
    ) external onlyRole(MINT_ROLE) {
        address synth = getSynth[_pid];
        require(synth != address(0), "No such synth");
        ETHSynthV1(synth).mint(_to, _amount);
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
    ) external onlyRole(MINT_ROLE) {
        address synth = getSynth[_pid];
        require(synth != address(0), "No such synth");
        ETHSynthV1(synth).burn(_from, _amount);
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
    function addMinter(address _minter) external onlyRole(ADMIN_ROLE) {
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
    function removeMinter(address _minter) external onlyRole(ADMIN_ROLE) {
        revokeRole(MINT_ROLE, _minter);
    }

    /**
     * @dev Returns addresses that control mint role
     */
    function minters() external view returns (address[] memory) {
        uint256 _mintersLength = getRoleMemberCount(MINT_ROLE);
        require(_mintersLength > 0, "No minters");
        address[] memory _minters = new address[](_mintersLength);
        for (uint256 i = 0; i < _mintersLength; i++) {
            _minters[i] = getRoleMember(MINT_ROLE, i);
        }
        return _minters;
    }
}
