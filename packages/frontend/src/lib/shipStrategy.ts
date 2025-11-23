import { MiniKit } from '@worldcoin/minikit-js'

// LayerZero Endpoint ID
const EID = import.meta.env.VITE_EID || '30184'

// Contract addresses on Base (where strategies are deployed)
const CONTRACTS_BASE = {
  STABLESWAP: import.meta.env.VITE_STABLESWAP_BASE || '0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E',
  CONCENTRATED_LIQUIDITY: import.meta.env.VITE_CONCENTRATED_BASE || '0xDf12aaAdBaEc2C9cf9E56Bd4B807008530269839',
}

// Composer on WorldChain (handles cross-chain operations)
const COMPOSER_WORLD = import.meta.env.VITE_COMPOSER_WORLD || '0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8'

// Token addresses on WorldChain
export const TOKENS = {
  USDC: import.meta.env.VITE_USDC_WORLD || '0x79A02482A880bCE3F13e09Da970dC34db4CD24d1',
  USDT: import.meta.env.VITE_USDT_WORLD || '0x79A02482A880bCE3F13e09Da970dC34db4CD24d1',
  ETH: import.meta.env.VITE_WETH_WORLD || '0x4200000000000000000000000000000000000006',
}

interface ShipStrategyParams {
  strategyType: 'stableswap' | 'concentrated'
  feeBps: number // Fee in basis points (e.g., 30 = 0.30%)
  token0: string // Address of first token
  token1: string // Address of second token
  // Additional params for concentrated liquidity
  priceLower?: string // For concentrated liquidity (in wei)
  priceUpper?: string // For concentrated liquidity (in wei)
  // Additional params for stableswap
  amplificationFactor?: number // For stableswap (A parameter)
}

