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
    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    ) external;
}

contract EntangleRouter is PausableAccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for EntangleSynth;

    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    uint256 zFactor;
    uint8 zFactorDecimals;
    uint8 accuracy;

    BaseSynthChef chef;

    EntangleSynthFactory factory;

    EntangleDEX idex;

    EntangleLending lending;

    EntanglePool pool;

    IBridge bridge;

    enum EventType {
        BUY,
        SELL
    }

    struct BridgeParams {
        IERC20 tokenToBridge;
        address to;
        uint256 chainId;
        IERC20 token;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        uint256 dx;
        uint256 minDy;
        uint256 deadline;
        uint8 swapTokenIndexFrom;
        uint8 swapTokenIndexTo;
        uint256 swapMinDy;
        uint256 swapDeadline;
    }

    event EventA(EventType _type, uint256 amount, uint256 pid, uint256 chainId, uint256 k);
    event EventBC(EventType _type, uint256 amount, uint256 pid, uint256 chainId, address user);

    constructor(
        EntanglePool _pool,
        EntangleDEX _idex,
        BaseSynthChef _chef,
        EntangleSynthFactory _factory,
        EntangleLending _lending,
        IBridge _bridge,
        uint256 _zFactor,
        uint8 _zFactorDecimals,
        uint8 _accuracy
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

        zFactor = _zFactor;
        zFactorDecimals = _zFactorDecimals;
        accuracy = _accuracy;
    }

    function buy(EntangleSynth synth, uint256 amountOp)
        external
        whenNotPaused
        returns (uint256 synthAmount)
    {
        IERC20 opToken = synth.opToken();
        opToken.safeTransferFrom(msg.sender, address(this), amountOp);
        if (opToken.allowance(address(this), address(idex)) < amountOp) {
            opToken.safeIncreaseAllowance(address(idex), type(uint256).max);
        }
        if (
            synth.convertOpAmountToSynthAmount(amountOp) >
            synth.balanceOf(address(idex))
        ) {
            emit EventBC(EventType.BUY, amountOp, synth.pid(), synth.chainId(), msg.sender);
        } else {
            synthAmount = idex.buy(synth, amountOp);
            synth.safeTransfer(msg.sender, synthAmount);
            checkEventA(synth);
        }
    }

    function sell(EntangleSynth synth, uint256 amount)
        external
        whenNotPaused
        returns (uint256 opTokenAmount)
    {
        IERC20 opToken = synth.opToken();
        synth.safeTransferFrom(msg.sender, address(this), amount);
        if (synth.allowance(address(this), address(idex)) < amount) {
            synth.safeIncreaseAllowance(address(idex), type(uint256).max);
        }
        if (
            synth.convertSynthAmountToOpAmount(amount) >
            synth.opToken().balanceOf(address(idex))
        ) {
            emit EventBC(
                EventType.SELL,
                synth.convertSynthAmountToOpAmount(amount),
                synth.pid(),
                synth.chainId(),
                msg.sender
            );
        } else {
            opTokenAmount = idex.sell(synth, amount);
            opToken.safeTransfer(msg.sender, opTokenAmount);
            checkEventA(synth);
        }
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        address _tokenFrom,
        uint256 _opId
    ) external onlyRole(ADMIN) whenNotPaused {
        IERC20(_tokenFrom).safeTransferFrom(msg.sender, address(this), _amount);
        if (
            IERC20(_tokenFrom).allowance(address(this), address(chef)) < _amount
        ) {
            IERC20(_tokenFrom).safeIncreaseAllowance(
                address(chef),
                type(uint256).max
            );
        }
        chef.deposit(_pid, _tokenFrom, _amount, _opId);
    }

    function withdraw(
        uint256 _pid,
        uint256 _amount,
        address _toToken,
        uint256 _opId
    ) external onlyRole(ADMIN) whenNotPaused {
        chef.withdraw(_pid, _toToken, _amount, address(this), _opId);
    }

    function depositFromPool(
        uint256 amount,
        IERC20 token,
        uint256 pid,
        uint256 opId
    ) external onlyRole(ADMIN) whenNotPaused {
        pool.withdrawToken(amount, token, address(this), opId);
        if (token.allowance(address(this), address(chef)) < amount) {
            token.safeIncreaseAllowance(address(chef), type(uint256).max);
        }
        chef.deposit(pid, address(token), amount, opId);
    }

    function withdrawFromPool(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 opId
    ) external onlyRole(ADMIN) whenNotPaused {
        pool.withdrawToken(amount, token, to, opId);
    }

    function bridgeToChain(BridgeParams calldata params)
        external
        onlyRole(ADMIN)
        whenNotPaused
    {
        if (
            params.tokenToBridge.allowance(address(this), address(bridge)) <
            params.dx
        ) {
            params.tokenToBridge.safeIncreaseAllowance(
                address(bridge),
                type(uint256).max
            );
        }
        bridge.swapAndRedeemAndSwap(
            params.to,
            params.chainId,
            params.token,
            params.tokenIndexFrom,
            params.tokenIndexTo,
            params.dx,
            params.minDy,
            params.deadline,
            params.swapTokenIndexFrom,
            params.swapTokenIndexTo,
            params.swapMinDy,
            params.swapDeadline
        );
    }

    function checkEventA(EntangleSynth synth) public {
        uint256 soldSynths = synth.totalSupply() -
            synth.balanceOf(address(idex));
        uint256 neededOpBalance = synth.convertSynthAmountToOpAmount(
            soldSynths
        );
        if (neededOpBalance == 0) {
            return;
        }
        uint256 currentOpBalance = synth.opToken().balanceOf(address(idex));
        uint256 k = (((currentOpBalance * 10**accuracy) / neededOpBalance) *
            10**zFactorDecimals) / zFactor;
        uint256 amountToRebalance;
        EventType _type;
        if (k == 10**accuracy) {
            return;
        }
        if (k > 10**accuracy) {
            amountToRebalance = currentOpBalance - 
                (neededOpBalance * (10**zFactorDecimals - zFactor)) /
                10**zFactorDecimals;
            _type = EventType.BUY;
        }
        if (k < 10**accuracy) {
            amountToRebalance =
                ((neededOpBalance * zFactor) / 10**zFactorDecimals) -
                currentOpBalance;
            _type = EventType.SELL;
        }
        emit EventA(_type, amountToRebalance, synth.pid(), synth.chainId(), k);
    }

    function borrowAndDeposit(
        uint256 amount,
        IERC20 token,
        ILender lender,
        uint256 pid,
        uint256 opId
    ) external onlyRole(ADMIN) whenNotPaused {
        lending.borrow(amount, token, lender, address(this), opId);
        if (token.allowance(address(this), address(chef)) < amount) {
            token.safeIncreaseAllowance(address(chef), type(uint256).max);
        }
        chef.deposit(pid, address(token), amount, opId);
    }

    function borrow(
        uint256 amount,
        IERC20 token,
        ILender lender,
        address receiver,
        uint256 opId
    ) external onlyRole(ADMIN) whenNotPaused {
        lending.borrow(amount, token, lender, receiver, opId);
    }

    function repayFromPool(uint256 loanId, uint256 opId)
        external
        onlyRole(ADMIN)
        whenNotPaused
    {
        EntangleLending.Loan memory loan = lending.getLoan(loanId);
        pool.withdrawToken(loan.amount, loan.token, address(this), opId);
        if (
            loan.token.allowance(address(this), address(lending)) < loan.amount
        ) {
            loan.token.safeIncreaseAllowance(
                address(lending),
                type(uint256).max
            );
        }
        lending.repay(loanId, opId);
    }

    function moveOpTokenFromDEXToPool(EntangleSynth synth, uint256 amount) external onlyRole(ADMIN) whenNotPaused {
        moveOpTokenFromDEX(synth, amount);
        IERC20 opToken = synth.opToken();
        opToken.transfer(address(pool), amount);
    }

    function moveOpTokenToDEX(EntangleSynth synth, uint256 amount)
        external
        onlyRole(ADMIN)
        whenNotPaused
    {
        IERC20 opToken = synth.opToken();
        opToken.transfer(address(idex), amount);
    }

    function moveOpTokenFromDEX(EntangleSynth synth, uint256 amount)
        public
        onlyRole(ADMIN)
        whenNotPaused
    {
        idex.moveOpToken(synth.opToken(), amount);
    }

    function checkBalanceSynth(EntangleSynth _synth, uint256 _amount)
        internal
        view
        returns (bool)
    {
        return _synth.balanceOf(address(idex)) < _amount;
    }

    function checkBalanceOpToken(EntangleSynth _synth, uint256 _amount)
        internal
        view
        returns (bool)
    {
        IERC20 opToken = _synth.opToken();
        return opToken.balanceOf(address(idex)) < _amount;
    }
}
