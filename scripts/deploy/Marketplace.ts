import hre, { ethers } from 'hardhat';
import { Marketplace__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

    const Marketplace = (await ethers.getContractFactory(
        'Marketplace'
    )) as Marketplace__factory;

    const marketplace = await Marketplace.deploy(maxxStakeAddress);
    log.yellow('marketplace.address: ', marketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
