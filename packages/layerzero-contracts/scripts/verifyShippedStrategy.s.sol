// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

/**
 * @title VerifyShippedStrategyScript
 * @notice Verifies that a strategy was successfully shipped on the destination chain
 *
 * Usage:
 * forge script scripts/verifyShippedStrategy.s.sol:VerifyShippedStrategyScript \
 *   --rpc-url $ARB_SEPOLIA_RPC
 *
 * Environment Variables Required:
 * - MAKER_ADDRESS: The LP's address (from source chain)
 * - STRATEGY_HASH: The strategy hash (from shipStrategyToChain output)
 * - AQUA_ADDRESS: Aqua protocol address on destination chain
 * - APP_ADDRESS: Strategy app address (e.g., StableswapAMM)
 * - TOKEN0_ADDRESS: First token address on destination chain
 * - TOKEN1_ADDRESS: Second token address on destination chain
 */
contract VerifyShippedStrategyScript is Script {
    function run() external view {
        // Get parameters
        address maker = vm.envAddress("MAKER_ADDRESS");
        bytes32 strategyHash = vm.envBytes32("STRATEGY_HASH");
        address aqua = vm.envAddress("AQUA_ADDRESS");
        address app = vm.envAddress("APP_ADDRESS");
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");

        console.log("=================================================");
        console.log("Verifying Shipped Strategy");
        console.log("=================================================");
        console.log("Maker:", maker);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Aqua:", aqua);
        console.log("App:", app);
        console.log("Token 0:", token0);
        console.log("Token 1:", token1);
        console.log("");

        // Check balances in Aqua
        console.log("Checking Aqua balances...");

        // Call rawBalances for token0
        (bool success0, bytes memory data0) = aqua.staticcall(
            abi.encodeWithSignature("rawBalances(address,address,bytes32,address)", maker, app, strategyHash, token0)
        );

        if (success0) {
            (uint248 balance0, uint8 tokensCount0) = abi.decode(data0, (uint248, uint8));
            console.log("");
            console.log("Token 0 Balance:", uint256(balance0));
            console.log("Tokens Count:", uint256(tokensCount0));

            if (tokensCount0 > 0 && tokensCount0 != 255) {
                console.log("Status: ACTIVE");
            } else if (tokensCount0 == 255) {
                console.log("Status: DOCKED");
            } else {
                console.log("Status: NOT FOUND");
            }
        } else {
            console.log("Failed to read token 0 balance");
        }

        // Call rawBalances for token1
        (bool success1, bytes memory data1) = aqua.staticcall(
            abi.encodeWithSignature("rawBalances(address,address,bytes32,address)", maker, app, strategyHash, token1)
        );

        if (success1) {
            (uint248 balance1, uint8 tokensCount1) = abi.decode(data1, (uint248, uint8));
            console.log("");
            console.log("Token 1 Balance:", uint256(balance1));
            console.log("Tokens Count:", uint256(tokensCount1));

            if (tokensCount1 > 0 && tokensCount1 != 255) {
                console.log("Status: ACTIVE");
            } else if (tokensCount1 == 255) {
                console.log("Status: DOCKED");
            } else {
                console.log("Status: NOT FOUND");
            }
        } else {
            console.log("Failed to read token 1 balance");
        }

        console.log("");
        console.log("=================================================");

        if (success0 && success1) {
            (uint248 balance0, uint8 tokensCount0) = abi.decode(data0, (uint248, uint8));
            (uint248 balance1, uint8 tokensCount1) = abi.decode(data1, (uint248, uint8));

            if (tokensCount0 > 0 && tokensCount0 != 255 && tokensCount1 > 0 && tokensCount1 != 255) {
                console.log("SUCCESS! Strategy is active on destination chain");
                console.log("Total tokens in strategy:", uint256(tokensCount0));
            } else {
                console.log("WARNING: Strategy not found or not active");
                console.log("Check if:");
                console.log("1. Message was delivered (check LayerZero Scan)");
                console.log("2. Composer has Aqua address set");
                console.log("3. Tokens are registered in Composer");
                console.log("4. Check CrossChainShipExecuted event");
            }
        }

        console.log("=================================================");
    }
}
