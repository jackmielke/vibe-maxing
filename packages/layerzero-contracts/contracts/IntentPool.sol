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
 *
 * Flow:
 * 1. Trader submits intent and locks tokenIn (USDC)
 * 2. LP fulfills intent and locks tokenOut (USDT)
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

    /// @notice Stargate OFT addresses
    address public stargateUSDC;
    address public stargateUSDT;

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

    event IntentSettling(bytes32 indexed intentId, uint256 usdcAmount, uint256 usdtAmount);

    event IntentCancelled(bytes32 indexed intentId, string reason);

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    constructor(uint32 _baseEid, address _composer, address _stargateUSDC, address _stargateUSDT) Ownable(msg.sender) {
        baseEid = _baseEid;
        composer = _composer;
        stargateUSDC = _stargateUSDC;
        stargateUSDT = _stargateUSDT;
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
     * @param tokenIn Input token address (USDC)
     * @param tokenOut Output token address (USDT)
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
        // Part 1: LP's tokenOut (USDT)
        bytes memory composeMsg1 = abi.encode(
            uint8(1), // Part 1
            intentId,
            intent.LP,
            intent.actualOut
        );

        // Part 2: Trader's tokenIn (USDC) - includes full intent data
        bytes memory composeMsg2 = abi.encode(
            uint8(2), // Part 2
            intentId,
            intent.trader,
            intent.LP,
            intent.amountIn,
            intent.strategyHash,
            intent.minOut
        );

        // Build LayerZero options (note: addExecutorComposeOption, NOT addExecutorLzComposeOption)
        bytes memory options = OptionsBuilder.newOptions().addExecutorComposeOption(0, composeGasLimit, 0);

        // Calculate fee split (50/50)
        uint256 feePerSend = msg.value / 2;

        // Approve Stargate OFTs
        IERC20(intent.tokenOut).approve(stargateUSDT, intent.actualOut);
        IERC20(intent.tokenIn).approve(stargateUSDC, intent.amountIn);

        // Send Part 1: LP's USDT
        SendParam memory sendParam1 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.actualOut,
            minAmountLD: intent.actualOut,
            extraOptions: options,
            composeMsg: composeMsg1,
            oftCmd: ""
        });

        IOFT(stargateUSDT).send{ value: feePerSend }(
            sendParam1,
            MessagingFee({ nativeFee: feePerSend, lzTokenFee: 0 }),
            msg.sender
        );

        // Send Part 2: Trader's USDC
        SendParam memory sendParam2 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountIn,
            minAmountLD: intent.amountIn,
            extraOptions: options,
            composeMsg: composeMsg2,
            oftCmd: ""
        });

        IOFT(stargateUSDC).send{ value: feePerSend }(
            sendParam2,
            MessagingFee({ nativeFee: feePerSend, lzTokenFee: 0 }),
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

        // Quote for USDT send
        SendParam memory sendParam1 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.actualOut,
            minAmountLD: intent.actualOut,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee1 = IOFT(stargateUSDT).quoteSend(sendParam1, false);

        // Quote for USDC send
        SendParam memory sendParam2 = SendParam({
            dstEid: baseEid,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountIn,
            minAmountLD: intent.amountIn,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee2 = IOFT(stargateUSDC).quoteSend(sendParam2, false);

        totalFee = fee1.nativeFee + fee2.nativeFee;
    }
}
