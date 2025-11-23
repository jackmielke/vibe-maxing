// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";

/**
 * @title RegisterUSDT
 * @notice Registers USDT token mapping on Base Chain Composer
 * @dev Maps canonical token ID keccak256("USDT") to actual USDT address on Base
 *
 * This is a ONE-TIME setup per token. Once registered, all future strategies
 * can use USDT without additional registration.
 *
 * Usage:
 * forge script scripts/RegisterUSDT.s.sol:RegisterUSDT \
 *   --rpc-url $BASE_RPC \
 *   --broadcast
 *
 * Environment Variables Required:
 * - DEPLOYER_PRIVATE_KEY: Owner of the AquaStrategyComposer
 * - COMPOSER_ADDRESS: AquaStrategyComposer address on Base
 *
 * Example:
 * export DEPLOYER_PRIVATE_KEY=0x...
 * export COMPOSER_ADDRESS=0x...
 * forge script scripts/RegisterUSDT.s.sol:RegisterUSDT --rpc-url $BASE_RPC --broadcast
 */
contract RegisterUSDT is Script {
    // USDT address on Base mainnet
    address constant USDT_BASE = 0x102d758f688a4C1C5a80b116bD945d4455460282;

    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");

        console.log("=================================================");
        console.log("Registering USDT Token on Base Composer");
        console.log("=================================================");
        console.log("Composer Address:", composerAddress);
        console.log("USDT Address:", USDT_BASE);

        // Calculate canonical ID
        bytes32 usdtId = keccak256("USDT");
        console.log("Canonical ID:", vm.toString(usdtId));

        vm.startBroadcast(deployerPk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));
        
        // Register USDT token mapping
        composer.registerToken(usdtId, USDT_BASE);

        console.log("\n=================================================");
        console.log("SUCCESS! USDT Registered");
        console.log("=================================================");
        console.log("");
        console.log("Verify registration:");
        console.log("cast call", composerAddress);
        console.log('  "tokenRegistry(bytes32)(address)"');
        console.log("  ", vm.toString(usdtId));
        console.log("  --rpc-url $BASE_RPC");
        console.log("");
        console.log("Expected output:", USDT_BASE);
        console.log("=================================================");

        vm.stopBroadcast();
    }
}

