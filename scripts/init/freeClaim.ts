import { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import log from 'ololog';

import {
    getMaxxFinance,
    getMaxxStake,
    getFreeClaim,
} from '../utils/getContractInstance';

import { freeClaimLeafInputs } from '../utils/freeClaimLeaves';
import { getMerkleRoot } from '../utils/merkleTree';

export async function initFreeClaim(
    maxxFinanceAddress: string,
    maxxStakeAddress: string,
    freeClaimAddress: string,
    totalClaimAmount: BigNumber
): Promise<boolean> {
    try {
        const signers = await ethers.getSigners();
        const signer = signers[0];

        const freeClaim = await getFreeClaim(freeClaimAddress);

        const merkleRoot = getMerkleRoot(freeClaimLeafInputs);

        const setRoot = await freeClaim.setMerkleRoot(merkleRoot);
        await setRoot.wait();

        const setMaxxStake = await freeClaim.setMaxxStake(maxxStakeAddress);
        await setMaxxStake.wait();

        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);

        const allowSigner = await maxxFinance.allow(signer.address);
        await allowSigner.wait();

        const allowFreeClaim = await maxxFinance.allow(freeClaimAddress);
        await allowFreeClaim.wait();

        const approve = await maxxFinance.approve(
            freeClaimAddress,
            totalClaimAmount
        );
        await approve.wait();

        const allocateMaxx = await freeClaim.allocateMaxx(totalClaimAmount, {
            gasLimit: 1_000_000,
        });
        await allocateMaxx.wait();

        const maxxStake = await getMaxxStake(maxxStakeAddress);
        const stakeFreeClaimAddress = await maxxStake.setFreeClaim(
            freeClaimAddress
        );
        await stakeFreeClaimAddress.wait();

        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

// const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
// const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
// const freeClaimAddress = process.env.FREE_CLAIM_ADDRESS!;
// const totalClaimAmount = ethers.utils.parseEther(
//     process.env.TOTAL_FREE_CLAIM_AMOUNT!
// );

// initFreeClaim(
//     maxxFinanceAddress,
//     maxxStakeAddress,
//     freeClaimAddress,
//     totalClaimAmount
// ).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
