import hre, { ethers } from 'hardhat';
import { Marketplace__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployMarketplace(
    maxxStakeAddress: string
): Promise<Deployment> {
    const Marketplace = (await ethers.getContractFactory(
        'Marketplace'
    )) as Marketplace__factory;

    const marketplace = await Marketplace.deploy(maxxStakeAddress);

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: marketplace.address,
                constructorArguments: [maxxStakeAddress],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: marketplace.address,
        block: marketplace.deployTransaction.blockNumber!,
    };
}

const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

// deployMarketplace(maxxStakeAddress).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
