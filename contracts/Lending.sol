//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface Ifactory {
   function getSynth(uint256) external view returns(address);
}


contract Lending is AccessControl, Pausable  {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER");

    Ifactory factory;

    constructor(address _factory) {
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        factory = Ifactory(_factory);
    }

    struct Loan {
        uint256 amount;
        address collector;
    }

    mapping(address => mapping(uint256 => Loan)) public getLoans;
    event GetLoan(uint256 pid, uint256 amount, address indexed creditor);
    event RepayLoan(uint256 pid, uint256 amount, address indexed creditor);


    function getLoan(uint256 amount, uint256 pid, address creditor) external onlyRole(BORROWER_ROLE) whenNotPaused {
        require(getLoans[msg.sender][pid].collector == address(0), "you have loan");
        address token = factory.getSynth(pid);
        require(token != address(0), "this token does not exist");
        require(IERC20(token).balanceOf(creditor) >= amount, "not enough money");

        getLoans[msg.sender][pid].amount = amount;

        IERC20(token).transferFrom(creditor, msg.sender, amount);

        emit GetLoan(pid, amount, creditor);
    }

    function repayLoan(uint256 pid, address creditor) external onlyRole(BORROWER_ROLE) whenNotPaused {
        uint256 amount = getLoans[msg.sender][pid].amount;
        address token = factory.getSynth(pid);
        require(token != address(0), "this token is does not exist");
        require(IERC20(token).balanceOf(msg.sender) >= amount, "not enough money");

        IERC20(token).transferFrom(msg.sender, creditor, amount);
        delete getLoans[msg.sender][pid];
        emit RepayLoan(pid, amount, creditor);
    }

    function addBorrower(address _borrower) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(hasRole(keccak256("ADMIN"), _borrower) && hasRole(keccak256("BORROWER"), _borrower), "you have role");
        grantRole(BORROWER_ROLE, _borrower);
    }   

    function removeBorrower(address _borrower) external onlyRole(ADMIN_ROLE) whenNotPaused {
        require(hasRole(keccak256("ADMIN"), _borrower) && hasRole(keccak256("BORROWER"), _borrower), "you have role");
        revokeRole(BORROWER_ROLE, _borrower);
    }

    function pause() external whenNotPaused onlyRole(ADMIN_ROLE) {
		_pause();
	}

	function unpause() external whenPaused onlyRole(ADMIN_ROLE) {
		_unpause();
	}
}
