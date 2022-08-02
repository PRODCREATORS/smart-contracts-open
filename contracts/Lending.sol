//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract Lending is AccessControl, Pausable  {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER");

    constructor() {
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    struct Loan {
        uint256 amount;
        IERC20 token,
        address borrower,
        address creditor,
    }

    mapping(address => bool) public creditors;
    mapping(uint256 => Loan) public loans;
    event GetLoan(IERC20 token, uint256 amount, address indexed creditor);
    event RepayLoan(IERC20 token, uint256 amount, address indexed creditor);

    uint256 nextLoanId = 0;


    function getLoan(uint256 amount, IERC20 token, address creditor) external onlyRole(BORROWER_ROLE) whenNotPaused {
        require(creditors[creditor], "Creditor is not authorized");
        loans[nextLoanId++] = Loan({
            amount: amount, 
            token: token, 
            borrower: msg.sender, 
            creditor: creditor,
            });
        token.transferFrom(creditor, msg.sender, amount);
        emit GetLoan(token, amount, creditor);
    }

    function repayLoan(uint256 loanId) external onlyRole(BORROWER_ROLE) whenNotPaused {
        Loan loan = loans[loanId];
        loan.token.transferFrom(msg.sender, creditor, amount);
        delete loans[loanId];
        emit RepayLoan(loan.token, amount, creditor);
    }

    function pause() external whenNotPaused onlyRole(ADMIN_ROLE) {
		_pause();
	}

	function unpause() external whenPaused onlyRole(ADMIN_ROLE) {
		_unpause();
	}
}
