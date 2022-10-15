import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { BytesLike, utils } from 'ethers';
import keccak256 from 'keccak256';
import log from 'ololog';

import {
    getMaxxFinance,
    getMaxxStake,
    getFreeClaim,
} from '../utils/getContractInstance';

interface input {
    address: string;
    amount: string;
}

export async function freeClaimTx(freeClaimAddress: string): Promise<boolean> {
    try {
        const signers = await ethers.getSigners();
        const signer = signers[0].address;

        const freeClaim = await getFreeClaim(freeClaimAddress);

        const merkleRoot = await freeClaim.merkleRoot();
        log.lightYellow('merkleRoot', merkleRoot);

        const owner = await freeClaim.owner();
        log.lightYellow('owner', owner);

        const transferOwnership = await freeClaim.transferOwnership(
            '0xDb0EAe4c4DDb75413d85B62B8391bFde75702B5a'
        );
        await transferOwnership.wait();
        log.lightYellow('transferOwnership', transferOwnership.hash);

        const newOwner = await freeClaim.owner();
        log.lightYellow('newOwner', newOwner);

        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

const freeClaimAddress = '0xC37C8426F42372FDE13893Bb92f5ba0105A52173';

freeClaimTx(freeClaimAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
