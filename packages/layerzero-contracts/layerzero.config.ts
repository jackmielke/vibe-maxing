import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const baseMainnetContract: OmniPointHardhat = {
    eid: EndpointId.BASE_V2_MAINNET,
    contractName: 'MyOFT',
}

const arbitrumMainnetContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_MAINNET,
    contractName: 'MyOFT',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: baseMainnetContract,
        },
        {
            contract: arbitrumMainnetContract,
        },
    ],
    connections: [
        {
            from: arbitrumMainnetContract,
            to: baseMainnetContract,
        },
        {
            from: baseMainnetContract,
            to: arbitrumMainnetContract,
        },
    ],
}

export default config
