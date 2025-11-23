// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Step1_SubmitIntent
 * @notice Trader submits an intent to swap USDC for USDT
 * 
 * Usage:
 * forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent --broadcast --rpc-url $WORLD_RPC
 * 
 * Required env vars:
 * - TRADER_PRIVATE_KEY
 * - INTENT_POOL_ADDRESS
 * - STRATEGY_HASH
 * - USDC_ADDRESS (World Chain)
 * - USDT_ADDRESS (World Chain)
 * - SWAP_AMOUNT_IN (e.g., 1000000 for 1 USDC)
 */
contract Step1_SubmitIntent is Script {
    function run() external {
        uint256 traderPk = vm.envUint("TRADER_PRIVATE_KEY");
        address intentPool = vm.envAddress("INTENT_POOL_ADDRESS");
        bytes32 strategyHash = vm.envBytes32("STRATEGY_HASH");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address usdt = vm.envAddress("USDT_ADDRESS");
        uint256 amountIn = vm.envUint("SWAP_AMOUNT_IN");
        
        address trader = vm.addr(traderPk);

        vm.startBroadcast(traderPk);

        // Calculate expected output (assuming 1:1 with 0.4% fee)
        // For production, query AMM on Base via RPC
        uint256 expectedOut = (amountIn * 9960) / 10000; // 0.4% fee
        uint256 minOut = (expectedOut * 9950) / 10000; // 0.5% slippage
        uint256 deadline = block.timestamp + 1 hours;

        console.log("=== Submitting Intent ===");
        console.log("Trader:", trader);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Amount In (USDC):", amountIn);
        console.log("Expected Out (USDT):", expectedOut);
        console.log("Min Out (USDT):", minOut);
        console.log("Deadline:", deadline);

        // Approve USDC to IntentPool
        IERC20(usdc).approve(intentPool, amountIn);
        console.log("USDC approved");

        // Submit intent
        (bool success, bytes memory data) = intentPool.call(
            abi.encodeWithSignature(
                "submitIntent(bytes32,address,address,uint256,uint256,uint256,uint256)",
                strategyHash,
                usdc,
                usdt,
                amountIn,
                expectedOut,
                minOut,
                deadline
            )
        );

        require(success, "Submit intent failed");
        bytes32 intentId = abi.decode(data, (bytes32));

        console.log("=== Intent Submitted Successfully ===");
        console.log("Intent ID:", vm.toString(intentId));
        console.log("");
        console.log("Next: LP needs to fulfill this intent");
        console.log("Run: forge script scripts/intent/Step2_FulfillIntent.s.sol");
        console.log("Set env var: INTENT_ID=", vm.toString(intentId));

        vm.stopBroadcast();
    }
}

