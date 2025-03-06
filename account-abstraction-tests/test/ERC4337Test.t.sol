// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "../lib/account-abstraction/contracts/core/UserOperationLib.sol";

contract ERC4337Test is Test {
    EntryPoint public entryPoint;
    address public constant beneficiary = address(0x123);
    address public constant mockedUser = address(0x456);

    function setUp() public {
        entryPoint = new EntryPoint();
    }

    // equivalencia
    function testDepositTo() public {
        uint256 depositAmount = 1 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser);
        uint256 balance = entryPoint.balanceOf(mockedUser);
        assertEq(balance, depositAmount, "Saldo depositado incorreto");
    }

    // fronteira
    function testWithdrawTo() public {
        uint256 depositAmount = 1 ether;
        entryPoint.depositTo{value: depositAmount}(mockedUser);

        // Caso de fronteira: sacar metade do depósito
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(mockedUser);
        entryPoint.withdrawTo(payable(beneficiary), withdrawAmount);
        uint256 remaining = entryPoint.balanceOf(mockedUser);
        assertEq(remaining, depositAmount - withdrawAmount, "Saldo restante incorreto");

        // Tentar sacar mais do que o saldo restante (deve reverter)
        vm.prank(mockedUser);
        vm.expectRevert();
        entryPoint.withdrawTo(payable(beneficiary), remaining + 1 wei);
    }

    function testHandleOps_MaxFeePerGas() public {
        // foi preciso dazer essa criacao pois estava dando erro
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        PackedUserOperation memory op = createmockedUserOp();
        ops[0] = op;
        
        op.gasFees = packGasFees(0, unpackHigh128(op.gasFees));
        vm.expectRevert(); // espera reverter devido a parâmetro inválido
        entryPoint.handleOps(ops, payable(beneficiary));
        
        op = createmockedUserOp();
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
        op.gasFees = packGasFees(1 gwei, 1 gwei);
        // Para accountGasLimits, os 128 bits inferiores serão callGasLimit e os superiores, verificationGasLimit.
        op.accountGasLimits = packGasLimits(100000, 100000);
        op.preVerificationGas = 21000;
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

    // Função auxiliar para extrair os 128 bits inferiores (maxFeePerGas) de um bytes32.
    function unpackLow128(bytes32 packed) internal pure returns (uint256) {
        return uint128(uint256(packed));
    }

    // Função auxiliar para extrair os 128 bits superiores (maxPriorityFeePerGas) de um bytes32.
    function unpackHigh128(bytes32 packed) internal pure returns (uint256) {
        return uint256(packed) >> 128;
    }

    receive() external payable {}
}
