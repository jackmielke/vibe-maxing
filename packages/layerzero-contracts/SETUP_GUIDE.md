# Cross-Chain Strategy Shipping - Complete Setup Guide

## Overview

The AquaStrategyComposer now **fully integrates with Aqua protocol** to actually ship strategies on the destination chain. When a message arrives, it:

1. ✅ Receives LayerZero message
2. ✅ Resolves canonical token IDs to local addresses
3. ✅ Calls `Aqua.ship()` with resolved tokens
4. ✅ Records cross-chain strategy info
5. ✅ Emits `CrossChainShipExecuted` event

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Source Chain (Ethereum Sepolia)                                 │
│                                                                  │
│  LP calls shipStrategyToChain()                                 │
│    - strategy params                                             │
│    - canonical token IDs (keccak256("USDC"))                    │
│    - amounts (virtual)                                           │
│    ↓                                                             │
│  AquaStrategyComposer                                           │
│    ↓ _lzSend()                                                  │
│  LayerZero Endpoint                                             │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ LayerZero Network
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ Destination Chain (Arbitrum Sepolia)                            │
│                                                                  │
│  LayerZero Endpoint                                             │
│    ↓ lzReceive()                                                │
│  AquaStrategyComposer                                           │
│    ↓ _lzReceive()                                               │
│    ↓ handleShip()                                               │
│    │                                                             │
│    ├─ Resolve token IDs:                                        │
│    │  keccak256("USDC") → 0xUSDC_on_Arbitrum                   │
│    │  keccak256("USDT") → 0xUSDT_on_Arbitrum                   │
│    │                                                             │
│    ├─ Call Aqua.ship():                                         │
│    │  aqua.ship(app, strategy, tokens, amounts)                │
│    │                                                             │
│    └─ Record cross-chain info                                   │
│       ↓                                                          │
│  ✅ Strategy shipped on Aqua!                                    │
│  ✅ CrossChainShipExecuted event                                │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Testnet ETH** on both chains
2. **Aqua deployed** on destination chain (Arbitrum Sepolia)
3. **Strategy apps deployed** (StableswapAMM, ConcentratedLiquiditySwap)
4. **Token addresses** on both chains

## Step-by-Step Setup

### 1. Deploy Aqua on Arbitrum Sepolia (if not already)

```bash
cd packages/aqua

# Deploy AquaRouter
forge script script/DeployAquaRouter.s.sol:DeployAquaRouter \
  --rpc-url $ARB_SEPOLIA_RPC \
  --broadcast \
  --verify

# Save address
export AQUA_ARB_SEPOLIA=0x...
```

**Note:** We'll set the trusted delegate after deploying the Composer in step 4.

### 2. Deploy Strategy Apps on Arbitrum Sepolia

```bash
cd packages/contracts

# Deploy StableswapAMM
forge create src/StableswapAMM.sol:StableswapAMM \
  --constructor-args $AQUA_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

export STABLESWAP_ARB_SEPOLIA=0x...

# Deploy ConcentratedLiquiditySwap
forge create src/ConcentratedLiquiditySwap.sol:ConcentratedLiquiditySwap \
  --constructor-args $AQUA_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

export CONCENTRATED_ARB_SEPOLIA=0x...
```

### 3. Deploy AquaStrategyComposer on Both Chains

**On Ethereum Sepolia (source):**

```bash
cd packages/ethglobal-ba-2025

# Deploy without Aqua (not needed on source chain)
pnpm hardhat lz:deploy --tags AquaStrategyComposer --network sepolia

export COMPOSER_SEPOLIA=0x...
```

**On Arbitrum Sepolia (destination):**

```bash
# Deploy with Aqua address
export AQUA_ADDRESS=$AQUA_ARB_SEPOLIA

pnpm hardhat lz:deploy --tags AquaStrategyComposer --network arbitrum-sepolia

export COMPOSER_ARB_SEPOLIA=0x...
```

### 4. Configure Composer on Arbitrum Sepolia

**Set Aqua address (if not set during deployment):**

