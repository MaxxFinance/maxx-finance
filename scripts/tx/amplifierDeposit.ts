import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import log from 'ololog';

import { getLiquidityAmplifier } from '../utils/getContractInstance';

export async function amplifierDepositTx(
    amplifierAddress: string,
    referrer: string,
    depositAmount: BigNumber
): Promise<boolean> {
    try {
        const liquidityAmplifier = await getLiquidityAmplifier(
            amplifierAddress
        );

        const deposit = await liquidityAmplifier['deposit()']({
            value: depositAmount,
            gasLimit: 250_000,
        });
        await deposit.wait();

        const depositReferral = await liquidityAmplifier['deposit(address)'](
            referrer,
            {
                value: depositAmount,
                gasLimit: 250_000,
            }
        );

        await depositReferral.wait();
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const amplifierAddress = process.env.LIQUIDITY_AMPLIFIER_ADDRESS!;
// const referrer = '0x661Cd43A26B92995C5eE8A21Cc3D715FE830576e';
// const depositAmount = ethers.utils.parseEther('0.001');

// amplifierDepositTx(amplifierAddress, referrer, depositAmount).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
