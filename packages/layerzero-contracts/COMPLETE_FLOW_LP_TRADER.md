# Complete Cross-Chain Swap Flow: LP and Trader

## 🎭 The Actors

**LP (Liquidity Provider):**
- Has USDC and USDT on **World Chain**
- Wants to provide liquidity to a strategy on **Base Chain**
- Earns fees from swaps

**Trader:**
- Has USDC on **World Chain**
- Wants to swap for USDT
- Willing to pay fees to LP

## 🔄 COMPLETE FLOW

### PHASE 1: LP Sets Up Liquidity (One-Time)

```
World Chain                              Base Chain
═══════════                              ══════════

LP's Wallet:                             
├─ 100 USDC
└─ 100 USDT

1. LP: "I want to provide liquidity on Base"
   
   LP calls LPVault.lockAndShipStrategy(
     USDC: 100e6,
     USDT: 100e6,
     dstEid: Base,
     fee: 0.04%,
     amplificationFactor: 100
   )
        │
        ├─► LPVault locks tokens
        │   LP's 100 USDC → Vault ✅
        │   LP's 100 USDT → Vault ✅
        │
        │ Bridge via LayerZero OFT
        │ Message: "Ship strategy"
        ├────────────────────────►  2. OFT delivers:
        │                              - 100 USDC arrives ✅
        │                              - 100 USDT arrives ✅
        │                              ↓
        │                           3. OFT calls lzCompose()
        │                              ↓
        │                           4. CrossChainSwapProxy.lzCompose()
        │                              IMMEDIATE EXECUTION:
        │                              ↓
        │                              // Approve Aqua
        │                              USDC.approve(aqua, max)
        │                              USDT.approve(aqua, max)
        │                              ↓
        │                              // Ship strategy
        │                              aqua.ship(
        │                                app: StableswapAMM,
        │                                strategy: {
        │                                  maker: Proxy,
        │                                  token0: USDC,
        │                                  token1: USDT,
        │                                  feeBps: 4,
        │                                  A: 100
        │                                },
        │                                tokens: [USDC, USDT],
        │                                amounts: [100e6, 100e6]
        │                              )
        │                              ↓
        │                              Aqua State on Base:
        │                              ├─ Proxy's virtual USDC: 100e6 ✅
        │                              ├─ Proxy's virtual USDT: 100e6 ✅
        │                              └─ Strategy active ✅
        │                              
        │                              Physical Reality:
        │                              ├─ Proxy's wallet: 100 USDC ✅
        │                              └─ Proxy's wallet: 100 USDT ✅
        │
        │ Confirmation
   ◄────────────────────────────   5. "Strategy active!"
        │
   LP's Position:
   ├─ 100 USDC locked in Vault (World)
   ├─ 100 USDT locked in Vault (World)
   └─ Strategy earning fees on Base ✅
```

### PHASE 2: Trader Swaps (The Main Event!)

