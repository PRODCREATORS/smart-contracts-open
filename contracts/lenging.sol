//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Ifactory {
   function getSynth(uint256) external view returns(address);
}


contract lending is AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER");

    Ifactory factory;

    constructor(address _factory) {
        _setRoleAdmin(BORROWER_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, msg.sender);
        factory = Ifactory(_factory);
    }

    struct loan {
        uint256 amount;
        address collector;
    }

    mapping(address => mapping(uint256 => loan)) public getLoans;
    event GetLoan(uint256 pid, uint256 amount);
    event RepayLoan(uint256 pid, uint256 amount);


    function getLoan(uint256 amount, uint256 pid, address creditor) external onlyRole(BORROWER_ROLE) {
        require(getLoans[msg.sender][pid].collector == address(0), "you have loan");
        address token = factory.getSynth(pid);
        require(token != address(0), "this token is does not exist");
        require(IERC20(token).balanceOf(creditor) >= amount, "not enough money");

        getLoans[msg.sender][pid].amount = amount;

        IERC20(token).transferFrom(creditor, msg.sender, amount);

        emit GetLoan(pid, amount);
    }

    function repayLoan(uint256 pid, address creditor) external onlyRole(BORROWER_ROLE) {
        uint256 amount = getLoans[msg.sender][pid].amount;
        address token = factory.getSynth(pid);
        require(token != address(0), "this token is does not exist");
        require(IERC20(token).balanceOf(msg.sender) >= amount, "not enough money");

        IERC20(token).transferFrom(msg.sender, creditor, amount);
        delete getLoans[msg.sender][pid];
        emit RepayLoan(pid, amount);
    }

    function addBorrower(address _minter) external onlyRole(ADMIN_ROLE) {
        grantRole(BORROWER_ROLE, _minter);
    }

}


