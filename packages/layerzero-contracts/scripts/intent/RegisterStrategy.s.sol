// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";

/**
 * @title RegisterStrategy
 * @notice Register a strategy hash with its LP address in IntentPool
 * 
 * Usage:
 * forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy --broadcast --rpc-url $WORLD_RPC
 * 
 * Required env vars:
 * - DEPLOYER_PRIVATE_KEY (IntentPool owner)
 * - INTENT_POOL_ADDRESS
 * - STRATEGY_HASH
 * - LP_ADDRESS
 */
contract RegisterStrategy is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address intentPool = vm.envAddress("INTENT_POOL_ADDRESS");
        bytes32 strategyHash = vm.envBytes32("STRATEGY_HASH");
        address lpAddress = vm.envAddress("LP_ADDRESS");

        vm.startBroadcast(deployerPk);

        console.log("=== Registering Strategy ===");
        console.log("IntentPool:", intentPool);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("LP Address:", lpAddress);

        // Register strategy
        (bool success, ) = intentPool.call(
            abi.encodeWithSignature(
                "registerStrategy(bytes32,address)",
                strategyHash,
                lpAddress
            )
        );
        require(success, "Registration failed");

        console.log("=== Strategy Registered Successfully ===");

        // Verify registration
        (bool verifySuccess, bytes memory data) = intentPool.staticcall(
            abi.encodeWithSignature("getStrategyLP(bytes32)", strategyHash)
        );
        require(verifySuccess, "Failed to verify");
        address registeredLP = abi.decode(data, (address));
        require(registeredLP == lpAddress, "LP mismatch");

        console.log("Verified - Strategy is registered to LP:", registeredLP);

        vm.stopBroadcast();
    }
}

