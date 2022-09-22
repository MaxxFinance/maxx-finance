import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import log from 'ololog';

import { getMaxxFinance } from '../utils/getContractInstance';

export async function maxxTransferTx(
    maxxFinanceAddress: string,
    amount: BigNumber,
    to: string
): Promise<boolean> {
    try {
        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);
        const transfer = await maxxFinance.transfer(to, amount);
        await transfer.wait();
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const amount = ethers.utils.parseEther('100000000'); // 1 million
// const to = '0xE84cbfd748FF3a24C0cD8A50eC147f971805bE67'; // Jordan

// maxxTransferTx(maxxFinanceAddress, amount, to).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
