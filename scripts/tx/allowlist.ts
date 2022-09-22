import log from 'ololog';

import { getMaxxFinance } from '../utils/getContractInstance';

export async function allowlistTx(
    maxxFinanceAddress: string,
    maxxStakeAddress: string
): Promise<boolean> {
    try {
        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);

        const allow = await maxxFinance.allow(maxxStakeAddress);
        await allow.wait();

        const newLimit = 100_000_000;
        const whaleLimit = await maxxFinance.setWhaleLimit(newLimit);
        await whaleLimit.wait();
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

// allowlistTx(maxxFinanceAddress, maxxStakeAddress).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
