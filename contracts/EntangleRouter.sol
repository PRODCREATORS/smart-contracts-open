// SPDX-License-Identifier: BSL 1.1

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./PausableAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./EntangleSynth.sol";
import "./EntangleDEX.sol";
import "./synth-chefs/BaseSynthChef.sol";
import "./EntangleSynthFactory.sol";
import "./EntanglePool.sol";
import "./EntangleLending.sol";

interface Ipool {
    function depositToken(uint256 amount) external;
}

interface Ifactory {
    function getSynth(uint256) external view returns (address);
}

interface IBridge {
    function anySwapOutAndCall(
        address token,
        string memory to,
        uint256 amount,
        uint256 toChainID,
        string memory anycallProxy,
        bytes calldata data
    ) external;
}

contract EntangleRouter is PausableAccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for EntangleSynth;

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    BaseSynthChef chef;

    EntangleSynthFactory factory;

    EntangleDEX idex;

    EntangleLending lending;

    EntanglePool pool;

    IBridge bridge;

    enum EventType { BUY, SELL }

    event EventA(EventType _type, uint256 amount);
    event Bridge(uint256 amount);

    constructor(
        EntanglePool _pool,
        EntangleDEX _idex,
        BaseSynthChef _chef,
        EntangleSynthFactory _factory,
        EntangleLending _lending,
        IBridge _bridge,
        address _feeCollector
    ) {
        _setRoleAdmin(ADMIN, OWNER);
        _setRoleAdmin(PAUSER_ROLE, ADMIN);
        _setupRole(OWNER, msg.sender);

        pool = _pool;
        bridge = _bridge;

        idex = _idex;
        chef = _chef;
        factory = _factory;
        lending = _lending;
    }
    function buy(EntangleSynth _synth, uint256 _amountOp)
        external
        whenNotPaused
        returns (uint256 synthAmount)
    {
        IERC20 opToken = _synth.opToken();
        opToken.safeTransferFrom(msg.sender, address(this), _amountOp);
        if (opToken.allowance(address(this), address(idex)) < _amountOp) {
            opToken.safeIncreaseAllowance(address(idex), type(uint256).max);
        }
        synthAmount = idex.buy(_synth, _amountOp);
        _synth.safeTransfer(msg.sender, synthAmount);
    }

    function sell(
        EntangleSynth _synth,
        uint256 _amount
    ) external whenNotPaused returns(uint256 opTokenAmount){
        IERC20 opToken = _synth.opToken();
        _synth.safeTransferFrom(msg.sender, address(this), _amount);
        if (_synth.allowance(address(this), address(idex)) < _amount) {
            _synth.safeIncreaseAllowance(address(idex), type(uint256).max);
        }
        opTokenAmount = idex.sell(_synth, _amount);
        opToken.safeTransfer(msg.sender, opTokenAmount);
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _tokenFrom,
        uint256 _opId
    ) external onlyRole(ADMIN) whenNotPaused {
        IERC20(_tokenFrom).safeTransferFrom(msg.sender, address(this), _amount);
        if (IERC20(_tokenFrom).allowance(address(this), address(chef)) < _amount) {
            IERC20(_tokenFrom).safeIncreaseAllowance(address(chef), type(uint256).max);
        }
        chef.deposit(_pid, _tokenFrom, _amount, _opId);
    }

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        address _toToken,
        uint256 _opId
    ) external onlyRole(ADMIN) whenNotPaused {
        chef.withdraw(_pid, _toToken, _amount, msg.sender, _opId);
    }

    function depositFromPool(uint256 _pid, uint256 _amount, uint256 _opId) external onlyRole(ADMIN) whenNotPaused {
        pool.withdrawToken(_amount, address(this));
        IERC20 _token = pool.token();
        if (IERC20(_token).allowance(address(this), address(chef)) < _amount) {
            IERC20(_token).safeIncreaseAllowance(address(chef), type(uint256).max);
        }
        chef.deposit(_pid, address(_token), _amount, _opId);
    }

    function bridgeToChain(
        address token,
        string memory to,
        uint256 amount,
        uint256 toChainID,
        string memory anycallProxy,
        bytes calldata data
    ) external onlyRole(ADMIN) whenNotPaused {
        bridge.anySwapOutAndCall(
            token,
            to,
            amount,
            toChainID,
            anycallProxy,
            data
        );
        emit Bridge(amount);
    }
    
    function checkEventA(EventType _type, EntangleSynth _synth) public {
        uint256 synthBalance = _synth.balanceOf(address(this));
        uint256 opBalance = _synth.opToken().balanceOf(address(this));
        uint256 percent = opBalance * 100 / _synth.convertSynthAmountToOpAmount(_synth.totalSupply() - synthBalance);
        if (percent > 33) {

        } 
        if (percent < 17) {

        }
    }

    function borrow(uint256 amount, IERC20 token, ILender lender) external onlyRole(ADMIN) whenNotPaused {
        lending.borrow(amount, token, lender);
        token.safeTransfer(msg.sender, amount);
    }

    function repay(uint256 _loanID) external onlyRole(ADMIN) whenNotPaused {
        EntangleLending.Loan memory loan = lending.getLoan(_loanID);
        loan.token.safeTransferFrom(msg.sender, address(this), loan.amount);
        if (loan.token.allowance(address(this), address(lending)) < loan.amount) {
            loan.token.safeIncreaseAllowance(address(lending), type(uint256).max);
        }
        lending.repay(_loanID);
    }

    function checkBalanceSynth(
        EntangleSynth _synth,
        uint256 _amount
    ) internal view returns (bool) {
        return _synth.balanceOf(address(idex)) < _amount;
    }

    function checkBalanceOpToken(EntangleSynth _synth, uint256 _amount)
        internal
        view
        returns (bool)
    {
        IERC20 opToken = _synth.opToken();
        opToken.balanceOf(address(idex)) < _amount;
    }
}
