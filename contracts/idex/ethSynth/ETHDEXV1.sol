// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ETHSynthFactoryV1.sol";
import "../utils/ISynthChef.sol";

contract ETHDEXV1 is AccessControlEnumerable {
    using SafeMath for uint256;

    address public opToken; //token which will be paid for synth and will be get after selling synth

    uint8 public rateDecimals; //rate decimals
    uint8 private opDecimals; //opToken decimals

    uint256 public fee;
    uint256 public feeRate = 1e3;

    address public chef; //synthChef
    address public factory; //synth factory

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    event Rebalancing(address token, uint256 amount);

    uint8 public farmPid;

    struct Synth {
        address synth;
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
        address _opToken,
        address _factory,
        address _chef,
        uint8 _farmPid
    ) {
        opToken = _opToken;
        opDecimals = ERC20(_opToken).decimals(); //6

        _setRoleAdmin(ADMIN, OWNER);
        _setupRole(OWNER, msg.sender);

        chef = _chef;
        factory = _factory;

        farmPid = _farmPid;
    }

    modifier isActive(uint8 _pid) {
        require(
            synths[_pid].isActive == true,
            "No such synth or it is disabled"
        );
        _;
    }

    modifier exist(uint8 _pid) {
        require(synths[_pid].synth != address(0), "Doesn't exist");
        _;
    }

    function add(
        address _synth,
        uint256 _startRate,
        uint8 _pid,
        bool _crosschain
    ) public onlyRole(ADMIN) {
        require(synths[_pid].isActive == false, "Already added");
        Synth memory newSynth = Synth({
            synth: _synth,
            synthDecimals: ERC20(_synth).decimals(),
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
        public
        exist(_pid)
        isActive(_pid)
    {
        //amount op
        Synth memory synthStruct = synths[_pid];
        if (CheckRebalancingSynth(_pid, _amount) == false) {
            uint256 amountSynth = _amount.mul(synthStruct.rate).div(
                10**opDecimals
            );
            IERC20(opToken).transferFrom(msg.sender, address(this), _amount);
            IERC20(synthStruct.synth).transfer(msg.sender, amountSynth);
        } else {
            emit Rebalancing(synthStruct.synth, _amount);
        }
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
function sell(uint8 _pid, uint256 _amount) public exist(_pid) isActive(_pid) {
    //amount synth
    Synth memory synthStruct = synths[_pid];
    uint256 amountOpToken = _amount
        .mul(10**rateDecimals)
        .div(synthStruct.rate)
        .div(10**(synthStruct.synthDecimals - opDecimals));
    if (CheckOPRebalancing(amountOpToken) == false ) {
    IERC20(synthStruct.synth).transferFrom(msg.sender, address(this), _amount);
    IERC20(opToken).transfer(msg.sender, amountOpToken);}
    else {
        emit Rebalancing(opToken, amountOpToken);
    }
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
    public
    onlyRole(ADMIN)
    exist(_pid)
    isActive(_pid)
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
function withdrawOp(uint256 _amount, address to) public onlyRole(ADMIN) {
    require(
        IERC20(opToken).balanceOf(address(this)) >= _amount,
        "Not enough opToken to withdraw"
    );
    IERC20(opToken).transfer(to, _amount);
}

/**
 * @dev function for changing the token for payment
 * @param _token op token address
 *
 * Requirements:
 *
 * - the caller must have admin role.
 */
function changeOpToken(address _token) public onlyRole(ADMIN) {
    require(_token != address(0), "Invalid address");
    opToken = _token;
    opDecimals = ERC20(_token).decimals();
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
function addAdmin(address _admin) public onlyRole(OWNER) {
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
function removeAdmin(address _admin) public onlyRole(OWNER) {
    revokeRole(ADMIN, _admin);
}

/**
 * @dev Returns addresses that control `ADMIN` role
 */
function admins() public view returns (address[] memory) {
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
function changeFee(uint256 _fee, uint256 _feeRate) public onlyRole(ADMIN) {
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
function pause(uint8 _pid) public exist(_pid) {
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
function setChef(address _chef) public onlyRole(ADMIN) {
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
function setFactory(address _factory) public onlyRole(ADMIN) {
    factory = _factory;
}

function getSynthBalance(uint8 _pid) public view returns (uint256) {
    Synth memory synthStruct = synths[_pid];
    uint256 Balance = IERC20(synthStruct.synth).balanceOf(address(this));
    return Balance;
}

function getOPBalance() public view returns (uint256) {
    uint256 Balance = IERC20(opToken).balanceOf(address(this));
    return Balance;
}

//Give Admin Role to IDEX at first
function CheckRebalancingSynth(uint8 _pid, uint256 _amount)
    internal
    onlyRole(ADMIN)
    returns (bool)
{
    if (getSynthBalance(_pid) < _amount) {
        return true;
    } else {
        return false;
    }
}

function CheckOPRebalancing(uint256 _amount)
    internal
    onlyRole(ADMIN)
    returns (bool)
{
    if (getOPBalance() < _amount) {
        return true;
    } else {
        return false;
    }
}
}