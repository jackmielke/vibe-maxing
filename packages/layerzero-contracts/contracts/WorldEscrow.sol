// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { OApp, Origin, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title WorldEscrow
 * @notice Escrow contract on World Chain that facilitates cross-chain swaps
 * 
 * Flow:
 * 1. Trader initiates swap → locks tokenIn
 * 2. LP accepts swap → locks tokenOut
 * 3. Both tokens bridge to BaseSettler on Base
 * 4. BaseSettler executes swap and updates Aqua
 * 5. Proceeds bridge back
 * 6. WorldEscrow distributes to Trader and LP
 */
contract WorldEscrow is OApp {
    using SafeERC20 for IERC20;

    // ══════════════════════════════════════════════════════════════════════════════
    // Types
    // ══════════════════════════════════════════════════════════════════════════════

    enum SwapStatus { 
        NONE,
        PENDING,    // Trader initiated, waiting for LP
        ACCEPTED,   // LP accepted, ready to settle
        SETTLING,   // Bridging to Base
        SETTLED,    // Completed successfully
        FAILED      // Failed, refunded
    }

    struct Swap {
        bytes32 id;
        address trader;
        address LP;
        bytes32 strategyHash;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        SwapStatus status;
        uint256 deadline;
        uint32 baseEid;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables
    // ══════════════════════════════════════════════════════════════════════════════

    mapping(bytes32 => Swap) public swaps;
    mapping(bytes32 => address) public strategyOwners;
    
    uint32 public baseEid;
    address public baseSettler;

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event SwapInitiated(bytes32 indexed swapId, address indexed trader, uint256 amountIn);
    event SwapAccepted(bytes32 indexed swapId, address indexed LP, uint256 amountOut);
    event SwapSettling(bytes32 indexed swapId);
    event SwapSettled(bytes32 indexed swapId);
    event SwapFailed(bytes32 indexed swapId, string reason);

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(
        address _endpoint,
        address _delegate,
        uint32 _baseEid,
        address _baseSettler
    ) OApp(_endpoint, _delegate) {
        baseEid = _baseEid;
        baseSettler = _baseSettler;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Admin Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function setBaseSettler(address _baseSettler) external onlyOwner {
        baseSettler = _baseSettler;
    }

    function registerStrategy(bytes32 strategyHash, address LP) external onlyOwner {
        strategyOwners[strategyHash] = LP;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Trader Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Trader initiates a cross-chain swap
     * @param strategyHash Hash of the strategy on Base
     * @param tokenIn Token to swap from
     * @param tokenOut Token to swap to
     * @param amountIn Amount to swap
     * @param minAmountOut Minimum amount to receive
     * @param deadline Swap expiry timestamp
     */
    function initiateSwap(
        bytes32 strategyHash,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (bytes32 swapId) {
        require(deadline > block.timestamp, "Invalid deadline");
        
        address LP = strategyOwners[strategyHash];
        require(LP != address(0), "Strategy not found");

        // Lock trader's tokenIn
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Generate swap ID
        swapId = keccak256(abi.encodePacked(
            msg.sender,
            strategyHash,
            amountIn,
            block.timestamp,
            block.number
        ));

        // Create swap
        swaps[swapId] = Swap({
            id: swapId,
            trader: msg.sender,
            LP: LP,
            strategyHash: strategyHash,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: minAmountOut, // Will be updated when LP accepts
            status: SwapStatus.PENDING,
            deadline: deadline,
            baseEid: baseEid
        });

        emit SwapInitiated(swapId, msg.sender, amountIn);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // LP Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice LP accepts a swap and locks output tokens
     * @param swapId ID of the swap to accept
     * @param amountOut Amount of tokenOut LP will provide
     */
    function acceptSwap(bytes32 swapId, uint256 amountOut) external {
        Swap storage swap = swaps[swapId];

        require(swap.status == SwapStatus.PENDING, "Not pending");
        require(msg.sender == swap.LP, "Not LP");
        require(block.timestamp <= swap.deadline, "Expired");
        require(amountOut >= swap.amountOut, "Amount too low");

        // Lock LP's tokenOut
        IERC20(swap.tokenOut).safeTransferFrom(msg.sender, address(this), amountOut);

        swap.amountOut = amountOut;
        swap.status = SwapStatus.ACCEPTED;

        emit SwapAccepted(swapId, msg.sender, amountOut);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Settlement Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Trigger settlement on Base (anyone can call)
     * @param swapId ID of the swap to settle
     * @param options LayerZero options for cross-chain message
     */
    function settleSwap(bytes32 swapId, bytes calldata options) external payable {
        Swap storage swap = swaps[swapId];

        require(swap.status == SwapStatus.ACCEPTED, "Not accepted");

        swap.status = SwapStatus.SETTLING;

        // Encode settlement message
        bytes memory message = abi.encode(
            swapId,
            swap.trader,
            swap.LP,
            swap.strategyHash,
            swap.tokenIn,
            swap.tokenOut,
            swap.amountIn,
            swap.amountOut
        );

        // Send message to BaseSettler
        _lzSend(
            baseEid,
            message,
            options,
            MessagingFee(msg.value, 0),
            payable(msg.sender)
        );

        emit SwapSettling(swapId);
        
        // Note: Actual token bridging would happen via OFT
        // For now, tokens stay locked until settlement confirmation
    }

    /**
     * @notice Receive settlement result from Base
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        require(_origin.srcEid == baseEid, "Invalid source");

        (bytes32 swapId, bool success) = abi.decode(_message, (bytes32, bool));

        Swap storage swap = swaps[swapId];

        if (success) {
            swap.status = SwapStatus.SETTLED;

            // Distribute tokens
            IERC20(swap.tokenOut).safeTransfer(swap.trader, swap.amountOut);
            IERC20(swap.tokenIn).safeTransfer(swap.LP, swap.amountIn);

            emit SwapSettled(swapId);
        } else {
            swap.status = SwapStatus.FAILED;

            // Refund both parties
            IERC20(swap.tokenIn).safeTransfer(swap.trader, swap.amountIn);
            IERC20(swap.tokenOut).safeTransfer(swap.LP, swap.amountOut);

            emit SwapFailed(swapId, "Settlement failed");
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function getSwap(bytes32 swapId) external view returns (Swap memory) {
        return swaps[swapId];
    }

    function getStrategyOwner(bytes32 strategyHash) external view returns (address) {
        return strategyOwners[strategyHash];
    }
}

