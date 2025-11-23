// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Step2_FulfillIntent
 * @notice LP fulfills a trader's intent by locking USDT
 * 
 * Usage:
 * forge script scripts/intent/Step2_FulfillIntent.s.sol:Step2_FulfillIntent --broadcast --rpc-url $WORLD_RPC
 * 
 * Required env vars:
 * - LP_PRIVATE_KEY
 * - INTENT_POOL_ADDRESS
 * - INTENT_ID
 * - USDT_ADDRESS (World Chain)
 */
contract Step2_FulfillIntent is Script {
    function run() external {
        uint256 lpPk = vm.envUint("LP_PRIVATE_KEY");
        address intentPool = vm.envAddress("INTENT_POOL_ADDRESS");
        bytes32 intentId = vm.envBytes32("INTENT_ID");
        address usdt = vm.envAddress("USDT_ADDRESS");
        
        address lp = vm.addr(lpPk);

        vm.startBroadcast(lpPk);

        console.log("=== Fulfilling Intent ===");
        console.log("LP:", lp);
        console.log("Intent ID:", vm.toString(intentId));

        // Get intent details
        (bool success, bytes memory data) = intentPool.staticcall(
            abi.encodeWithSignature("getIntent(bytes32)", intentId)
        );
        require(success, "Failed to get intent");

        // Decode intent (matching Intent struct)
        (
            bytes32 id,
            address trader,
            address lpAddress,
            bytes32 strategyHash,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            uint256 expectedOut,
            uint256 minOut,
            uint256 actualOut,
            uint8 status,
            uint256 deadline,
            uint256 quoteTimestamp
        ) = abi.decode(
            data,
            (bytes32, address, address, bytes32, address, address, uint256, uint256, uint256, uint256, uint8, uint256, uint256)
        );

        require(status == 1, "Intent not in PENDING status"); // 1 = PENDING
        require(lpAddress == lp, "Not LP for this strategy");
        require(block.timestamp <= deadline, "Intent expired");

        console.log("Trader:", trader);
        console.log("LP (expected):", lpAddress);
        console.log("Amount In (USDC):", amountIn);
        console.log("Expected Out (USDT):", expectedOut);

        // Approve USDT to IntentPool
        IERC20(usdt).approve(intentPool, expectedOut);
        console.log("USDT approved:", expectedOut);

        // Fulfill intent
        (bool fulfillSuccess, ) = intentPool.call(
            abi.encodeWithSignature("fulfillIntent(bytes32)", intentId)
        );
        require(fulfillSuccess, "Fulfill intent failed");

        console.log("=== Intent Fulfilled Successfully ===");
        console.log("");
        console.log("Next: Trigger settlement to bridge tokens to Base");
        console.log("Run: forge script scripts/intent/Step3_SettleIntent.s.sol");

        vm.stopBroadcast();
    }
}

