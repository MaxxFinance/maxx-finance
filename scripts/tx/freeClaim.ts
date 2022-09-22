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

export async function freeClaimTx(
    maxxFinanceAddress: string,
    maxxStakeAddress: string,
    freeClaimAddress: string,
    inputs: input[]
): Promise<boolean> {
    try {
        const signers = await ethers.getSigners();
        const signer = signers[0].address;

        const maxxFinance = await getMaxxFinance(maxxFinanceAddress);
        const maxxStake = await getMaxxStake(maxxStakeAddress);
        const freeClaim = await getFreeClaim(freeClaimAddress);

        let index = 1;
        const [leaf, proof] = await getMerkleProof(index);
        let referrer;
        if (index > 0) {
            referrer = inputs[index - 1].address;
        } else {
            referrer = inputs[1].address;
        }

        const address = inputs[index].address;
        const amount = inputs[index].amount;

        let selfReferral = referrer === address;

        const freeClaimBalance = await maxxFinance.balanceOf(freeClaimAddress);
        const remainingBalance = await freeClaim.remainingBalance();
        const hasClaimed = await freeClaim.hasClaimed(address);

        const stakeLaunchDate = await maxxStake.launchDate();
        const blockNumber = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNumber);
        const timestamp = block.timestamp;
        const claimLaunchDate = await freeClaim.launchDate();
        const started = claimLaunchDate.lte(timestamp);
        if (started) {
            const timePassed = timestamp - claimLaunchDate.toNumber();
            const timePassedInDays = timePassed / 86400;
        }

        const allowance = await maxxFinance.allowance(
            freeClaimAddress,
            maxxStakeAddress
        );

        let claimStakeAddress = await freeClaim.maxxStake();
        let stakeSet = claimStakeAddress === maxxStakeAddress;
        if (!stakeSet) {
            let setStakeTx = await freeClaim.setMaxxStake(maxxStakeAddress);
            await setStakeTx.wait();
            stakeSet = true;
        }
        claimStakeAddress = await freeClaim.maxxStake();

        let stakeStarted = stakeSet && stakeLaunchDate.lte(timestamp);

        if (
            typeof proof !== 'string' &&
            address === signer &&
            !freeClaimBalance.eq(0) &&
            !remainingBalance.eq(0) &&
            !hasClaimed &&
            started &&
            !selfReferral
        ) {
            const v = await freeClaim.verifyMerkleLeaf(address, amount, proof);

            const hasClaimed = await freeClaim.hasClaimed(address);

            if (v && !hasClaimed) {
                const claim = await freeClaim.freeClaim(
                    amount,
                    proof,
                    referrer,
                    {
                        gasLimit: 1_000_000,
                    }
                );
                await claim.wait();
            }
        }
        return true;
    } catch (e) {
        log.red(e);
        return false;
    }
}

async function getMerkleProof(index: number) {
    const leaves = createLeaves(inputs);

    const merkleTree = new MerkleTree(leaves, keccak256, { sort: true });

    const rootHash = merkleTree.getHexRoot();

    const address = inputs[index].address;
    const amount = inputs[index].amount;

    const hashedLeaf = utils.solidityKeccak256(
        ['address', 'uint256'],
        [address, amount]
    );

    const proof: BytesLike[] = merkleTree.getHexProof(hashedLeaf);

    return [hashedLeaf, proof];
}

function createLeaves(inputs: input[]) {
    const leaves = inputs.map((x) =>
        utils.solidityKeccak256(['address', 'uint256'], [x.address, x.amount])
    );
    return leaves;
}

const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
const freeClaimAddress = process.env.FREE_CLAIM_ADDRESS!;

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

// freeClaimTx(
//     maxxFinanceAddress,
//     maxxStakeAddress,
//     freeClaimAddress,
//     inputs
// ).catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
