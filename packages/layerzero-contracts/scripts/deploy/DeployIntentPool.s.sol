// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../../contracts/IntentPool.sol";

/**
 * @title DeployIntentPool
 * @notice Deploy IntentPool on World Chain
 *
 * Usage:
 * forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool --broadcast --rpc-url $WORLD_RPC
 *
 * Required env vars:
 * - DEPLOYER_PRIVATE_KEY
 * - BASE_EID (e.g., 30184)
 * - COMPOSER_ADDRESS (CrossChainSwapComposer on Base)
 * - STARGATE_USDT_WORLD
 * - STARGATE_rUSD_WORLD
 */
contract DeployIntentPool is Script {
    function run() external returns (address intentPool) {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint32 baseEid = uint32(vm.envUint("BASE_EID"));
        address composer = vm.envAddress("COMPOSER_ADDRESS");
        address stargateUSDT = vm.envAddress("STARGATE_USDT_WORLD");
        address stargateRUSD = vm.envAddress("STARGATE_rUSD_WORLD");

        vm.startBroadcast(deployerPk);

        console.log("=== Deploying IntentPool on World Chain ===");
        console.log("Base EID:", baseEid);
        console.log("Composer (Base):", composer);
        console.log("Stargate USDT:", stargateUSDT);
        console.log("Stargate rUSD:", stargateRUSD);

        IntentPool pool = new IntentPool(baseEid, composer, stargateUSDT, stargateRUSD);

        intentPool = address(pool);

        console.log("=== IntentPool Deployed ===");
        console.log("Address:", intentPool);
        console.log("");
        console.log("Next steps:");
        console.log("1. Register strategies: forge script scripts/intent/RegisterStrategy.s.sol");
        console.log("2. Submit intents: forge script scripts/intent/Step1_SubmitIntent.s.sol");

        vm.stopBroadcast();
    }
}
