# Cross-Chain Swap Architecture

## 🎯 Problem Statement

**Scenario:**
- **LP** has USDC/USDT on **World Chain** (actual tokens in wallet)
- **Trader** has USDC on **World Chain** (actual tokens in wallet)
- **Strategy** is shipped to **Base Chain** (virtual balances only)

**Goal:** Enable trader to swap against a strategy on Base while all tokens remain on World.

## 🏗️ Architecture Overview

### Three-Component System

```
World Chain (Liquidity)          Base Chain (Logic)
═══════════════════════          ══════════════════

┌─────────────────────┐          ┌─────────────────────┐
│ CrossChainSwapSettler│          │ CrossChainSwapQuoter│
│                      │          │                      │
│ - Executes swaps     │◄────────►│ - Stores metadata    │
│ - Uses Aqua pull/push│          │ - Calculates quotes  │
│ - Holds trader tokens│          │ - Sends instructions │
└─────────────────────┘          └─────────────────────┘
         │                                 │
         │ Uses Aqua                       │ Tracks strategy
         ▼                                 ▼
┌─────────────────────┐          ┌─────────────────────┐
│      Aqua.sol       │          │ AquaStrategyComposer│
│                      │          │                      │
│ - LP's virtual      │          │ - Ships strategies   │
│   balances          │          │ - Registers metadata │
└─────────────────────┘          └─────────────────────┘
```

## 🔄 Complete Flow

### Phase 1: Strategy Setup

```
World Chain                           Base Chain
───────────                           ──────────

1. LP ships strategy
   aqua.ship(strategy)
        │
        │ LayerZero Message
        ├──────────────────────────►  2. AquaStrategyComposer
        │                                receives strategy
        │                                     │
        │                                     ├─► aqua.shipOnBehalfOf()
        │                                     │   (creates virtual balances)
        │                                     │
        │                                     └─► CrossChainSwapQuoter
        │                                         .registerStrategy()
        │                                         (stores metadata for quotes)
        │
   ◄────────────────────────────────  3. Confirmation sent back
        │
   Strategy active on both chains ✅
   - World: Virtual balances tracked in Aqua
   - Base: Metadata stored in Quoter
```

### Phase 2: Trader Swaps

```
World Chain                           Base Chain
───────────                           ──────────

1. Trader deposits tokens
   trader.approve(settler, 1 USDC)
   settler.depositForSwap(USDC, 1e6)
        │
        │ Tokens locked in settler ✅
        │
2. Trader requests swap
   Request: "Swap 1 USDC → USDT"
        │
        │ LayerZero Message
        ├──────────────────────────►  3. CrossChainSwapQuoter
        │                                receives request
        │                                     │
        │                                     ├─► Load strategy metadata
        │                                     ├─► Calculate quote using
        │                                     │   stableswap formula
        │                                     │   Quote: 0.996 USDT
        │                                     │
        │                                     └─► Send execution instruction
        │
   ◄────────────────────────────────  4. Execution instruction
        │                                "Pull 0.996 USDT, Push 1 USDC"
        │
5. CrossChainSwapSettler executes:
        │
        ├─► aqua.pull(LP, USDT, 0.996, trader)
        │   LP's USDT → Trader ✅
        │
        └─► aqua.push(LP, app, USDC, 1)
            Trader's USDC → LP ✅
        
   Swap complete! All tokens stayed on World ✅
```

## 📦 Contract Details

### 1. CrossChainSwapSettler (World Chain)

**Purpose:** Executes swaps using Aqua's pull/push interface

```solidity
contract CrossChainSwapSettler {
    IAqua public immutable AQUA;
    
    // Trader deposits tokens before swap
    function depositForSwap(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }
    
    // Receives execution instruction from Base
    function _lzReceive(...) internal override {
        // Decode: swapId, trader, maker, tokenIn, tokenOut, amountIn, amountOut
        
        // Execute swap:
        // 1. Pull LP's tokenOut → trader
        AQUA.pull(maker, strategyHash, tokenOut, amountOut, trader);
        
        // 2. Push trader's tokenIn → LP
        IERC20(tokenIn).approve(address(AQUA), amountIn);
        AQUA.push(maker, strategyApp, strategyHash, tokenIn, amountIn);
    }
}
```

