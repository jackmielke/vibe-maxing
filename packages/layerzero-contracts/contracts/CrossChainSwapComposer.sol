// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OFTComposeMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import { IOFT, SendParam, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import { IStargateEndpoint } from "./interfaces/IStargateEndpoint.sol";

/**
 * @title IAqua
 * @notice Interface for Aqua protocol
 */
interface IAqua {
    function pullOnBehalfOf(
        address maker,
        address delegate,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address to
    ) external;

    function pushOnBehalfOf(
        address maker,
        address delegate,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount
    ) external;
}

/**
 * @title IStableswapAMM
 * @notice Interface for Stableswap AMM
 */
interface IStableswapAMM {
    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 amplificationFactor;
        bytes32 salt;
    }

    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountOut);
}

/**
 * @title IStableswapCallback
 * @notice Callback interface for Stableswap AMM
 */
interface IStableswapCallback {
    function stableswapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external;
}

/**
 * @title CrossChainSwapComposer
 * @notice Executes cross-chain swaps after DUAL tokens arrive via Stargate
 * @dev Deployed per token pair (e.g., one for USDT/rUSD, another for USDC/DAI)
 *
 * Architecture (Intent-Based with Dual Bridge):
 * 1. IntentPool on World sends TWO token transfers to Base:
 *    - Part 1: LP's tokenOut (e.g., rUSD for trader)
 *    - Part 2: Trader's tokenIn (e.g., USDT for swap)
 * 2. This contract waits for BOTH tokens to arrive
 * 3. When both arrived → Execute swap using AMM
 * 4. During swap: pullOnBehalfOf(LP's tokenOut) + pushOnBehalfOf(Trader's tokenIn)
 * 5. Send both output tokens back to World:
 *    - tokenOut → Trader
 *    - tokenIn → LP (swap proceeds)
 *
 * Flow:
 * World: Intent matched → Dual Stargate.send()
 * Base: Both tokens arrive → lzCompose() x2 → Execute swap → Bridge back x2
 */
