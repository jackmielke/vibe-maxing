# 🚀 Complete Deployment Guide: USDT/rUSD Cross-Chain Intent Fulfillment

## 📋 Overview

This guide covers the complete deployment and testing of the USDT/rUSD cross-chain swap system using the intent-based flow.

**Token Pair:** USDT (6 decimals) ↔ rUSD (18 decimals)

**Chains:**
- **World Chain**: Where trader and LP initiate swaps
- **Base Chain**: Where strategy lives and swap executes

---

## 🎯 System Architecture

```
World Chain                                Base Chain
┌─────────────────────────────┐          ┌──────────────────────────────┐
│ 1. Trader submits intent    │          │ 5. CrossChainSwapComposer    │
│    (locks USDT)              │          │    receives both tokens      │
│                              │          │                              │
│ 2. LP fulfills intent        │          │ 6. Executes swap on AMM      │
│    (locks rUSD)              │          │    - Calls aqua.pull()       │
│                              │          │    - Calls aqua.push()       │
│ 3. Settler triggers          │ Stargate │                              │
│    dual bridge:              │ ───────> │ 7. Bridges tokens back:      │
│    - LP's rUSD → Base        │          │    - rUSD → Trader (World)   │
│    - Trader's USDT → Base    │          │    - USDT → LP (World)       │
│                              │          │                              │
│ IntentPool                   │          │ Aqua + StableswapAMM         │
└─────────────────────────────┘          └──────────────────────────────┘
```

---

## 📦 Prerequisites

### **Addresses You Need:**

```bash
# World Chain
export WORLD_RPC=https://worldchain-mainnet.g.alchemy.com/public
export USDT_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
export rUSD_WORLD=0x...  # Your rUSD address on World
export STARGATE_USDT_WORLD=0x...  # Stargate USDT OFT on World
export STARGATE_rUSD_WORLD=0x...  # Stargate rUSD OFT on World

# Base Chain
export BASE_RPC=https://mainnet.base.org
export USDT_BASE=0x102d758f688a4C1C5a80b116bD945d4455460282
export rUSD_BASE=0x...  # Your rUSD address on Base
export STARGATE_USDT_BASE=0x...  # Stargate USDT OFT on Base
export STARGATE_rUSD_BASE=0x...  # Stargate rUSD OFT on Base

# Aqua Deployments (already deployed)
export AQUA_BASE=0x...  # Aqua Router on Base
export AMM_BASE=0x...   # StableswapAMM on Base

# LayerZero
export BASE_EID=30184
export WORLD_EID=30280

# Private Keys
export DEPLOYER_PRIVATE_KEY=0x...
export LP_PRIVATE_KEY=0x...
export TRADER_PRIVATE_KEY=0x...
```

---

## 🏗️ Phase 1: Deploy Core Contracts

### **Step 1.1: Deploy CrossChainSwapComposer on Base**

```bash
cd packages/layerzero-contracts

# Set environment
export AQUA_ADDRESS=$AQUA_BASE
export AMM_ADDRESS=$AMM_BASE
export OFT_IN=$STARGATE_USDT_BASE
export OFT_OUT=$STARGATE_rUSD_BASE

# Deploy
forge script scripts/deploy/DeployComposer.s.sol:DeployComposer \
    --rpc-url $BASE_RPC \
    --broadcast \
    --verify

# Save address
export COMPOSER_BASE=0x...  # From deployment output
```

### **Step 1.2: Set Composer as Trusted Delegate in Aqua**

```bash
# The Composer needs to call pullOnBehalfOf/pushOnBehalfOf
cast send $AQUA_BASE \
    "setTrustedDelegate(address,bool)" \
    $COMPOSER_BASE true \
    --rpc-url $BASE_RPC \
    --private-key $DEPLOYER_PRIVATE_KEY
```

### **Step 1.3: Deploy IntentPool on World**

```bash
# Set environment
export BASE_EID=30184
export COMPOSER_ADDRESS=$COMPOSER_BASE
export STARGATE_USDC=$STARGATE_USDT_WORLD  # Note: Script uses USDC var name
export STARGATE_USDT=$STARGATE_rUSD_WORLD  # Note: Script uses USDT var name

# Deploy
forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
    --rpc-url $WORLD_RPC \
    --broadcast \
    --verify

# Save address
export INTENT_POOL_WORLD=0x...  # From deployment output
```

