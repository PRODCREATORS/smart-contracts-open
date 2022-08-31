// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./PausableAccessControl.sol";
import "./interfaces/IETHDEXV1.sol";

interface IsynthChef {
    function withdraw(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) external;

    function deposit(
        uint256 _amount,
        address _token,
        uint256 _poolID
    ) external;
}

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

contract Router is PausableAccessControl {
    bytes32 public constant OWNER = keccak256("OWNER");
    bytes32 public constant ADMIN = keccak256("ADMIN");

    IsynthChef chef;

    IERC20Metadata opToken;

    Ifactory factory;

    IETHDEXV1 idex;

    address pool;

    address bridge;

    uint256 opDecimals;

    event DEXRebalancing(
        uint8 pid,
        uint256 kof,
        uint256 amount,
        uint indexed id
    );
    event Deposit(address indexed pid, uint256 amount);
    event Withdraw(address indexed pid, uint256 amountSynth);
    event Bridge(uint256 amount);

    constructor(
        address _pool,
        IETHDEXV1 _idex,
        IsynthChef _chef,
        IERC20Metadata _opToken,
        Ifactory _factory,
        address _bridge,
        address _feeCollector
    ) {
        _setRoleAdmin(ADMIN, OWNER);
        _setRoleAdmin(PAUSER_ROLE, ADMIN);
        _setupRole(OWNER, msg.sender);

        pool = _pool;
        bridge = _bridge;

        idex = _idex;
        chef = _chef;
        opToken = _opToken;
        opDecimals = _opToken.decimals();
        factory = _factory;
    }

    function buy(uint8 _pid, uint256 _amount)
        external
        whenNotPaused
        returns (uint256 synthAmount)
    {
        if (checkBalanceSynth(_pid, _amount)) {
            emit DEXRebalancing(_pid, 0, _amount, 3);
        } else {
            Synth memory synth = idex.synths(_pid);
            opToken.transferFrom(msg.sender, address(this), _amount);
            if (opToken.allowance(address(this), address(idex)) < _amount) {
                opToken.approve(address(idex), type(uint256).max);
            }
            synthAmount = idex.buy(_pid, _amount);
            synth.synth.transfer(msg.sender, synthAmount);
            checkLiquidity(_pid);
        }
    }

    function sell(
        uint8 _pid,
        uint256 _amount
    ) external whenNotPaused returns(uint256 opTokenAmount){
        if (checkBalanceOpToken(_amount)) {
            emit DEXRebalancing(0, 0, _amount, 4);
        } else {
            Synth memory synth = idex.synths(_pid);
            synth.synth.transferFrom(msg.sender, address(this), _amount);
            if (synth.synth.allowance(address(this), address(idex)) < _amount) {
                synth.synth.approve(address(idex), type(uint256).max);
            }
            opTokenAmount = idex.sell(_pid, _amount);
            opToken.transfer(msg.sender, opTokenAmount);
            checkLiquidity(_pid);
        }
    }

    function withdraw(
        uint256 pid,
        uint256 amountSynth,
        uint256 poolID
    ) external onlyRole(ADMIN) whenNotPaused {
        chef.withdraw(amountSynth, factory.getSynth(pid), poolID);
        emit Withdraw(factory.getSynth(pid), amountSynth);
    }

    function deposit(
        uint256 pid,
        uint256 amountSynth,
        uint256 poolID
    ) external onlyRole(ADMIN) whenNotPaused {
        chef.deposit(amountSynth, factory.getSynth(pid), poolID);
        emit Deposit(factory.getSynth(pid), amountSynth);
    }

    function depositToPool(uint256 amount)
        external
        onlyRole(ADMIN)
        whenNotPaused
    {
        opToken.transfer(pool, amount);
        emit Deposit(pool, amount);
    }

    function bridgeToChain(
        address token,
        string memory to,
        uint256 amount,
        uint256 toChainID,
        string memory anycallProxy,
        bytes calldata data
    ) external onlyRole(ADMIN) whenNotPaused {
        IBridge(bridge).anySwapOutAndCall(
            token,
            to,
            amount,
            toChainID,
            anycallProxy,
            data
        );
        emit Bridge(amount);
    }

    function changePool(address _pool) external onlyRole(OWNER) whenNotPaused {
        pool = _pool;
    }

    function changeChef(address _chef) external onlyRole(OWNER) whenNotPaused {
        chef = IsynthChef(_chef);
    }

    function changeFactory(address _factory)
        external
        onlyRole(OWNER)
        whenNotPaused
    {
        factory = Ifactory(_factory);
    }

    function changeOpToken(IERC20Metadata _opToken)
        external
        onlyRole(OWNER)
        whenNotPaused
    {
        opToken = _opToken;
    }

    function addAdmin(address _admin) public onlyRole(OWNER) whenNotPaused {
        require(!hasRole(ADMIN, _admin), "already admin");
        grantRole(ADMIN, _admin);
    }

    function removeAdmin(address _admin) public onlyRole(OWNER) {
        revokeRole(ADMIN, _admin);
    }

    function checkLiquidity(uint8 _pid) internal {
        uint256 synthBalance;
        uint256 opTokenBalance;
        Synth memory synth = idex.synths(_pid);
        if (opDecimals > 18) {
            synthBalance =
                synth.synth.balanceOf(address(idex)) * 10 ** (opDecimals - 17);
            opTokenBalance = opToken.balanceOf(address(idex)) * 10;
        } else {
            opTokenBalance = opToken.balanceOf(address(idex)) * 10 ** (19 - opDecimals);
            synthBalance = synth.synth.balanceOf(address(idex)) * 10;
        }

        uint256 kof = synthBalance / opTokenBalance;
        if (kof <= 5) {
            emit DEXRebalancing(_pid, kof, 0, 2);
        } else if (kof >= 15) {
            emit DEXRebalancing(_pid, kof, 0, 1);
        }
    }

    function checkBalanceSynth(
        uint8 _pid,
        uint256 _amount
    ) internal view returns (bool) {
        if (idex.synths(_pid).synth.balanceOf(address(idex)) < _amount) {
            return true;
        } else {
            return false;
        }
    }

    function checkBalanceOpToken(uint256 _amount)
        internal
        view
        returns (bool)
    {
        if (opToken.balanceOf(address(idex)) < _amount) {
            return true;
        } else {
            return false;
        }
    }
}
