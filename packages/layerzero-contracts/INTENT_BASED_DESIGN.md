# Intent-Based Cross-Chain Swaps (No Vault!)

## 🎯 The Real Design: Just-In-Time Liquidity

**Key Insight:** LP's tokens stay in their wallet on World. When a trader wants to swap, the LP fulfills the intent by bridging tokens on-demand!

## 🎭 The Actors

**LP:**
- Keeps USDC/USDT in wallet on **World Chain** ✅
- Ships strategy metadata to **Base Chain** (no tokens!)
- When trader submits intent, LP bridges tokens just-in-time

**Trader:**
- Has USDC on **World Chain**
- Submits swap intent
- Waits for LP to fulfill

## 🔄 COMPLETE FLOW

### PHASE 1: LP Ships Strategy (No Tokens!)

```
World Chain                              Base Chain
═══════════                              ══════════

LP's Wallet:
├─ 100 USDC ✅ (stays in wallet!)
└─ 100 USDT ✅ (stays in wallet!)

1. LP: "I want to provide liquidity on Base"
   
   LP calls AquaStrategyComposer.shipStrategyToChain(
     dstEid: Base,
     strategy: {
       maker: LP,
       token0: USDC,
       token1: USDT,
       feeBps: 4,
       A: 100
     },
     tokenIds: [keccak256("USDC"), keccak256("USDT")],
     amounts: [100e6, 100e6]  // Virtual only!
   )
        │
        │ LZ Message (metadata only, no tokens!)
        ├────────────────────────►  2. AquaStrategyComposer receives
        │                              ↓
        │                           3. Composer.handleShip()
        │                              ↓
        │                              aqua.shipOnBehalfOf(
        │                                LP,
        │                                app,
        │                                strategy,
        │                                tokens: [USDC, USDT],
        │                                amounts: [100e6, 100e6]
        │                              )
        │                              ↓
        │                              Aqua State on Base:
        │                              ├─ LP's virtual USDC: 100e6 ✅
        │                              ├─ LP's virtual USDT: 100e6 ✅
        │                              └─ Strategy active ✅
        │                              
        │                              BUT: No physical tokens on Base!
        │                              LP's wallet is on World!
        │
        │ Confirmation
   ◄────────────────────────────   4. "Strategy active!"
        │
   LP's Position:
   ├─ USDC still in wallet (World) ✅
   ├─ USDT still in wallet (World) ✅
   └─ Strategy active on Base (virtual) ✅
```

### PHASE 2: Trader Submits Intent

```
World Chain                              Base Chain
═══════════                              ══════════

Trader's Wallet:
└─ 10 USDC

1. Trader: "I want to swap 10 USDC for USDT"
   
   Trader calls IntentPool.submitSwapIntent(
     strategyHash: 0x123...,
     tokenIn: USDC,
     tokenOut: USDT,
     amountIn: 10e6,
     minAmountOut: 9.96e6,
     deadline: block.timestamp + 10 minutes
   )
        │
        ├─► IntentPool:
        │   // Lock trader's USDC
        │   USDC.safeTransferFrom(trader, this, 10e6)
        │   
        │   // Create intent
        │   intents[intentId] = Intent({
        │     trader: trader,
        │     strategyHash: 0x123...,
        │     tokenIn: USDC,
        │     tokenOut: USDT,
        │     amountIn: 10e6,
        │     minAmountOut: 9.96e6,
        │     deadline: block.timestamp + 10 min,
        │     status: PENDING
        │   })
        │   
        │   emit IntentSubmitted(intentId, trader, ...)
        │
   Intent is now PENDING ⏳
   Waiting for LP to fulfill...
```

### PHASE 3: LP Fulfills Intent (The Magic!)

