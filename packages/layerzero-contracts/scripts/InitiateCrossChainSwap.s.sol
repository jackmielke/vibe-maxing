// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SendParam, MessagingFee, OFTReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { IOFT } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

/**
 * @title InitiateCrossChainSwap
 * @notice Script to initiate a cross-chain swap from World to Base using Stargate
 * 
 * Flow:
 * 1. Trader approves Stargate OFT
 * 2. Trader calls Stargate.send() with composeMsg
 * 3. Stargate bridges tokens to CrossChainSwapComposer on Base
 * 4. LayerZero calls lzCompose() on CrossChainSwapComposer
 * 5. Composer executes swap and sends output back
 * 
 * Environment Variables:
 * - TRADER_PRIVATE_KEY: Trader's private key
 * - STARGATE_OFT_IN: Stargate OFT address for input token (USDC)
 * - DST_EID: Destination chain ID (Base)
 * - COMPOSER: CrossChainSwapComposer address on Base
 * - AMOUNT_IN: Amount to swap
 * - LP_ADDRESS: LP's address
 * - STRATEGY_HASH: Strategy hash
 * - MIN_AMOUNT_OUT: Minimum output amount
 * - COMPOSE_GAS_LIMIT: Gas limit for compose (default: 500000)
 */
contract InitiateCrossChainSwap is Script {
    using OptionsBuilder for bytes;

    function run() external {
        // Load config
        uint256 traderPk = vm.envUint("TRADER_PRIVATE_KEY");
        address trader = vm.addr(traderPk);

        address stargateOftIn = vm.envAddress("STARGATE_OFT_IN");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        address composer = vm.envAddress("COMPOSER");
        uint256 amountIn = vm.envUint("AMOUNT_IN");
        address LP = vm.envAddress("LP_ADDRESS");
        bytes32 strategyHash = vm.envBytes32("STRATEGY_HASH");
        uint256 minAmountOut = vm.envUint("MIN_AMOUNT_OUT");

        // Optional: compose gas limit
        uint128 composeGas = 500000;
        if (vm.envExists("COMPOSE_GAS_LIMIT")) {
            composeGas = uint128(vm.envUint("COMPOSE_GAS_LIMIT"));
        }

        // Optional: refund address
        address refund = trader;
        if (vm.envExists("REFUND_ADDRESS")) {
            refund = vm.envAddress("REFUND_ADDRESS");
        }

        console.log("=== Cross-Chain Swap Initiation ===");
        console.log("Trader:", trader);
        console.log("Amount In:", amountIn);
        console.log("Min Amount Out:", minAmountOut);
        console.log("LP:", LP);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Composer:", composer);
        console.log("Destination EID:", dstEid);

        vm.startBroadcast(traderPk);

        // Step 1: Compose message with swap parameters
        bytes memory composeMsg = abi.encode(
            trader,         // Trader address (to receive output)
            LP,             // LP address
            strategyHash,   // Strategy hash
            minAmountOut    // Minimum output amount
        );

        // Step 2: Build LayerZero options (compose with gas limit)
        bytes memory extraOptions = OptionsBuilder
            .newOptions()
            .addExecutorLzComposeOption(0, composeGas, 0); // index 0, gas limit, no native drop

        // Step 3: Assemble SendParam
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(composer))), // Send to composer
            amountLD: amountIn,
            minAmountLD: 0, // Will be updated after quote
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        // Step 4: Quote to get actual receive amount (accounting for fees)
        (, , OFTReceipt memory oftReceipt) = IOFT(stargateOftIn).quoteOFT(sendParam);
        sendParam.minAmountLD = oftReceipt.amountReceivedLD;

        console.log("Amount to be received on Base:", oftReceipt.amountReceivedLD);

        // Step 5: Quote LayerZero messaging fee
        MessagingFee memory fee = IOFT(stargateOftIn).quoteSend(sendParam, false);
        console.log("Native fee:", fee.nativeFee);

        // Step 6: Approve Stargate OFT if needed
        address token = IOFT(stargateOftIn).token();
        if (token != address(0)) {
            _ensureApproval(token, trader, stargateOftIn, sendParam.amountLD);
            console.log("Token approved:", token);
        }

        // Step 7: Send via Stargate
        console.log("Sending cross-chain swap request...");
        (, OFTReceipt memory finalReceipt) = IOFT(stargateOftIn).send{ value: fee.nativeFee }(
            sendParam,
            fee,
            refund
        );

        console.log("=== Swap Request Sent! ===");
        console.log("Amount received on Base:", finalReceipt.amountReceivedLD);
        console.log("Waiting for compose execution on Base...");
        console.log("Output will be sent back to trader:", trader);

        vm.stopBroadcast();
    }

    function _ensureApproval(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        IERC20 erc20 = IERC20(token);
        if (erc20.allowance(owner, spender) < amount) {
            erc20.approve(spender, type(uint256).max);
            console.log("Approved", spender, "to spend", token);
        }
    }
}