**⚠️ Note:** The IntentPool script currently uses `stargateUSDC` and `stargateUSDT` variable names, but we're mapping them to USDT and rUSD Stargate OFTs respectively.

---

## 🔑 Phase 2: Register Tokens on Base Composer

### **Step 2.1: Verify Current Registrations**

```bash
cd packages/layerzero-contracts

export COMPOSER_ADDRESS=$COMPOSER_BASE

forge script scripts/VerifyTokenRegistrations.s.sol:VerifyTokenRegistrations \
    --rpc-url $BASE_RPC
```

### **Step 2.2: Register USDT and rUSD**

```bash
export DEPLOYER_PRIVATE_KEY=0x...
export COMPOSER_ADDRESS=$COMPOSER_BASE
export rUSD_BASE=0x...

# Register both tokens
forge script scripts/RegisterBothTokens.s.sol:RegisterBothTokens \
    --rpc-url $BASE_RPC \
    --broadcast
```

### **Step 2.3: Verify Registrations**

```bash
# Verify USDT
cast call $COMPOSER_BASE \
    "tokenRegistry(bytes32)(address)" \
    $(cast keccak "USDT") \
    --rpc-url $BASE_RPC
# Expected: 0x102d758f688a4C1C5a80b116bD945d4455460282

# Verify rUSD
cast call $COMPOSER_BASE \
    "tokenRegistry(bytes32)(address)" \
    $(cast keccak "rUSD") \
    --rpc-url $BASE_RPC
# Expected: Your rUSD address
```

---

## 📊 Phase 3: Ship Strategy from World to Base

### **Step 3.1: Ship USDT/rUSD Strategy**

```bash
export LP_PRIVATE_KEY=0x...
export COMPOSER_ADDRESS=0x...  # AquaStrategyComposer on World (if you have one)
export DST_EID=$BASE_EID
export DST_APP=$AMM_BASE

# Ship strategy
forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save from output:
export STRATEGY_HASH=0x...
export GUID=0x...
```

### **Step 3.2: Track Message Delivery**

```bash
# Visit LayerZero scan
echo "https://layerzeroscan.com/tx/$GUID"

# Wait 2-5 minutes for delivery
```

### **Step 3.3: Verify Strategy on Base**

```bash
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

# Check USDT balance
cast call $AQUA_BASE \
    "balances(address,bytes32,address)(uint256)" \
    $LP_ADDRESS \
    $STRATEGY_HASH \
    $USDT_BASE \
    --rpc-url $BASE_RPC
# Expected: 2000000 (2 USDT)

# Check rUSD balance
cast call $AQUA_BASE \
    "balances(address,bytes32,address)(uint256)" \
    $LP_ADDRESS \
    $STRATEGY_HASH \
    $rUSD_BASE \
    --rpc-url $BASE_RPC
# Expected: 2000000000000000000 (2 rUSD)
```

---

## 🧪 Phase 4: Test Intent Fulfillment Flow

### **Step 4.1: Register Strategy in IntentPool**

```bash
export LP_PRIVATE_KEY=0x...
export INTENT_POOL=$INTENT_POOL_WORLD
export STRATEGY_HASH=0x...  # From Phase 3

forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy \
    --rpc-url $WORLD_RPC \
    --broadcast
```

### **Step 4.2: Prepare Test Accounts**

```bash
# Get addresses
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)
export TRADER_ADDRESS=$(cast wallet address --private-key $TRADER_PRIVATE_KEY)

# Ensure LP has rUSD on World
cast call $rUSD_WORLD "balanceOf(address)" $LP_ADDRESS --rpc-url $WORLD_RPC

# Ensure Trader has USDT on World
cast call $USDT_WORLD "balanceOf(address)" $TRADER_ADDRESS --rpc-url $WORLD_RPC

# Both need ETH for gas
cast balance $LP_ADDRESS --rpc-url $WORLD_RPC
cast balance $TRADER_ADDRESS --rpc-url $WORLD_RPC
```

### **Step 4.3: Step 1 - Trader Submits Intent**

