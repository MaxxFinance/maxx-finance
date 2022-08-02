import hre, { ethers } from 'hardhat';
import {
    LiquidityAmplifier__factory,
    MaxxFinance__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
    const amplifierLaunchDate = '1659420000'; // Tue Aug 02 2022 06:00:00 GMT+0000
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

    const totalAllocation = ethers.utils.parseEther('40000000000'); // // 40 billion tokens
    const dailyAllocation = totalAllocation.div(60); // totalAllocation divided equally for 60 days

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;
    const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);

    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifier'
    )) as LiquidityAmplifier__factory;

    const liquidityAmplifier = await LiquidityAmplifier.deploy(
        maxxVaultAddress,
        amplifierLaunchDate,
        maxxFinance.address
    );
    log.yellow('liquidityAmplifier.address: ', liquidityAmplifier.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
