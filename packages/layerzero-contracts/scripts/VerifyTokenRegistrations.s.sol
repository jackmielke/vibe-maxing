// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";

/**
 * @title VerifyTokenRegistrations
 * @notice Verifies which tokens are registered on the AquaStrategyComposer
 * @dev Checks USDC and rUSD token mappings
 *
 * Usage:
 * forge script scripts/VerifyTokenRegistrations.s.sol:VerifyTokenRegistrations \
 *   --rpc-url $BASE_RPC
 *
 * Environment Variables:
 * - COMPOSER_ADDRESS: AquaStrategyComposer address on Base
 */
contract VerifyTokenRegistrations is Script {
    function run() external view {
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");

        console.log("=================================================");
        console.log("Token Registration Verification");
        console.log("=================================================");
        console.log("Composer Address:", composerAddress);
        console.log("");

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));

        // Check USDT
        bytes32 usdtId = keccak256("USDT");
        address usdtAddress = composer.tokenRegistry(usdtId);

        console.log("--- USDT ---");
        console.log("Canonical ID:", vm.toString(usdtId));
        console.log("Registered Address:", usdtAddress);

        if (usdtAddress == address(0)) {
            console.log("Status: NOT REGISTERED");
            console.log("Expected: 0x102d758f688a4C1C5a80b116bD945d4455460282");
        } else if (usdtAddress == 0x102d758f688a4C1C5a80b116bD945d4455460282) {
            console.log("Status: REGISTERED CORRECTLY");
        } else {
            console.log("Status: REGISTERED (but unexpected address)");
            console.log("Expected: 0x102d758f688a4C1C5a80b116bD945d4455460282");
        }
        console.log("");

        // Check rUSD
        bytes32 rusdId = keccak256("rUSD");
        address rusdAddress = composer.tokenRegistry(rusdId);

        console.log("--- rUSD ---");
        console.log("Canonical ID:", vm.toString(rusdId));
        console.log("Registered Address:", rusdAddress);

        if (rusdAddress == address(0)) {
            console.log("Status: NOT REGISTERED");
            console.log("Action: Run RegisterRUSD.s.sol script");
        } else {
            console.log("Status: REGISTERED");

            // Verify decimals
            (bool success, bytes memory data) = rusdAddress.staticcall(abi.encodeWithSignature("decimals()"));
            if (success && data.length > 0) {
                uint8 decimals = abi.decode(data, (uint8));
                console.log("Decimals:", decimals);
                if (decimals == 18) {
                    console.log("Decimals: CORRECT (18)");
                } else {
                    console.log("Warning: Expected 18 decimals!");
                }
            }
        }
        console.log("");

        // Summary
        console.log("=================================================");
        console.log("Summary");
        console.log("=================================================");

        if (usdtAddress == address(0)) {
            console.log("ACTION REQUIRED: Register USDT");
            console.log("Run: forge script scripts/RegisterUSDT.s.sol:RegisterUSDT --rpc-url $BASE_RPC --broadcast");
        } else {
            console.log("USDT: OK");
        }

        if (rusdAddress == address(0)) {
            console.log("ACTION REQUIRED: Register rUSD");
            console.log("Run: forge script scripts/RegisterRUSD.s.sol:RegisterRUSD --rpc-url $BASE_RPC --broadcast");
        } else {
            console.log("rUSD: OK");
        }

        console.log("=================================================");
    }
}