```bash
export TRADER_PRIVATE_KEY=0x...
export INTENT_POOL=$INTENT_POOL_WORLD
export STRATEGY_HASH=0x...
export USDC_ADDRESS=$USDT_WORLD  # Note: Script uses USDC var name
export USDT_ADDRESS=$rUSD_WORLD  # Note: Script uses USDT var name
export AMM_ADDRESS=$AMM_BASE

# Submit intent (trader wants to swap USDT for rUSD)
forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save from output:
export INTENT_ID=0x...
```

**What happens:**
- Trader locks USDT in IntentPool
- Intent is created with status PENDING

### **Step 4.4: Step 2 - LP Fulfills Intent**

```bash
export LP_PRIVATE_KEY=0x...
export INTENT_POOL=$INTENT_POOL_WORLD
export INTENT_ID=0x...
export USDT_ADDRESS=$rUSD_WORLD  # Note: Script uses USDT var name

# Fulfill intent
forge script scripts/intent/Step2_FulfillIntent.s.sol:Step2_FulfillIntent \
    --rpc-url $WORLD_RPC \
    --broadcast
```

**What happens:**
- LP locks rUSD in IntentPool
- Intent status changes to MATCHED

### **Step 4.5: Step 3 - Settle Intent (Trigger Cross-Chain Swap)**

```bash
export DEPLOYER_PRIVATE_KEY=0x...  # Or any account with ETH
export INTENT_POOL=$INTENT_POOL_WORLD
export INTENT_ID=0x...

# Quote the settlement fee first
cast call $INTENT_POOL \
    "quoteSettlementFee(bytes32,uint128)" \
    $INTENT_ID \
    200000 \
    --rpc-url $WORLD_RPC

# Save the quoted fee
export SETTLEMENT_FEE=0x...  # Convert to decimal

# Settle intent (with 20% buffer)
forge script scripts/intent/Step3_SettleIntent.s.sol:Step3_SettleIntent \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save GUID from output
export SWAP_GUID=0x...
```

**What happens:**
1. IntentPool sends LP's rUSD to Base via Stargate
2. IntentPool sends Trader's USDT to Base via Stargate
3. Both transfers include `composeMsg` with swap details
4. Intent status changes to SETTLING

### **Step 4.6: Track Cross-Chain Swap**

```bash
# Track on LayerZero scan
echo "https://layerzeroscan.com/tx/$SWAP_GUID"

# Wait 5-10 minutes for:
# 1. Tokens to arrive on Base
# 2. Composer to execute swap
# 3. Tokens to bridge back to World
```

