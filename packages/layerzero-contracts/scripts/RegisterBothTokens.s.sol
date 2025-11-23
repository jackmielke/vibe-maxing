// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";

/**
 * @title RegisterBothTokens
 * @notice Registers BOTH USDT and rUSD token mappings on Base Chain Composer
 * @dev Batch registration for efficiency
 *
 * This is the RECOMMENDED way to set up the Composer for USDT/rUSD strategies.
 * It registers both tokens in a single transaction.
 *
 * Usage:
 * forge script scripts/RegisterBothTokens.s.sol:RegisterBothTokens \
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
 * forge script scripts/RegisterBothTokens.s.sol:RegisterBothTokens --rpc-url $BASE_RPC --broadcast
 */
contract RegisterBothTokens is Script {
    // USDT address on Base mainnet (constant)
    address constant USDT_BASE = 0x102d758f688a4C1C5a80b116bD945d4455460282;

    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        address rusdBase = vm.envAddress("rUSD_BASE");

        console.log("=================================================");
        console.log("Batch Token Registration on Base Composer");
        console.log("=================================================");
        console.log("Composer Address:", composerAddress);
        console.log("");

        // Prepare batch registration
        bytes32[] memory canonicalIds = new bytes32[](2);
        address[] memory tokens = new address[](2);

        // USDT
        canonicalIds[0] = keccak256("USDT");
        tokens[0] = USDT_BASE;

        console.log("Token 1: USDT");
        console.log("  Canonical ID:", vm.toString(canonicalIds[0]));
        console.log("  Address:", tokens[0]);
        console.log("");

        // rUSD
        canonicalIds[1] = keccak256("rUSD");
        tokens[1] = rusdBase;

        console.log("Token 2: rUSD");
        console.log("  Canonical ID:", vm.toString(canonicalIds[1]));
        console.log("  Address:", tokens[1]);
        console.log("");

        vm.startBroadcast(deployerPk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));

        // Batch register both tokens
        composer.registerTokens(canonicalIds, tokens);

        console.log("=================================================");
        console.log("SUCCESS! Both Tokens Registered");
        console.log("=================================================");
        console.log("");
        console.log("Verify USDT registration:");
        console.log(
            "cast call",
            composerAddress,
            '"tokenRegistry(bytes32)(address)"',
            vm.toString(canonicalIds[0]),
            "--rpc-url $BASE_RPC"
        );
        console.log("");
        console.log("Verify rUSD registration:");
        console.log(
            "cast call",
            composerAddress,
            '"tokenRegistry(bytes32)(address)"',
            vm.toString(canonicalIds[1]),
            "--rpc-url $BASE_RPC"
        );
        console.log("=================================================");

        vm.stopBroadcast();
    }
}
