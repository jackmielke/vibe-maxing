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
 * @notice Executes cross-chain swaps after tokens arrive via Stargate
 * 
 * Architecture (inspired by AaveV3Composer):
 * 1. Trader sends tokens via Stargate OFT with composeMsg
 * 2. Stargate delivers tokens to this contract
 * 3. LayerZero Endpoint calls lzCompose()
 * 4. This contract executes swap on Base using arrived tokens
 * 5. Uses pullOnBehalfOf/pushOnBehalfOf to update Aqua
 * 6. Sends proceeds back to trader via Stargate
 * 
 * Flow:
 * World Chain: Trader → Stargate.send(composeMsg) → Tokens bridge
 * Base Chain: Tokens arrive → lzCompose() → Execute swap → Bridge back
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

    /// @notice Stargate OFT for tokenIn (USDC)
    address public immutable OFT_IN;

    /// @notice Underlying ERC20 for tokenIn
    address public immutable TOKEN_IN;

    /// @notice Stargate OFT for tokenOut (USDT)
    address public immutable OFT_OUT;

    /// @notice Underlying ERC20 for tokenOut
    address public immutable TOKEN_OUT;

    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════

    error OnlyValidComposerCaller(address sender);
    error OnlyEndpoint(address sender);
    error OnlySelf(address sender);
    error OnlyAMM(address sender);
    error SwapExecutionFailed(bytes32 swapId);

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event SwapExecuted(bytes32 indexed guid, address trader, uint256 amountIn, uint256 amountOut);
    event SwapFailed(bytes32 indexed guid, address trader, uint256 amountIn);
    event Refunded(bytes32 indexed guid, address trader, uint256 amount);

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
    constructor(
        address _aqua,
        address _amm,
        address _oftIn,
        address _oftOut
    ) {
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
    // LayerZero Compose - Main Entry Point
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Called by LayerZero Endpoint after Stargate delivers tokens
     * @dev Message format from OFT:
     *      | nonce(64) | srcEid(32) | amountLD(128) | composeFrom(256) | composeMsg(bytes) |
     *      
     *      composeMsg contains: (address trader, address LP, bytes32 strategyHash, uint256 minAmountOut)
     * 
     * @param _sender Address of the Stargate OFT that sent tokens
     * @param _guid Message identifier
     * @param _message Encoded compose payload
     */
    function lzCompose(
        address _sender,
        bytes32 _guid,
        bytes calldata _message,
        address /* _executor */,
        bytes calldata /* _extraData */
    ) external payable {
        // Authenticate: only trusted Stargate OFT via Endpoint
        if (_sender != OFT_IN) revert OnlyValidComposerCaller(_sender);
        if (msg.sender != ENDPOINT) revert OnlyEndpoint(msg.sender);

        // Decode amount in local decimals
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);

        // Try to execute swap, refund if it fails
        try this.handleCompose{ value: msg.value }(_guid, _message, amountLD) {
            // Success handled in handleCompose
        } catch {
            _refundToTrader(_message, amountLD, tx.origin, msg.value);
            emit Refunded(_guid, tx.origin, amountLD);
        }
    }

    /**
     * @notice Handles the swap execution (external for try-catch)
     * @param _guid Message identifier
     * @param _message Original OFT message
     * @param _amountLD Amount of tokenIn received
     */
    function handleCompose(
        bytes32 _guid,
        bytes calldata _message,
        uint256 _amountLD
    ) external payable {
        if (msg.sender != address(this)) revert OnlySelf(msg.sender);

        // Decode compose message
        (
            address trader,
            address LP,
            bytes32 strategyHash,
            uint256 minAmountOut
        ) = abi.decode(OFTComposeMsgCodec.composeMsg(_message), (address, address, bytes32, uint256));

        // Build strategy for AMM call
        IStableswapAMM.Strategy memory strategy = IStableswapAMM.Strategy({
            maker: LP,
            token0: TOKEN_IN < TOKEN_OUT ? TOKEN_IN : TOKEN_OUT,
            token1: TOKEN_IN < TOKEN_OUT ? TOKEN_OUT : TOKEN_IN,
            feeBps: 4, // TODO: Get from strategy metadata
            amplificationFactor: 100, // TODO: Get from strategy metadata
            salt: strategyHash // Use strategyHash as salt for now
        });

        bool zeroForOne = TOKEN_IN == strategy.token0;

        // Execute swap
        uint256 amountOut = AMM.swapExactIn(
            strategy,
            zeroForOne,
            _amountLD,
            minAmountOut,
            address(this), // Receive output here
            abi.encode(_guid, trader, LP, strategyHash)
        );

        emit SwapExecuted(_guid, trader, _amountLD, amountOut);

        // Send output token back to trader on World Chain
        _sendToTrader(_message, amountOut, trader, msg.value);
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
        (bytes32 guid, address trader, address LP,) = abi.decode(takerData, (bytes32, address, address, bytes32));

        // Push trader's tokenIn to LP's strategy using trusted delegate
        // Note: tokenIn is already in this contract (received via Stargate)
        AQUA.pushOnBehalfOf(
            LP,             // maker
            address(this),  // delegate (this contract is trusted)
            app,            // AMM app
            strategyHash,
            tokenIn,
            amountIn
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Helper Functions - Bridging Back
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Send output token back to trader on source chain
     */
    function _sendToTrader(
        bytes calldata _message,
        uint256 _amount,
        address _trader,
        uint256 _msgValue
    ) internal {
        SendParam memory sendParam;
        sendParam.dstEid = OFTComposeMsgCodec.srcEid(_message);
        sendParam.to = bytes32(uint256(uint160(_trader)));
        sendParam.amountLD = _amount;
        sendParam.minAmountLD = _amount; // No slippage for return trip

        IOFT(OFT_OUT).send{ value: _msgValue }(
            sendParam,
            MessagingFee({ nativeFee: _msgValue, lzTokenFee: 0 }),
            _trader
        );
    }

    /**
     * @notice Refund input token back to trader on source chain
     */
    function _refundToTrader(
        bytes calldata _message,
        uint256 _amount,
        address _refundAddress,
        uint256 _msgValue
    ) internal {
        SendParam memory refundSendParam;
        refundSendParam.dstEid = OFTComposeMsgCodec.srcEid(_message);
        refundSendParam.to = OFTComposeMsgCodec.composeFrom(_message);
        refundSendParam.amountLD = _amount;
        refundSendParam.minAmountLD = _amount;

        IOFT(OFT_IN).send{ value: _msgValue }(
            refundSendParam,
            MessagingFee({ nativeFee: _msgValue, lzTokenFee: 0 }),
            _refundAddress
        );
    }
}

