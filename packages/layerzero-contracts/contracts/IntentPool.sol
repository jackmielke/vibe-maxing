// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOFT, SendParam, MessagingFee } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title IntentPool
 * @notice Matches swap intents between traders and LPs on World Chain
 * @dev Deployed per token pair (e.g., one for USDT/rUSD, another for USDC/DAI)
 *
 * Flow:
 * 1. Trader submits intent and locks tokenIn (e.g., USDT)
 * 2. LP fulfills intent and locks tokenOut (e.g., rUSD)
 * 3. Anyone triggers settlement → dual Stargate send to Base
 * 4. CrossChainSwapComposer executes swap on Base
 * 5. Both parties receive their output tokens back
 */
contract IntentPool is Ownable {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    // ══════════════════════════════════════════════════════════════════════════════
    // Types
    // ══════════════════════════════════════════════════════════════════════════════

    enum IntentStatus {
        NONE,
        PENDING, // Trader submitted, waiting for LP
        MATCHED, // LP fulfilled, ready to settle
        SETTLING, // Sent to Base for execution
        SETTLED, // Completed successfully
        CANCELLED // Cancelled or expired
    }

    struct Intent {
        bytes32 id;
        address trader;
        address LP;
        bytes32 strategyHash;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedOut;
        uint256 minOut;
        uint256 actualOut;
        IntentStatus status;
        uint256 deadline;
        uint256 quoteTimestamp;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice All intents
    mapping(bytes32 => Intent) public intents;

    /// @notice Strategy hash → LP address
    mapping(bytes32 => address) public strategyOwners;

    /// @notice Base chain endpoint ID
    uint32 public baseEid;

    /// @notice CrossChainSwapComposer address on Base
    address public composer;

    /// @notice Stargate OFT addresses for token pair
    address public stargateTokenA; // OFT for tokenIn (e.g., USDT)
    address public stargateTokenB; // OFT for tokenOut (e.g., rUSD)

    /// @notice Counter for generating intent IDs
    uint256 public intentCounter;

    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    event IntentSubmitted(
        bytes32 indexed intentId,
        address indexed trader,
        bytes32 indexed strategyHash,
        uint256 amountIn,
        uint256 expectedOut,
        uint256 minOut
    );

    event IntentFulfilled(bytes32 indexed intentId, address indexed LP, uint256 actualOut);

    event IntentSettling(bytes32 indexed intentId, uint256 tokenAAmount, uint256 tokenBAmount);

    event IntentCancelled(bytes32 indexed intentId, string reason);

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(
        uint32 _baseEid,
        address _composer,
        address _stargateTokenA,
        address _stargateTokenB
    ) Ownable(msg.sender) {
        baseEid = _baseEid;
        composer = _composer;
        stargateTokenA = _stargateTokenA;
        stargateTokenB = _stargateTokenB;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Admin Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function setComposer(address _composer) external onlyOwner {
        composer = _composer;
    }

    function setBaseEid(uint32 _baseEid) external onlyOwner {
        baseEid = _baseEid;
    }

    function registerStrategy(bytes32 strategyHash, address LP) external onlyOwner {
        strategyOwners[strategyHash] = LP;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Intent Submission (Trader)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Trader submits a swap intent
     * @param strategyHash Hash of the strategy to swap against
     * @param tokenIn Input token address (e.g., USDT)
     * @param tokenOut Output token address (e.g., rUSD)
     * @param amountIn Amount of tokenIn to swap
     * @param expectedOut Expected output from quote (no slippage)
     * @param minOut Minimum acceptable output (with slippage)
     * @param deadline Intent expiry timestamp
     */
    function submitIntent(
        bytes32 strategyHash,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedOut,
        uint256 minOut,
        uint256 deadline
    ) external returns (bytes32 intentId) {
        require(deadline > block.timestamp, "Invalid deadline");
        require(minOut <= expectedOut, "Invalid slippage");
        require(minOut > 0, "Min output too low");

        address LP = strategyOwners[strategyHash];
        require(LP != address(0), "Strategy not registered");

        // Transfer trader's tokenIn
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Generate intent ID
        intentCounter++;
        intentId = keccak256(abi.encodePacked(msg.sender, strategyHash, amountIn, block.timestamp, intentCounter));

        // Create intent
        intents[intentId] = Intent({
            id: intentId,
            trader: msg.sender,
            LP: LP,
            strategyHash: strategyHash,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            expectedOut: expectedOut,
            minOut: minOut,
            actualOut: 0,
            status: IntentStatus.PENDING,
            deadline: deadline,
            quoteTimestamp: block.timestamp
        });

        emit IntentSubmitted(intentId, msg.sender, strategyHash, amountIn, expectedOut, minOut);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Intent Fulfillment (LP)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice LP fulfills an intent by locking output tokens
     * @param intentId ID of the intent to fulfill
     */
    function fulfillIntent(bytes32 intentId) external {
        Intent storage intent = intents[intentId];

        require(intent.status == IntentStatus.PENDING, "Not pending");
        require(msg.sender == intent.LP, "Not LP for this strategy");
        require(block.timestamp <= intent.deadline, "Intent expired");

        // Use expectedOut as the amount LP provides
        uint256 lpAmount = intent.expectedOut;

        // Transfer LP's tokenOut
        IERC20(intent.tokenOut).safeTransferFrom(msg.sender, address(this), lpAmount);

        // Update intent
        intent.actualOut = lpAmount;
        intent.status = IntentStatus.MATCHED;

        emit IntentFulfilled(intentId, msg.sender, lpAmount);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Settlement (Trigger Dual Stargate Send)
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Trigger settlement by sending both tokens to Base
     * @param intentId ID of the intent to settle
     * @param composeGasLimit Gas limit for lzCompose execution
     */
    function settleIntent(bytes32 intentId, uint128 composeGasLimit) external payable {
        Intent storage intent = intents[intentId];

        require(intent.status == IntentStatus.MATCHED, "Not matched");
        require(block.timestamp <= intent.deadline, "Intent expired");

        intent.status = IntentStatus.SETTLING;

        // Build compose messages for both token sends
        // Part 1: LP's tokenOut (e.g., rUSD)
        bytes memory composeMsg1 = abi.encode(
            uint8(1), // Part 1
            intentId,
            intent.LP,
            intent.actualOut
        );

        // Part 2: Trader's tokenIn (e.g., USDT) - includes full intent data
        bytes memory composeMsg2 = abi.encode(
            uint8(2), // Part 2
            intentId,
            intent.trader,
            intent.LP,
            intent.amountIn,
            intent.strategyHash,
            intent.minOut
        );

        // Build LayerZero options
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, composeGasLimit, 0);

        // Approve Stargate OFTs
        IERC20(intent.tokenOut).approve(stargateTokenB, intent.actualOut);
        IERC20(intent.tokenIn).approve(stargateTokenA, intent.amountIn);

        // Build SendParams for both transfers
        SendParam memory sendParam1 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.actualOut,
            minAmountLD: intent.actualOut, // Simplified for MVP
            extraOptions: options,
            composeMsg: composeMsg1,
            oftCmd: ""
        });

        SendParam memory sendParam2 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountIn,
            minAmountLD: intent.amountIn, // Simplified for MVP
            extraOptions: options,
            composeMsg: composeMsg2,
            oftCmd: ""
        });

        // User must call quoteSettlementFee() first to get the required fee
        // Then send that amount (or more with buffer) as msg.value
        // We quote again to determine the proportional split between the two sends
        MessagingFee memory fee1 = IOFT(stargateTokenB).quoteSend(sendParam1, false);
        MessagingFee memory fee2 = IOFT(stargateTokenA).quoteSend(sendParam2, false);

        uint256 totalQuotedFee = fee1.nativeFee + fee2.nativeFee;

        // Split msg.value proportionally based on quoted fees
        // User should have sent >= totalQuotedFee (recommended: 120% for buffer)
        uint256 value1 = totalQuotedFee > 0 ? (msg.value * fee1.nativeFee) / totalQuotedFee : msg.value / 2;
        uint256 value2 = msg.value - value1;

        // Send Part 1: LP's tokenOut with proportional fee
        IOFT(stargateTokenB).send{ value: value1 }(
            sendParam1,
            MessagingFee({ nativeFee: value1, lzTokenFee: 0 }),
            msg.sender
        );

        // Send Part 2: Trader's tokenIn with proportional fee
        IOFT(stargateTokenA).send{ value: value2 }(
            sendParam2,
            MessagingFee({ nativeFee: value2, lzTokenFee: 0 }),
            msg.sender
        );

        emit IntentSettling(intentId, intent.amountIn, intent.actualOut);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Intent Cancellation
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Cancel an expired or unfulfilled intent
     * @param intentId ID of the intent to cancel
     */
    function cancelIntent(bytes32 intentId) external {
        Intent storage intent = intents[intentId];

        require(intent.status == IntentStatus.PENDING || intent.status == IntentStatus.MATCHED, "Cannot cancel");
        require(block.timestamp > intent.deadline || msg.sender == intent.trader, "Not authorized");

        intent.status = IntentStatus.CANCELLED;

        // Refund trader's tokenIn
        if (intent.amountIn > 0) {
            IERC20(intent.tokenIn).safeTransfer(intent.trader, intent.amountIn);
        }

        // Refund LP's tokenOut if already locked
        if (intent.actualOut > 0) {
            IERC20(intent.tokenOut).safeTransfer(intent.LP, intent.actualOut);
        }

        emit IntentCancelled(intentId, "Cancelled");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // View Functions
    // ══════════════════════════════════════════════════════════════════════════════

    function getIntent(bytes32 intentId) external view returns (Intent memory) {
        return intents[intentId];
    }

    function getStrategyLP(bytes32 strategyHash) external view returns (address) {
        return strategyOwners[strategyHash];
    }

    /**
     * @notice Quote LayerZero fees for settlement
     * @param intentId ID of the intent
     * @param composeGasLimit Gas limit for compose
     */
    function quoteSettlementFee(bytes32 intentId, uint128 composeGasLimit) external view returns (uint256 totalFee) {
        Intent memory intent = intents[intentId];
        require(intent.status == IntentStatus.MATCHED, "Not matched");

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzComposeOption(0, composeGasLimit, 0);

        // Quote for tokenOut send
        SendParam memory sendParam1 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.actualOut,
            minAmountLD: intent.actualOut,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee1 = IOFT(stargateTokenB).quoteSend(sendParam1, false);

        // Quote for tokenIn send
        SendParam memory sendParam2 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountIn,
            minAmountLD: intent.amountIn,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee2 = IOFT(stargateTokenA).quoteSend(sendParam2, false);

        totalFee = fee1.nativeFee + fee2.nativeFee;
    }
}