```bash
cast send $COMPOSER_ARB_SEPOLIA \
  "setAqua(address)" \
  $AQUA_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**⭐ CRITICAL: Set Composer as Trusted Delegate in Aqua:**

```bash
# This allows the Composer to call shipOnBehalfOf() for cross-chain operations
cast send $AQUA_ARB_SEPOLIA \
  "setTrustedDelegate(address,bool)" \
  $COMPOSER_ARB_SEPOLIA \
  true \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

# Verify it was set
cast call $AQUA_ARB_SEPOLIA \
  "trustedDelegates(address)" \
  $COMPOSER_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC
# Should return: true (0x0000...0001)
```

**Alternative: Use the dedicated script:**

```bash
cd packages/aqua

AQUA_ADDRESS=$AQUA_ARB_SEPOLIA \
DELEGATE_ADDRESS=$COMPOSER_ARB_SEPOLIA \
TRUSTED=true \
forge script script/SetTrustedDelegate.s.sol:SetTrustedDelegate \
  --rpc-url $ARB_SEPOLIA_RPC \
  --broadcast
```

**Register tokens:**

```bash
# Get token addresses on Arbitrum Sepolia
export USDC_ARB_SEPOLIA=0x...  # USDC on Arbitrum Sepolia
export USDT_ARB_SEPOLIA=0x...  # USDT on Arbitrum Sepolia

# Register USDC
cast send $COMPOSER_ARB_SEPOLIA \
  "registerToken(bytes32,address)" \
  $(cast keccak "USDC") \
  $USDC_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

# Register USDT
cast send $COMPOSER_ARB_SEPOLIA \
  "registerToken(bytes32,address)" \
  $(cast keccak "USDT") \
  $USDT_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**Or batch register:**

```bash
cast send $COMPOSER_ARB_SEPOLIA \
  "registerTokens(bytes32[],address[])" \
  "[$(cast keccak "USDC"),$(cast keccak "USDT")]" \
  "[$USDC_ARB_SEPOLIA,$USDT_ARB_SEPOLIA]" \
  --rpc-url $ARB_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

### 5. Configure LayerZero Peers

```bash
pnpm hardhat lz:oapp:wire --oapp-config layerzero.aqua.config.ts
```

### 6. Enable Destination Chain on Source

```bash
cast send $COMPOSER_SEPOLIA \
  "addSupportedChain(uint32)" \
  40231 \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

### 7. Test Cross-Chain Ship

```bash
export COMPOSER_ADDRESS=$COMPOSER_SEPOLIA
export DST_EID=40231
export DST_APP=$STABLESWAP_ARB_SEPOLIA

forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $SEPOLIA_RPC \
  --broadcast
```

### 8. Verify Strategy Was Shipped

**Check events on Arbitrum Sepolia:**

```bash
# Check for CrossChainShipExecuted event
cast logs \
  --address $COMPOSER_ARB_SEPOLIA \
  --from-block latest-1000 \
  --rpc-url $ARB_SEPOLIA_RPC
```

**Check Aqua for the strategy:**

```bash
# Get strategy hash from the output of step 7
export STRATEGY_HASH=0x...
export MAKER_ADDRESS=0x...  # Your address

# Check balance in Aqua
cast call $AQUA_ARB_SEPOLIA \
  "rawBalances(address,address,bytes32,address)" \
  $MAKER_ADDRESS \
  $STABLESWAP_ARB_SEPOLIA \
  $STRATEGY_HASH \
  $USDC_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC
```

## Contract Interface

### AquaStrategyComposer

**Key Functions:**

```solidity
// Admin - Setup
function setAqua(address _aqua) external onlyOwner
function registerToken(bytes32 canonicalId, address token) external onlyOwner
function registerTokens(bytes32[] calldata canonicalIds, address[] calldata tokens) external onlyOwner

// Admin - Configuration
function addSupportedChain(uint32 eid) external onlyOwner
function whitelistApp(uint32 eid, address app) external onlyOwner

// User - Shipping
function shipStrategyToChain(
    uint32 dstEid,
    address dstApp,
    bytes calldata strategy,
    bytes32[] calldata tokenIds,
    uint256[] calldata amounts,
    bytes calldata options
) external payable returns (MessagingReceipt memory)

function quoteShipStrategy(...) external view returns (MessagingFee memory)

// View
function tokenRegistry(bytes32 canonicalId) external view returns (address)
function crossChainStrategies(address maker, bytes32 strategyHash) external view returns (CrossChainStrategy memory)
```

