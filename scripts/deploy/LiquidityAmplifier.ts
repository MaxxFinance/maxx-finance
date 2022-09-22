import hre, { ethers } from 'hardhat';
import { LiquidityAmplifier__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployLiquidityAmplifier(
    maxxFinanceAddress: string,
    launchDate: string
): Promise<Deployment> {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const maxx = {
        address: maxxFinanceAddress,
    };

    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifier'
    )) as LiquidityAmplifier__factory;

    const liquidityAmplifier = await LiquidityAmplifier.deploy(
        maxxVaultAddress,
        launchDate,
        maxx.address
    );
    await liquidityAmplifier.deployed();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: liquidityAmplifier.address,
                constructorArguments: [
                    maxxVaultAddress,
                    launchDate,
                    maxx.address,
                ],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: liquidityAmplifier.address,
        block: liquidityAmplifier.deployTransaction.blockNumber!,
    };
}

const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
const launchDate = process.env.AMPLIFIER_LAUNCH_DATE!;

// deployLiquidityAmplifier(maxxFinanceAddress, launchDate).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