```
World Chain                              Base Chain
═══════════                              ══════════

Trader's Wallet:
└─ 10 USDC

1. Trader: "I want to swap 10 USDC for USDT"
   
   Trader calls SwapInitiator.swapCrossChain(
     strategyHash: 0x123...,
     tokenIn: USDC,
     tokenOut: USDT,
     amountIn: 10e6,
     minAmountOut: 9.96e6, // 0.04% fee
     dstEid: Base
   )
        │
        ├─► SwapInitiator:
        │   // Transfer USDC from trader
        │   USDC.safeTransferFrom(trader, this, 10e6)
        │   
        │   Trader's wallet: 10 USDC → 0 USDC
        │   SwapInitiator: 0 → 10 USDC ✅
        │
        │ Bridge via LayerZero OFT
        │ Message: "Execute swap"
        ├────────────────────────►  2. OFT delivers:
        │                              - 10 USDC arrives in Proxy ✅
        │                              ↓
        │                           3. OFT calls lzCompose()
        │                              ↓
        │                           4. Proxy.lzCompose()
        │                              IMMEDIATE SWAP EXECUTION:
        │                              ↓
        │                              AMM.swapExactIn(
        │                                strategy: {
        │                                  maker: Proxy,
        │                                  token0: USDC,
        │                                  token1: USDT,
        │                                  feeBps: 4,
        │                                  A: 100,
        │                                  salt: 0
        │                                },
        │                                zeroForOne: true,
        │                                amountIn: 10e6,
        │                                minOut: 9.96e6,
        │                                to: Proxy,
        │                                takerData: "..."
        │                              )
        │                              ↓
        │                           ┌─────────────────────────┐
        │                           │ INSIDE AMM.swapExactIn()│
        │                           └─────────────────────────┘
        │                              ↓
        │                           5a. Calculate quote:
        │                              Quote = 9.996 USDT
        │                              (10 USDC - 0.04% fee)
        │                              ↓
        │                           5b. AQUA.PULL:
        │                              aqua.pull(
        │                                Proxy,      // maker (the "LP")
        │                                strategyHash,
        │                                USDT,
        │                                9.996e6,
        │                                Proxy       // to
        │                              )
        │                              ↓
        │                              This does internally:
        │                              USDT.safeTransferFrom(
        │                                Proxy,  // LP's wallet
        │                                Proxy,  // recipient
        │                                9.996e6
        │                              )
        │                              
        │                              Physical Movement:
        │                              Proxy's wallet:
        │                              ├─ USDT: 100 → 100 (stays!)
        │                              └─ (It's from→to same address)
        │                              
        │                              Aqua Virtual Balances:
        │                              └─ Proxy's USDT: 100 → 90.004 ✅
        │                              ↓
        │                           5c. CALLBACK:
        │                              IStableswapCallback(Proxy)
        │                                .stableswapCallback(
        │                                  tokenIn: USDC,
        │                                  tokenOut: USDT,
        │                                  amountIn: 10e6,
        │                                  amountOut: 9.996e6,
        │                                  maker: Proxy,
        │                                  app: AMM,
        │                                  strategyHash,
        │                                  takerData
        │                                )
        │                              ↓
        │                           6. Proxy.stableswapCallback():
        │                              // Push trader's USDC
        │                              USDC.approve(aqua, 10e6)
        │                              aqua.push(
        │                                Proxy,      // maker
        │                                AMM,        // app
        │                                strategyHash,
        │                                USDC,
        │                                10e6
        │                              )
        │                              ↓
        │                              This does internally:
        │                              USDC.safeTransferFrom(
        │                                Proxy,  // from (has bridged USDC)
        │                                Proxy,  // to (back to proxy)
        │                                10e6
        │                              )
        │                              
        │                              Physical Movement:
        │                              Proxy's wallet:
        │                              ├─ USDC: 110 → 110 (stays!)
        │                              └─ (It's from→to same address)
        │                              
        │                              Aqua Virtual Balances:
        │                              ├─ Proxy's USDC: 100 → 110 ✅
        │                              └─ Proxy's USDT: 90.004 ✅
        │                              ↓
        │                           7. Swap complete on Base!
        │                              
        │                              Final State:
        │                              Proxy's Physical Wallet:
        │                              ├─ USDC: 110e6 ✅
        │                              └─ USDT: 100e6 ✅
        │                              
        │                              Proxy's Virtual (Aqua):
        │                              ├─ USDC: 110e6 ✅
        │                              └─ USDT: 90.004e6 ✅
        │                              ↓
        │                           8. Bridge USDT back:
        │                              Send 9.996 USDT to trader
        │                              ↓
   ◄────────────────────────────   9. USDT arrives!
        │                              9.996 USDT → Trader ✅
        │
   Trader's Final Wallet:
   ├─ USDC: 0 (spent 10)
   └─ USDT: 9.996 (received) ✅

   LP's Earnings:
   └─ Earned 0.004 USDC fee! 💰
```

