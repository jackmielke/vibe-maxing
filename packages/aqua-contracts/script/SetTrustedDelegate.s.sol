// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import {Script} from "forge-std/Script.sol";

import {AquaRouter} from "../src/AquaRouter.sol";

// solhint-disable no-console
import {console2} from "forge-std/console2.sol";

/**
 * @title SetTrustedDelegate
 * @notice Sets or removes trusted delegates for Aqua cross-chain operations
 * 
 * Usage:
 * 1. Add delegate:
 *    AQUA_ADDRESS=0x... DELEGATE_ADDRESS=0x... TRUSTED=true \
 *    forge script script/SetTrustedDelegate.s.sol:SetTrustedDelegate --rpc-url $RPC --broadcast
 * 
 * 2. Remove delegate:
 *    AQUA_ADDRESS=0x... DELEGATE_ADDRESS=0x... TRUSTED=false \
 *    forge script script/SetTrustedDelegate.s.sol:SetTrustedDelegate --rpc-url $RPC --broadcast
 * 
 * Environment Variables:
 * - DEPLOYER_KEY (required): Private key of Aqua owner
 * - AQUA_ADDRESS (required): Address of deployed AquaRouter
 * - DELEGATE_ADDRESS (required): Address to trust/untrust (e.g., AquaStrategyComposer)
 * - TRUSTED (optional): "true" to trust, "false" to revoke (default: true)
 */
contract SetTrustedDelegate is Script {
    function run() external {
        uint256 privKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.rememberKey(privKey);

        address aquaAddress = vm.envAddress("AQUA_ADDRESS");
        address delegateAddress = vm.envAddress("DELEGATE_ADDRESS");
        
        // Default to true if not specified
        bool trusted = true;
        if (vm.envExists("TRUSTED")) {
            string memory trustedStr = vm.envString("TRUSTED");
            trusted = keccak256(bytes(trustedStr)) == keccak256(bytes("true"));
        }

        console2.log("=================================================");
        console2.log("Setting Trusted Delegate");
        console2.log("=================================================");
        console2.log("Caller:", deployer);
        console2.log("AquaRouter:", aquaAddress);
        console2.log("Delegate:", delegateAddress);
        console2.log("Trusted:", trusted);

        AquaRouter aquaRouter = AquaRouter(payable(aquaAddress));

        // Verify caller is owner
        address owner = aquaRouter.owner();
        require(owner == deployer, "Caller is not owner");
        console2.log("✓ Ownership verified");

        vm.startBroadcast(deployer);
        
        aquaRouter.setTrustedDelegate(delegateAddress, trusted);
        
        vm.stopBroadcast();

        console2.log("\n=================================================");
        console2.log(trusted ? "✓ Delegate ADDED" : "✓ Delegate REMOVED");
        console2.log("=================================================");
        
        // Verify the change
        bool isTrusted = aquaRouter.trustedDelegates(delegateAddress);
        console2.log("Current status:", isTrusted);
        require(isTrusted == trusted, "Verification failed");
        console2.log("✓ Verification passed");
        console2.log("=================================================");
    }
}
// solhint-enable no-console

