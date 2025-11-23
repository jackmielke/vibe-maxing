import { type DeployFunction } from 'hardhat-deploy/types'

/**
 * Deploys AquaStrategyComposer contract
 * 
 * This contract enables cross-chain strategy shipping for Aqua protocol
 * and integrates with Aqua to actually ship strategies on destination chain
 * 
 * Required environment variables:
 * - PRIVATE_KEY: Deployer private key
 * 
 * Optional environment variables:
 * - AQUA_ADDRESS: Aqua protocol address (can be set later via setAqua())
 * 
 * The contract will be deployed with:
 * - LayerZero endpoint for the current network
 * - Deployer as the delegate/owner
 * - Aqua address (if provided)
 */
const deployAquaStrategyComposer: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    // Get LayerZero endpoint for this network
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')

    // Get Aqua address if provided
    const aquaAddress = process.env.AQUA_ADDRESS || '0x0000000000000000000000000000000000000000'

    console.log(`\n=================================================`)
    console.log(`Deploying AquaStrategyComposer`)
    console.log(`=================================================`)
    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)
    console.log(`Endpoint: ${endpointV2Deployment.address}`)
    console.log(`Aqua: ${aquaAddress === '0x0000000000000000000000000000000000000000' ? 'Not set (can set later)' : aquaAddress}`)

    // Deploy the composer
    const { address, newlyDeployed } = await deploy('AquaStrategyComposer', {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero endpoint
            deployer,                      // Delegate (owner)
            aquaAddress,                   // Aqua protocol address
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    })

    if (newlyDeployed) {
        console.log(`\n✅ AquaStrategyComposer deployed at: ${address}`)
        console.log(`\nNext steps:`)
        console.log(`1. Set Aqua address (if not set):`)
        console.log(`   cast send ${address} "setAqua(address)" <AQUA_ADDRESS> --private-key $PRIVATE_KEY`)
        console.log(`\n2. Register tokens (canonical ID => local address):`)
        console.log(`   cast send ${address} "registerToken(bytes32,address)" $(cast keccak "USDC") <USDC_ADDRESS> --private-key $PRIVATE_KEY`)
        console.log(`   cast send ${address} "registerToken(bytes32,address)" $(cast keccak "USDT") <USDT_ADDRESS> --private-key $PRIVATE_KEY`)
        console.log(`\n3. Set peers for cross-chain communication:`)
        console.log(`   npx hardhat lz:oapp:wire --oapp-config layerzero.aqua.config.ts`)
        console.log(`\n4. Add supported destination chains:`)
        console.log(`   cast send ${address} "addSupportedChain(uint32)" <CHAIN_EID> --private-key $PRIVATE_KEY`)
        console.log(`\n5. Test cross-chain ship:`)
        console.log(`   forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript --broadcast`)
    } else {
        console.log(`\n♻️  AquaStrategyComposer already deployed at: ${address}`)
    }

    console.log(`=================================================\n`)
}

deployAquaStrategyComposer.tags = ['AquaStrategyComposer']

export default deployAquaStrategyComposer

