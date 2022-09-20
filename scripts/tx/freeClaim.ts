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
    const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);

    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = MaxxStake.attach(maxxStakeAddress);

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = FreeClaim.attach(freeClaimAddress);

    const [leaf, proof] = await getMerkleProof(1);
    const referrer = inputs[0].address;
    log.magenta('referrer:', referrer);
    const address = inputs[1].address;
    log.magenta('address:', address);
    const amount = inputs[1].amount;

    let selfReferral = referrer === address;
    log.magenta('selfReferral:', selfReferral);

    const freeClaimBalance = await maxxFinance.balanceOf(freeClaimAddress);
    log.yellow('freeClaimBalance: ', freeClaimBalance.toString());
    const remainingBalance = await freeClaim.remainingBalance();
    log.yellow('remainingBalance: ', remainingBalance.toString());
    log.magenta('amount > remainingBalance: ', remainingBalance.lt(amount));
    const hasClaimed = await freeClaim.hasClaimed(address);
    log.cyan('hasClaimed: ', hasClaimed);

    const stakeLaunchDate = await maxxStake.launchDate();
    log.cyan('stakeLaunchDate: ', stakeLaunchDate.toString());
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    const timestamp = block.timestamp;
    log.cyan('timestamp: ', timestamp.toString());
    log.cyan('stake has launched:', stakeLaunchDate.lte(timestamp));
    const claimLaunchDate = await freeClaim.launchDate();
    log.cyan('claimLaunchDate: ', claimLaunchDate.toString());
    const started = claimLaunchDate.lte(timestamp);
    if (started) {
        log.cyan('claim has started');
        const timePassed = timestamp - claimLaunchDate.toNumber();
        log.cyan('timePassed in seconds: ', timePassed);
        const timePassedInDays = timePassed / 86400;
        log.cyan('timePassed in days: ', timePassedInDays);
    }

    const allowance = await maxxFinance.allowance(
        freeClaimAddress,
        maxxStakeAddress
    );
    log.yellow('allowance: ', allowance.toString());

    const claimStakeAddress = await freeClaim.maxxStake();
    log.cyan('stake address set:', claimStakeAddress === maxxStakeAddress);

    const stakeFreeClaimAddress = await maxxStake.freeClaim();
    log.cyan('claim address set:', stakeFreeClaimAddress === freeClaimAddress);

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
        log.magenta('verify:', v);

        const hasClaimed = await freeClaim.hasClaimed(address);
        log.cyan('hasClaimed: ', hasClaimed);

        if (v && !hasClaimed) {
            const balanceBefore = await maxxFinance.balanceOf(address);
            log.yellow('balanceBefore:', balanceBefore.toString());
            const claim = await freeClaim.freeClaim(amount, proof, referrer, {
                gasLimit: 1_000_000,
            });
            await claim.wait();
            log.yellow('claim:', claim.hash);

            const balanceAfter = await maxxFinance.balanceOf(inputs[1].address);
            log.yellow('balanceAfter:', balanceAfter.toString());

            const balanceDiff = balanceAfter.sub(balanceBefore);
            log.yellow('balanceDiff:', balanceDiff.toString());

            const eq = balanceDiff.toString() === inputs[1].amount;
            log.yellow('eq:', eq);
        }
    }
}

async function getMerkleProof(index: number) {
    const leaves = createLeaves(inputs);

    const merkleTree = new MerkleTree(leaves, keccak256, { sort: true });

    log.yellow('merkleTree:', merkleTree.toString());

    const rootHash = merkleTree.getHexRoot();
    log.yellow('rootHash: ', rootHash);

    const address = inputs[index].address;
    const amount = inputs[index].amount;

    const hashedLeaf = utils.solidityKeccak256(
        ['address', 'uint256'],
        [address, amount]
    );

    const proof: BytesLike[] = merkleTree.getHexProof(hashedLeaf);
    log.yellow('proof: ', proof);

    log.yellow('isBytesLike:', utils.isBytesLike(proof));

    return [hashedLeaf, proof];
}

function createLeaves(inputs: input[]) {
    const leaves = inputs.map((x) =>
        utils.solidityKeccak256(['address', 'uint256'], [x.address, x.amount])
    );
    return leaves;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
