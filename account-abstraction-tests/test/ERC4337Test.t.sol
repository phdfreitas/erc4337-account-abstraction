// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {IEntryPoint} from "../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC4337.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "../lib/account-abstraction/contracts/core/UserOperationLib.sol";

contract ERC4337Test is Test {
    EntryPoint public entryPoint;
    address public constant beneficiary = address(0x123);
    address public constant mockedUser = address(0x456);

    function setUp() public {
        entryPoint = new EntryPoint();
        vm.deal(address(entryPoint), 10 ether);
    }

    function testDepositTo() public {
        uint256 depositAmount = 1 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser);
        uint256 balance = entryPoint.balanceOf(mockedUser);
        assertEq(balance, depositAmount, "Incorrect deposited balance");
    }

    function testWithdrawTo_ValidAmount() public {
        uint256 depositAmount = 1 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser);
        uint256 initialBalance = entryPoint.balanceOf(mockedUser);

        vm.prank(mockedUser);
        entryPoint.withdrawTo(payable(beneficiary), depositAmount);
        uint256 finalBalance = entryPoint.balanceOf(mockedUser);
        
        assertEq(initialBalance, depositAmount, "Deposit not registered");
        assertEq(finalBalance, 0, "Withdraw did not reduce balance correctly");
    }

    function testWithdraw_InsufficientAmount() public {
        uint256 depositTestWithdraw = 1 ether;
        entryPoint.depositTo{value: depositTestWithdraw}(mockedUser);
        
        uint256 depositAmount = entryPoint.balanceOf(mockedUser);
        
        assertEq(depositAmount, 1 ether, "Deposit not registered as expected");
        
        vm.prank(mockedUser);
        vm.expectRevert(bytes("Withdraw amount too large"));
        entryPoint.withdrawTo(payable(beneficiary), 2 ether);
    }

    // function testHandleOps_Success() public {
    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     PackedUserOperation memory op = createmockedUserOp();
    //     ops[0] = op;
        
    //     uint256 initialBalance = entryPoint.balanceOf(beneficiary);

    //     vm.expectRevert();
    //     entryPoint.handleOps(ops, payable(beneficiary));

    //     uint256 finalBalance = entryPoint.balanceOf(beneficiary);
    //     assertGt(finalBalance, initialBalance, "Beneficiary did not receive compensation");
    // }

    function testHandleOps_Invalid() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;
        
        op.gasFees = packGasFees(0, unpackHigh128(op.gasFees));
        vm.expectRevert(); 
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    function testHandleOps_ValidationFailsDueToInsufficientBalance() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;

        vm.prank(mockedUser);
        entryPoint.withdrawTo(payable(beneficiary), entryPoint.balanceOf(mockedUser));

        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // AA23 reverted
    function testHandleOps_AccountValidationFails() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;

        // Simulando conta inválida (usuário com código inesperado)
        vm.mockCall(mockedUser, abi.encodeWithSignature("validateUserOp(bytes32,uint256)", "", 0), abi.encode(1));

        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }
    
    // AA94 gas values overflow - _validatePrepayment
    function testHandleOps_GasValuesOverflow() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        // Sobrescrevendo valores de gás causar overflow
        op.preVerificationGas = type(uint120).max / 2;
        op.accountGasLimits = packGasLimits(type(uint120).max / 2, type(uint120).max / 2);
        op.gasFees = packGasFees(type(uint120).max / 2, type(uint120).max / 2);

        ops[0] = op;

        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // AA21 didn't pay prefund 
    function testHandleOps_InsufficientPrefund() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        
        op.preVerificationGas = 100000;
        op.accountGasLimits = packGasLimits(100000, 100000);
        op.gasFees = packGasFees(10 gwei, 5 gwei);

        ops[0] = op;

        vm.prank(mockedUser);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // AA25 invalid account nonce
    function testHandleOps_InvalidNonce() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        op.nonce = 999; 

        ops[0] = op;

        vm.startPrank(mockedUser);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
        vm.stopPrank();
    }

    // AA26 over verificationGasLimit
    function testHandleOps_OverVerificationGasLimit() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        op.accountGasLimits = packGasLimits(10, 10);

        ops[0] = op;

        vm.startPrank(mockedUser);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
        vm.stopPrank();
    }

    // AA13 initCode failed or OOG
    function testCreateSenderIfNeeded_FailedInitCode() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        op.initCode = hex"00";

        ops[0] = op;

        vm.startPrank(mockedUser);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
        vm.stopPrank();
    }

    // AA10 sender already constructed
    function testCreateSenderIfNeeded_AlreadyConstructed() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;
        
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // AA24 signature error
    function testHandleOps_AA24_SignatureError() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        uint256 invalidValidationData = packValidationData(
            address(0x1234), // Um agregador inesperado
            0, 
            type(uint48).max
        );

        vm.mockCall(
            mockedUser,
            abi.encodeWithSignature("validateUserOp(bytes32,uint256)", "", 0),
            abi.encode(invalidValidationData) // Retorna um agregador inválido
        );

        ops[0] = op;

        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }



    function createmockedUserOp() internal pure returns (PackedUserOperation memory op) {
        op.sender = mockedUser;
        op.nonce = 0;
        op.initCode = "";
        op.callData = "";
        // Define os limites de gás e fees: 
        // Para gasFees, usaremos um bytes32 onde os 128 bits mais baixos são maxFeePerGas
        // e os 128 bits mais altos são maxPriorityFeePerGas.
        op.gasFees = packGasFees(2 gwei, 2 gwei);
        // Para accountGasLimits, os 128 bits inferiores serão callGasLimit e os superiores, verificationGasLimit.
        op.accountGasLimits = packGasLimits(200000, 200000);
        op.preVerificationGas = 30000;
        op.paymasterAndData = "";
        op.signature = "";
    }

    // Função auxiliar para empacotar gasFees: 
    // Retorna um bytes32 com os 128 bits mais baixos = maxFeePerGas e os 128 bits mais altos = maxPriorityFeePerGas.
    function packGasFees(uint256 maxFeePerGas, uint256 maxPriorityFeePerGas) internal pure returns (bytes32) {
        return bytes32((maxPriorityFeePerGas << 128) | maxFeePerGas);
    }

    // Função auxiliar para empacotar accountGasLimits:
    // Os 128 bits inferiores serão callGasLimit e os 128 bits superiores serão verificationGasLimit.
    function packGasLimits(uint256 callGasLimit, uint256 verificationGasLimit) internal pure returns (bytes32) {
        return bytes32((verificationGasLimit << 128) | callGasLimit);
    }

    function packValidationData(address aggregator, uint48 validAfter, uint48 validUntil) internal pure returns (uint256) {
        return (uint256(validAfter) << 160) | (uint256(validUntil) << 128) | uint256(uint160(aggregator));
    }

    // Função auxiliar para extrair os 128 bits inferiores (maxFeePerGas) de um bytes32.
    function unpackLow128(bytes32 packed) internal pure returns (uint256) {
        return uint128(uint256(packed));
    }

    // Função auxiliar para extrair os 128 bits superiores (maxPriorityFeePerGas) de um bytes32.
    function unpackHigh128(bytes32 packed) internal pure returns (uint256) {
        return uint256(packed) >> 128;
    }
}