contract CrossChainSwapComposer is ILayerZeroComposer, IStableswapCallback {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Immutable State
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Aqua protocol on Base
    IAqua public immutable AQUA;

    /// @notice Stableswap AMM on Base
    IStableswapAMM public immutable AMM;

    /// @notice LayerZero Endpoint (trusted to invoke lzCompose)
    address public immutable ENDPOINT;

    /// @notice Stargate OFT for tokenIn (e.g., USDT)
    address public immutable OFT_IN;

    /// @notice Underlying ERC20 for tokenIn
    address public immutable TOKEN_IN;

    /// @notice Stargate OFT for tokenOut (e.g., rUSD)
    address public immutable OFT_OUT;

    /// @notice Underlying ERC20 for tokenOut
    address public immutable TOKEN_OUT;

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables (Dual Transfer Tracking)
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Tracks dual token arrivals for each intent
    struct DualTransfer {
        uint256 tokenOutAmount; // LP's tokenOut (part 1, e.g., rUSD)
        uint256 tokenInAmount; // Trader's tokenIn (part 2, e.g., USDT)
        address trader;
        address LP;
        bytes32 strategyHash;
        uint256 minAmountOut;
        uint8 partsReceived; // 0, 1, or 2
        uint32 srcEid;
    }

    /// @notice Pending dual transfers by intentId
    mapping(bytes32 => DualTransfer) public pendingTransfers;

    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════

    error OnlyValidComposerCaller(address sender);
    error OnlyEndpoint(address sender);
    error OnlySelf(address sender);
    error OnlyAMM(address sender);
    error SwapExecutionFailed(bytes32 swapId);
    error InvalidPart(uint8 part);
    error IntentAlreadyProcessed(bytes32 intentId);

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event SwapExecuted(bytes32 indexed guid, address trader, uint256 amountIn, uint256 amountOut);
    event SwapFailed(bytes32 indexed guid, address trader, uint256 amountIn);
    event Refunded(bytes32 indexed guid, address trader, uint256 amount);
    event PartReceived(bytes32 indexed intentId, uint8 part, uint256 amount);
    event BothPartsReceived(bytes32 indexed intentId, uint256 tokenInAmount, uint256 tokenOutAmount);

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Deploys the composer and connects to Aqua, AMM, and Stargate
     * @param _aqua Aqua protocol address on Base
     * @param _amm Stableswap AMM address on Base
     * @param _oftIn Stargate OFT for input token (USDC)
     * @param _oftOut Stargate OFT for output token (USDT)
     */
    constructor(address _aqua, address _amm, address _oftIn, address _oftOut) {
        require(_aqua != address(0), "Invalid aqua");
        require(_amm != address(0), "Invalid amm");
        require(_oftIn != address(0), "Invalid oftIn");
        require(_oftOut != address(0), "Invalid oftOut");

        AQUA = IAqua(_aqua);
        AMM = IStableswapAMM(_amm);
        OFT_IN = _oftIn;
        OFT_OUT = _oftOut;

        // Get endpoint from OFT
        ENDPOINT = address(IStargateEndpoint(_oftIn).endpoint());

        // Get underlying tokens
        TOKEN_IN = IOFT(_oftIn).token();
        TOKEN_OUT = IOFT(_oftOut).token();

        // Grant unlimited allowance to Aqua for both tokens
        IERC20(TOKEN_IN).approve(address(AQUA), type(uint256).max);
        IERC20(TOKEN_OUT).approve(address(AQUA), type(uint256).max);

        // Grant unlimited allowance to OFTs for refunds/sending
        IERC20(TOKEN_IN).approve(_oftIn, type(uint256).max);
        IERC20(TOKEN_OUT).approve(_oftOut, type(uint256).max);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // LayerZero Compose - Main Entry Point (Dual Transfer)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Called by LayerZero Endpoint after Stargate delivers tokens
     * @dev This is called TWICE per intent:
     *      1. Part 1: LP's USDT arrives
     *      2. Part 2: Trader's USDC arrives
     *
     *      composeMsg for Part 1: (uint8(1), bytes32 intentId, address LP, uint256 tokenOutAmount)
     *      composeMsg for Part 2: (uint8(2), bytes32 intentId, address trader, address LP, uint256 tokenInAmount, bytes32 strategyHash, uint256 minOut)
     *
     * @param _sender Address of the Stargate OFT that sent tokens
     * @param _guid Message identifier (unique per transfer)
     * @param _message Encoded compose payload
     */
    function lzCompose(
        address _sender,
        bytes32 _guid,
        bytes calldata _message,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) external payable {
        // Authenticate: only trusted Stargate OFTs via Endpoint
        if (_sender != OFT_IN && _sender != OFT_OUT) revert OnlyValidComposerCaller(_sender);
        if (msg.sender != ENDPOINT) revert OnlyEndpoint(msg.sender);

        // Decode amount and compose message
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        uint32 srcEid = OFTComposeMsgCodec.srcEid(_message);

        // Decode part number
        uint8 part = abi.decode(composeMsg, (uint8));

        if (part == 1) {
            // Part 1: LP's USDT (tokenOut)
            (, bytes32 intentId, address LP, uint256 tokenOutAmount) = abi.decode(
                composeMsg,
                (uint8, bytes32, address, uint256)
            );

            _handlePart1(intentId, LP, tokenOutAmount, srcEid);
        } else if (part == 2) {
            // Part 2: Trader's USDC (tokenIn)
            (
                ,
                bytes32 intentId,
                address trader,
                address LP,
                uint256 tokenInAmount,
                bytes32 strategyHash,
                uint256 minOut
            ) = abi.decode(composeMsg, (uint8, bytes32, address, address, uint256, bytes32, uint256));

            _handlePart2(intentId, trader, LP, tokenInAmount, strategyHash, minOut, srcEid);
        } else {
            revert InvalidPart(part);
        }
    }

    /**
     * @notice Handle Part 1: LP's USDT arrival
     */
    function _handlePart1(bytes32 intentId, address LP, uint256 tokenOutAmount, uint32 srcEid) internal {
        DualTransfer storage transfer = pendingTransfers[intentId];

        // Initialize or validate
        if (transfer.partsReceived == 0) {
            transfer.LP = LP;
            transfer.tokenOutAmount = tokenOutAmount;
            transfer.srcEid = srcEid;
            transfer.partsReceived = 1;
        } else {
            require(transfer.LP == LP, "LP mismatch");
            transfer.partsReceived += 1;
        }

        emit PartReceived(intentId, 1, tokenOutAmount);

        // If both parts arrived, execute swap
        if (transfer.partsReceived == 2) {
            _executeDualSwap(intentId);
        }
    }

    /**
     * @notice Handle Part 2: Trader's tokenIn arrival
     */
    function _handlePart2(
        bytes32 intentId,
        address trader,
        address LP,
        uint256 tokenInAmount,
        bytes32 strategyHash,
        uint256 minOut,
        uint32 srcEid
    ) internal {
        DualTransfer storage transfer = pendingTransfers[intentId];

        // Initialize or validate
        if (transfer.partsReceived == 0) {
            transfer.trader = trader;
            transfer.LP = LP;
            transfer.tokenInAmount = tokenInAmount;
            transfer.strategyHash = strategyHash;
            transfer.minAmountOut = minOut;
            transfer.srcEid = srcEid;
            transfer.partsReceived = 1;
        } else {
            require(transfer.trader == trader, "Trader mismatch");
            require(transfer.LP == LP, "LP mismatch");
            transfer.partsReceived += 1;
        }

        emit PartReceived(intentId, 2, tokenInAmount);

        // If both parts arrived, execute swap
        if (transfer.partsReceived == 2) {
            _executeDualSwap(intentId);
        }
    }

    /**
     * @notice Execute swap once both tokens have arrived
     */
    function _executeDualSwap(bytes32 intentId) internal {
        DualTransfer memory transfer = pendingTransfers[intentId];

        if (transfer.partsReceived != 2) revert IntentAlreadyProcessed(intentId);

        emit BothPartsReceived(intentId, transfer.tokenInAmount, transfer.tokenOutAmount);

        // Clear storage to prevent re-execution
        delete pendingTransfers[intentId];

        // Execute swap with try-catch for safety
        try this.handleDualSwap(intentId, transfer) {
            // Success handled in handleDualSwap
        } catch {
            // Refund both parties on failure
            _refundBothParties(transfer);
            emit SwapFailed(intentId, transfer.trader, transfer.tokenInAmount);
        }
    }

    /**
     * @notice Handles the swap execution (external for try-catch)
     */
    function handleDualSwap(bytes32 intentId, DualTransfer memory transfer) external payable {
        if (msg.sender != address(this)) revert OnlySelf(msg.sender);

        // Build strategy for AMM call
        IStableswapAMM.Strategy memory strategy = IStableswapAMM.Strategy({
            maker: transfer.LP,
            token0: TOKEN_IN < TOKEN_OUT ? TOKEN_IN : TOKEN_OUT,
            token1: TOKEN_IN < TOKEN_OUT ? TOKEN_OUT : TOKEN_IN,
            feeBps: 4, // TODO: Get from strategy metadata
            amplificationFactor: 100, // TODO: Get from strategy metadata
            salt: transfer.strategyHash
        });

        bool zeroForOne = TOKEN_IN == strategy.token0;

        // Execute swap
        // This will trigger stableswapCallback() where we push trader's tokenIn
        uint256 amountOut = AMM.swapExactIn(
            strategy,
            zeroForOne,
            transfer.tokenInAmount,
            transfer.minAmountOut,
            address(this), // Receive output here
            abi.encode(intentId, transfer.trader, transfer.LP, transfer.strategyHash)
        );

        emit SwapExecuted(intentId, transfer.trader, transfer.tokenInAmount, amountOut);

        // Send tokenOut to trader on World Chain
        _sendTokenToWorld(TOKEN_OUT, transfer.trader, amountOut, transfer.srcEid);

        // Send tokenIn (swap proceeds) to LP on World Chain
        // LP gets back the trader's tokenIn that was swapped
        _sendTokenToWorld(TOKEN_IN, transfer.LP, transfer.tokenInAmount, transfer.srcEid);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // AMM Callback - Handle Push
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Callback from AMM during swap execution
     * @dev Called after aqua.pull(), expects us to aqua.push()
     */
    function stableswapCallback(
        address tokenIn,
        address, // tokenOut
        uint256 amountIn,
        uint256, // amountOut
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external override {
        if (msg.sender != address(AMM)) revert OnlyAMM(msg.sender);

        // Decode trader info
        (, , address LP, ) = abi.decode(takerData, (bytes32, address, address, bytes32));

        // Push trader's tokenIn to LP's strategy using trusted delegate
        // Note: tokenIn is already in this contract (received via Stargate)
        AQUA.pushOnBehalfOf(
            LP, // maker
            address(this), // delegate (this contract is trusted)
            app, // AMM app
            strategyHash,
            tokenIn,
            amountIn
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Helper Functions - Bridging Back
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Send token back to World Chain
     */
    function _sendTokenToWorld(address token, address recipient, uint256 amount, uint32 dstEid) internal {
        address oft = token == TOKEN_IN ? OFT_IN : OFT_OUT;

        SendParam memory sendParam;
        sendParam.dstEid = dstEid;
        sendParam.to = bytes32(uint256(uint160(recipient)));
        sendParam.amountLD = amount;
        sendParam.minAmountLD = amount; // No slippage for return trip

        // Note: Requires native fee, should be sent by caller
        IOFT(oft).send{ value: address(this).balance / 2 }(
            sendParam,
            MessagingFee({ nativeFee: address(this).balance / 2, lzTokenFee: 0 }),
            recipient
        );
    }

    /**
     * @notice Refund both parties if swap fails
     */
    function _refundBothParties(DualTransfer memory transfer) internal {
        // Refund tokenOut to LP
        if (transfer.tokenOutAmount > 0) {
            _sendTokenToWorld(TOKEN_OUT, transfer.LP, transfer.tokenOutAmount, transfer.srcEid);
        }

        // Refund tokenIn to trader
        if (transfer.tokenInAmount > 0) {
            _sendTokenToWorld(TOKEN_IN, transfer.trader, transfer.tokenInAmount, transfer.srcEid);
        }
    }

    /**
     * @notice Fallback to receive native tokens for gas fees
     */
    receive() external payable {}
}
