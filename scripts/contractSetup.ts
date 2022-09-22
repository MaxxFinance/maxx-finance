import hre, { ethers } from 'hardhat';
import log from 'ololog';

import { freeClaimLeafInputs } from './utils/freeClaimLeaves';
import { deployAll } from './deploy/deployAll';
import { initMaxxStake, initFreeClaim, initLiquidityAmplifier } from './init';
import {
    allowlistTx,
    amplifierDepositTx,
    freeClaimTx,
    maxxTransferTx,
    stakeTx,
} from './tx';

export async function contractSetup() {
    const network = hre.network.name;
    log.bright.yellow('network: ', network);

    const contracts = await deployAll();

    const initMaxxStakeResult = await initMaxxStake(
        contracts.maxx.address,
        contracts.stake.address,
        contracts.maxxBoost.address,
        contracts.maxxGenesis.address
    );

    const totalClaimAmount = ethers.utils.parseEther(
        process.env.TOTAL_FREE_CLAIM_AMOUNT!
    );
    const initFreeClaimResult = await initFreeClaim(
        contracts.maxx.address,
        contracts.stake.address,
        contracts.freeClaim.address,
        totalClaimAmount
    );
    const initLiquidityAmplifierResult = await initLiquidityAmplifier(
        contracts.maxx.address,
        contracts.stake.address,
        contracts.amplifier.address
    );

    switch (network) {
        case 'mumbai':
            let allowlistTxResult = await allowlistTx(
                contracts.maxx.address,
                contracts.maxxGenesis.address
            );

            const maxxTransferAmount = ethers.utils.parseEther('100000000'); // 1 million
            const to = process.env.TEMRITE_ADDRESS!;
            let maxxTransferTxResult = await maxxTransferTx(
                contracts.maxx.address,
                maxxTransferAmount,
                to
            );

            let freeClaimTxResult = await freeClaimTx(
                contracts.maxx.address,
                contracts.stake.address,
                contracts.freeClaim.address,
                freeClaimLeafInputs
            );

            const referrer = process.env.SON_OF_MOSIAH_ADDRESS!;
            const depositAmount = ethers.utils.parseEther('0.01');
            let amplifierDepositTxResult = await amplifierDepositTx(
                contracts.amplifier.address,
                referrer,
                depositAmount
            );

            let stakeTxResult = await stakeTx(
                contracts.maxx.address,
                contracts.stake.address
            );
            break;
        default:
            break;
    }

    console.table(contracts);
    return contracts;
}

contractSetup().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
