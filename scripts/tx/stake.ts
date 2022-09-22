import { ethers } from 'hardhat';
import log from 'ololog';

import { getMaxxFinance, getMaxxStake } from '../utils/getContractInstance';

export async function stakeTx(
    maxxFinanceAddress: string,
    maxxStakeAddress: string
): Promise<boolean> {
    try {
        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);
        const maxxStake = await getMaxxStake(maxxStakeAddress);

        const amount = ethers.utils.parseEther('1000000'); // 1 million

        const approval = await maxxFinance.approve(maxxStake.address, amount);
        await approval.wait();

        const numDays = 365;

        const stake = await maxxStake['stake(uint16,uint256)'](numDays, amount);
        await stake.wait();
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

// stakeTx(maxxFinanceAddress, maxxStakeAddress).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
