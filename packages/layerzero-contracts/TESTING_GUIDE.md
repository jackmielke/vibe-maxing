# Testing Guide - Cross-Chain Strategy Shipping

## Setup Test Account

Create a separate tester private key:

```bash
# Generate a new private key (or use an existing test account)
export TESTER_PRIVATE_KEY=0x...

# Get the address
cast wallet address --private-key $TESTER_PRIVATE_KEY

# Fund it with testnet ETH on both chains
# Sepolia: https://sepoliafaucet.com/
# Arbitrum Sepolia: https://faucet.quicknode.com/arbitrum/sepolia
```

## Environment Setup

```bash
# Required for all operations
export PRIVATE_KEY=0x...  # Admin key
export TESTER_PRIVATE_KEY=0x...  # Test LP key

# RPC URLs
export SEPOLIA_RPC=https://ethereum-sepolia.publicnode.com
export ARB_SEPOLIA_RPC=https://arbitrum-sepolia.publicnode.com

# Deployed addresses (from deployment steps)
export COMPOSER_SEPOLIA=0x...
export COMPOSER_ARB_SEPOLIA=0x...
export AQUA_ARB_SEPOLIA=0x...
export STABLESWAP_ARB_SEPOLIA=0x...

# Token addresses on Arbitrum Sepolia
export USDC_ARB_SEPOLIA=0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
export USDT_ARB_SEPOLIA=0x...
```

## Test Flow

### 1. Ship Strategy from Sepolia

```bash
cd packages/ethglobal-ba-2025

# Set test parameters
export COMPOSER_ADDRESS=$COMPOSER_SEPOLIA
export DST_EID=40231  # Arbitrum Sepolia
export DST_APP=$STABLESWAP_ARB_SEPOLIA

# Run the ship script (uses TESTER_PRIVATE_KEY if available)
forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $SEPOLIA_RPC \
  --broadcast
```

### 2. Save Output Values

The script will output:

```
=================================================
SUCCESS! Strategy Shipped Cross-Chain
=================================================

IMPORTANT - Save these values:
---------------------------------------------
Maker Address: 0xYourTesterAddress
Strategy Hash: 0x...

MESSAGE TRACKING:
GUID: 0x...
Nonce: 0
Fee Paid: 150000000000000 wei

Track your message at:
https://testnet.layerzeroscan.com/tx/0x...
=================================================
```

**Save these:**
```bash
export MAKER_ADDRESS=0x...  # From output
export STRATEGY_HASH=0x...  # From output
export GUID=0x...           # From output
```

### 3. Track Message on LayerZero Scan

Visit the URL from the output:
```
https://testnet.layerzeroscan.com/tx/0x...
```

Wait for:
- ✅ Status: Delivered
- ✅ Execution: Success

This usually takes 2-5 minutes on testnets.

### 4. Verify Strategy on Destination

Once the message is delivered, verify the strategy was shipped:

```bash
# Set verification parameters
export MAKER_ADDRESS=0x...      # From step 2
export STRATEGY_HASH=0x...      # From step 2
export AQUA_ADDRESS=$AQUA_ARB_SEPOLIA
export APP_ADDRESS=$STABLESWAP_ARB_SEPOLIA
export TOKEN0_ADDRESS=$USDC_ARB_SEPOLIA
export TOKEN1_ADDRESS=$USDT_ARB_SEPOLIA

# Run verification script
forge script scripts/verifyShippedStrategy.s.sol:VerifyShippedStrategyScript \
  --rpc-url $ARB_SEPOLIA_RPC
```

### 5. Expected Verification Output

```
=================================================
Verifying Shipped Strategy
=================================================
Maker: 0xYourTesterAddress
Strategy Hash: 0x...
Aqua: 0x...
App: 0x...

Token 0 Balance: 1000000000
Tokens Count: 2
Status: ACTIVE

Token 1 Balance: 1000000000
Tokens Count: 2
Status: ACTIVE

=================================================
SUCCESS! Strategy is active on destination chain
Total tokens in strategy: 2
=================================================
```

## Manual Verification Commands

### Check Composer Configuration

```bash
# Check Aqua is set
cast call $COMPOSER_ARB_SEPOLIA "aqua()" --rpc-url $ARB_SEPOLIA_RPC

# Check token registry
cast call $COMPOSER_ARB_SEPOLIA \
  "tokenRegistry(bytes32)" $(cast keccak "USDC") \
  --rpc-url $ARB_SEPOLIA_RPC

# Should return: $USDC_ARB_SEPOLIA
```

### Check Aqua Balances Directly

