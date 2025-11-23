# Cross-Chain Swap Architecture (CORRECT VERSION)

## 🎯 The Problem

**LP's Reality:**
- Physical tokens on **World Chain** (USDC/USDT in wallet)
- Ships strategy to **Base Chain** (virtual balances)
- Aqua on Base expects to call `safeTransferFrom(LP, trader, amount)`
- **BUT**: LP's tokens are on World, not Base! ❌

**We need:** Aqua pull/push on Base, but tokens are on World.

## 🏗️ Solution: Escrow + Bridge Coordinator

### Architecture Components

```
World Chain                              Base Chain
═══════════                              ══════════

┌────────────────────┐                  ┌─────────────────────┐
│  LPEscrowVault     │                  │ CrossChainSwapProxy │
│                    │                  │                     │
│ - Holds LP's tokens│◄────────────────►│ - Acts as "LP" for  │
│ - Bridges on demand│                  │   Aqua on Base      │
│ - Receives proceeds│                  │ - Receives swaps    │
└────────────────────┘                  └─────────────────────┘
         │                                        │
         │ Has actual tokens                      │ Has virtual bal
         ▼                                        ▼
    LP's wallet                            ┌──────────────┐
    (USDC/USDT)                            │   Aqua.sol   │
                                           │              │
                                           │ Tracks LP's  │
                                           │ virtual bal  │
                                           └──────────────┘
                                                  │
                                                  ▼
                                           ┌──────────────┐
                                           │ StableswapAMM│
                                           │              │
                                           │ Swap logic   │
                                           └──────────────┘
```

## 🔄 Complete Flow

### Phase 1: LP Ships Strategy (One-time Setup)

```
World Chain                              Base Chain
───────────                              ──────────

1. LP approves LPEscrowVault
   token.approve(vault, type(uint256).max)

2. LP deposits tokens to vault
   vault.depositAndShipStrategy(
     USDC: 2e6,
     USDT: 2e6,
     dstEid: Base,
     strategyParams
   )
        │
        ├─► Vault locks LP's tokens ✅
        │   USDC: 2e6, USDT: 2e6
        │
        │ LZ Message: "Ship strategy"
        ├─────────────────────────►  3. CrossChainSwapProxy
        │                                receives message
        │                                ↓
        │                             4. Proxy acts as "LP"
        │                                ↓
        │                                aqua.ship(
        │                                  app,
        │                                  strategy, 
        │                                  [USDC, USDT],
        │                                  [2e6, 2e6]
        │                                )
        │                                ↓
        │                                BUT WAIT! Proxy doesn't
        │                                have tokens yet!
```

**Problem:** Aqua.ship() doesn't transfer tokens (LP keeps them), but our Proxy on Base doesn't have any tokens to "keep"!

**Solution:** We need to bridge tokens to Proxy FIRST, then ship.

### Phase 1 (CORRECTED): LP Ships Strategy

```
World Chain                              Base Chain
───────────                              ──────────

1. LP deposits to vault
   vault.depositAndShipStrategy(
     USDC: 2e6, USDT: 2e6, ...
   )
        │
        ├─► Vault locks tokens ✅
        │
        │ Bridge USDC + USDT to Base Proxy
        ├─────────────────────────►  2. Proxy receives tokens
        │                                USDC: 2e6, USDT: 2e6 ✅
        │                                ↓
        │                             3. Proxy approves Aqua
        │                                ↓
        │                             4. Proxy ships strategy
        │                                aqua.ship(
        │                                  app, strategy,
        │                                  [USDC, USDT],
        │                                  [2e6, 2e6]
        │                                )
        │                                ↓
        │                                Aqua tracks virtual bal ✅
        │                                Tokens stay in Proxy ✅
```

### Phase 2: Trader Swaps

