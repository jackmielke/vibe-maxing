// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import {Script} from "forge-std/Script.sol";

import {AquaRouter} from "../src/AquaRouter.sol";

// solhint-disable no-console
import {console2} from "forge-std/console2.sol";

/**
 * @title DeployAquaRouter
 * @notice Deploys AquaRouter for Aqua protocol
 *
 * Usage:
 *    forge script script/DeployAquaRouter.s.sol:DeployAquaRouter --rpc-url $RPC --broadcast
 *
 * Note: For cross-chain operations, set trusted delegates AFTER deploying AquaStrategyComposer
 *       using the SetTrustedDelegate script.
 *
 * Environment Variables:
 * - DEPLOYER_KEY (required): Private key for deployment
 */
contract DeployAquaRouter is Script {
    function run() external {
        uint256 privKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.rememberKey(privKey);

        console2.log("=================================================");
        console2.log("Deploying AquaRouter");
        console2.log("=================================================");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployer);

        AquaRouter aquaRouter = new AquaRouter();

        vm.stopBroadcast();

        console2.log("\n=================================================");
        console2.log("Deployment Complete!");
        console2.log("=================================================");
        console2.log("AquaRouter:", address(aquaRouter));
        console2.log("Owner:", deployer);
        console2.log("\nNext Steps:");
        console2.log("1. Deploy AquaStrategyComposer");
        console2.log("2. Set Composer as trusted delegate:");
        console2.log("   Use script/SetTrustedDelegate.s.sol");
        console2.log("=================================================");
    }
}
// solhint-enable no-console
