import hre, { ethers } from 'hardhat';
import {
    MaxxFinance__factory,
    MaxxStake__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = MaxxFinance.attach(process.env.MAXX_FINANCE_ADDRESS!);

    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = MaxxStake.attach(process.env.MAXX_STAKE_ADDRESS!);

    const amount = ethers.utils.parseEther('1000000'); // 1 million

    const approval = await maxxFinance.approve(maxxStake.address, amount);
    await approval.wait();
    log.yellow('approval: ', approval.hash);

    const numDays = 365;

    const stake = await maxxStake['stake(uint16,uint256)'](numDays, amount);
    await stake.wait();
    log.yellow('stake: ', stake.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
