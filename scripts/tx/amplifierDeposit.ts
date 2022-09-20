import hre, { ethers } from 'hardhat';
import {
    LiquidityAmplifier__factory,
    MaxxFinance__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifier'
    )) as LiquidityAmplifier__factory;

    const liquidityAmplifier = LiquidityAmplifier.attach(
        process.env.LIQUIDITY_AMPLIFIER_ADDRESS!
    );

    const amount = ethers.utils.parseEther('0.001');
    const referrer = '0x661Cd43A26B92995C5eE8A21Cc3D715FE830576e';

    const launchDate = await liquidityAmplifier.launchDate();
    log.yellow('launchDate:', launchDate.toString());

    const getDay = await liquidityAmplifier.getDay();
    log.yellow('currentDay:', getDay);

    const deposit = await liquidityAmplifier['deposit()']({
        value: amount,
        gasLimit: 250_000,
    });

    await deposit.wait();
    log.yellow('deposit: ', deposit.hash);

    const depositReferral = await liquidityAmplifier['deposit(address)'](
        referrer,
        {
            value: amount,
            gasLimit: 250_000,
        }
    );

    await depositReferral.wait();
    log.yellow('depositReferral: ', depositReferral.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
