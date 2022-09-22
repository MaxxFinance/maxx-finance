import hre, { ethers } from 'hardhat';
import { MAXXBoost__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployMaxxBoost(
    amplifierAddress: string,
    stakingAddress: string
): Promise<Deployment> {
    const MAXXBoost = (await ethers.getContractFactory(
        'MAXXBoost'
    )) as MAXXBoost__factory;

    const maxxBoost = await MAXXBoost.deploy(amplifierAddress, stakingAddress);
    await maxxBoost.deployed();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: maxxBoost.address,
                constructorArguments: [amplifierAddress, stakingAddress],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: maxxBoost.address,
        block: maxxBoost.deployTransaction.blockNumber!,
    };
}

const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!;
const stakingAddress = process.env.MAXX_STAKE_ADDRESS!;

// deployMaxxBoost(amplifierAddress, stakingAddress).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
