import hre, { ethers } from 'hardhat';
import { FreeClaim__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployFreeClaim(
    maxxFinanceAddress: string,
    startDate: string
): Promise<Deployment> {
    const maxx = {
        address: maxxFinanceAddress,
    };

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = await FreeClaim.deploy(startDate, maxx.address);
    await freeClaim.deployed();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: freeClaim.address,
                constructorArguments: [startDate, maxx.address],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: freeClaim.address,
        block: freeClaim.deployTransaction.blockNumber!,
    };
}

const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
const startDate = process.env.FREE_CLAIM_START_DATE!;

// deployFreeClaim(maxxFinanceAddress, startDate).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