```
World Chain                              Base Chain
═══════════                              ══════════

LP sees IntentSubmitted event:
"Trader wants 10 USDC → USDT"

2. LP: "I'll fulfill this intent!"
   
   LP calls IntentPool.fulfillIntent(
     intentId,
     proof: signature/merkle
   )
        │
        ├─► IntentPool validates:
        │   ✓ Intent exists
        │   ✓ Not expired
        │   ✓ LP owns strategy
        │   ✓ LP has approved tokens
        │   
        │   // Transfer LP's USDT for trader
        │   USDT.safeTransferFrom(
        │     LP,              // LP's wallet
        │     trader,          // Trader's wallet  
        │     9.996e6          // Output amount
        │   )
        │   
        │   LP's Wallet:
        │   └─ USDT: 100 → 90.004 ✅
        │   
        │   Trader's Wallet:
        │   └─ USDT: 0 → 9.996 ✅
        │   
        │   Trader is HAPPY! Got their USDT! 🎉
        │   
        │   // Now settle on Base...
        │   ↓
        │
        │ Bridge LP's USDT + Trader's USDC to Base
        │ Message: "Settle swap"
        ├────────────────────────►  3. OFT delivers to SwapSettler:
        │                              - 9.996 USDT (from LP)
        │                              - 10 USDC (from trader)
        │                              ↓
        │                           4. OFT calls lzCompose()
        │                              ↓
        │                           5. SwapSettler.lzCompose()
        │                              SETTLEMENT ON BASE:
        │                              ↓
        │                              // Execute swap to update Aqua
        │                              AMM.swapExactIn(
        │                                strategy,
        │                                zeroForOne: true,
        │                                amountIn: 10e6,
        │                                minOut: 9.96e6,
        │                                to: SwapSettler,
        │                                takerData: "..."
        │                              )
        │                              ↓
        │                           ┌─────────────────────────┐
        │                           │ INSIDE AMM.swapExactIn()│
        │                           └─────────────────────────┘
        │                              ↓
        │                           6. AQUA.PULL:
        │                              aqua.pull(
        │                                LP,         // maker
        │                                strategyHash,
        │                                USDT,
        │                                9.996e6,
        │                                SwapSettler // to
        │                              )
        │                              ↓
        │                              BUT: LP's wallet is on World!
        │                              This would FAIL! ❌
        │                              
        │                              SOLUTION: Use pullOnBehalfOf!
        │                              SwapSettler is trusted delegate
        │                              ↓
        │                              aqua.pullOnBehalfOf(
        │                                LP,         // maker
        │                                SwapSettler,// delegate
        │                                strategyHash,
        │                                USDT,
        │                                9.996e6,
        │                                SwapSettler
        │                              )
        │                              ↓
        │                              This transfers bridged USDT
        │                              (already on Base from step 3)
        │                              ↓
        │                              Aqua Virtual Balances:
        │                              └─ LP's USDT: 100 → 90.004 ✅
        │                              ↓
        │                           7. CALLBACK:
        │                              SwapSettler.stableswapCallback(...)
        │                              ↓
        │                              aqua.pushOnBehalfOf(
        │                                LP,         // maker
        │                                SwapSettler,// delegate
        │                                app,
        │                                strategyHash,
        │                                USDC,
        │                                10e6
        │                              )
        │                              ↓
        │                              This transfers bridged USDC
        │                              (already on Base from step 3)
        │                              ↓
        │                              Aqua Virtual Balances:
        │                              ├─ LP's USDC: 100 → 110 ✅
        │                              └─ LP's USDT: 90.004 ✅
        │                              ↓
        │                           8. Settlement complete!
        │                              Aqua's books are updated ✅
        │                              ↓
        │                              Bridge LP's USDC proceeds back
        │                              ↓
   ◄────────────────────────────   9. 10 USDC arrives for LP
        │                              
        │   LP receives their USDC! ✅
        │
   Final State:
   
   LP's Wallet (World):
   ├─ USDC: 100 → 110 ✅ (+10 from trader)
   └─ USDT: 100 → 90.004 ✅ (-9.996 to trader)
   
   Trader's Wallet (World):
   ├─ USDC: 10 → 0 ✅ (spent)
   └─ USDT: 0 → 9.996 ✅ (received)
   
   LP's Virtual (Base):
   ├─ USDC: 100 → 110 ✅
   └─ USDT: 100 → 90.004 ✅
   
   Everything synced! 🎉
```

## 🔑 Key Innovations

### 1. **Intent-Based Settlement**
```
Trader submits intent → LP fulfills on World → Settle on Base
                         ↓
                   LP gives trader USDT immediately!
                   Trader doesn't wait for Base settlement
```

### 2. **No Vault Needed**
- LP keeps tokens in wallet ✅
- Only moves tokens when fulfilling intent ✅
- No pre-locking required ✅

### 3. **Just-In-Time Bridging**
- LP bridges USDT to Base (for settlement)
- Trader's USDC bridges to Base (for settlement)
- Only when intent is fulfilled
- Not in advance

### 4. **Two-Step Settlement**

**Step 1 (World):** Trader gets output
```
LP's USDT → Trader (immediate!)
```

**Step 2 (Base):** Update Aqua's books
```
Bridge tokens → Execute swap → Update virtual balances
```

## 📦 Required Contracts

### 1. IntentPool (World Chain)

