import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import type { OAppEnforcedOption, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'
import { generateConnectionsConfig } from '@layerzerolabs/metadata-tools'

/**
 * LayerZero Simple Config for AquaStrategyComposer
 * 
 * Using LayerZero's Simple Config Generator for automated DVN and Executor setup.
 * This approach automatically configures bidirectional pathways with best practices.
 * 
 * Supported Chains:
 * - Base Mainnet (EID: 30184)
 * - World Chain Mainnet (EID: 30319)
 * 
 * Note: Uses 'LayerZero Labs' DVNs which will automatically resolve to the
 * appropriate DVN addresses for each chain.
 * 
 * References:
 * - https://docs.layerzero.network/v2/tools/simple-config
 * - https://docs.layerzero.network/v2/deployments/deployed-contracts
 */

// Base Mainnet Contract
const baseMainnetContract: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: 'AquaStrategyComposer',
}

// World Chain Mainnet Contract
const worldMainnetContract: OmniPointHardhat = {
    eid: EndpointId.WORLDCHAIN_V2_MAINNET,
    contractName: 'AquaStrategyComposer',
}

// Enforced options for gas and execution
// Higher gas limits ensure faster executor pickup and prevent execution failures
const ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    {
        msgType: 1, // OApp message type
        optionType: ExecutorOptionType.LZ_RECEIVE,
        gas: 500000, // Increased gas limit for complex operations (shipOnBehalfOf + token mapping)
        value: 0,
    },
]

export default async function () {
    // Generate connections config using Simple Config Generator
    // This automatically creates bidirectional pathways
    const connections = await generateConnectionsConfig([
        [
            worldMainnetContract, // Chain A (World Chain)
            baseMainnetContract, // Chain B (Base)
            [['LayerZero Labs'], []], // DVNs: [ requiredDVN[], [ optionalDVN[], threshold ] ]
            [5, 5], // Confirmations: [World→Base confirmations, Base→World confirmations]
                    // Reduced to 5 for faster delivery while maintaining security
            [ENFORCED_OPTIONS, ENFORCED_OPTIONS], // [Base enforcedOptions, World enforcedOptions]
        ],
    ])

    return {
        contracts: [
            { contract: worldMainnetContract },
            { contract: baseMainnetContract },
        ],
        connections,
    }
}

