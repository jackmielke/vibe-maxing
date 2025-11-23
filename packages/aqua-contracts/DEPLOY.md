# SwapVM Deployment Guide

This guide describes how to deploy Aqua contracts using the Makefile-based deployment system.

## Prerequisites

Before deploying, ensure you have the following installed:

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (includes `forge`, `cast`, and `anvil`)
- Make (usually pre-installed on Unix systems)
- jq (JSON processor for parsing deployment outputs)
- A funded wallet for gas fees

## Quick Start

```bash
# 1. Copy and configure environment file
cp .env.example .env

# 2. Set required environment variables
# Edit .env file with your values

# 3. Deploy standard AquaRouter
make deploy-aqua-router

# 4. Get AquaRouter deployment address
make get PARAMETER=OPS_AQUA_ROUTER_ADDRESS
```

## Environment Configuration

The deployment system uses environment variables that can be configured in two ways:

### Manual Mode (Default)
Create a `.env` file in the project root with the following variables:

```bash
# Network Configuration
OPS_NETWORK="localhost"          # Network name (e.g., mainnet, sepolia, localhost)
OPS_CHAIN_ID="31337"            # Chain ID for the target network

# Network-specific RPC and Private Key
# Format: <NETWORK_NAME>_RPC_URL and <NETWORK_NAME>_PRIVATE_KEY
LOCALHOST_RPC_URL=http://127.0.0.1:8546
LOCALHOST_PRIVATE_KEY=0x...

# For other networks, add corresponding entries:
# MAINNET_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR-KEY"
# MAINNET_PRIVATE_KEY="0x..."
# SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR-KEY"
# SEPOLIA_PRIVATE_KEY="0x..."
```

### Automation Mode (Automated deployment framework)
For automated deployments .env.automation file will be created automatically and deployment is launched with:

```bash
OPS_LAUNCH_MODE=auto make deploy-aqua-router
```

## Deployment Commands

### Main Deployment Targets

| Command | Description | Contract |
|---------|-------------|----------|
| `make deploy-aqua-router` | Deploy standard AquaRouter | AquaRouter.sol |

### Deployment Artifacts

Deployment information is saved in:
- `broadcast/` - Forge deployment transactions
- `deployments/<network>/` - Organized deployment files per network

## Helper Commands

### Development Tools

| Command | Description |
|---------|-------------|
| `make build` | Compile all contracts |
| `make tests` | Run test suite with gas reporting |
| `make coverage` | Generate code coverage report |
| `make snapshot` | Create gas snapshot |
| `make format` | Format code using Forge formatter |
| `make lint` | Check code formatting |
| `make clean` | Clean build artifacts |

### Local Development

Start local Anvil fork:
```bash
make anvil NODE_URL=<your-rpc-url>
```

Define correct env variables:

```bash
# define your network alias (e.g. localhost)
OPS_NETWORK="localhost"
# Use 31337 for local development
OPS_CHAIN_ID="31337"

# RPC URL for localhost network
LOCALHOST_RPC_URL=http://localhost:8546
# Replace with your own private key for localhost testing
LOCALHOST_PRIVATE_KEY=0x
```
