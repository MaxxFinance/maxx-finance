import hre, { ethers } from 'hardhat';
import {
    LiquidityAmplifier__factory,
    MaxxFinance__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
    const maxxLiquidityAmplifierAddress =
        process.env.LIQUIDITY_AMPLIFIER_ADDRESS!;

    const totalAllocation = ethers.utils.parseEther('40000000000'); // // 40 billion tokens
    const dailyAllocation = totalAllocation.div(60); // totalAllocation divided equally for 60 days

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;
    const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);

    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifier'
    )) as LiquidityAmplifier__factory;

    const liquidityAmplifier = LiquidityAmplifier.attach(
        maxxLiquidityAmplifierAddress
    );

    const vaultAllowed = await maxxFinance.isAllowed(maxxVaultAddress);
    if (!vaultAllowed) {
        const allowVault = await maxxFinance.allow(maxxVaultAddress);
        await allowVault.wait();
        log.green('allowVault: ', allowVault.hash);
    }

    const maxxTransfer = await maxxFinance.transfer(
        liquidityAmplifier.address,
        totalAllocation,
        {
            gasLimit: 1000000,
        }
    );
    await maxxTransfer.wait();
    log.yellow(
        'maxx total allocation (' +
            totalAllocation.toString() +
            ') transferred: ',
        maxxTransfer.hash
    );

    const setStakeAddress = await liquidityAmplifier.setStakeAddress(
        maxxStakeAddress
    );
    await setStakeAddress.wait();
    log.green('setStakeAddress: ', setStakeAddress.hash);

    const dailyAllocations = [
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
        dailyAllocation,
    ];

    const setDailyAllocations = await liquidityAmplifier.setDailyAllocations(
        dailyAllocations
    );
    await setDailyAllocations.wait();
    log.green('setDailyAllocations: ', setDailyAllocations.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
