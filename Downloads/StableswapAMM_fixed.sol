// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAqua} from "aqua/interfaces/IAqua.sol";
import {AquaApp} from "aqua/AquaApp.sol";
import {TransientLock, TransientLockLib} from "aqua/libs/ReentrancyGuard.sol";

/// @title StableswapAMM
/// @notice Implements a Curve-style stableswap AMM optimized for assets with similar prices
/// @dev Implements the actual StableSwap invariant: An^n ∑x_i + D = An^n D + D^(n+1)/(n^n ∏x_i)
contract StableswapAMM is AquaApp {
    using Math for uint256;
    using TransientLockLib for TransientLock;

    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);
    error ConvergenceFailed();

    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 amplificationFactor; // A parameter: higher = flatter near 1:1, lower = more curved
        bytes32 salt;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant N_COINS = 2; // For 2-asset pools
    uint256 internal constant MAX_LOOP_ITERATIONS = 255;

    constructor(IAqua aqua_) AquaApp(aqua_) {}

    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balanceIn, uint256 balanceOut) = _getInAndOut(
            strategy,
            strategyHash,
            zeroForOne
        );
        amountOut = _quoteExactIn(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountIn
        );
    }

    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balanceIn, uint256 balanceOut) = _getInAndOut(
            strategy,
            strategyHash,
            zeroForOne
        );
        amountIn = _quoteExactOut(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountOut
        );
    }

    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountOut)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        ) = _getInAndOut(strategy, strategyHash, zeroForOne);

        amountOut = _quoteExactIn(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountIn
        );
        require(
            amountOut >= amountOutMin,
            InsufficientOutputAmount(amountOut, amountOutMin)
        );

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IStableswapCallback(msg.sender).stableswapCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );
        _safeCheckAquaPush(
            strategy.maker,
            strategyHash,
            tokenIn,
            balanceIn + amountIn
        );
    }

    function swapExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountIn)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        ) = _getInAndOut(strategy, strategyHash, zeroForOne);

        amountIn = _quoteExactOut(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountOut
        );
        require(
            amountIn <= amountInMax,
            ExcessiveInputAmount(amountIn, amountInMax)
        );

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IStableswapCallback(msg.sender).stableswapCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );
        _safeCheckAquaPush(
            strategy.maker,
            strategyHash,
            tokenIn,
            balanceIn + amountIn
        );
    }

    /// @notice Calculate D, the invariant for the current balances
    /// @dev For 2 coins: An²(x + y) + D = An²D + D³/(4xy)
    function _getD(
        uint256 A,
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        uint256 Ann = A * N_COINS * N_COINS; // A * n^n = A * 4
        uint256 S = x + y; // Sum of balances
        
        if (S == 0) return 0;
        
        uint256 D = S;
        uint256 D_prev;
        
        // Newton's method to find D
        // We're solving: f(D) = An²D + D³/(4xy) - An²S - D = 0
        for (uint256 i = 0; i < MAX_LOOP_ITERATIONS; i++) {
            uint256 D_P = D;
            
            // Calculate D^3 / (4 * x * y)
            // Split into steps to prevent overflow
            D_P = (D_P * D) / (x * N_COINS);
            D_P = (D_P * D) / (y * N_COINS);
            
            D_prev = D;
            
            // Newton step: D = (Ann * S + D_P * N_COINS) * D / ((Ann - 1) * D + (N_COINS + 1) * D_P)
            uint256 numerator = (Ann * S / PRECISION + D_P * N_COINS) * D;
            uint256 denominator = ((Ann - PRECISION) * D / PRECISION + (N_COINS + 1) * D_P);
            
            D = numerator / denominator;
            
            // Check convergence
            if (D > D_prev) {
                if (D - D_prev <= 1) return D;
            } else {
                if (D_prev - D <= 1) return D;
            }
        }
        
        revert ConvergenceFailed();
    }

    /// @notice Calculate y (output balance) given x (input balance) for the StableSwap invariant
    /// @dev Solves the invariant equation for y when D and x are known
    function _getY(
        uint256 A,
        uint256 x,
        uint256 D
    ) internal pure returns (uint256) {
        uint256 Ann = A * N_COINS * N_COINS;
        
        // For 2 coins, we solve for y:
        // An²(x + y) + D = An²D + D³/(4xy)
        // This becomes a quadratic equation in y
        
        uint256 c = (D * D * D * PRECISION) / (x * N_COINS * N_COINS * Ann);
        uint256 b = x + (D * PRECISION / Ann);
        
        uint256 y = D;
        uint256 y_prev;
        
        // Newton's method to find y
        for (uint256 i = 0; i < MAX_LOOP_ITERATIONS; i++) {
            y_prev = y;
            
            // y = (y^2 + c) / (2y + b - D)
            uint256 numerator = y * y + c;
            uint256 denominator = 2 * y + b - D;
            
            y = numerator / denominator;
            
            // Check convergence
            if (y > y_prev) {
                if (y - y_prev <= 1) return y;
            } else {
                if (y_prev - y <= 1) return y;
            }
        }
        
        revert ConvergenceFailed();
    }

    /// @notice Calculate output amount using the proper StableSwap invariant
    function _quoteExactIn(
        uint256 feeBps,
        uint256 A,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        // Apply fee to input
        uint256 amountInWithFee = (amountIn * (BPS_BASE - feeBps)) / BPS_BASE;
        
        // Scale A to match precision (A is typically 10-1000 for stablecoins)
        uint256 scaledA = A * PRECISION;
        
        // Calculate D for current balances
        uint256 D = _getD(scaledA, balanceIn, balanceOut);
        
        // Calculate new x balance after adding input
        uint256 newBalanceIn = balanceIn + amountInWithFee;
        
        // Calculate what y should be to maintain the invariant
        uint256 newBalanceOut = _getY(scaledA, newBalanceIn, D);
        
        // The output amount is the difference
        if (balanceOut <= newBalanceOut) {
            return 0; // This shouldn't happen in normal conditions
        }
        
        amountOut = balanceOut - newBalanceOut;
        
        // Ensure we don't drain the pool
        if (amountOut >= balanceOut) {
            amountOut = balanceOut - 1;
        }
    }

    /// @notice Calculate input amount needed for desired output using StableSwap formula
    function _quoteExactOut(
        uint256 feeBps,
        uint256 A,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountOut
    ) internal pure returns (uint256 amountIn) {
        // Check that we're not trying to drain the pool
        require(amountOut < balanceOut, "Output too large");
        
        // Scale A to match precision
        uint256 scaledA = A * PRECISION;
        
        // Calculate D for current balances
        uint256 D = _getD(scaledA, balanceIn, balanceOut);
        
        // Calculate new y balance after removing output
        uint256 newBalanceOut = balanceOut - amountOut;
        
        // Calculate what x should be to maintain the invariant
        uint256 newBalanceIn = _getY(scaledA, newBalanceOut, D);
        
        // The input amount before fee
        uint256 amountInBeforeFee;
        if (newBalanceIn >= balanceIn) {
            amountInBeforeFee = newBalanceIn - balanceIn;
        } else {
            // This shouldn't happen in normal conditions
            return type(uint256).max; // Signal error with max value
        }
        
        // Apply fee (inverse calculation)
        amountIn = (amountInBeforeFee * BPS_BASE).ceilDiv(BPS_BASE - feeBps);
    }

    function _getInAndOut(
        Strategy calldata strategy,
        bytes32 strategyHash,
        bool zeroForOne
    )
        private
        view
        returns (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        )
    {
        tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        tokenOut = zeroForOne ? strategy.token1 : strategy.token0;
        (balanceIn, balanceOut) = AQUA.safeBalances(
            strategy.maker,
            address(this),
            strategyHash,
            tokenIn,
            tokenOut
        );
    }
}

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
