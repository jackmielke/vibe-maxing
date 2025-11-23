# Quick Start: Cross-Chain Strategy Shipping

Test the message-only cross-chain flow in 5 minutes!

## Prerequisites

- Testnet ETH on Sepolia and Arbitrum Sepolia
- Private key with funds

## Step 1: Setup (1 min)

```bash
cd packages/ethglobal-ba-2025
pnpm install
pnpm compile

# Create .env file
echo "PRIVATE_KEY=0xyourkey" > .env
```

## Step 2: Deploy Contracts (2 min)

```bash
# Deploy on Sepolia
pnpm hardhat lz:deploy --tags AquaStrategyComposer --network sepolia

# Deploy on Arbitrum Sepolia
pnpm hardhat lz:deploy --tags AquaStrategyComposer --network arbitrum-sepolia

# Save addresses to .env
echo "COMPOSER_ADDRESS_SEPOLIA=0x..." >> .env
echo "COMPOSER_ADDRESS_ARB_SEPOLIA=0x..." >> .env
```

## Step 3: Configure Peers (1 min)

```bash
# Wire the contracts together
pnpm hardhat lz:oapp:wire --oapp-config layerzero.aqua.config.ts
```

## Step 4: Enable Destination Chain (30 sec)

```bash
# On Sepolia, allow shipping to Arbitrum Sepolia (EID: 40231)
cast send $COMPOSER_ADDRESS_SEPOLIA \
  "addSupportedChain(uint32)" 40231 \
  --rpc-url https://ethereum-sepolia.publicnode.com \
  --private-key $PRIVATE_KEY
```

## Step 5: Ship Strategy! (30 sec)

```bash
# Set test parameters
export COMPOSER_ADDRESS=$COMPOSER_ADDRESS_SEPOLIA
export DST_EID=40231
export DST_APP=0x0000000000000000000000000000000000000001

# Run the test script
forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url https://ethereum-sepolia.publicnode.com \
  --broadcast
```

## Step 6: Track Message

Visit the LayerZero Scan URL from the output:
```
https://testnet.layerzeroscan.com/tx/0x...
```

You should see:
- ✅ Message sent from Sepolia
- ✅ Message delivered to Arbitrum Sepolia
- ✅ `CrossChainShipConfirmed` event emitted

## Success! 🎉

You've successfully shipped a strategy cross-chain using only messages (no token transfers).

## What Just Happened?

1. **On Sepolia**: Your LP address called `shipStrategyToChain()` with:
   - Strategy parameters (USDC/USDT stableswap, 0.3% fee, 100x amplification)
   - Virtual amounts (1000 USDC, 1000 USDT)
   - Destination chain (Arbitrum Sepolia)

2. **LayerZero**: Message was verified by DVNs and executed by relayer

3. **On Arbitrum Sepolia**: `lzReceive()` was called and emitted `CrossChainShipConfirmed`

## Next Steps

See [CROSS_CHAIN_SHIP_GUIDE.md](./CROSS_CHAIN_SHIP_GUIDE.md) for:
- Detailed explanations
- Troubleshooting
- Advanced configurations
- Integration with Aqua protocol

## Troubleshooting

**"InvalidDestinationChain"** → Run Step 4 again

**"Insufficient balance"** → Get more testnet ETH from faucets

**Message not arriving** → Wait 5-10 minutes, check LayerZero Scan

## Faucets

- Sepolia: https://sepoliafaucet.com/
- Arbitrum Sepolia: https://faucet.quicknode.com/arbitrum/sepolia

