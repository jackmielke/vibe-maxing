# 🚀 Final Deployment Guide: USDT/rUSD Intent System

## **Environment Setup**

```bash
# Chains
export BASE_RPC=https://mainnet.base.org
export WORLD_RPC=https://worldchain-mainnet.g.alchemy.com/public
export BASE_EID=30184

# Tokens on World
export USDT_WORLD=0x79A02482A880bCE3F13e09Da970dC34db4CD24d1
export rUSD_WORLD=<your_rusd_address_on_world>

# Tokens on Base
export USDT_BASE=0x102d758f688a4C1C5a80b116bD945d4455460282
export rUSD_BASE=<your_rusd_address_on_base>

# Stargate OFTs on World (FIND THESE FROM STARGATE DOCS)
export STARGATE_USDT_WORLD=<stargate_usdt_oft_on_world>
export STARGATE_rUSD_WORLD=<stargate_rusd_oft_on_world>

# Stargate OFTs on Base (FIND THESE FROM STARGATE DOCS)
export STARGATE_USDT_BASE=<stargate_usdt_oft_on_base>
export STARGATE_rUSD_BASE=<stargate_rusd_oft_on_base>

# Existing Aqua
export AQUA_BASE=<aqua_router_on_base>
export AMM_BASE=<stableswap_amm_on_base>

# Private Keys
export DEPLOYER_PRIVATE_KEY=0x...
export LP_PRIVATE_KEY=0x...
export TRADER_PRIVATE_KEY=0x...
```

---

## **Step 1: Deploy CrossChainSwapComposer on Base**

```bash
cd packages/layerzero-contracts

forge script scripts/deploy/DeployComposer.s.sol:DeployComposer \
    --rpc-url $BASE_RPC \
    --broadcast

# Save the address
export COMPOSER_BASE=<deployed_address>
```

---

## **Step 2: Set Composer as Trusted Delegate**

```bash
cast send $AQUA_BASE \
    "setTrustedDelegate(address,bool)" \
    $COMPOSER_BASE true \
    --rpc-url $BASE_RPC \
    --private-key $DEPLOYER_PRIVATE_KEY
```

---

## **Step 3: Deploy IntentPool on World**

```bash
export COMPOSER_ADDRESS=$COMPOSER_BASE

forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save the address
export INTENT_POOL_WORLD=<deployed_address>
```

---

## **Step 4: Register USDT and rUSD on Base Composer**

```bash
export COMPOSER_ADDRESS=$COMPOSER_BASE

forge script scripts/RegisterBothTokens.s.sol:RegisterBothTokens \
    --rpc-url $BASE_RPC \
    --broadcast

# Verify
cast call $COMPOSER_BASE "tokenRegistry(bytes32)(address)" $(cast keccak "USDT") --rpc-url $BASE_RPC
cast call $COMPOSER_BASE "tokenRegistry(bytes32)(address)" $(cast keccak "rUSD") --rpc-url $BASE_RPC
```

---

## **Step 5: Ship USDT/rUSD Strategy (if needed)**

```bash
export COMPOSER_ADDRESS=<aqua_strategy_composer_world>  # If you have one
export DST_EID=$BASE_EID
export DST_APP=$AMM_BASE

forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save STRATEGY_HASH from output
export STRATEGY_HASH=<strategy_hash>
```

---

## **Step 6: Register Strategy in IntentPool**

```bash
export INTENT_POOL=$INTENT_POOL_WORLD

forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy \
    --rpc-url $WORLD_RPC \
    --broadcast
```

---

## **Step 7: Test Intent Flow**

### **7.1 - Trader Submits Intent (USDT → rUSD)**

```bash
export TRADER_PRIVATE_KEY=<trader_key>
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD
export STRATEGY_HASH=<your_strategy_hash>
export USDT_ADDRESS=$USDT_WORLD
export rUSD_ADDRESS=$rUSD_WORLD
export SWAP_AMOUNT_IN=1000000  # 1 USDT (6 decimals)

forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent \
    --rpc-url $WORLD_RPC \
    --broadcast

# Save INTENT_ID from output
export INTENT_ID=<intent_id>
```

### **7.2 - LP Fulfills Intent (locks rUSD)**

```bash
export LP_PRIVATE_KEY=<lp_key>
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD
export INTENT_ID=<from_step_7.1>
export rUSD_ADDRESS=$rUSD_WORLD

forge script scripts/intent/Step2_FulfillIntent.s.sol:Step2_FulfillIntent \
    --rpc-url $WORLD_RPC \
    --broadcast
```

### **7.3 - Settle Intent (trigger cross-chain swap)**

```bash
# Quote the fee
cast call $INTENT_POOL_WORLD \
    "quoteSettlementFee(bytes32,uint128)" \
    $INTENT_ID 200000 \
    --rpc-url $WORLD_RPC

# Settle with 20% buffer
export INTENT_POOL=$INTENT_POOL_WORLD
export INTENT_ID=<from_step_7.1>

forge script scripts/intent/Step3_SettleIntent.s.sol:Step3_SettleIntent \
    --rpc-url $WORLD_RPC \
    --broadcast

# Track on LayerZero scan, wait 5-10 minutes
```

### **7.4 - Verify Final Balances**

```bash
export TRADER_ADDRESS=$(cast wallet address --private-key $TRADER_PRIVATE_KEY)
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

# Trader should receive rUSD
cast call $rUSD_WORLD "balanceOf(address)" $TRADER_ADDRESS --rpc-url $WORLD_RPC

# LP should receive USDT
cast call $USDT_WORLD "balanceOf(address)" $LP_ADDRESS --rpc-url $WORLD_RPC
```

---

## **Summary of Variable Names**

| Purpose | Variable Name | Example Value |
|---------|--------------|---------------|
| **Deployment** | | |
| Base Composer | `COMPOSER_BASE` | Deployed address |
| World IntentPool | `INTENT_POOL_WORLD` | Deployed address |
| **Tokens** | | |
| USDT on World | `USDT_WORLD` | `0x79A02...` |
| rUSD on World | `rUSD_WORLD` | Your address |
| USDT on Base | `USDT_BASE` | `0x102d7...` |
| rUSD on Base | `rUSD_BASE` | Your address |
| **Stargate OFTs** | | |
| USDT OFT World | `STARGATE_USDT_WORLD` | From Stargate docs |
| rUSD OFT World | `STARGATE_rUSD_WORLD` | From Stargate docs |
| USDT OFT Base | `STARGATE_USDT_BASE` | From Stargate docs |
| rUSD OFT Base | `STARGATE_rUSD_BASE` | From Stargate docs |
| **Testing** | | |
| Intent Pool | `INTENT_POOL_ADDRESS` | Same as `INTENT_POOL_WORLD` |
| USDT for swap | `USDT_ADDRESS` | Same as `USDT_WORLD` |
| rUSD for swap | `rUSD_ADDRESS` | Same as `rUSD_WORLD` |
| Swap amount | `SWAP_AMOUNT_IN` | `1000000` (1 USDT) |

---

## **Key Points**

1. **All scripts now use USDT and rUSD** (no more USDC references)
2. **Decimal conversion**: USDT (6 decimals) → rUSD (18 decimals) = multiply by 1e12
3. **One deployment per token pair** - this is for USDT/rUSD only
4. **Find Stargate OFT addresses** from: https://stargateprotocol.gitbook.io

---

**Ready to deploy!** Follow the steps in order.