```bash
# Check USDC balance
cast call $AQUA_ARB_SEPOLIA \
  "rawBalances(address,address,bytes32,address)" \
  $MAKER_ADDRESS \
  $STABLESWAP_ARB_SEPOLIA \
  $STRATEGY_HASH \
  $USDC_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC

# Returns: (balance, tokensCount)
# Example: (0x000000000000000000000000000000000000000000000000000000003b9aca00, 0x02)
# 0x3b9aca00 = 1000000000 = 1000 USDC (6 decimals)
# 0x02 = 2 tokens in strategy
```

### Check Events

```bash
# Check CrossChainShipExecuted event on Arbitrum Sepolia
cast logs \
  --address $COMPOSER_ARB_SEPOLIA \
  --from-block latest-1000 \
  --rpc-url $ARB_SEPOLIA_RPC
```

### Check Cross-Chain Strategy Info

```bash
# Check cross-chain strategy tracking
cast call $COMPOSER_ARB_SEPOLIA \
  "crossChainStrategies(address,bytes32)" \
  $MAKER_ADDRESS \
  $STRATEGY_HASH \
  --rpc-url $ARB_SEPOLIA_RPC

# Returns: (sourceEid, sourceMaker, hasVirtualLiquidity, timestamp)
```

## Troubleshooting

### Message Not Delivered

**Check LayerZero Scan status:**
- If "Inflight": Wait longer (can take up to 15 min on testnets)
- If "Failed": Check error message

**Common causes:**
- Insufficient gas limit (increase to 300000)
- Peer not set correctly
- Destination chain not supported

### Strategy Not Found in Aqua

**Check:**

1. **Aqua address set?**
```bash
cast call $COMPOSER_ARB_SEPOLIA "aqua()" --rpc-url $ARB_SEPOLIA_RPC
```

2. **Tokens registered?**
```bash
cast call $COMPOSER_ARB_SEPOLIA \
  "tokenRegistry(bytes32)" $(cast keccak "USDC") \
  --rpc-url $ARB_SEPOLIA_RPC
```

3. **Check for CrossChainShipFailed event:**
```bash
cast logs \
  --address $COMPOSER_ARB_SEPOLIA \
  --from-block latest-1000 \
  --rpc-url $ARB_SEPOLIA_RPC | grep "CrossChainShipFailed"
```

### Wrong Maker Address

The maker address should be the **tester's address** (the one that called `shipStrategyToChain` on Sepolia).

**Verify:**
```bash
# Get address from private key
cast wallet address --private-key $TESTER_PRIVATE_KEY

# This should match the maker address in the output
```

## Test Scenarios

### Scenario 1: Basic USDC/USDT Stableswap

```bash
# Already implemented in shipStrategyToChain.s.sol
# Uses: keccak256("USDC"), keccak256("USDT")
# Amounts: 1000 USDC, 1000 USDT
# Fee: 30 bps (0.3%)
# Amplification: 100
```

### Scenario 2: WETH/USDC Concentrated Liquidity

Modify the script to use:
```solidity
tokenIds[0] = keccak256("WETH");
tokenIds[1] = keccak256("USDC");
amounts[0] = 1e18;      // 1 WETH
amounts[1] = 2000e6;    // 2000 USDC
```

### Scenario 3: Multiple Strategies from Same LP

Run the script multiple times with different salts:
```solidity
salt: keccak256("pool-1")
salt: keccak256("pool-2")
salt: keccak256("pool-3")
```

Each will create a different strategy hash.

## Success Criteria

✅ Message delivered on LayerZero Scan  
✅ CrossChainShipExecuted event emitted  
✅ Strategy found in Aqua with correct balances  
✅ Maker address matches tester address  
✅ Strategy hash matches expected value  
✅ tokensCount = 2 (for 2-token strategy)  
✅ Virtual liquidity recorded correctly  

## Next Steps After Successful Test

1. **Test with different token pairs**
2. **Test with different strategy parameters**
3. **Test from different source chains** (if deployed)
4. **Implement liquidity fulfillment** (Phase 2)
5. **Test cross-chain dock()** (Phase 2)

## Quick Reference

```bash
# Ship strategy
forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $SEPOLIA_RPC --broadcast

# Verify strategy
forge script scripts/verifyShippedStrategy.s.sol:VerifyShippedStrategyScript \
  --rpc-url $ARB_SEPOLIA_RPC

# Check balance
cast call $AQUA_ARB_SEPOLIA \
  "rawBalances(address,address,bytes32,address)" \
  $MAKER $APP $HASH $TOKEN --rpc-url $ARB_SEPOLIA_RPC
```

