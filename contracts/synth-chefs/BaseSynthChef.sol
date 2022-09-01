// SPDX-License-Identifier: BSL 1.1
pragma solidity 0.8.15;

import "../Lender.sol";
import "../PausableAccessControl.sol";
import "../interfaces/IEntangleDEXWrapper.sol";

abstract contract BaseSynthChef is PausableAccessControl, Lender {
    struct TokenAmount {
        uint256 amount;
        address token;
    }

    IEntangleDEXWrapper public DEXWrapper;
    address public stablecoin;
    address[] internal rewardTokens;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

    event Deposit(uint256 indexed pid, uint256 amount);
    event Withdraw(uint256 indexed pid, uint256 amount);
    event Compound(uint256 indexed pid, uint256 amountStable);

    constructor(address _DEXWrapper, address _stablecoin, address[] memory _rewardTokens) {
        DEXWrapper = IEntangleDEXWrapper(_DEXWrapper);
        stablecoin = _stablecoin;
        rewardTokens = _rewardTokens;

        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _grantRole(ADMIN_ROLE, address(this)); // needed for calling this.deposit in compound
        _setupRole(OWNER_ROLE, msg.sender);
    }

    function deposit(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        if (msg.sender != address(this))
            IERC20(_tokenFrom).transferFrom(msg.sender, address(this), _amount);
        uint256 amountLPs = _addLiquidity(_pid, _tokenFrom, _amount);
        _depositToFarm(_pid, amountLPs);
        emit Deposit(_pid, amountLPs);
    }

    function withdraw(
        uint256 _pid,
        address _toToken,
        uint256 _amount,
        address _to
    ) public onlyRole(ADMIN_ROLE) whenNotPaused {
        _withdrawFromFarm(_pid, _amount);
        TokenAmount[] memory tokens = _removeLiquidity(_pid, _amount);
        uint256 tokenAmount = 0;
        for (uint i = 0; i < tokens.length; i++) {
            tokenAmount += _convertTokens(
                tokens[i].token,
                _toToken,
                tokens[i].amount
            );
        }
        IERC20(_toToken).transfer(_to, tokenAmount);
        emit Withdraw(_pid, _amount);
    }

    function compound(uint256 _pid) public onlyRole(ADMIN_ROLE) whenNotPaused {
        _harvest(_pid);
        for(uint i = 0; i < rewardTokens.length; i++) {
            uint256 balance = IERC20(rewardTokens[i]).balanceOf(address(this));
            if (balance > 0) {
                this.deposit(_pid, address(rewardTokens[i]), balance);
            }
        }
        emit Compound(_pid, getBalanceOnFarm(_pid));
    }

    function convertTokenToStablecoin(address _tokenAddress, uint256 _amount)
        internal
        view
        returns (uint256 amountStable)
    {
        if (_tokenAddress == stablecoin) return _amount;
        return _previewConvertTokens(_tokenAddress, stablecoin, _amount);
    }

    function convertStablecoinToToken(
        address _tokenAddress,
        uint256 _amountStablecoin
    ) internal view returns (uint256 amountToken) {
        if (_tokenAddress == stablecoin) return _amountStablecoin;
        return
            _previewConvertTokens(stablecoin, _tokenAddress, _amountStablecoin);
    }

    function getBalanceOnFarm(uint256 _pid)
        public
        view
        returns (uint256 totalAmount)
    {
        TokenAmount[] memory tokens = _getTokensInLP(_pid);
        for (uint i = 0; i < tokens.length; i++) {
            totalAmount += convertTokenToStablecoin(
                tokens[i].token,
                tokens[i].amount
            );
        }
    }

    function _harvest(uint256 _pid) internal virtual;

    function _withdrawFromFarm(uint256 _pid, uint256 _amount) internal virtual;

    function _depositToFarm(uint256 _pid, uint256 _amount) internal virtual;

    function _removeLiquidity(uint256 _pid, uint256 _amount)
        internal
        virtual
        returns (TokenAmount[] memory tokenAmounts);

    function _addLiquidity(
        uint256 _pid,
        address _tokenFrom,
        uint256 _amount
    ) internal virtual returns (uint256 LPAmount);

    function _getTokensInLP(uint256 _pid)
        internal
        view
        virtual
        returns (TokenAmount[] memory tokens);
    
    function _convertTokens(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        if (from == to) return amount;
        if (
            IERC20(from).allowance(address(this), address(DEXWrapper)) < amount
        ) {
            IERC20(from).approve(address(DEXWrapper), type(uint256).max);
        }
        return DEXWrapper.convert(from, to, amount);
    }

    function _previewConvertTokens(
        address from,
        address to,
        uint256 amount
    ) internal view returns (uint256) {
        return DEXWrapper.previewConvert(from, to, amount);
    }
}
