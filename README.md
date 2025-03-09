# ERC-4337: Account Abstraction

> This repository is focused on creating a test environment over the ERC 4337 token.

## The project
The main goal of the project is to create tests for ERC 4337 using both black-box and white-box techniques. Our tests were executed using the Foundry framework. Additionally, we performed the tests using both Halmos and HEVM for symbolic testing. Below, we will detail more about our experience and the lessons learned.


## About the tests
Our focus was to test the functions that perform actions, especially those that execute transactions, as these are the functions that make everything work. Therefore, given this scenario, we created tests for the following functions:

-[x] depositTo
-[x] withdrawTo
-[x] handleOps
-[] addStake
-[] unlockStake
-[] validateUserOp
-[] executeUserOp

## Black-box testing


## White-box testing
As for the white-box tests, we again analyzed each function individually and, in this case, any other functions (internal or external) called within the implementation of each one. In this scenario, we analyzed the implementation of **eth-infinitism**. We will describe below what we did and our results.

### depositTo
```
    function _incrementDeposit(address account, uint256 amount) internal returns (uint256) {
        DepositInfo storage info = deposits[account];
        uint256 newAmount = info.deposit + amount;
        info.deposit = newAmount;
        return newAmount;
    }

    function depositTo(address account) public virtual payable {
        uint256 newDeposit = _incrementDeposit(account, msg.value);
        emit Deposited(account, newDeposit);
    }

```
If we take a closer look at the implementation of the deposit method, there is not much complexity, no decision flow, nothing. For this reason, there wasn’t much to be done in terms of new tests, i.e., the important thing is to analyze whether, after the method is called and executed, the account passed as a parameter has a value greater than the initial one.

### withdrawTo