```solidity
contract IntentPool is OApp {
    struct Intent {
        address trader;
        address LP;
        bytes32 strategyHash;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        IntentStatus status;
    }
    
    enum IntentStatus { PENDING, FULFILLED, CANCELLED }
    
    mapping(bytes32 intentId => Intent) public intents;
    
    event IntentSubmitted(bytes32 indexed intentId, address trader);
    event IntentFulfilled(bytes32 indexed intentId, address LP);
    
    /**
     * @notice Trader submits swap intent
     */
    function submitSwapIntent(
        bytes32 strategyHash,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (bytes32 intentId) {
        // Lock trader's tokenIn
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // Create intent
        intentId = keccak256(abi.encodePacked(
            msg.sender,
            strategyHash,
            amountIn,
            block.timestamp
        ));
        
        intents[intentId] = Intent({...});
        
        emit IntentSubmitted(intentId, msg.sender);
    }
    
    /**
     * @notice LP fulfills intent
     */
    function fulfillIntent(bytes32 intentId) external {
        Intent storage intent = intents[intentId];
        
        // Validate
        require(intent.status == IntentStatus.PENDING, "Not pending");
        require(block.timestamp <= intent.deadline, "Expired");
        require(ownsStrategy(msg.sender, intent.strategyHash), "Not LP");
        
        // Calculate output (could call Base for quote)
        uint256 amountOut = 9.996e6; // Example
        
        // Transfer LP's tokenOut to trader (IMMEDIATE!)
        IERC20(intent.tokenOut).safeTransferFrom(
            msg.sender,    // LP
            intent.trader, // Trader
            amountOut
        );
        
        intent.status = IntentStatus.FULFILLED;
        
        // Now settle on Base
        _settleOnBase(intentId, intent, msg.sender);
        
        emit IntentFulfilled(intentId, msg.sender);
    }
    
    function _settleOnBase(
        bytes32 intentId,
        Intent memory intent,
        address LP
    ) internal {
        // Bridge LP's tokenOut + Trader's tokenIn to Base
        // Send message to SwapSettler on Base to update Aqua
        
        bytes memory message = abi.encode(
            intentId,
            LP,
            intent.trader,
            intent.strategyHash,
            intent.tokenIn,
            intent.tokenOut,
            intent.amountIn,
            amountOut
        );
        
        // Bridge tokens and send message
        _lzSend(baseEid, message, options, fee, refund);
    }
}
```

### 2. SwapSettler (Base Chain)

```solidity
contract SwapSettler is OApp, IStableswapCallback {
    IAqua public immutable AQUA;
    IStableswapAMM public immutable AMM;
    
    /**
     * @notice Receive settlement from World
     */
    function lzCompose(...) external {
        // Tokens already arrived:
        // - LP's tokenOut (for pull)
        // - Trader's tokenIn (for push)
        
        (
            bytes32 intentId,
            address LP,
            address trader,
            bytes32 strategyHash,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            uint256 amountOut
        ) = abi.decode(message, (...));
        
        // Execute swap to update Aqua's books
        AMM.swapExactIn(
            strategy,
            zeroForOne: true,
            amountIn,
            amountOut,
            address(this),
            abi.encode(LP, trader, intentId)
        );
        
        // Swap calls aqua.pull() and aqua.push()
        // We handle in callback below
        
        // Bridge LP's proceeds back to World
        _bridgeToLP(LP, tokenIn, amountIn);
    }
    
    /**
     * @notice Callback from AMM
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
        // Push happens here
        IERC20(tokenIn).approve(address(AQUA), amountIn);
        
        // Use pushOnBehalfOf since LP is on World
        AQUA.pushOnBehalfOf(
            maker,           // LP
            address(this),   // delegate
            app,
            strategyHash,
            tokenIn,
            amountIn
        );
    }
}
```

## ✅ Why This Works

### 1. **No Pre-Locking**
- LP keeps tokens in wallet until needed
- Only moves tokens when fulfilling intent
- More capital efficient

### 2. **Instant Settlement for Trader**
- Trader gets USDT immediately on World
- Doesn't wait for Base settlement
- Better UX

### 3. **Eventual Consistency**
- World: Physical settlement (trader gets USDT)
- Base: Virtual settlement (Aqua books updated)
- Eventually consistent across chains

### 4. **Uses Aqua's Trusted Delegate**
- SwapSettler is trusted delegate
- Can call `pullOnBehalfOf` and `pushOnBehalfOf`
- Updates LP's balances on Base

## 🎯 This Is The Right Design!

No vault, no pre-locking, just:
1. Trader submits intent
2. LP fulfills (gives trader output on World)
3. Settlement happens on Base (updates Aqua)
4. LP gets input back on World

Perfect! 🎉

