// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./EntangleSynth.sol";
import "./PausableAccessControl.sol";

/** @dev Contract that manages synth tokens */
contract EntangleSynthFactory is PausableAccessControl {

    bytes32 public constant SYNT_HASH =
        keccak256(abi.encodePacked(type(EntangleSynth).creationCode));

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
        bytes memory bytecode = abi.encodePacked(type(EntangleSynth).creationCode);
        assembly {
            synth := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        EntangleSynth(synth).initialize(_pid);
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
        EntangleSynth(synth).mint(_to, _amount);
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
        EntangleSynth(synth).burn(_from, _amount);
    }
}
