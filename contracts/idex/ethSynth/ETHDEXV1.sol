// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../utils/ISynthChef.sol";
import "../../Lender.sol";
import "../../PausableAccessControl.sol";
import "../../utils/IERC20Extended.sol";

contract ETHDEXV1 is AccessControlEnumerable, PausableAccessControl, Lender {
    using SafeMath for uint256;

    IERC20Extended public opToken; //token which will be paid for synth and will be get after selling synth

    uint8 public rateDecimals; //rate decimals
    uint8 private opDecimals; //opToken decimals

    uint256 public fee;
    uint256 public feeRate = 1e3;
    address public feeCollector;
    address public chef; //synthChef
    address public factory; //synth factory

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    event Rebalancing(address token, uint256 amount);

    uint8 public farmPid;

    struct Synth {
        IERC20Extended synth;
        uint8 synthDecimals;
        uint256 rate; //how much synth for 1 opToken
        uint8 rateDecimals;
        uint8 pid;
        bool isActive;
        bool crosschain;
    }

    mapping(uint8 => Synth) public synths;

    /**
     * @dev Sets the values for `synth`, `opToken` and `rate`.
     */
    constructor(
        IERC20Extended _opToken,
        address _factory,
        address _chef,
        uint8 _farmPid,
        address _feeCollector
    ) {
        opToken = _opToken;
        opDecimals = _opToken.decimals(); //6

        _setRoleAdmin(ADMIN, OWNER);
        _setRoleAdmin(OWNER, OWNER);
        _setRoleAdmin(PAUSER_ROLE, ADMIN);
        _setRoleAdmin(BORROWER_ROLE, ADMIN);
        _setupRole(OWNER, msg.sender);

        chef = _chef;
        factory = _factory;

        farmPid = _farmPid;

        feeCollector = _feeCollector;
    }

    modifier isActive(uint8 _pid) {
        require(
            synths[_pid].isActive == true,
            "No such synth or it is disabled"
        );
        _;
    }

    modifier exist(uint8 _pid) {
        require(address(synths[_pid].synth) != address(0), "Doesn't exist");
        _;
    }

    function add(
        IERC20Extended _synth,
        uint256 _startRate,
        uint8 _pid,
        bool _crosschain
    ) external onlyRole(ADMIN) whenNotPaused {
        require(synths[_pid].isActive == false, "Already added");
        Synth memory newSynth = Synth({
            synth: _synth,
            synthDecimals: _synth.decimals(),
            rate: _startRate,
            rateDecimals: 18,
            pid: _pid,
            isActive: true,
            crosschain: _crosschain
        });
        synths[_pid] = newSynth;
    }

    /**
     * @notice Trade function to buy synth token.
     * @param _amount The amount of the source token being traded.
     *
     * Requirements:
     *
     * - the caller must have `BUYER` role.
     */
    function buy(uint8 _pid, uint256 _amount)
        external
        exist(_pid)
        isActive(_pid)
        whenNotPaused
        returns(uint256 synthAmount)
    {
        Synth memory synth = synths[_pid];
        uint256 fee_ = _amount.div(100).mul(1);
        synthAmount = _amount.mul(synth.rate).div(10**opDecimals);
        opToken.transferFrom(msg.sender, address(this), _amount);
        opToken.transfer(feeCollector, fee_);
        synth.synth.transfer(msg.sender, synthAmount);
    }

    /**
     * @notice Trade function to sell synth token.
     * @param _amount The amount of the source token being traded.
     * @param _pid pid of token
     * Requirements:
     *
     * - the caller must have `BUYER` role.
     *
     */
    function sell(uint8 _pid, uint256 _amount)
        external
        exist(_pid)
        isActive(_pid) 
        whenNotPaused 
        returns (uint256 opTokenAmount)
    {
        //amount synth
        Synth memory synth = synths[_pid];
        uint256 fee_ = _amount.div(100).mul(1);
        opTokenAmount = _amount
            .mul(10**rateDecimals)
            .div(synth.rate)
            .div(10**(synth.synthDecimals - opDecimals));
        fee_ = opTokenAmount.div(100).mul(1);
        opTokenAmount = opTokenAmount - fee_;
        synth.synth.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        opToken.transfer(msg.sender, fee_);
        opToken.transfer(msg.sender, opTokenAmount);
    }

    /**
     * @dev function to set the price of tokens
     * @param _rate synth token price
     * @param _pid pid of token
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function changeRate(uint8 _pid, uint256 _rate)
        external
        onlyRole(ADMIN)
        exist(_pid)
        isActive(_pid)
        whenNotPaused
    {
        synths[_pid].rate = _rate;
    }

    /**
     * @dev function for withdrawing token for payment
     * @param _amount op token amount
     * @param to recipient's address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function withdrawOpTokens(uint256 _amount, address to) external onlyRole(ADMIN) whenNotPaused {
        require(
            opToken.balanceOf(address(this)) >= _amount,
            "Not enough opToken to withdraw"
        );
        opToken.transfer(to, _amount);
    }

    /**
     * @dev function for changing the token for payment
     * @param _opToken op token address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function changeOpToken(IERC20Extended _opToken) external onlyRole(ADMIN) whenNotPaused {
        require(address(_opToken) != address(0), "Invalid address");
        opToken = _opToken;
        opDecimals = _opToken.decimals();
    }

    /**
     * @dev Grants `ADMIN` to `_admin`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have `OWNER` role.
     *
     * May emit a {RoleGranted} event.
     */
    function addAdmin(address _admin) external onlyRole(OWNER) whenNotPaused {
        require(!hasRole(ADMIN, _admin), "already admin");
        grantRole(ADMIN, _admin);
    }

    /**
     * @dev Revokes `ADMIN` role from `_admin`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have `OWNER` role.
     *
     * May emit a {RoleGranted} event.
     */
    function removeAdmin(address _admin) external onlyRole(OWNER) whenNotPaused {
        revokeRole(ADMIN, _admin);
    }

    /**
     * @dev Returns addresses that control `ADMIN` role
     */
    function admins() external view returns (address[] memory) {
        uint256 _adminsLength = getRoleMemberCount(ADMIN);
        require(_adminsLength > 0, "No admins");
        address[] memory _admins = new address[](_adminsLength);
        for (uint256 i = 0; i < _adminsLength; i++) {
            _admins[i] = getRoleMember(ADMIN, i);
        }
        return _admins;
    }

    /**
     * @dev function for setting fee
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function changeFee(uint256 _fee, uint256 _feeRate) external onlyRole(ADMIN) whenNotPaused {
        fee = _fee;
        feeRate = _feeRate;
    }

    /**
     * @dev function for stopping token acceptance
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function pauseSynth(uint8 _pid) external exist(_pid) whenNotPaused {
        synths[_pid].isActive = !synths[_pid].isActive;
    }

    /**
     * @dev function to set Synth Chef address
     * @param _chef SynthChef address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setChef(address _chef) external onlyRole(ADMIN) whenNotPaused {
        chef = _chef;
    }

    /**
     * @dev function to set Synth Factory address
     * @param _factory SynthFactory address
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function setFactory(address _factory) external onlyRole(ADMIN) whenNotPaused {
        factory = _factory;
    }

    function getSynthBalance(uint8 _pid) public view whenNotPaused returns (uint256) {
        Synth memory synth = synths[_pid];
        uint256 balance = synth.synth.balanceOf(address(this));
        return balance;
    }

    function getOpTokenBalance() public view whenNotPaused returns (uint256) {
        uint256 balance = opToken.balanceOf(address(this));
        return balance;
    }

    //Give Admin Role to IDEX at first
    function checkRebalancingSynth(uint8 _pid, uint256 _amount)
        internal
        view
        onlyRole(ADMIN)
        whenNotPaused
        returns (bool)
    {
        return getSynthBalance(_pid) < _amount;
    }

    function checkOpRebalancing(uint256 _amount)
        internal
        view
        onlyRole(ADMIN)
        whenNotPaused
        returns (bool)
    {
        return getOpTokenBalance() < _amount;
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
