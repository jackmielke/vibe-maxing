// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OApp, Origin, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

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
 * @title IAqua
 * @notice Minimal interface for Aqua protocol
 */
interface IAqua {
    function push(
        address maker,
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
 * @title CrossChainSwapProxy
 * @notice Acts as LP's proxy on Base Chain, holds bridged tokens and executes swaps
 * 
 * Architecture:
 * - LP's tokens are physically on World Chain (in LPEscrowVault)
 * - This contract holds bridged tokens on Base Chain
 * - Strategy is shipped on Base with this contract as the "maker"
 * - Aqua on Base sees this contract as a normal LP
 * - This contract executes swaps and handles callbacks
 * 
 * Flow:
 * 1. LP deposits tokens to LPEscrowVault on World
 * 2. Vault bridges tokens to this contract on Base
 * 3. This contract ships strategy to Aqua (tokens stay in this contract)
 * 4. When trader swaps:
 *    - Trader's tokenIn is bridged to Base
 *    - This contract calls AMM.swapExactIn()
 *    - AMM calls aqua.pull(this, tokenOut, amt, trader) ✅
 *    - AMM callbacks to stableswapCallback()
 *    - We call aqua.push(this, app, tokenIn, amt) ✅
 * 5. Trader's tokenOut is bridged back to World
 * 
 * Key: All aqua.pull/push happen on Base where this contract holds the tokens!
 */
contract CrossChainSwapProxy is OApp, IStableswapCallback {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event SwapExecuted(
        bytes32 indexed swapId,
        address indexed trader,
        address indexed maker,
        uint256 amountIn,
        uint256 amountOut
    );

    event TokensReceived(
        bytes32 indexed swapId,
        address token,
        uint256 amount
    );

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Aqua protocol address on Base
    IAqua public immutable AQUA;

    /// @notice Stableswap AMM address on Base
    IStableswapAMM public immutable STABLESWAP_AMM;

    /// @notice Pending swaps
    struct PendingSwap {
        address trader;
        address traderOnSrcChain; // Trader's address on World
        uint32 srcEid; // World chain ID
        bool executed;
    }

    mapping(bytes32 => PendingSwap) public pendingSwaps;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(
        address _endpoint,
        address _delegate,
        address _aqua,
        address _stableswapAmm
    ) OApp(_endpoint, _delegate) {
        AQUA = IAqua(_aqua);
        STABLESWAP_AMM = IStableswapAMM(_stableswapAmm);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Receive Swap Request from World Chain
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Receives bridged tokens and swap instructions from World Chain
     * @dev Called by LayerZero after OFT token transfer completes
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        // Decode swap instruction
        (
            bytes32 swapId,
            address traderOnWorld,
            address maker,
            address token0,
            address token1,
            uint256 amountIn,
            uint256 minAmountOut,
            uint256 feeBps,
            uint256 amplificationFactor,
            bytes32 salt,
            bool zeroForOne
        ) = abi.decode(
            _message,
            (bytes32, address, address, address, address, uint256, uint256, uint256, uint256, bytes32, bool)
        );

        // Store pending swap
        pendingSwaps[swapId] = PendingSwap({
            trader: address(this), // This contract acts as trader on Base
            traderOnSrcChain: traderOnWorld,
            srcEid: _origin.srcEid,
            executed: false
        });

        // Execute swap on Base
        _executeSwap(
            swapId,
            maker,
            token0,
            token1,
            amountIn,
            minAmountOut,
            feeBps,
            amplificationFactor,
            salt,
            zeroForOne
        );
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Execute Swap on Base Chain
    // ══════════════════════════════════════════════════════════════════════════════

    function _executeSwap(
        bytes32 swapId,
        address maker,
        address token0,
        address token1,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 feeBps,
        uint256 amplificationFactor,
        bytes32 salt,
        bool zeroForOne
    ) internal {
        // Build strategy struct
        IStableswapAMM.Strategy memory strategy = IStableswapAMM.Strategy({
            maker: maker,
            token0: token0,
            token1: token1,
            feeBps: feeBps,
            amplificationFactor: amplificationFactor,
            salt: salt
        });

        // Determine tokenIn and tokenOut
        address tokenIn = zeroForOne ? token0 : token1;
        address tokenOut = zeroForOne ? token1 : token0;

        // Approve AMM to spend our tokenIn
        IERC20(tokenIn).approve(address(STABLESWAP_AMM), amountIn);

        // Call AMM swap - this will:
        // 1. Pull LP's tokenOut → this contract
        // 2. Callback to stableswapCallback (below)
        // 3. We push tokenIn → LP in the callback
        uint256 amountOut = STABLESWAP_AMM.swapExactIn(
            strategy,
            zeroForOne,
            amountIn,
            minAmountOut,
            address(this), // Receive tokenOut here
            abi.encode(swapId) // Pass swapId in takerData
        );

        // Mark as executed
        pendingSwaps[swapId].executed = true;

        emit SwapExecuted(swapId, address(this), maker, amountIn, amountOut);

        // TODO: Bridge tokenOut back to World Chain
        // This requires OFT integration or similar bridging mechanism
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Stableswap Callback - Push tokens to LP
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Callback from Stableswap AMM during swap execution
     * @dev This is called after aqua.pull() but before the swap completes
     *      We must push tokenIn to the LP here
     */
    function stableswapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external override {
        // Only callable by the AMM
        require(msg.sender == address(STABLESWAP_AMM), "Only AMM");

        // Approve Aqua to spend tokenIn
        IERC20(tokenIn).approve(address(AQUA), amountIn);

        // Push tokenIn to LP's strategy balance
        // This completes the swap: LP gives tokenOut, receives tokenIn
        AQUA.push(maker, app, strategyHash, tokenIn, amountIn);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Helper: Receive bridged tokens
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Allows contract to receive tokens (for bridging)
     */
    function onTokenReceived(
        bytes32 swapId,
        address token,
        uint256 amount
    ) external {
        emit TokensReceived(swapId, token, amount);
    }
}

