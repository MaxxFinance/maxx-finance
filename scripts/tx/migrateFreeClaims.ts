import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import log from 'ololog';

import { getMaxxStakeTest } from '../utils/getContractInstance';

export async function migrateFreeClaims(
    maxxStakeAddress: string
): Promise<boolean> {
    try {
        const maxxStake = await getMaxxStakeTest(maxxStakeAddress);
        for (let i = 0; i < 400; i++) {
            const migrate = await maxxStake[
                'migrateUnstakedFreeClaims(uint256)'
            ](50);
            await migrate.wait();
            log.yellow('Free claims migrated', migrate.hash);
            i += 49;
        }

        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
const maxxStakeAddress = '0x4E92a00fe40c1905B2fBF9867213867b4a82ae19';

migrateFreeClaims(maxxStakeAddress);
