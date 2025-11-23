// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {
    SafeERC20,
    IERC20
} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

import {IAqua} from "./interfaces/IAqua.sol";
import {Balance, BalanceLib} from "./libs/Balance.sol";

/// @title Aqua - Shared Liquidity Layer
contract Aqua is IAqua {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using BalanceLib for Balance;

    error MaxNumberOfTokensExceeded(
        uint256 tokensCount,
        uint256 maxTokensCount
    );
    error StrategiesMustBeImmutable(address app, bytes32 strategyHash);
    error DockingShouldCloseAllTokens(address app, bytes32 strategyHash);
    error PushToNonActiveStrategyPrevented(
        address maker,
        address app,
        bytes32 strategyHash,
        address token
    );
    error SafeBalancesForTokenNotInActiveStrategy(
        address maker,
        address app,
        bytes32 strategyHash,
        address token
    );
    error UnauthorizedDelegate(address caller);

    uint8 private constant _DOCKED = 0xff;

    mapping(address maker => mapping(address app => mapping(bytes32 strategyHash => mapping(address token => Balance))))
        private _balances; // aka makers' allowances

    /// @notice Trusted delegates that can act on behalf of makers (e.g., cross-chain composer contracts)
    mapping(address => bool) public trustedDelegates;

    /// @notice Owner address for managing trusted delegates
    address public owner;

    /// @notice Emitted when a trusted delegate is added or removed
    event TrustedDelegateSet(address indexed delegate, bool trusted);

    /// @notice Emitted when ownership is transferred
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function rawBalances(
        address maker,
        address app,
        bytes32 strategyHash,
        address token
    ) external view returns (uint248 balance, uint8 tokensCount) {
        return _balances[maker][app][strategyHash][token].load();
    }

    function safeBalances(
        address maker,
        address app,
        bytes32 strategyHash,
        address token0,
        address token1
    ) external view returns (uint256 balance0, uint256 balance1) {
        (uint248 amount0, uint8 tokensCount0) = _balances[maker][app][
            strategyHash
        ][token0].load();
        require(
            tokensCount0 > 0 && tokensCount0 != _DOCKED,
            SafeBalancesForTokenNotInActiveStrategy(
                maker,
                app,
                strategyHash,
                token0
            )
        );
        balance0 = amount0;

        (uint248 amount1, uint8 tokensCount1) = _balances[maker][app][
            strategyHash
        ][token1].load();
        require(
            tokensCount1 > 0 && tokensCount1 != _DOCKED,
            SafeBalancesForTokenNotInActiveStrategy(
                maker,
                app,
                strategyHash,
                token1
            )
        );
        balance1 = amount1;
    }

    /// @notice Transfers ownership to a new address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Sets or removes a trusted delegate
    /// @param delegate Address of the delegate contract
    /// @param trusted True to trust, false to revoke
    function setTrustedDelegate(
        address delegate,
        bool trusted
    ) external onlyOwner {
        trustedDelegates[delegate] = trusted;
        emit TrustedDelegateSet(delegate, trusted);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Public Functions (backward compatible)
    // ══════════════════════════════════════════════════════════════════════════════

    function ship(
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash) {
        return _ship(msg.sender, app, strategy, tokens, amounts);
    }

    /// @notice Ships a strategy on behalf of a maker (for cross-chain operations)
    /// @dev Only callable by trusted delegates (e.g., AquaStrategyComposer)
    function shipOnBehalfOf(
        address maker,
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash) {
        if (!trustedDelegates[msg.sender])
            revert UnauthorizedDelegate(msg.sender);
        return _ship(maker, app, strategy, tokens, amounts);
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Internal Implementation
    // ══════════════════════════════════════════════════════════════════════════════

    function _ship(
        address maker,
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) internal returns (bytes32 strategyHash) {
        strategyHash = keccak256(strategy);
        uint8 tokensCount = tokens.length.toUint8();
        require(
            tokensCount != _DOCKED,
            MaxNumberOfTokensExceeded(tokensCount, _DOCKED)
        );

        emit Shipped(maker, app, strategyHash, strategy);
        for (uint256 i = 0; i < tokens.length; i++) {
            Balance storage balance = _balances[maker][app][strategyHash][
                tokens[i]
            ];
            require(
                balance.tokensCount == 0,
                StrategiesMustBeImmutable(app, strategyHash)
            );
            balance.store(amounts[i].toUint248(), tokensCount);
            emit Pushed(maker, app, strategyHash, tokens[i], amounts[i]);
        }
    }

    function dock(
        address app,
        bytes32 strategyHash,
        address[] calldata tokens
    ) external {
        _dock(msg.sender, app, strategyHash, tokens);
    }

    /// @notice Docks a strategy on behalf of a maker (for cross-chain operations)
    /// @dev Only callable by trusted delegates (e.g., AquaStrategyComposer)
    function dockOnBehalfOf(
        address maker,
        address app,
        bytes32 strategyHash,
        address[] calldata tokens
    ) external {
        if (!trustedDelegates[msg.sender])
            revert UnauthorizedDelegate(msg.sender);
        _dock(maker, app, strategyHash, tokens);
    }

    function _dock(
        address maker,
        address app,
        bytes32 strategyHash,
        address[] calldata tokens
    ) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            Balance storage balance = _balances[maker][app][strategyHash][
                tokens[i]
            ];
            require(
                balance.tokensCount == tokens.length,
                DockingShouldCloseAllTokens(app, strategyHash)
            );
            balance.store(0, _DOCKED);
        }
        emit Docked(maker, app, strategyHash);
    }

    function pull(
        address maker,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address to
    ) external {
        _pull(maker, msg.sender, strategyHash, token, amount, to);
    }

    /// @notice Pulls tokens on behalf of an app (for cross-chain operations)
    /// @dev Only callable by trusted delegates (e.g., AquaStrategyComposer)
    function pullOnBehalfOf(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address to
    ) external {
        if (!trustedDelegates[msg.sender])
            revert UnauthorizedDelegate(msg.sender);
        _pull(maker, app, strategyHash, token, amount, to);
    }

    function _pull(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address to
    ) internal {
        Balance storage balance = _balances[maker][app][strategyHash][token];
        (uint248 prevBalance, uint8 tokensCount) = balance.load();
        balance.store(prevBalance - amount.toUint248(), tokensCount);

        IERC20(token).safeTransferFrom(maker, to, amount);
        emit Pulled(maker, app, strategyHash, token, amount);
    }

    function push(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount
    ) external {
        _push(maker, app, strategyHash, token, amount, msg.sender);
    }

    /// @notice Pushes tokens on behalf of a payer (for cross-chain operations)
    /// @dev Only callable by trusted delegates (e.g., AquaStrategyComposer)
    function pushOnBehalfOf(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address payer
    ) external {
        if (!trustedDelegates[msg.sender])
            revert UnauthorizedDelegate(msg.sender);
        _push(maker, app, strategyHash, token, amount, payer);
    }

    function _push(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address payer
    ) internal {
        Balance storage balance = _balances[maker][app][strategyHash][token];
        (uint248 prevBalance, uint8 tokensCount) = balance.load();
        require(
            tokensCount > 0 && tokensCount != _DOCKED,
            PushToNonActiveStrategyPrevented(maker, app, strategyHash, token)
        );
        balance.store(prevBalance + amount.toUint248(), tokensCount);

        IERC20(token).safeTransferFrom(payer, maker, amount);
        emit Pushed(maker, app, strategyHash, token, amount);
    }
}