**Key Features:**
- ✅ Uses Aqua's native pull/push (no callback needed!)
- ✅ All token transfers happen locally on World
- ✅ LP's tokens never leave their wallet until swap
- ✅ Trader's tokens locked in settler before swap

### 2. CrossChainSwapQuoter (Base Chain)

**Purpose:** Stores strategy metadata and calculates quotes

```solidity
contract CrossChainSwapQuoter {
    struct StrategyMetadata {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 amplificationFactor;
        uint256 balance0;
        uint256 balance1;
        bool exists;
    }
    
    mapping(bytes32 => StrategyMetadata) public strategies;
    
    // Register strategy when shipped
    function _handleStrategyRegistration(...) internal {
        strategies[strategyHash] = StrategyMetadata({...});
    }
    
    // Calculate quote when swap requested
    function _handleSwapRequest(...) internal {
        StrategyMetadata memory strategy = strategies[strategyHash];
        
        // Use stableswap formula to calculate quote
        uint256 amountOut = _quoteExactIn(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountIn
        );
        
        // Send execution instruction to World
        _lzSend(srcEid, executionPayload, ...);
    }
}
```

**Key Features:**
- ✅ Stores full strategy metadata
- ✅ Uses same AMM math as local swaps
- ✅ No token operations (logic only)
- ✅ Sends execution instructions back

### 3. AquaStrategyComposer (Both Chains)

**Enhanced for Swap Support:**

```solidity
contract AquaStrategyComposer {
    // Existing: Ships strategies cross-chain
    
    // NEW: Also register with Quoter
    function handleShip(...) external {
        // 1. Ship to Aqua (existing)
        bytes32 strategyHash = aqua.shipOnBehalfOf(maker, dstApp, strategy, tokens, amounts);
        
        // 2. Register with Quoter (new)
        IQuoter(quoter).registerStrategy(strategyHash, metadata);
    }
}
```

## 🔑 Key Insights

### Why This Works with Aqua

1. **Virtual Balances:** Aqua tracks balances without locking tokens
   ```solidity
   // LP ships strategy on World
   aqua.ship(app, strategy, [USDC, USDT], [2e6, 2e6]);
   // → LP's wallet: still has 2 USDC + 2 USDT ✅
   // → Aqua's state: tracks virtual allocation
   ```

2. **Pull/Push Pattern:** Perfect for cross-chain
   ```solidity
   // Pull: LP's tokens → Trader
   aqua.pull(LP, strategyHash, USDT, 0.996e6, trader);
   // → Does: safeTransferFrom(LP, trader, 0.996e6)
   
   // Push: Trader's tokens → LP
   aqua.push(LP, app, strategyHash, USDC, 1e6);
   // → Does: safeTransferFrom(settler, LP, 1e6)
   // → Updates: virtual balances in Aqua
   ```

3. **No Callback Needed:** Direct execution
   ```solidity
   // Traditional AMM (same chain):
   AMM.swap() {
       aqua.pull(LP, tokenOut, amt, trader);
       callback(); // ← Trader must push here
       _safeCheckAquaPush(); // ← Verify push happened
   }
   
   // Our approach (cross-chain):
   Settler.executeSwap() {
       aqua.pull(LP, tokenOut, amt, trader);
       aqua.push(LP, tokenIn, amt); // ← Direct push, no callback
   }
   // Works because settler already has trader's tokens!
   ```

### State Consistency

