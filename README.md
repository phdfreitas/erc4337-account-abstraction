# ERC-4337: Account Abstraction

> This repository is focused on creating a test environment over the ERC 4337 token.

## The project
The main goal of the project is to create tests for ERC 4337 using both black-box and white-box techniques. Our tests were executed using the Foundry framework. Additionally, we performed the tests using both Halmos and HEVM for symbolic testing. Below, we will detail more about our experience and the lessons learned.


## About the tests
Our focus was to test the functions that perform actions, especially those that execute transactions, as these are the functions that make everything work. Therefore, given this scenario, we created tests for the following functions:

- [x] depositTo
- [x] withdrawTo
- [ ] handleOps (In development, not all indirect function calls have been tested)
- [ ] addStake
- [ ] unlockStake
- [ ] validateUserOp
- [ ] executeUserOp

## Black-box testing
Until the present date, we have not focused much on this type of testing. In fact, we have conducted only a few types of tests (for specific functions, which will be mentioned later in this document). In this scenario, we have tested the following functions: depositTo and withdrawTo, as they are simple functions.


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
The same applies to the _withdrawTo_ function. For this and other reasons, we chose to test the main function of the EntryPoint _handleOps_. The _handleOps_ function calls several other functions during its execution, either directly or indirectly. As we progress in testing, we will add explanations of what has been done.

When executing handleOps, the first function that triggers some type of modification or flow control is _validatePrepayment, which can cause some reverts, including:

1. AA94 gas values overflow: _Reverts if the sum of the attributes of PackedUserOperation exceeds a maximum value._

2. AA25 invalid account nonce: _Reverts if the counter (nonce) is not valid._

3. AA26 over verificationGasLimit: _Reverts if the gas used in the transaction exceeds the limit set in the verificationGasLimit attribute._

Therefore, these were the first tests created, aiming to cover scenarios that could trigger these conditions.

## Symbolic Execution (Hevm and Halmos)
One of our goals with this project is to also run tests using hevm and halmos, both tools for symbolic test execution, despite their different approaches. So far, we have only been able to execute tests with halmos, but we plan to run tests with hevm soon as well.

In this regard, we noticed that the tests we wrote are entirely focused on the "concrete" execution of methods, meaning:

After researching a bit, we discovered interesting differences between symbolic and concrete execution. For example, when running our tests with halmos, we encountered two main issues:

1. **Halmos does not support tests with "expectRevert"**, as it considers them "cheat codes." However, most of our tests were designed to expect reverts due to the way we initially structured or envisioned the development of this project. This is something that can be revised later.

2. **Overly restrictive initial states**. In this case, the constraints were too limiting, which makes sense. In some situations, in order to deliberately test certain functions, we intentionally imposed restrictions—for instance, setting insufficient gas limits to force a "require" statement to fail.

Therefore, it would be beneficial to change our approach to testing, considering a more comprehensive strategy that allows for both concrete and symbolic test execution. 

For future reference and further developments, in the first execution of halmos, the only function that passed was **check_testDepositZeroEther_ShouldNotChangeBalance**.