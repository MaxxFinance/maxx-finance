import hre, { ethers } from 'hardhat';
import { MaxxStake__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
    const maxxBoostAddress = process.env.MAXX_BOOST_ADDRESS!;
    const maxxGenesisAddress = process.env.MAXX_GENESIS_ADDRESS!;

    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = await MaxxStake.attach(maxxStakeAddress);
    log.yellow('maxxStake.address: ', maxxStake.address);

    const setMaxxBoost = await maxxStake.setMaxxBoost(maxxBoostAddress);
    await setMaxxBoost.wait();
    log.green('setMaxxBoost: ', setMaxxBoost.hash);

    const setMaxxGenesis = await maxxStake.setMaxxGenesis(maxxGenesisAddress);
    await setMaxxGenesis.wait();
    log.green('setMaxxGenesis: ', setMaxxGenesis.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
