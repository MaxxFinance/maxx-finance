import { ethers } from 'hardhat';
import {
    MaxxStake__factory,
    MaxxFinance__factory,
} from '../../typechain-types';
import log from 'ololog';

export async function initMaxxStake(
    maxxFinanceAddress: string,
    maxxStakeAddress: string,
    maxxBoostAddress: string,
    maxxGenesisAddress: string
): Promise<boolean> {
    try {
        const MaxxStake = (await ethers.getContractFactory(
            'MaxxStake'
        )) as MaxxStake__factory;

        const maxxStake = MaxxStake.attach(maxxStakeAddress);

        const setMaxxBoost = await maxxStake.setMaxxBoost(maxxBoostAddress);
        await setMaxxBoost.wait();

        const setMaxxGenesis = await maxxStake.setMaxxGenesis(
            maxxGenesisAddress
        );
        await setMaxxGenesis.wait();

        const MaxxFinance = (await ethers.getContractFactory(
            'MaxxFinance'
        )) as MaxxFinance__factory;
        const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);

        const allow = await maxxFinance.allow(maxxStakeAddress);
        await allow.wait();

        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
// const maxxBoostAddress = process.env.MAXX_BOOST_ADDRESS!;
// const maxxGenesisAddress = process.env.MAXX_GENESIS_ADDRESS!;

// initMaxxStake(
//     maxxFinanceAddress,
//     maxxStakeAddress,
//     maxxBoostAddress,
//     maxxGenesisAddress
// ).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
