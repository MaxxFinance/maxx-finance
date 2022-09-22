import hre, { ethers } from 'hardhat';
import { MaxxStake__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployMaxxStake(
    maxxFinanceAddress: string,
    launchDate: string
): Promise<Deployment> {
    const maxxVault = process.env.MAXX_VAULT_ADDRESS!;
    const maxx = {
        address: maxxFinanceAddress,
    };

    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = await MaxxStake.deploy(
        maxxVault,
        maxx.address,
        launchDate
    );
    await maxxStake.deployed();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: maxxStake.address,
                constructorArguments: [maxxVault, maxx.address, launchDate],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: maxxStake.address,
        block: maxxStake.deployTransaction.blockNumber!,
    };
}

const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
const launchDate = process.env.STAKE_LAUNCH_DATE!;

// deployMaxxStake(maxxFinanceAddress, launchDate).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
