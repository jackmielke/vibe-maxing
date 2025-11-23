// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OApp, Origin, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

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
 * @title BaseSettler
 * @notice Settler contract on Base Chain that executes swaps and updates Aqua
 * 
 * Flow:
 * 1. Receives tokens and swap instructions from WorldEscrow
 * 2. Executes swap via AMM (which calls aqua.pull and aqua.push)
 * 3. Uses pullOnBehalfOf/pushOnBehalfOf as trusted delegate
 * 4. Confirms settlement back to WorldEscrow
 */
contract BaseSettler is OApp, IStableswapCallback {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables
    // ══════════════════════════════════════════════════════════════════════════════

    IAqua public immutable AQUA;
    IStableswapAMM public immutable AMM;

    uint32 public worldEid;
    address public worldEscrow;

    mapping(bytes32 => Settlement) public settlements;

    struct Settlement {
        bytes32 swapId;
        address trader;
        address LP;
        bytes32 strategyHash;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        bool executed;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event SettlementReceived(bytes32 indexed swapId);
    event SettlementExecuted(bytes32 indexed swapId, bool success);

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(
        address _endpoint,
        address _delegate,
        address _aqua,
        address _amm,
        uint32 _worldEid,
        address _worldEscrow
    ) OApp(_endpoint, _delegate) {
        AQUA = IAqua(_aqua);
        AMM = IStableswapAMM(_amm);
        worldEid = _worldEid;
        worldEscrow = _worldEscrow;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Admin Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function setWorldEscrow(address _worldEscrow) external onlyOwner {
        worldEscrow = _worldEscrow;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Settlement Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Receive settlement request from WorldEscrow
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        require(_origin.srcEid == worldEid, "Invalid source");

        (
            bytes32 swapId,
            address trader,
            address LP,
            bytes32 strategyHash,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            uint256 amountOut
        ) = abi.decode(_message, (bytes32, address, address, bytes32, address, address, uint256, uint256));

        // Store settlement info
        settlements[swapId] = Settlement({
            swapId: swapId,
            trader: trader,
            LP: LP,
            strategyHash: strategyHash,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            executed: false
        });

        emit SettlementReceived(swapId);

        // Execute settlement
        bool success = _executeSettlement(swapId);

        // Send confirmation back to WorldEscrow
        _confirmSettlement(swapId, success);
    }

    /**
     * @notice Execute settlement by calling AMM swap
     */
    function _executeSettlement(bytes32 swapId) internal returns (bool) {
        Settlement storage settlement = settlements[swapId];

        try this.executeSwap(settlement) returns (uint256) {
            settlement.executed = true;
            emit SettlementExecuted(swapId, true);
            return true;
        } catch {
            emit SettlementExecuted(swapId, false);
            return false;
        }
    }

    /**
     * @notice Execute swap (external for try-catch)
     */
    function executeSwap(Settlement memory settlement) external returns (uint256 amountOut) {
        require(msg.sender == address(this), "Only self");

        // Build strategy
        IStableswapAMM.Strategy memory strategy = IStableswapAMM.Strategy({
            maker: settlement.LP,
            token0: settlement.tokenIn < settlement.tokenOut ? settlement.tokenIn : settlement.tokenOut,
            token1: settlement.tokenIn < settlement.tokenOut ? settlement.tokenOut : settlement.tokenIn,
            feeBps: 4, // TODO: Get from strategy metadata
            amplificationFactor: 100, // TODO: Get from strategy metadata
            salt: bytes32(0)
        });

        bool zeroForOne = settlement.tokenIn == strategy.token0;

        // Execute swap
        // Note: Tokens should already be in this contract (bridged from World)
        amountOut = AMM.swapExactIn(
            strategy,
            zeroForOne,
            settlement.amountIn,
            settlement.amountOut,
            address(this),
            abi.encode(settlement.swapId)
        );

        return amountOut;
    }

    /**
     * @notice Callback from AMM - handle push
     */
    function stableswapCallback(
        address tokenIn,
        address,
        uint256 amountIn,
        uint256,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external override {
        require(msg.sender == address(AMM), "Only AMM");

        bytes32 swapId = abi.decode(takerData, (bytes32));
        Settlement memory settlement = settlements[swapId];

        // Approve Aqua to spend tokenIn
        IERC20(tokenIn).approve(address(AQUA), amountIn);

        // Push trader's tokenIn to LP's strategy using trusted delegate
        AQUA.pushOnBehalfOf(
            settlement.LP,      // maker
            address(this),      // delegate (this contract is trusted)
            app,                // AMM app
            strategyHash,
            tokenIn,
            amountIn
        );
    }

    /**
     * @notice Confirm settlement back to WorldEscrow
     */
    function _confirmSettlement(bytes32 swapId, bool success) internal {
        bytes memory message = abi.encode(swapId, success);

        // Send confirmation (for now, just emit event)
        // In production, would use _lzSend to WorldEscrow
        
        // TODO: Implement actual LZ send
        // _lzSend(worldEid, message, options, fee, refund);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function getSettlement(bytes32 swapId) external view returns (Settlement memory) {
        return settlements[swapId];
    }
}