## 📊 Balance Changes Summary

### Before Swap:

**World Chain:**
```
LP: 
├─ 0 USDC (locked in Vault)
└─ 0 USDT (locked in Vault)

Vault:
├─ 100 USDC (from LP)
└─ 100 USDT (from LP)

Trader:
├─ 10 USDC
└─ 0 USDT
```

**Base Chain:**
```
Proxy Physical Wallet:
├─ 100 USDC (bridged from Vault)
└─ 100 USDT (bridged from Vault)

Aqua Virtual Balances (Proxy):
├─ 100 USDC
└─ 100 USDT
```

### After Swap:

**World Chain:**
```
LP: (unchanged, still locked in Vault)
├─ 0 USDC
└─ 0 USDT

Vault: (unchanged, tokens bridged to Base)
├─ 100 USDC
└─ 100 USDT

Trader: (swap complete! ✅)
├─ 0 USDC (spent 10)
└─ 9.996 USDT (received)
```

**Base Chain:**
```
Proxy Physical Wallet:
├─ 110 USDC (100 original + 10 from trader)
└─ 100 USDT (unchanged, 9.996 bridged back to trader)

Aqua Virtual Balances (Proxy):
├─ 110 USDC (increased by swap)
└─ 90.004 USDT (decreased by swap)
```

## 🔑 Key Insights

### 1. **Why `safeTransferFrom(Proxy, Proxy, amount)` Works**

When Aqua does:
```solidity
IERC20(USDT).safeTransferFrom(Proxy, Proxy, 9.996e6);
```

This is VALID because:
- ✅ Proxy has approved Aqua to spend its tokens
- ✅ Proxy has the tokens (bridged from World)
- ✅ Transfer from→to same address is allowed
- ✅ Aqua updates virtual balances regardless

**Physical tokens don't actually move, but Aqua's accounting is updated!**

### 2. **The Trader Gets Their USDT**

The trader receives USDT because:
1. Proxy holds 100 USDT on Base (bridged from LP)
2. Swap pulls 9.996 USDT from Proxy's virtual balance
3. Proxy bridges those 9.996 USDT back to World
4. Trader receives on World Chain ✅

### 3. **LP Earns Fees**

LP's profit:
- Started with: 100 USDC, 100 USDT
- After swap: 110 USDC, 90.004 USDT
- Net gain: +10 USDC, -9.996 USDT
- Fee earned: 0.004 USDC (0.04% of 10) 💰

### 4. **All Automatic via `lzCompose`**

The beauty:
```
Trader sends USDC → OFT bridges → lzCompose() triggers
                                    ↓
                              Swap executes automatically
                                    ↓
                              USDT bridged back
                                    ↓
                              Trader receives ✅
```

No manual steps, no waiting!

## 🎯 The Critical Flow

**The key to understand:**

1. **LP's tokens are PHYSICALLY on Base** (in Proxy's wallet after bridging)
2. **Aqua tracks them VIRTUALLY** (in Proxy's strategy balance)
3. **When trader swaps:**
   - Trader's USDC bridges to Base → Proxy
   - `aqua.pull()` updates virtual USDT: 100 → 90.004
   - Physical USDT stays in Proxy's wallet
   - Proxy bridges 9.996 USDT to trader
   - `aqua.push()` updates virtual USDC: 100 → 110
   - Physical USDC stays in Proxy's wallet
4. **Everything happens on Base** where Aqua and tokens are!

## ✅ Why This Works Without Modifying Aqua

From Aqua's perspective on Base:
- ✅ Proxy is a normal LP with tokens in its wallet
- ✅ `pull()` does `safeTransferFrom(Proxy, Proxy, amt)` → Valid!
- ✅ `push()` does `safeTransferFrom(Proxy, Proxy, amt)` → Valid!
- ✅ Virtual balances update correctly
- ✅ No idea tokens came from another chain!

**Aqua sees Proxy as a regular LP - no modifications needed!** 🎉

