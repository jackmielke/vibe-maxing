// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin, MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";

/**
 * @title IAqua
 * @notice Interface for Aqua protocol
 */
interface IAqua {
    function ship(
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash);

    function shipOnBehalfOf(
        address maker,
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash);
}

/**
 * @title AquaStrategyComposer
 * @notice Enables cross-chain strategy shipping for Aqua protocol
 * @dev Integrates with Aqua to actually ship strategies on destination chain
 *
 * Flow:
 * 1. LP on Ethereum calls shipStrategyToChain()
 * 2. Message sent via LayerZero to destination chain
 * 3. Destination chain's Composer receives message via lzReceive()
 * 4. Composer resolves token IDs to addresses and calls Aqua.ship()
 * 5. Strategy is shipped on destination chain with virtual liquidity
 */
contract AquaStrategyComposer is OApp, OAppOptionsType3 {
    // ══════════════════════════════════════════════════════════════════════════════
    // Events
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Emitted when a cross-chain strategy ship is initiated
    event CrossChainShipInitiated(address indexed maker, uint32 indexed dstEid, bytes32 strategyHash, bytes32 guid);

    /// @notice Emitted when a cross-chain strategy ship is confirmed and executed
    event CrossChainShipExecuted(
        address indexed maker,
        uint32 indexed srcEid,
        bytes32 strategyHash,
        bytes32 guid,
        address app,
        address[] tokens
    );

    /// @notice Emitted when a strategy ship fails on destination
    event CrossChainShipFailed(bytes32 indexed guid, uint32 indexed srcEid, string reason);

    /// @notice Emitted when a token is registered
    event TokenRegistered(bytes32 indexed canonicalId, address indexed token);

    // ══════════════════════════════════════════════════════════════════════════════
    // Errors
    // ══════════════════════════════════════════════════════════════════════════════

    error InvalidDestinationChain(uint32 dstEid);
    error InvalidAppAddress(address app);
    error InsufficientFee(uint256 required, uint256 provided);
    error OnlySelf(address caller);
    error TokenNotMapped(bytes32 canonicalId);
    error AquaNotSet();

    // ══════════════════════════════════════════════════════════════════════════════
    // State Variables
    // ══════════════════════════════════════════════════════════════════════════════

    /// @notice Aqua protocol address on this chain
    IAqua public aqua;

    /// @notice Token registry: canonical ID => local token address
    /// @dev e.g., keccak256("USDC") => 0xUSDC_address_on_this_chain
    mapping(bytes32 canonicalId => address token) public tokenRegistry;

    /// @notice Mapping of supported destination chains
    mapping(uint32 eid => bool supported) public supportedChains;

    /// @notice Mapping of whitelisted app addresses per chain
    mapping(uint32 eid => mapping(address app => bool whitelisted)) public whitelistedApps;

    /// @notice Nonce for tracking messages per maker
    mapping(address maker => uint256 nonce) public makerNonces;

    /// @notice Tracking shipped strategies
    struct ShippedStrategy {
        address maker;
        uint32 dstEid;
        bytes32 strategyHash;
        uint256 timestamp;
        bool confirmed;
    }

    mapping(bytes32 guid => ShippedStrategy) public shippedStrategies;

    /// @notice Cross-chain strategy tracking
    struct CrossChainStrategy {
        uint32 sourceEid;
        address sourceMaker;
        bool hasVirtualLiquidity;
        uint256 timestamp;
    }

    mapping(address maker => mapping(bytes32 strategyHash => CrossChainStrategy)) public crossChainStrategies;

    // ══════════════════════════════════════════════════════════════════════════════
    // Constructor
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Initializes the AquaStrategyComposer
     * @param _endpoint LayerZero endpoint address
     * @param _delegate Contract owner/delegate
     * @param _aqua Aqua protocol address (can be set later if not available)
     */
    constructor(address _endpoint, address _delegate, address _aqua) OApp(_endpoint, _delegate) Ownable(_delegate) {
        if (_aqua != address(0)) {
            aqua = IAqua(_aqua);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // External Functions - Sending
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Ships a strategy to another chain via LayerZero message
     * @param dstEid Destination chain endpoint ID
     * @param dstApp Address of the strategy app on destination chain
     * @param strategy Encoded strategy parameters
     * @param tokenIds Canonical token IDs (e.g., keccak256("USDC"))
     * @param amounts Virtual liquidity amounts
     * @param options LayerZero execution options
     * @return receipt Messaging receipt with guid
     */
    function shipStrategyToChain(
        uint32 dstEid,
        address dstApp,
        bytes calldata strategy,
        bytes32[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata options
    ) external payable returns (MessagingReceipt memory receipt) {
        // Validate inputs
        if (!supportedChains[dstEid]) revert InvalidDestinationChain(dstEid);
        if (dstApp == address(0)) revert InvalidAppAddress(dstApp);
        require(tokenIds.length == amounts.length, "Length mismatch");

        // Calculate strategy hash for tracking
        bytes32 strategyHash = keccak256(strategy);

        // Increment nonce for this maker
        uint256 nonce = makerNonces[msg.sender]++;

        // Encode message payload
        bytes memory payload = abi.encode(
            msg.sender, // maker address
            dstApp, // destination app address
            strategy, // strategy bytes
            tokenIds, // canonical token IDs
            amounts, // virtual amounts
            nonce // nonce for ordering
        );

        // Send via LayerZero
        receipt = _lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), payable(msg.sender));

        // Track the shipped strategy
        shippedStrategies[receipt.guid] = ShippedStrategy({
            maker: msg.sender,
            dstEid: dstEid,
            strategyHash: strategyHash,
            timestamp: block.timestamp,
            confirmed: false
        });

        emit CrossChainShipInitiated(msg.sender, dstEid, strategyHash, receipt.guid);
    }

    /**
     * @notice Quotes the fee for shipping a strategy cross-chain
     * @param dstEid Destination chain endpoint ID
     * @param dstApp Address of the strategy app on destination chain
     * @param strategy Encoded strategy parameters
     * @param tokenIds Canonical token IDs
     * @param amounts Virtual liquidity amounts
     * @param options LayerZero execution options
     * @param payInLzToken Whether to pay in LZ token
     * @return fee Messaging fee quote
     */
    function quoteShipStrategy(
        uint32 dstEid,
        address dstApp,
        bytes calldata strategy,
        bytes32[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata options,
        bool payInLzToken
    ) external view returns (MessagingFee memory fee) {
        bytes memory payload = abi.encode(msg.sender, dstApp, strategy, tokenIds, amounts, makerNonces[msg.sender]);

        fee = _quote(dstEid, payload, options, payInLzToken);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Internal Functions - Receiving
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Handles incoming LayerZero messages
     * @dev This is called by the LayerZero endpoint when a message arrives
     * @param _origin Origin information (source chain, sender)
     * @param _guid Global unique identifier for the message
     * @param _message Encoded message payload
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        // Decode the message
        (
            address maker,
            address dstApp,
            bytes memory strategy,
            bytes32[] memory tokenIds,
            uint256[] memory amounts,
            uint256 nonce
        ) = abi.decode(_message, (address, address, bytes, bytes32[], uint256[], uint256));

        // Calculate strategy hash
        bytes32 strategyHash = keccak256(strategy);

        // Try to execute the ship with error handling
        try this.handleShip(_origin.srcEid, _guid, maker, dstApp, strategy, tokenIds, amounts) {
            // Success - event emitted in handleShip
        } catch Error(string memory reason) {
            emit CrossChainShipFailed(_guid, _origin.srcEid, reason);
        } catch {
            emit CrossChainShipFailed(_guid, _origin.srcEid, "Unknown error");
        }
    }

    /**
     * @notice Handles the actual strategy shipping on destination chain
     * @dev External function called via try-catch for better error handling
     * @param srcEid Source chain endpoint ID
     * @param guid Message GUID
     * @param maker LP's address on source chain
     * @param dstApp Strategy app address on this chain
     * @param strategy Encoded strategy parameters
     * @param tokenIds Canonical token IDs
     * @param amounts Virtual liquidity amounts
     */
    function handleShip(
        uint32 srcEid,
        bytes32 guid,
        address maker,
        address dstApp,
        bytes memory strategy,
        bytes32[] memory tokenIds,
        uint256[] memory amounts
    ) external {
        // Only callable by this contract (via try-catch)
        if (msg.sender != address(this)) revert OnlySelf(msg.sender);

        // Ensure Aqua is set
        if (address(aqua) == address(0)) revert AquaNotSet();

        // Resolve canonical token IDs to local token addresses
        address[] memory tokens = new address[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokens[i] = tokenRegistry[tokenIds[i]];
            if (tokens[i] == address(0)) revert TokenNotMapped(tokenIds[i]);
        }

        // Call Aqua.shipOnBehalfOf() to ship the strategy on behalf of the remote maker
        bytes32 strategyHash = aqua.shipOnBehalfOf(maker, dstApp, strategy, tokens, amounts);

        // Record cross-chain strategy info
        crossChainStrategies[maker][strategyHash] = CrossChainStrategy({
            sourceEid: srcEid,
            sourceMaker: maker,
            hasVirtualLiquidity: true,
            timestamp: block.timestamp
        });

        // Emit success event
        emit CrossChainShipExecuted(maker, srcEid, strategyHash, guid, dstApp, tokens);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Admin Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Sets the Aqua protocol address
     * @param _aqua Aqua protocol address
     */
    function setAqua(address _aqua) external onlyOwner {
        require(_aqua != address(0), "Invalid Aqua address");
        aqua = IAqua(_aqua);
    }

    /**
     * @notice Registers a token mapping (canonical ID => local address)
     * @param canonicalId Canonical token ID (e.g., keccak256("USDC"))
     * @param token Local token address on this chain
     */
    function registerToken(bytes32 canonicalId, address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        tokenRegistry[canonicalId] = token;
        emit TokenRegistered(canonicalId, token);
    }

    /**
     * @notice Batch register multiple tokens
     * @param canonicalIds Array of canonical token IDs
     * @param tokens Array of local token addresses
     */
    function registerTokens(bytes32[] calldata canonicalIds, address[] calldata tokens) external onlyOwner {
        require(canonicalIds.length == tokens.length, "Length mismatch");
        for (uint256 i = 0; i < canonicalIds.length; i++) {
            require(tokens[i] != address(0), "Invalid token address");
            tokenRegistry[canonicalIds[i]] = tokens[i];
            emit TokenRegistered(canonicalIds[i], tokens[i]);
        }
    }

    /**
     * @notice Adds support for a destination chain
     * @param eid Endpoint ID to support
     */
    function addSupportedChain(uint32 eid) external onlyOwner {
        supportedChains[eid] = true;
    }

    /**
     * @notice Removes support for a destination chain
     * @param eid Endpoint ID to remove
     */
    function removeSupportedChain(uint32 eid) external onlyOwner {
        supportedChains[eid] = false;
    }

    /**
     * @notice Whitelists an app address on a destination chain
     * @param eid Endpoint ID
     * @param app App address to whitelist
     */
    function whitelistApp(uint32 eid, address app) external onlyOwner {
        whitelistedApps[eid][app] = true;
    }

    /**
     * @notice Removes an app from whitelist
     * @param eid Endpoint ID
     * @param app App address to remove
     */
    function removeApp(uint32 eid, address app) external onlyOwner {
        whitelistedApps[eid][app] = false;
    }

    /**
     * @notice Allows owner to withdraw any stuck native tokens
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