```
World Chain                              Base Chain
───────────                              ──────────

1. Trader: "Swap 1 USDC for USDT"
   Deposits 1 USDC to SwapInitiator
        │
        │ Bridge 1 USDC to Base
        ├─────────────────────────►  2. Proxy receives 1 USDC
        │                                ↓
        │                             3. Proxy executes swap
        │                                AMM.swapExactIn(
        │                                  strategy,
        │                                  zeroForOne: true,
        │                                  amountIn: 1e6,
        │                                  ...
        │                                )
        │                                ↓
        │                             4. AMM execution:
        │                                ↓
        │                                aqua.pull(
        │                                  Proxy, // "LP"
        │                                  USDT,
        │                                  0.996e6,
        │                                  trader
        │                                )
        │                                ↓
        │                                safeTransferFrom(
        │                                  Proxy,
        │                                  trader,
        │                                  0.996e6
        │                                ) ✅
        │                                Proxy's USDT → Trader
        │                                ↓
        │                             5. Callback to Proxy:
        │                                stableswapCallback()
        │                                ↓
        │                                aqua.push(
        │                                  Proxy, // "LP"
        │                                  app,
        │                                  USDC,
        │                                  1e6
        │                                )
        │                                ↓
        │                                Trader's USDC → Aqua
        │                                Balances updated ✅
        │                                ↓
        │                             6. Bridge 0.996 USDT back
        │                                ↓
   ◄─────────────────────────────  7. USDT arrives on World
        │                                Send to trader ✅
        ↓
   Trader receives 0.996 USDT! 🎉

8. Update vault accounting (optional):
   - Track that Proxy now has 3 USDC, 1.004 USDT
   - Sync for future withdrawals
```

## 🔑 Key Insights

### 1. **Proxy Acts as LP on Base**
The `CrossChainSwapProxy` on Base:
- Holds the actual tokens on Base
- Is registered as the "maker" in Aqua strategies
- Receives swaps and handles callbacks
- Tokens stay in Proxy's wallet (Aqua's no-lock principle)

### 2. **Vault Acts as LP's Agent on World**
The `LPEscrowVault` on World:
- Holds LP's original tokens
- Coordinates bridging to/from Proxy
- Tracks LP's net position
- Allows LP to withdraw

### 3. **Aqua Works Normally on Base**
From Aqua's perspective:
- Proxy is just a normal LP
- Tokens are in Proxy's wallet on Base
- pull/push work as expected
- No cross-chain awareness needed!

### 4. **LP Never Sends Tokens Manually**
- LP deposits to Vault once
- Vault handles all bridging
- LP can withdraw at any time
- Accounting stays synced

## 📋 Contracts Needed

### 1. LPEscrowVault (World Chain)
```solidity
contract LPEscrowVault is OApp {
    // Stores LP's tokens on World
    mapping(address lp => mapping(address token => uint256 balance)) public deposits;
    
    // Deposit and ship strategy
    function depositAndShipStrategy(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint32 dstEid,
        bytes calldata strategyParams
    ) external;
    
    // Withdraw (after docking strategy)
    function withdraw(address token, uint256 amount) external;
    
    // Sync balances from Base
    function _lzReceive(...) internal override;
}
```

### 2. CrossChainSwapProxy (Base Chain)
```solidity
contract CrossChainSwapProxy is OApp, IStableswapCallback {
    IAqua public immutable AQUA;
    IStableswapAMM public immutable AMM;
    
    // Receive bridged tokens and ship strategy
    function _lzReceive(...) internal override;
    
    // Execute swap on behalf of trader
    function executeSwap(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut,
        address traderOnSrcChain
    ) external;
    
    // Callback from AMM
    function stableswapCallback(...) external override;
}
```

## ✅ Why This Works

1. **Tokens are where Aqua expects:** Proxy has tokens on Base
2. **pull/push work normally:** `safeTransferFrom(Proxy, trader, amt)` succeeds
3. **LP maintains control:** Can withdraw from Vault anytime
4. **Atomic swaps:** All happens on Base, no async issues
5. **Safe bridging:** Tokens only bridge when needed

## 🚧 Edge Cases to Handle

### 1. **Insufficient Bridged Balance**
If Proxy on Base runs low on tokens:
- Vault detects and bridges more
- Or: Reject swap until liquidity arrives

### 2. **Failed Bridge**
If bridge fails:
- Tokens stuck in Vault
- Retry mechanism needed
- Or: LP can force withdraw

### 3. **Balance Synchronization**
After each swap:
- Proxy's balance changes
- Vault needs to know for withdrawals
- Send periodic sync messages

### 4. **Multiple LPs**
If multiple LPs use same Proxy:
- Need to track which tokens belong to whom
- Separate strategies per LP
- Or: Pool-based accounting

## 🎯 Simplified MVP Flow

For quick implementation:

1. **One LP, one strategy**
2. **No withdrawals during active swaps**
3. **Pre-bridge all liquidity upfront**
4. **Periodic sync (not real-time)**

This makes it much simpler while proving the concept works!

