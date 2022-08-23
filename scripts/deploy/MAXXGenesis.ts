import hre, { ethers } from 'hardhat';
import { MAXXGenesis__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!; // Mumbai Testnet address

    const MAXXGenesis = (await ethers.getContractFactory(
        'MAXXGenesis'
    )) as MAXXGenesis__factory;

    const maxxGenesis = await MAXXGenesis.deploy(amplifierAddress);
    log.yellow('maxxGenesis.address: ', maxxGenesis.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