**What happens on Base:**
1. Composer receives both USDT and rUSD
2. Executes `AMM.swapExactIn(USDT → rUSD)`
3. During swap, calls `aqua.pullOnBehalfOf()` (LP's rUSD)
4. During swap, calls `aqua.pushOnBehalfOf()` (Trader's USDT)
5. Bridges output tokens back:
   - rUSD → Trader on World
   - USDT → LP on World

### **Step 4.7: Verify Final Balances**

```bash
# Check Trader received rUSD on World
cast call $rUSD_WORLD "balanceOf(address)" $TRADER_ADDRESS --rpc-url $WORLD_RPC

# Check LP received USDT on World
cast call $USDT_WORLD "balanceOf(address)" $LP_ADDRESS --rpc-url $WORLD_RPC

# Check updated Aqua balances on Base
cast call $AQUA_BASE \
    "balances(address,bytes32,address)(uint256)" \
    $LP_ADDRESS \
    $STRATEGY_HASH \
    $USDT_BASE \
    --rpc-url $BASE_RPC

cast call $AQUA_BASE \
    "balances(address,bytes32,address)(uint256)" \
    $LP_ADDRESS \
    $STRATEGY_HASH \
    $rUSD_BASE \
    --rpc-url $BASE_RPC
```

---

## 📋 Complete Checklist

### **Phase 1: Deploy**
- [ ] Deploy CrossChainSwapComposer on Base
- [ ] Set Composer as trusted delegate in Aqua
- [ ] Deploy IntentPool on World
- [ ] Fund Composer with ETH for return trips (optional)

### **Phase 2: Register Tokens**
- [ ] Verify token registrations on Base Composer
- [ ] Register USDT on Base Composer
- [ ] Register rUSD on Base Composer
- [ ] Verify both registrations

### **Phase 3: Ship Strategy**
- [ ] Ship USDT/rUSD strategy from World to Base
- [ ] Track message on LayerZero scan
- [ ] Verify strategy balances on Base

### **Phase 4: Test Intent Flow**
- [ ] Register strategy in IntentPool
- [ ] Ensure LP has rUSD on World
- [ ] Ensure Trader has USDT on World
- [ ] Step 1: Trader submits intent
- [ ] Step 2: LP fulfills intent
- [ ] Step 3: Settle intent (trigger cross-chain swap)
- [ ] Track swap on LayerZero scan
- [ ] Verify final balances

---

## 🚨 Important Notes

### **Token Naming in Scripts**

Some scripts still use old variable names. Here's the mapping:

| Script Variable | Actual Token | Address |
|----------------|--------------|---------|
| `USDC_ADDRESS` | USDT | `0x79A02482A880bCE3F13e09Da970dC34db4CD24d1` (World) |
| `USDT_ADDRESS` | rUSD | Your rUSD address |
| `stargateUSDC` | Stargate USDT | Your Stargate USDT OFT |
| `stargateUSDT` | Stargate rUSD | Your Stargate rUSD OFT |

### **Decimals**

- USDT: 6 decimals → amounts like `1000000` = 1 USDT
- rUSD: 18 decimals → amounts like `1000000000000000000` = 1 rUSD

### **Gas Fees**

- Trader needs ETH on World for submitting intent
- LP needs ETH on World for fulfilling intent
- Settler needs ETH on World for triggering settlement
- Settlement requires significant ETH for dual Stargate transfers

---

## 🔍 Troubleshooting

### **Issue: "TokenNotMapped" error**

**Solution:** Register tokens on Base Composer
```bash
forge script scripts/RegisterBothTokens.s.sol:RegisterBothTokens \
    --rpc-url $BASE_RPC --broadcast
```

### **Issue: "Insufficient fee" during settlement**

**Solution:** Quote the fee first and add buffer
```bash
# Quote fee
cast call $INTENT_POOL "quoteSettlementFee(bytes32,uint128)" $INTENT_ID 200000 --rpc-url $WORLD_RPC

# Use the quoted amount + 20% buffer
```

### **Issue: Swap not executing on Base**

**Check:**
1. Both tokens arrived at Composer
2. Composer is trusted delegate in Aqua
3. Strategy has sufficient liquidity
4. AMM is deployed and functional

### **Issue: Tokens not bridging back**

**Check:**
1. Composer has ETH for return trip gas
2. Stargate OFT addresses are correct
3. LayerZero message delivered successfully

---

## 🎉 Success Criteria

Your system is working when:

1. ✅ Trader submits intent and USDT is locked
2. ✅ LP fulfills intent and rUSD is locked
3. ✅ Settlement triggers dual Stargate transfers
4. ✅ Swap executes on Base
5. ✅ Aqua balances update correctly
6. ✅ Trader receives rUSD on World
7. ✅ LP receives USDT on World

---

## 📚 Available Scripts

### **Deployment:**
- `scripts/deploy/DeployComposer.s.sol` - Deploy CrossChainSwapComposer on Base
- `scripts/deploy/DeployIntentPool.s.sol` - Deploy IntentPool on World

### **Token Registration:**
- `scripts/VerifyTokenRegistrations.s.sol` - Check token registrations
- `scripts/RegisterBothTokens.s.sol` - Register USDT + rUSD
- `scripts/RegisterUSDT.s.sol` - Register USDT only
- `scripts/RegisterRUSD.s.sol` - Register rUSD only

### **Strategy Shipping:**
- `scripts/shipStrategyToChain.s.sol` - Ship USDT/rUSD strategy

### **Intent Flow:**
- `scripts/intent/RegisterStrategy.s.sol` - Register strategy in IntentPool
- `scripts/intent/Step1_SubmitIntent.s.sol` - Trader submits intent
- `scripts/intent/Step2_FulfillIntent.s.sol` - LP fulfills intent
- `scripts/intent/Step3_SettleIntent.s.sol` - Trigger cross-chain swap

---

**🚀 You're ready to test the complete USDT/rUSD intent fulfillment flow!**