export async function shipStrategyToChain(params: ShipStrategyParams) {
  const { strategyType, feeBps, token0, token1 } = params

  // Get wallet address from localStorage (saved during WorldID auth)
  let maker: string

  try {
    const authData = localStorage.getItem('worldid_auth')
    if (authData) {
      const { wallet_address } = JSON.parse(authData)
      if (wallet_address) {
        maker = wallet_address
        console.log('Maker address from localStorage:', maker)
      } else {
        throw new Error('Wallet address not found')
      }
    } else {
      throw new Error('Not authenticated')
    }
  } catch (error) {
    console.error('Error getting wallet address:', error)

    // Fallback: try to get wallet address from MiniKit
    try {
      const walletAuth = await MiniKit.commandsAsync.walletAuth({
        nonce: Date.now().toString(),
        requestId: Date.now().toString(),
        expirationTime: new Date(Date.now() + 5 * 60 * 1000),
        notBefore: new Date(Date.now()),
        statement: 'Sign to create a cross-chain liquidity strategy',
      })

      if (walletAuth.finalPayload && (walletAuth.finalPayload as any).status === 'success') {
        maker = (walletAuth.finalPayload as any).address
        console.log('Maker address from MiniKit:', maker)

        // Save it to localStorage for next time
        const authData = localStorage.getItem('worldid_auth')
        if (authData) {
          const data = JSON.parse(authData)
          data.wallet_address = maker
          localStorage.setItem('worldid_auth', JSON.stringify(data))
        }
      } else {
        throw new Error('Failed to get wallet address')
      }
    } catch (err) {
      console.error('Fallback wallet auth failed:', err)
      throw new Error('Please authenticate with WorldID to create a strategy')
    }
  }

  // Salt is always 0
  const salt = '0x' + '0'.repeat(64)

  // Determine which contract on Base to target
  const targetContract = strategyType === 'stableswap'
    ? CONTRACTS_BASE.STABLESWAP
    : CONTRACTS_BASE.CONCENTRATED_LIQUIDITY

  // Build strategy data based on type
  let strategyData: any

  if (strategyType === 'stableswap') {
    const amplificationFactor = params.amplificationFactor || 100
    strategyData = {
      maker,
      token0,
      token1,
      feeBps,
      amplificationFactor,
      salt,
    }
  } else {
    const priceLower = params.priceLower || '900000000000000000' // 0.9 * 1e18
    const priceUpper = params.priceUpper || '1100000000000000000' // 1.1 * 1e18
    strategyData = {
      maker,
      token0,
      token1,
      feeBps,
      priceLower,
      priceUpper,
      salt,
    }
  }

  // ABI for the Composer contract on WorldChain (from AquaStrategyComposer.json)
  const composerABI = [
    {
      type: 'function',
      name: 'quoteShipStrategy',
      inputs: [
        { name: 'dstEid', type: 'uint32' },
        { name: 'dstApp', type: 'address' },
        { name: 'strategy', type: 'bytes' },
        { name: 'tokenIds', type: 'bytes32[]' },
        { name: 'amounts', type: 'uint256[]' },
        { name: 'options', type: 'bytes' },
        { name: 'payInLzToken', type: 'bool' },
      ],
      outputs: [
        {
          components: [
            { name: 'nativeFee', type: 'uint256' },
            { name: 'lzTokenFee', type: 'uint256' },
          ],
          name: 'fee',
          type: 'tuple',
        },
      ],
      stateMutability: 'view',
    },
    {
      type: 'function',
      name: 'shipStrategyToChain',
      inputs: [
        { name: 'dstEid', type: 'uint32' },
        { name: 'dstApp', type: 'address' },
        { name: 'strategy', type: 'bytes' },
        { name: 'tokenIds', type: 'bytes32[]' },
        { name: 'amounts', type: 'uint256[]' },
        { name: 'options', type: 'bytes' },
      ],
      outputs: [
        {
          components: [
            { name: 'guid', type: 'bytes32' },
            { name: 'nonce', type: 'uint64' },
            {
              components: [
                { name: 'nativeFee', type: 'uint256' },
                { name: 'lzTokenFee', type: 'uint256' },
              ],
              name: 'fee',
              type: 'tuple',
            },
          ],
          name: 'receipt',
          type: 'tuple',
        },
      ],
      stateMutability: 'payable',
    },
  ]

  try {
    // Encode the strategy data as ABI-encoded bytes (NOT JSON!)
    // This should match how the Solidity script encodes it: abi.encode(strategy)
    // For now, we need to properly ABI-encode the strategy struct
    // TODO: Use ethers.js or viem to properly ABI-encode the strategy
    const strategyJson = JSON.stringify(strategyData)
    const encodedStrategy = '0x' + Array.from(strategyJson)
      .map(c => c.charCodeAt(0).toString(16).padStart(2, '0'))
      .join('')

    // Token IDs should be keccak256(abi.encodePacked("erc20", tokenAddress))
    // For now, keeping empty as we're not sending initial liquidity
    const tokenIds: string[] = []

    // Amounts of each token to send with the strategy
    // For initial creation without liquidity, keep empty
    const amounts: string[] = []

    // LayerZero executorLzReceiveOption
    // Format: 0x0003 (option type 3) + 0x00000000000000000000000000000000000000000000000000000000000186a0 (gas limit: 100,000)
    const gasLimit = 200000 // 200k gas for execution on destination
    const gasLimitHex = gasLimit.toString(16).padStart(64, '0')
    const options = '0x0003' + gasLimitHex

    console.log('Shipping strategy cross-chain:', {
      type: strategyType,
      dstEid: parseInt(EID),
      dstApp: targetContract,
      strategy: encodedStrategy,
      tokenIds,
      amounts,
      options,
      gasLimit,
    })

    // Send transaction to Composer on WorldChain using MiniKit
    // Value should cover the LayerZero fee (typically small, e.g., 0.01 ETH)
    const value = '0x' + Math.floor(0.01 * 10**18).toString(16) // 0.01 ETH in hex

    const result = await MiniKit.commandsAsync.sendTransaction({
      transaction: [
        {
          address: COMPOSER_WORLD,
          abi: composerABI,
          functionName: 'shipStrategyToChain',
          args: [
            parseInt(EID), // dstEid: Destination chain EID (Base)
            targetContract, // dstApp: Target contract address on Base
            encodedStrategy, // strategy: Encoded strategy data
            tokenIds, // tokenIds: Array of token IDs
            amounts, // amounts: Array of amounts
            options, // options: LayerZero options with gas limit
          ],
          value, // Send ETH to cover LayerZero fees
        },
      ],
    })

    console.log('Transaction result:', result)
    console.log('Command payload:', result.commandPayload)
    console.log('Final payload:', result.finalPayload)

    // Check if transaction was successful
    if (result.finalPayload && (result.finalPayload as any).status === 'success') {
      const transactionId = (result.finalPayload as any).transaction_id
      console.log('Transaction ID:', transactionId)
      return {
        success: true,
        txHash: transactionId, // Note: This is transaction_id, not hash. Hash comes later after confirmation
      }
    } else {
      const errorCode = (result.finalPayload as any)?.error_code || 'Unknown error'
      const debugUrl = (result.finalPayload as any)?.debug_url
      const errorDetails = (result.finalPayload as any)?.details

      console.error('Transaction failed:', {
        error_code: errorCode,
        debug_url: debugUrl,
        details: errorDetails,
        full_payload: result.finalPayload
      })

      throw new Error(`Transaction failed: ${errorCode}${debugUrl ? ` - Debug: ${debugUrl}` : ''}${errorDetails ? ` - ${errorDetails}` : ''}`)
    }
  } catch (error) {
    console.error('Error shipping strategy:', error)
    throw error
  }
}
