// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "./Lender.sol";
import "./PausableAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISynthV1 is IERC20Metadata {
    function convertSynthToOp(uint256 synthAmount) external view returns (uint256 opAmount);
    function convertOpToSynth(uint256 opAmount) external view returns (uint256 synthAmount);
}

contract EntangleDEX is PausableAccessControl, Lender {
    IERC20Metadata public opToken; //token which will be paid for synth and will be get after selling synth

    uint256 public fee;
    uint256 public feeRate = 1e3;
    address public feeCollector;

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    event Rebalancing(address token, uint256 amount);

    struct Synth {
        ISynthV1 synth;
        uint8 pid;
        bool isActive;
    }

    mapping(uint8 => Synth) public synths;

    /**
     * @dev Sets the values for `synth`, `opToken` and `rate`.
     */
    constructor(
        IERC20Metadata _opToken,
        address _feeCollector
    ) {
        opToken = _opToken;

        _setRoleAdmin(ADMIN, OWNER);
        _setRoleAdmin(OWNER, OWNER);
        _setRoleAdmin(PAUSER_ROLE, ADMIN);
        _setRoleAdmin(BORROWER_ROLE, ADMIN);
        _setupRole(OWNER, msg.sender);

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
        ISynthV1 _synth,
        uint8 _pid
    ) public onlyRole(ADMIN) whenNotPaused {
        require(synths[_pid].isActive == false, "Already added");
        synths[_pid] = Synth({
            synth: _synth,
            pid: _pid,
            isActive: true
        });
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
        whenNotPaused
        returns(uint256 synthAmount)
    {
        Synth memory synth = synths[_pid];
        uint256 fee_ = _amount * fee / feeRate;
        _amount -= fee_;
        synthAmount = synth.synth.convertOpToSynth(_amount);
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
        public
        exist(_pid)
        isActive(_pid) 
        whenNotPaused 
        returns (uint256 opTokenAmount)
    {
        //amount synth
        Synth memory synth = synths[_pid];
        opTokenAmount = synth.synth.convertSynthToOp(_amount);
        uint256 fee_ = opTokenAmount * fee / feeRate;
        opTokenAmount = opTokenAmount - fee_;
        synth.synth.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        opToken.transfer(feeCollector, fee_);
        opToken.transfer(msg.sender, opTokenAmount);
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
    function withdrawOpTokens(uint256 _amount, address to) public onlyRole(ADMIN) whenNotPaused {
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
    function changeOpToken(IERC20Metadata _opToken) public onlyRole(ADMIN) whenNotPaused {
        require(address(_opToken) != address(0), "Invalid address");
        opToken = _opToken;
    }

    /**
     * @dev function for setting fee
     *
     * Requirements:
     *
     * - the caller must have admin role.
     */
    function changeFee(uint256 _fee, uint256 _feeRate) public onlyRole(ADMIN) whenNotPaused {
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
    function pauseSynth(uint8 _pid) public exist(_pid) whenNotPaused onlyRole(ADMIN) {
        synths[_pid].isActive = !synths[_pid].isActive;
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
        external
        view
        onlyRole(ADMIN)
        whenNotPaused
        returns (bool)
    {
        return getSynthBalance(_pid) < _amount;
    }

    function checkOpRebalancing(uint256 _amount)
        external
        view
        onlyRole(ADMIN)
        whenNotPaused
        returns (bool)
    {
        return getOpTokenBalance() < _amount;
    }
}
