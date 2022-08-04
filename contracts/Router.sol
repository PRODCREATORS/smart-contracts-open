// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    IERC20 opToken;

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
        IERC20 _opToken,
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

    function buy(
        uint8 _pid,
        uint256 _amount
    ) external whenNotPaused {
        if (checkBalanceSynth(_pid, _amount)) {
            emit DEXRebalancing(_pid, 0, _amount, 3);
        } else {
            Synth memory synth = idex.synths(_pid);
            opToken.transferFrom(msg.sender, address(this), _amount);
            if (opToken.allowance(address(this), address(idex)) < _amount) {
                opToken.approve(address(idex), type(uint256).max);
            }
            idex.buy(_pid, _amount);
            uint256 fee_ = _amount.div(100).mul(1);
            uint256 amountSynth = _amount.mul(synth.rate).div(10**opDecimals);
            opToken.transferFrom(msg.sender, address(this), _amount);
            opToken.transfer(feeCollector, fee_);
            synth.synth.transfer(msg.sender, amountSynth);
        }
    }

    function sell(
        address _to,
        uint8 _pid,
        uint256 _amount
    ) external whenNotPaused {
        if (checkBalanceOpToken(_to, _amount)) {
            emit DEXRebalancing(_to, 0, 0, _amount, 4);
        } else {
            IDEX(_to).sell(_pid, _amount);
            checkLiquidity(_to, _pid);
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

    function changeTokenOp(address _tokenOp)
        external
        onlyRole(OWNER)
        whenNotPaused
    {
        opToken = IERC20(_tokenOp);
    }

    function addAdmin(address _admin) public onlyRole(OWNER) whenNotPaused {
        require(!hasRole(ADMIN, _admin), "already admin");
        grantRole(ADMIN, _admin);
    }

    function removeAdmin(address _admin) public onlyRole(OWNER) {
        revokeRole(ADMIN, _admin);
    }

    function checkLiquidity(address _idex, uint8 _pid) internal {
        uint256 balanceSynth;
        uint256 balanceOpToken;
        if (opDecimals > 18) {
            balanceSynth =
                IERC20(factory.getSynth(_pid)).balanceOf(_idex) *
                10**(opDecimals - 17);
            balanceOpToken = opToken.balanceOf(_idex) * 10;
        } else {
            balanceOpToken = opToken.balanceOf(_idex) * 10**(19 - opDecimals);
            balanceSynth = IERC20(factory.getSynth(_pid)).balanceOf(_idex) * 10;
        }

        uint256 kof = balanceSynth / balanceOpToken;
        if (kof <= 5) {
            emit DEXRebalancing(_idex, _pid, kof, 0, 2);
        } else if (kof >= 15) {
            emit DEXRebalancing(_idex, _pid, kof, 0, 1);
        }
    }

    function checkBalanceSynth(
        address _idex,
        uint8 _pid,
        uint256 _amount
    ) internal view returns (bool) {
        if (IERC20(factory.getSynth(_pid)).balanceOf(_idex) < _amount) {
            return true;
        } else {
            return false;
        }
    }

    function checkBalanceOpToken(address _idex, uint256 _amount)
        internal
        view
        returns (bool)
    {
        if (opToken.balanceOf(_idex) < _amount) {
            return true;
        } else {
            return false;
        }
    }
}
