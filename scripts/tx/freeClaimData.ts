import hre, { ethers } from 'hardhat';
import {
    FreeClaim__factory,
    MaxxFinance__factory,
    MaxxStake__factory,
} from '../../typechain-types';
import { MerkleTree } from 'merkletreejs';
import { BytesLike, utils } from 'ethers';
import keccak256 from 'keccak256';
import log from 'ololog';

interface input {
    address: string;
    amount: string;
}

const inputs: input[] = [
    {
        address: '0xBF7BF3d445aEc7B0c357163d5594DB8ca7C12D31',
        amount: '1000000',
    },
    {
        address: '0x087183a411770a645A96cf2e31fA69Ab89e22F5E',
        amount: '100000000000000000000000',
    },
    {
        address: '0xe3F641AD659249a020e2aF63c3f9aBd6cfFb668b',
        amount: '250000',
    },
    {
        address: '0xE84cbfd748FF3a24C0cD8A50eC147f971805bE67',
        amount: '1000',
    },
];

async function main() {
    const signers = await ethers.getSigners();
    const signer = signers[0].address;

    const freeClaimAddress = process.env.FREE_CLAIM_ADDRESS!;

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = FreeClaim.attach(freeClaimAddress);

    const userClaims = await freeClaim.getUserClaims(signer);
    log.yellow('userClaims', userClaims);

    const userFreeReferrals = await freeClaim.getUserFreeReferrals(signer);
    log.yellow('userFreeReferrals', userFreeReferrals);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
