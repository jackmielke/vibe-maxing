// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

/**
 * @title Step3_SettleIntent
 * @notice Trigger settlement to bridge both tokens to Base for swap execution
 * 
 * Usage:
 * forge script scripts/intent/Step3_SettleIntent.s.sol:Step3_SettleIntent --broadcast --rpc-url $WORLD_RPC
 * 
 * Required env vars:
 * - SETTLER_PRIVATE_KEY (can be any address willing to pay gas)
 * - INTENT_POOL_ADDRESS
 * - INTENT_ID
 * - COMPOSE_GAS_LIMIT (optional, default 500000)
 */
contract Step3_SettleIntent is Script {
    function run() external {
        uint256 settlerPk = vm.envUint("SETTLER_PRIVATE_KEY");
        address intentPool = vm.envAddress("INTENT_POOL_ADDRESS");
        bytes32 intentId = vm.envBytes32("INTENT_ID");
        
        uint128 composeGasLimit = 500000;
        if (vm.envExists("COMPOSE_GAS_LIMIT")) {
            composeGasLimit = uint128(vm.envUint("COMPOSE_GAS_LIMIT"));
        }

        address settler = vm.addr(settlerPk);

        console.log("=== Settling Intent ===");
        console.log("Settler:", settler);
        console.log("Intent ID:", vm.toString(intentId));
        console.log("Compose Gas Limit:", composeGasLimit);

        // Quote settlement fee
        (bool quoteSuccess, bytes memory quoteData) = intentPool.staticcall(
            abi.encodeWithSignature(
                "quoteSettlementFee(bytes32,uint128)",
                intentId,
                composeGasLimit
            )
        );
        require(quoteSuccess, "Failed to quote settlement fee");
        uint256 totalFee = abi.decode(quoteData, (uint256));

        // Add 20% buffer for safety
        uint256 feeWithBuffer = (totalFee * 120) / 100;

        console.log("Quoted Fee:", totalFee);
        console.log("Fee with 20% buffer:", feeWithBuffer);
        console.log("Settler balance:", settler.balance);
        require(settler.balance >= feeWithBuffer, "Insufficient balance for fees");

        vm.startBroadcast(settlerPk);

        // Settle intent
        (bool settleSuccess, ) = intentPool.call{ value: feeWithBuffer }(
            abi.encodeWithSignature(
                "settleIntent(bytes32,uint128)",
                intentId,
                composeGasLimit
            )
        );
        require(settleSuccess, "Settlement failed");

        console.log("=== Intent Settling ===");
        console.log("");
        console.log("Next: Wait for LayerZero to bridge tokens to Base");
        console.log("Then: Monitor CrossChainSwapComposer events on Base");
        console.log("");
        console.log("Expected events on Base:");
        console.log("1. PartReceived(intentId, 1, tokenOutAmount) - LP's rUSD arrived");
        console.log("2. PartReceived(intentId, 2, tokenInAmount) - Trader's USDT arrived");
        console.log("3. BothPartsReceived(intentId, tokenInAmount, tokenOutAmount)");
        console.log("4. SwapExecuted(intentId, trader, amountIn, amountOut)");
        console.log("");
        console.log("Finally: Tokens will be bridged back to World Chain");
        console.log("- Trader receives rUSD");
        console.log("- LP receives USDT");

        vm.stopBroadcast();
    }
}

