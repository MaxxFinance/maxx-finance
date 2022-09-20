import hre, { ethers } from 'hardhat';
import { MaxxStake__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = MaxxStake.attach(process.env.MAXX_STAKE_ADDRESS!);

    const stake = await maxxStake.stakes(0);

    log.yellow('stake: ', stake.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
