<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/LayerZero_Logo_White.svg"/>
  </a>
</p>

<p align="center">
  <a href="https://layerzero.network" style="color: #a77dff">Homepage</a> | <a href="https://docs.layerzero.network/" style="color: #a77dff">Docs</a> | <a href="https://layerzero.network/developers" style="color: #a77dff">Developers</a>
</p>

<h1 align="center">Aave V3 Composer Example</h1>

<p align="center">
  <a href="https://docs.layerzero.network/v2/developers/evm/oft/quickstart" style="color: #a77dff">Quickstart</a> | <a href="https://docs.layerzero.network/contracts/oapp-configuration" style="color: #a77dff">Configuration</a> | <a href="https://docs.layerzero.network/contracts/options" style="color: #a77dff">Message Execution Options</a> | <a href="https://docs.layerzero.network/v2/developers/evm/composer/overview" style="color: #a77dff">Composer Overview</a>
</p>

<p align="center">
  A set of Composer examples to integrate LayerZero composer contracts with the Omnichain Fungible Token (OFT) standard.
</p>

## Table of Contents

- [Prerequisite Knowledge](#prerequisite-knowledge)
- [Introduction](#introduction)
- [Requirements](#requirements)
- [Scaffold this Example](#scaffold-this-example)
- [Helper Resources](#helper-resources)
- [Helper Tasks](#helper-tasks)
- [Setup](#setup)
  - [1. Environment Configuration](#1-environment-configuration)
  - [2. Network Configuration](#2-network-configuration)
  - [3. Composer Deployment Configuration](#3-composer-deployment-configuration)
- [Build](#build)
- [Deploy](#deploy)
  - [AaveV3 Composer Deployment](#aavev3-composer-deployment)
- [Enable Messaging (for manually deployed OFTs only)](#enable-messaging-for-manually-deployed-ofts-only)
- [Stargate to Aave Supply Task](#stargate-to-aave-supply-task)
- [Appendix](#appendix)
  - [Running Tests](#running-tests)
  - [Adding Other Chains](#adding-other-chains)

## Prerequisite Knowledge

Before diving into this repository you should understand:

- [OFT Standard](https://docs.layerzero.network/v2/developers/evm/oft/quickstart) — how omnichain ERC20s are minted/burned across chains.
- [Composer Pattern](https://docs.layerzero.network/v2/developers/evm/composer/overview) — how OFT transfers can be extended with compose payloads.
- [Aave v3](https://docs.aave.com/developers/core-contracts/pool) lending flow.

## Introduction

The OFT Composer library demonstrates how to run **post-bridge workflows** on the destination chain. Ready-to-run contract live in `contracts/` and it's deployment script live in `deploy/`:

- `AaveV3Composer` routes bridged tokens through Stargate and supplies them to an Aave v3 pool.

Learn more about [OFT (Omnichain Fungible Token)](https://docs.layerzero.network/v2/concepts/glossary#oft-omnichain-fungible-token)

## Requirements

- git
- Node.js ≥ 18.18
- pnpm ≥ 8.15 (enable via `corepack enable`)

## Scaffold this Example

```bash
git clone https://github.com/lzJxhn/ethglobal-ba-2025

cd ethglobal-ba-2025
```
## Helper Resources

- [Endpoint IDs and Addresses](https://docs.layerzero.network/v2/deployments/deployed-contracts)
- [Stargate v2 Addresses](https://docs.layerzero.network/v2/deployments/oft-ecosystem-stargate-assets?stages=testnet&issuers=Stargate)
- [Aave v3 Pool Addresses](https://aave.com/docs/resources/addresses) 

## Helper Tasks

Run `pnpm hardhat` to list every built-in task. The most relevant tasks for this example are:

- `lz:deploy` — deploy and tag composer contracts per network.
- `lz:oapp:config:init` / `lz:oapp:wire` — bootstrap and apply messaging configs.
- `lz:oft:send` — send OFT tokens without composer logic (useful for smoke tests).
- `aave:supply` — bridge tokens through Stargate and compose into `AaveV3Composer`.

## Setup
### 1. Environment Configuration

Copy the template and fill in every value before running builds, deploys, or tasks:

```bash
cp .env.example .env
```

```bash
PRIVATE_KEY="0xyourdeployer"
```

- `AAVE_V3_POOL_ADDRESS` / `STARGATE_POOL_ADDRESS` are required by `deploy/AaveV3Composer.ts`.

### 2. Network Configuration

Edit `hardhat.config.ts` and align networks with the Endpoint IDs you intend to use. Example configuration:

```ts
   ...
   networks: {
        'arbitrum-mainnet': {
            eid: EndpointId.ARBITRUM_V2_MAINNET,
            url: process.env.RPC_URL_ARB || 'https://arbitrum.gateway.tenderly.co',
            accounts,
        },
        'base-mainnet': {
            eid: EndpointId.BASE_V2_MAINNET,
            url: process.env.RPC_URL_BASE || 'https://base.gateway.tenderly.co',
            accounts,
        },
    ...
```

Ensure every network listed here has a matching `RPC_URL_*` entry in `.env`.

Note: you don't have to use mainnet as in the demo, you can also use testnets, just make sure to use testnets where stargate and aave contracts are deployed. [See Resources.](#helper-resources)

## Build

Install dependencies and compile contracts:

```bash
pnpm install
pnpm compile        # runs both Hardhat + Forge toolchains
```

Need a specific tool only? Run `pnpm compile:hardhat` or `pnpm compile:forge`.

Run unit tests with `pnpm test`, or select suites via `pnpm test:hardhat` / `pnpm test:forge`.

## Deploy

### AaveV3 Composer Deployment

- Script: `examples/oft-composers/deploy/AaveV3Composer.ts`
- Required `.env` keys: `PRIVATE_KEY`, `AAVE_V3_POOL_ADDRESS`, `STARGATE_POOL_ADDRESS`, relevant `RPC_URL_*`.
- Constructor: `(aavePool, stargatePool)`.

```bash
AAVE_V3_POOL_ADDRESS="0xDstAavePool" \
STARGATE_POOL_ADDRESS="0xDstStargateContract" \
pnpm hardhat lz:deploy --tags AaveV3Composer
```

The script asserts both addresses exist and belong to deployed contracts before broadcasting. Double-check that the Stargate pool you specify supports the token you’ll bridge (e.g., USDC on Arbitrum Sepolia) and that the Aave pool lives on the hub chain that will execute the supply.

## Enable Messaging (for manually deployed OFTs only)

If you manually deployed OFTs (Asset/Share, adapters, or any custom OApp), you still need to wire them with LayerZero. There are two ways to do it—pick the one that matches your tooling:

### Option A — Use the generated `layerzero.config.ts` (default DVNs & Executors)

1. This example already ships a `layerzero.config.ts` that targets LayerZero’s default DVNs/Executors. Update the contract names/EIDs if you changed them during deployment.
2. Run wiring directly:

   ```bash
   pnpm hardhat lz:oapp:wire --oapp-config layerzero.custom.config.ts
   ```

This is the quickest path and mirrors the standard OFT example in `EX_README.md`.

### Option B — Manual configs

1. Generate per-mesh config scaffolding:

   ```bash
   npx hardhat lz:oapp:config:init --contract-name MyOFT --oapp-config layerzero.custom.config.ts
   ```

2. Fill in DVNs, executors, and enforced gas options using the `TwoWayConfig` helpers.

3. Wire each config once all contracts exist:

   ```bash
   pnpm hardhat lz:oapp:wire --oapp-config layerzero.custom.config.ts
   ```

Skip this entire section if you are using the Aave/Stargate composer workflow described below—Stargate pools already implement OFT semantics, so no extra wiring is required beyond configuring Stargate itself.

## Stargate to Aave Supply Task

File: `examples/oft-composers/tasks/supplyAave.ts`

1. Run the task with CLI parameters (replace placeholders with live addresses/amounts):

   ```bash
   pnpm hardhat aave:supply \
     --src-oft <0xSrcStargateContract> \
     --dst-eid <DstEID> \
     --composer <0xComposerAddress> \
     --amount-ld <AmountInLocalDecimals> \
     --network <NetworkInHardhatConfig>
   ```

   - `amount-ld` is specified in local decimals (1,000,000 = 1 USDC if the pool uses 6 decimals).
   - `compose-gas-limit` defaults to `395000`.

2. The task automatically:
   - Encodes the compose payload (receiver address).
   - Quotes Stargate fees and approves ERC20 transfers when needed.
   - Sends the transaction with the correct messaging fee (native or LZ token).

Monitor progress on [LayerZero Scan](https://layerzeroscan.com/). 

## Appendix

### Running Tests

```bash
pnpm test
pnpm test:forge     # only Forge
```

### Adding Other Chains

1. Append new networks to `hardhat.config.ts` and `.env`.
2. Add composer and OFT addresses for the new chain to your deployment config.
3. Extend `layerzero.*.config.ts` pathways so the new chain can talk to existing hubs/spokes.
4. Re-run `lz:oapp:wire` with the updated config file.

Need help? Reach out in the [LayerZero Discord](https://discord.com/channels/554623348622098432/1136412205064130703) or check the [Developer Docs](https://docs.layerzero.network/).
