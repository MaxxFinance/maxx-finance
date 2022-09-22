import { ethers } from 'hardhat';
import {
    LiquidityAmplifier__factory,
    MaxxFinance__factory,
    MaxxStake__factory,
} from '../../typechain-types';
import log from 'ololog';

import {
    getMaxxFinance,
    getMaxxStake,
    getLiquidityAmplifier,
} from '../utils/getContractInstance';

export async function initLiquidityAmplifier(
    maxxFinanceAddress: string,
    maxxStakeAddress: string,
    amplifierAddress: string
): Promise<boolean> {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;

    try {
        const totalAllocation = ethers.utils.parseEther('40000000000'); // // 40 billion tokens
        const dailyAllocation = totalAllocation.div(60); // totalAllocation divided equally for 60 days

        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);

        const liquidityAmplifier = await getLiquidityAmplifier(
            amplifierAddress
        );

        const vaultAllowed = await maxxFinance.isAllowed(maxxVaultAddress);
        if (!vaultAllowed) {
            const allowVault = await maxxFinance.allow(maxxVaultAddress);
            await allowVault.wait();
        }

        const maxxTransfer = await maxxFinance.transfer(
            liquidityAmplifier.address,
            totalAllocation,
            {
                gasLimit: 1000000,
            }
        );
        await maxxTransfer.wait();

        const setStakeAddress = await liquidityAmplifier.setStakeAddress(
            maxxStakeAddress
        );
        await setStakeAddress.wait();

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

        const setDailyAllocations =
            await liquidityAmplifier.setDailyAllocations(dailyAllocations, {
                gasLimit: 5_000_000,
            });
        await setDailyAllocations.wait();

        const maxxStake = await getMaxxStake(maxxStakeAddress);
        const stakeAmplifierAddress = await maxxStake.setLiquidityAmplifier(
            amplifierAddress
        );
        await stakeAmplifierAddress.wait();
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
// const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!;

// initLiquidityAmplifier(
//     maxxFinanceAddress,
//     maxxStakeAddress,
//     amplifierAddress
// ).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
