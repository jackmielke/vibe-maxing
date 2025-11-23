// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../../contracts/CrossChainSwapComposer.sol";

/**
 * @title DeployComposer
 * @notice Deploy CrossChainSwapComposer on Base Chain
 * 
 * Usage:
 * forge script scripts/deploy/DeployComposer.s.sol:DeployComposer --broadcast --rpc-url $BASE_RPC
 * 
 * Required env vars:
 * - DEPLOYER_PRIVATE_KEY
 * - AQUA_ADDRESS (Aqua Router on Base)
 * - AMM_ADDRESS (StableswapAMM on Base)
 * - STARGATE_USDC_BASE
 * - STARGATE_USDT_BASE
 */
contract DeployComposer is Script {
    function run() external returns (address composer) {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address aqua = vm.envAddress("AQUA_ADDRESS");
        address amm = vm.envAddress("AMM_ADDRESS");
        address stargateUSDC = vm.envAddress("STARGATE_USDC_BASE");
        address stargateUSDT = vm.envAddress("STARGATE_USDT_BASE");

        vm.startBroadcast(deployerPk);

        console.log("=== Deploying CrossChainSwapComposer on Base ===");
        console.log("Aqua Router:", aqua);
        console.log("Stableswap AMM:", amm);
        console.log("Stargate USDC:", stargateUSDC);
        console.log("Stargate USDT:", stargateUSDT);

        CrossChainSwapComposer composerContract = new CrossChainSwapComposer(
            aqua,
            amm,
            stargateUSDC,
            stargateUSDT
        );

        composer = address(composerContract);

        console.log("=== CrossChainSwapComposer Deployed ===");
        console.log("Address:", composer);
        console.log("");
        console.log("Next steps:");
        console.log("1. Set as trusted delegate in Aqua:");
        console.log("   cast send --rpc-url $BASE_RPC $AQUA_ADDRESS");
        console.log("   'setTrustedDelegate(address,bool)' ", composer, " true");
        console.log("");
        console.log("2. Send some ETH to composer for return gas fees:");
        console.log("   cast send --rpc-url $BASE_RPC --value 0.01ether", composer);
        console.log("");
        console.log("3. Update IntentPool with composer address (on World Chain):");
        console.log("   cast send --rpc-url $WORLD_RPC $INTENT_POOL");
        console.log("   'setComposer(address)' ", composer);

        vm.stopBroadcast();
    }
}

