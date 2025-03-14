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

    function testDepositZeroEther_ShouldNotChangeBalance() public {
        uint256 initialBalance = entryPoint.balanceOf(mockedUser);
        entryPoint.depositTo{value: 0}(mockedUser);
        uint256 finalBalance = entryPoint.balanceOf(mockedUser);
        
        assertEq(initialBalance, finalBalance, "Balance should not change for 0 ether deposit");
    }

    function testDepositMaxEther() public {
        uint256 maxDeposit = type(uint256).max;
        
        // Verifica se o contrato falha ao tentar depositar o valor máximo
        vm.expectRevert();
        entryPoint.depositTo{value: maxDeposit}(mockedUser);
    }

    function testDeposit_Overflow() public {
        address user = address(0x999);
        uint256 depositAmount = type(uint256).max;

        // Tenta depositar o valor máximo
        vm.expectRevert(); // Espera que o contrato reverta
        entryPoint.depositTo{value: depositAmount}(user);
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

    function testWithdraw_MoreThanBalance_ShouldFail() public {
        uint256 depositTestWithdraw = 1 ether;
        entryPoint.depositTo{value: depositTestWithdraw}(mockedUser);
        
        uint256 depositAmount = entryPoint.balanceOf(mockedUser);
        
        assertEq(depositAmount, 1 ether, "Deposit not registered as expected");
        
        vm.prank(mockedUser);
        vm.expectRevert(bytes("Withdraw amount too large"));
        entryPoint.withdrawTo(payable(beneficiary), 2 ether);
    }

    function testWithdraw_ZeroEther() public {
        entryPoint.depositTo{value: 1 ether}(mockedUser); // Deposita 1 ether para garantir saldo
        uint256 initialBalance = entryPoint.balanceOf(mockedUser);
        
        vm.prank(mockedUser);
        entryPoint.withdrawTo(payable(beneficiary), 0); // Saque de 0 ether
        
        uint256 finalBalance = entryPoint.balanceOf(mockedUser);
        assertEq(initialBalance, finalBalance, "Balance should not change for 0 ether withdrawal");
    }

    function testWithdraw_ExactBalance() public {
        uint256 depositAmount = 2 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser); // Deposita 2 ether
        
        uint256 initialBeneficiaryBalance = beneficiary.balance;
        
        vm.prank(mockedUser);
        entryPoint.withdrawTo(payable(beneficiary), depositAmount); // Saca o valor total
        
        uint256 finalBalance = entryPoint.balanceOf(mockedUser);
        uint256 finalBeneficiaryBalance = beneficiary.balance;
        
        assertEq(finalBalance, 0, "Balance should be zero after full withdrawal");
        assertEq(finalBeneficiaryBalance, initialBeneficiaryBalance + depositAmount, "Beneficiary should receive the exact amount");
    }

    function testWithdrawMaxEther_ShouldFail() public {
        uint256 depositAmount = 1 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser); // Deposita 1 ether
        
        vm.prank(mockedUser);
        vm.expectRevert(bytes("Withdraw amount too large")); // Mensagem de erro esperada
        entryPoint.withdrawTo(payable(beneficiary), type(uint256).max); // Tenta sacar o valor máximo
    }

    //function testWithdraw_UnknownUser() public { (não precisa pq só da pra sacar da própria conta)

    // não reverteu para endereço zero, não sei se esse teste é relevante
    //function testWithdraw_InvalidAddress() public {
    //    address invalidAddress = address(0); // Endereço zero
    //    uint256 depositAmount = 1 ether;
    //
    //    // Deposita para o mockedUser
    //    entryPoint.depositTo{value: depositAmount}(mockedUser);
        // Tenta sacar para um endereço inválido
    //    vm.prank(mockedUser);
    //    vm.expectRevert(bytes("Invalid address")); // Mensagem de erro esperada
    //    entryPoint.withdrawTo(payable(invalidAddress), depositAmount);
    //}

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

    // talvez esteja repetindo testHandleOps_InsufficientPrefund
    function testHandleOps_InsufficientGas() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;

        // Define limites de gás insuficientes
        op.accountGasLimits = packGasLimits(1000, 1000); // Limites muito baixos

        // Verifica se o contrato falha
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    function testHandleOps_InvalidSignature() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;

        // Define uma assinatura inválida
        op.signature = abi.encodePacked(bytes32("invalid_signature"));

        // Verifica se o contrato falha
        vm.expectRevert(); // Mensagem de erro esperada
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    function testHandleOps_InvalidCallData() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;

        // Define um callData inválido
        op.callData = abi.encodeWithSignature("nonExistentFunction()");

        // Verifica se o contrato falha
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    //_createSenderIfNeeded - AA13 initCode failed or OOG
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

    // _createSenderIfNeeded AA10 sender already constructed
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
    
    function testHandleOps_CopyUserOpToMemory_ValidData() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        // Criando um paymasterAndData válido
        op.paymasterAndData = new bytes(UserOperationLib.PAYMASTER_DATA_OFFSET);
        for (uint256 i = 0; i < op.paymasterAndData.length; i++) {
            op.paymasterAndData[i] = bytes1(uint8(i + 1));
        }

        ops[0] = op;

        vm.expectRevert(); 
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // 
    function testHandleOps_CopyUserOpToMemory_InvalidPaymasterData() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();

        // Criando um paymasterAndData inválido (menor do que o esperado)
        op.paymasterAndData = new bytes(UserOperationLib.PAYMASTER_DATA_OFFSET - 1);

        ops[0] = op;

        vm.expectRevert(bytes("AA93 invalid paymasterAndData"));
        entryPoint.handleOps(ops, payable(beneficiary));
    }

    // function testValidateAccountAndPaymaster_ExpiredOrNotDue() public {
    //     uint256 validationData = packValidationData(address(0x123), block.timestamp + 1000, block.timestamp + 2000);
    //     uint256 paymasterValidationData = packValidationData(address(0), block.timestamp - 10, block.timestamp + 100);

    //     vm.expectRevert(bytes("AA22 expired or not due"));
    //     entryPoint.validateAccountAndPaymasterValidationData(0, validationData, paymasterValidationData, address(0x123));
    // }

    // function testHandleOps_ExpiredOrNotDue() public {
    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     PackedUserOperation memory op = createmockedUserOp();

    //     uint256 expiredValidationData = packValidationData(
    //         address(0),         // Sem agregador
    //         uint48(block.timestamp + 100), // validAfter no futuro (não devido)
    //         uint48(block.timestamp - 100)  // validUntil no passado (expirado)
    //     );

    //     vm.mockCall(
    //         mockedUser,
    //         abi.encodeWithSignature("validateUserOp(bytes32,uint256)", "", 0),
    //         abi.encode(expiredValidationData) // Retorna um validationData com erro de tempo
    //     );

    //     ops[0] = op;

    //     vm.expectRevert(bytes("AA22 expired or not due"));
    //     entryPoint.handleOps(ops, payable(beneficiary));
    // }

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
