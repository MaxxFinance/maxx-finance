import hre, { ethers } from 'hardhat';
import { MAXXGenesis__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployMaxxGenesis(
    amplifierAddress: string
): Promise<Deployment> {
    const MAXXGenesis = (await ethers.getContractFactory(
        'MAXXGenesis'
    )) as MAXXGenesis__factory;

    const maxxGenesis = await MAXXGenesis.deploy(amplifierAddress);
    await maxxGenesis.deployed();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: maxxGenesis.address,
                constructorArguments: [amplifierAddress],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: maxxGenesis.address,
        block: maxxGenesis.deployTransaction.blockNumber!,
    };
}

const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!;

// deployMaxxGenesis(amplifierAddress).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
