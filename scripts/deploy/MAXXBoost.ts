import hre, { ethers } from 'hardhat';
import { MAXXBoost__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!; // Mumbai Testnet address
    const stakingAddress = process.env.MAXX_STAKE_ADDRESS!; // Mumbai Testnet address

    const MAXXBoost = (await ethers.getContractFactory(
        'MAXXBoost'
    )) as MAXXBoost__factory;

    const maxxBoost = await MAXXBoost.deploy(amplifierAddress, stakingAddress);
    log.yellow('maxxBoost.address: ', maxxBoost.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
