import hre, { ethers } from 'hardhat';
import { FreeClaim__factory, MaxxStake__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;
    const maxxStake = MaxxStake.attach(maxxStakeAddress);

    const startDate = (await maxxStake.launchDate()).add(1);

    // const claimLaunchDate = '1661407200'; // Thu Aug 25 2022 06:00:00 GMT+0000
    const maxx = {
        address: process.env.MAXX_FINANCE_ADDRESS!,
    };

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = await FreeClaim.deploy(startDate, maxx.address);
    await freeClaim.deployed();

    log.yellow('freeClaim.address: ', freeClaim.address);

    // let freeClaimAddress = process.env.FREE_CLAIM_ADDRESS!;

    // await hre.run('verify:verify', {
    //     address: freeClaimAddress,
    //     constructorArguments: [claimLaunchDate, maxxFinance.address],
    // });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