**Events:**

```solidity
event CrossChainShipInitiated(address indexed maker, uint32 indexed dstEid, bytes32 strategyHash, bytes32 guid)
event CrossChainShipExecuted(address indexed maker, uint32 indexed srcEid, bytes32 strategyHash, bytes32 guid, address app, address[] tokens)
event CrossChainShipFailed(bytes32 indexed guid, uint32 indexed srcEid, string reason)
event TokenRegistered(bytes32 indexed canonicalId, address indexed token)
```

## Token Registry

The composer uses canonical token IDs to resolve tokens across chains:

| Canonical ID | Ethereum Sepolia | Arbitrum Sepolia |
|--------------|------------------|------------------|
| `keccak256("USDC")` | 0x... | 0x... |
| `keccak256("USDT")` | 0x... | 0x... |
| `keccak256("WETH")` | 0x... | 0x... |
| `keccak256("DAI")` | 0x... | 0x... |

Register tokens on each chain where the composer will receive messages.

## Error Handling

The composer includes comprehensive error handling:

```solidity
// If token not registered
error TokenNotMapped(bytes32 canonicalId)

// If Aqua not set
error AquaNotSet()

// If destination chain not supported
error InvalidDestinationChain(uint32 dstEid)

// If app address invalid
error InvalidAppAddress(address app)
```

**Failed ships emit:**
```solidity
event CrossChainShipFailed(bytes32 indexed guid, uint32 indexed srcEid, string reason)
```

## Testing Checklist

- [ ] Aqua deployed on destination chain
- [ ] Strategy apps deployed on destination chain
- [ ] Composer deployed on both chains
- [ ] Aqua address set on destination composer
- [ ] Tokens registered on destination composer
- [ ] Peers configured
- [ ] Destination chain enabled on source
- [ ] Test message sent
- [ ] Message delivered (check LayerZero Scan)
- [ ] Strategy shipped (check Aqua balances)
- [ ] Events emitted correctly

## Troubleshooting

### "AquaNotSet" Error

**Solution**: Set Aqua address on destination chain:
```bash
cast send $COMPOSER_ARB_SEPOLIA "setAqua(address)" $AQUA_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC --private-key $PRIVATE_KEY
```

### "TokenNotMapped" Error

**Solution**: Register the token:
```bash
cast send $COMPOSER_ARB_SEPOLIA \
  "registerToken(bytes32,address)" \
  $(cast keccak "USDC") \
  $USDC_ARB_SEPOLIA \
  --rpc-url $ARB_SEPOLIA_RPC --private-key $PRIVATE_KEY
```

### Strategy Not Showing in Aqua

**Check**:
1. Verify `CrossChainShipExecuted` event was emitted
2. Check if Aqua.ship() reverted (see `CrossChainShipFailed`)
3. Verify token addresses are correct
4. Check if maker address matches

### Message Delivered but No Ship

**Possible causes**:
1. Aqua not set - check with `cast call $COMPOSER "aqua()"`
2. Tokens not registered - check with `cast call $COMPOSER "tokenRegistry(bytes32)" $(cast keccak "USDC")`
3. Aqua.ship() reverted - check events

## Next Steps

After confirming the flow works:

1. **Add Liquidity Fulfillment**: Implement escrow/pool/relayer model
2. **Cross-Chain Dock**: Enable strategy removal from source chain
3. **Fee Distribution**: Send earned fees back to LP
4. **Multi-Chain Support**: Add more chains (Base, Optimism, etc.)
5. **Mainnet Deployment**: Deploy to production networks

## Resources

- [LayerZero Docs](https://docs.layerzero.network/)
- [Aqua Protocol](../aqua/)
- [LayerZero Scan](https://testnet.layerzeroscan.com/)

## Support

For issues:
1. Check LayerZero Scan for message status
2. Verify all configuration steps
3. Check contract events
4. Review error messages

