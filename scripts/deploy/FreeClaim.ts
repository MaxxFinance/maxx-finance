import hre, { ethers } from 'hardhat';
import { FreeClaim__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const claimLaunchDate = '1661407200'; // Thu Aug 25 2022 06:00:00 GMT+0000
    const maxxFinance = {
        address: process.env.MAXX_FINANCE_ADDRESS!,
    };

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = await FreeClaim.deploy(
        claimLaunchDate,
        maxxFinance.address
    );

    log.yellow('freeClaim.address: ', freeClaim.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
