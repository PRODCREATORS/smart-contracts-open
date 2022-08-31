//SPDX-License-Identifier: BSL 1.1

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILender.sol";
import "./PausableAccessControl.sol";


contract Lending is PausableAccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER");

    constructor() {
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    struct Loan {
        uint256 amount;
        IERC20 token;
        address borrower;
        ILender lender;
    }

    mapping(address => bool) public lenders;
    mapping(uint256 => Loan) public loans;
    event GetLoan(IERC20 token, uint256 amount, address indexed creditor);
    event RepayLoan(IERC20 token, uint256 amount, address indexed creditor);

    uint256 private nextLoanId = 0;

    function getLoan(uint256 amount, IERC20 token, ILender lender) external onlyRole(BORROWER_ROLE) whenNotPaused {
        require(lenders[address(lender)], "Lender is not authorized");
        loans[nextLoanId++] = Loan({
            amount: amount, 
            token: token, 
            borrower: msg.sender, 
            lender: lender
            });
        lender.borrow(token, amount, msg.sender);
        emit GetLoan(token, amount, address(lender));
    }

    function repayLoan(uint256 loanId) external onlyRole(BORROWER_ROLE) whenNotPaused {
        Loan storage loan = loans[loanId];
        loan.token.transferFrom(msg.sender, address(loan.lender), loan.amount);
        emit RepayLoan(loan.token, loan.amount, address(loan.lender));
        delete loans[loanId];
    }
}
