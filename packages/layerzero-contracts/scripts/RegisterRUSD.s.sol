// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";

/**
 * @title RegisterRUSD
 * @notice Registers rUSD token mapping on Base Chain Composer
 * @dev Maps canonical token ID keccak256("rUSD") to actual rUSD address on Base
 *
 * This is a ONE-TIME setup per token. Once registered, all future strategies
 * can use rUSD without additional registration.
 *
 * Usage:
 * forge script scripts/RegisterRUSD.s.sol:RegisterRUSD \
 *   --rpc-url $BASE_RPC \
 *   --broadcast
 *
 * Environment Variables Required:
 * - DEPLOYER_PRIVATE_KEY: Owner of the AquaStrategyComposer
 * - COMPOSER_ADDRESS: AquaStrategyComposer address on Base
 * - rUSD_BASE: rUSD token address on Base Chain
 *
 * Example:
 * export DEPLOYER_PRIVATE_KEY=0x...
 * export COMPOSER_ADDRESS=0x...
 * export rUSD_BASE=0x...
 * forge script scripts/RegisterRUSD.s.sol:RegisterRUSD --rpc-url $BASE_RPC --broadcast
 */
contract RegisterRUSD is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        address rusdBase = vm.envAddress("rUSD_BASE");

        console.log("=================================================");
        console.log("Registering rUSD Token on Base Composer");
        console.log("=================================================");
        console.log("Composer Address:", composerAddress);
        console.log("rUSD Address:", rusdBase);

        // Calculate canonical ID
        bytes32 rusdId = keccak256("rUSD");
        console.log("Canonical ID:", vm.toString(rusdId));

        vm.startBroadcast(deployerPk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));
        
        // Register rUSD token mapping
        composer.registerToken(rusdId, rusdBase);

        console.log("\n=================================================");
        console.log("SUCCESS! rUSD Registered");
        console.log("=================================================");
        console.log("");
        console.log("Verify registration:");
        console.log("cast call", composerAddress);
        console.log('  "tokenRegistry(bytes32)(address)"');
        console.log("  ", vm.toString(rusdId));
        console.log("  --rpc-url $BASE_RPC");
        console.log("");
        console.log("Expected output:", rusdBase);
        console.log("=================================================");

        vm.stopBroadcast();
    }

    /**
     * @notice Batch register multiple tokens at once
     * @dev Useful for initial setup or adding multiple tokens
     */
    function registerMultipleTokens() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");

        console.log("=== Batch Token Registration ===");

        // Define tokens to register
        bytes32[] memory canonicalIds = new bytes32[](2);
        address[] memory tokens = new address[](2);

        // USDC
        canonicalIds[0] = keccak256("USDC");
        tokens[0] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base

        // rUSD
        canonicalIds[1] = keccak256("rUSD");
        tokens[1] = vm.envAddress("rUSD_BASE");

        console.log("Registering", canonicalIds.length, "tokens...");

        vm.startBroadcast(deployerPk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));
        composer.registerTokens(canonicalIds, tokens);

        console.log("=== All Tokens Registered ===");

        vm.stopBroadcast();
    }
}