**Balance Tracking:**
```
World Chain (Aqua)                Base Chain (Quoter)
──────────────────                ───────────────────

Initial:                          Initial:
balance0: 2 USDC                  balance0: 2 USDC
balance1: 2 USDT                  balance1: 2 USDT

After Swap (1 USDC → 0.996 USDT): After Swap:
balance0: 3 USDC ✅               balance0: 3 USDC ✅
balance1: 1.004 USDT ✅           balance1: 1.004 USDT ✅
```

**How Balances Stay Synced:**
1. Quoter uses last known balances to calculate quote
2. Settler executes using that quote
3. Next swap request will need updated balances
4. **TODO:** Sync balances back to Quoter after each swap

## 🚧 Current Limitations & TODOs

### 1. Balance Synchronization
**Problem:** Quoter on Base has stale balances after swaps execute on World

**Solution Options:**
- **A)** Send balance update from World → Base after each swap
- **B)** Quoter tracks balance changes mathematically (amountIn added, amountOut subtracted)
- **C)** Periodic sync: World → Base every N swaps or M time

**Recommended:** Option B (mathematical tracking) + Option C (periodic sync)

### 2. Message Orchestration
**Current:** Settler needs to know how to send message back to Quoter

**TODO:** 
- Add `quoterAddress` to settler constructor
- Add LZ options for return messages
- Handle fee payment for return messages

### 3. Strategy Registration Flow
**Current:** AquaStrategyComposer ships to Aqua, but doesn't notify Quoter

**TODO:**
- Add message type: `MSG_TYPE_REGISTER_STRATEGY`
- When strategy shipped to Base → also register in Quoter
- Store: strategyHash, maker, tokens, feeBps, amplification, initial balances

### 4. Security Considerations

**Reentrancy:**
- ✅ Settler uses `safeTransferFrom` and `approve` (standard ERC20)
- ✅ No external calls during critical state changes
- ⚠️ Consider adding `nonReentrant` modifier

**Front-running:**
- ⚠️ Quotes can become stale during message flight
- **Solution:** Add deadline and minAmountOut checks

**Slippage:**
- ⚠️ Balance changes between quote and execution
- **Solution:** Trader specifies minAmountOut, tx reverts if not met

## 📋 Implementation Checklist

- [x] CrossChainSwapSettler contract
- [x] CrossChainSwapQuoter contract
- [ ] Update AquaStrategyComposer to register with Quoter
- [ ] Add balance sync mechanism
- [ ] Add message types and handlers
- [ ] Add slippage protection
- [ ] Add deadline checks
- [ ] Write deployment scripts
- [ ] Write test scripts
- [ ] Add error handling and events
- [ ] Security audit considerations

## 🧪 Testing Flow

```bash
# 1. Setup (one-time)
# Deploy Aqua on World
# Deploy Settler on World
# Deploy Quoter on Base
# Deploy Composer on both chains
# Register tokens on both chains

# 2. LP ships strategy
# On World: LP calls Composer.shipStrategyToChain()
# → Strategy created on Base with metadata in Quoter

# 3. Trader prepares
# On World: Trader approves settler
# On World: Trader deposits tokens to settler

# 4. Trader swaps
# On World: Trader requests swap via settler
# → Message to Base
# → Quoter calculates
# → Message back to World
# → Settler executes via Aqua
# → Trader receives tokens

# 5. Verify
# Check LP's balance increased by amountIn
# Check Trader's balance increased by amountOut
# Check virtual balances in Aqua
```

## 🎓 Key Takeaways

1. **No Token Bridging Required:** All tokens stay on World
2. **Quote Comes from Base:** AMM logic executes where strategy lives
3. **Settlement on World:** Aqua pull/push happen where tokens are
4. **LP Never Moves Tokens:** Aqua's no-lock philosophy preserved
5. **Trader Locks First:** Settler holds tokens during swap process
6. **State Eventually Consistent:** Balances sync after execution

This architecture maintains Aqua's core principle: **LPs don't lock tokens**, while enabling cross-chain strategy execution through message-based coordination.

