import { expect } from 'chai';
import {
    time,
    takeSnapshot,
    mine,
} from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import log from 'ololog';

import { MaxxFinance } from '../typechain-types/contracts/MaxxFinance';
import { MaxxFinance__factory } from '../typechain-types/factories/contracts/MaxxFinance__factory';

import { MaxxStake } from '../typechain-types/contracts/MaxxStake';
import { MaxxStake__factory } from '../typechain-types/factories/contracts/MaxxStake__factory';

import { FreeClaim } from '../typechain-types/contracts/FreeClaim';
import { FreeClaim__factory } from '../typechain-types/factories/contracts/FreeClaim__factory';

import {
    createMerkleTree,
    createLeaves,
    input,
    inputs,
} from './helpers/merkleTree';

describe.only('Free Claim', () => {
    let Maxx: MaxxFinance__factory;
    let maxx: MaxxFinance;

    let Stake: MaxxStake__factory;
    let stake: MaxxStake;

    let FreeClaim: FreeClaim__factory;
    let freeClaim: FreeClaim;

    let stakeLaunchDate: any;
    const nftAddress: any = '0x0000000000000000000000000000000000000000'; // TODO add real address
    // let maxxVault = process.env.MAXX_VAULT_ADDRESS!;
    let maxxVault: any;

    let merkleTree: any;
    let merkleRoot: string;
    let startDate: any;
    let signers: any;
    let inputs: input[];
    let deployer: any;

    before(async () => {
        signers = await ethers.getSigners();
        inputs = [
            {
                address: signers[0].address,
                amount: '1000000',
            },
            {
                address: signers[1].address,
                amount: '100000000000000000000000',
            },
            {
                address: signers[2].address,
                amount: '250000',
            },
            {
                address: signers[3].address,
                amount: '1000',
            },
        ];
        merkleTree = createMerkleTree(inputs);
        merkleRoot = merkleTree.getHexRoot();
        deployer = signers[0];

        Maxx = (await ethers.getContractFactory(
            'MaxxFinance'
        )) as MaxxFinance__factory;
        maxx = await Maxx.deploy();

        let initMaxx = await maxx.init(
            deployer.address,
            500,
            1_000_000,
            1_000_000_000
        ); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

        const blockNumBefore = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumBefore);
        const timestampBefore = blockBefore.timestamp;
        stakeLaunchDate = timestampBefore + 1;

        maxxVault = deployer.address;

        Stake = (await ethers.getContractFactory(
            'MaxxStake'
        )) as MaxxStake__factory;
        stake = await Stake.deploy(maxxVault, maxx.address, stakeLaunchDate);

        startDate = stakeLaunchDate + 10;
        // startDate = '1661407200';

        FreeClaim = (await ethers.getContractFactory(
            'FreeClaim'
        )) as FreeClaim__factory;
        freeClaim = await FreeClaim.deploy();

        let updateLaunch = await freeClaim.updateLaunchDate(startDate);
        await updateLaunch.wait();

        let setMaxx = await freeClaim.setMaxx(maxx.address);
        await setMaxx.wait();

        await freeClaim.setMerkleRoot(merkleRoot);

        const amount = ethers.utils.parseEther('100000000');
        await maxx.approve(freeClaim.address, amount);

        await maxx.allow(deployer.address);

        await freeClaim.allocateMaxx(amount);
        await freeClaim.setMaxxStake(stake.address);
        await stake.setFreeClaim(freeClaim.address);
    });

    describe('deploy', () => {
        it('should deploy', async () => {
            expect(maxx.address).to.exist;
            expect(stake.address).to.exist;
            expect(freeClaim.address).to.exist;
        });
    });

    describe('Data', () => {
        it('should return userClaims', async () => {
            const userClaim = await freeClaim.getUserClaims(signers[0].address);
            log.yellow('userClaim:', userClaim);
            expect(userClaim).to.exist;
        });
    });

    describe('Merkle Tree', () => {
        it('should verify the merkle leaf', async () => {
            const address = inputs[0].address;
            const amount = inputs[0].amount;

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);
            const eligibility = await freeClaim.verifyMerkleLeaf(
                address,
                amount,
                proof
            );
            expect(eligibility).to.be.true;
        });

        it('should not verify the merkle leaf with an incorrect amount', async () => {
            const address = inputs[0].address;
            const amount = '150';

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);
            const eligibility = await freeClaim.verifyMerkleLeaf(
                address,
                amount,
                proof
            );
            expect(eligibility).to.be.false;
        });

        it('should not verify the merkle leaf with an incorrect account', async () => {
            const address = signers[7].address;
            const amount = inputs[0].amount;

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);
            const eligibility = await freeClaim.verifyMerkleLeaf(
                address,
                amount,
                proof
            );
            expect(eligibility).to.be.false;
        });
    });

    describe('Claim', () => {
        it('should make a free claim without a referral before stake launch', async () => {
            const noReferral = '0x0000000000000000000000000000000000000000';
            const address = inputs[0].address;
            const amount = inputs[0].amount;

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);

            const stakeId = await stake.idCounter();
            await freeClaim.freeClaim(amount, proof, noReferral);
        });

        it('should make a free claim with a referral before stake launch', async () => {
            const referrer = inputs[0].address;
            const address = inputs[3].address;
            const amount = inputs[3].amount;

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);
            log.yellow('isBytesLike:', ethers.utils.isBytesLike(proof));

            let stakeLaunchDate = await stake.launchDate();
            log.cyan('stakeLaunchDate: ', stakeLaunchDate.toString());
            let blockNumber = await ethers.provider.getBlockNumber();
            let block = await ethers.provider.getBlock(blockNumber);
            let timestamp = block.timestamp;
            log.cyan('stake has launched:', stakeLaunchDate.lte(timestamp));

            Stake = (await ethers.getContractFactory(
                'MaxxStake'
            )) as MaxxStake__factory;
            stake = await Stake.deploy(
                maxxVault,
                maxx.address,
                timestamp + 1000
            );

            let setStake = await freeClaim.setMaxxStake(stake.address);
            let setFreeClaim = await stake.setFreeClaim(freeClaim.address);

            log.yellow("new stakes's address:", stake.address);

            stakeLaunchDate = await stake.launchDate();
            blockNumber = await ethers.provider.getBlockNumber();
            block = await ethers.provider.getBlock(blockNumber);
            timestamp = block.timestamp;
            log.cyan('stake has launched:', stakeLaunchDate.lte(timestamp));

            const stakeId = await stake.idCounter();
            log.yellow('stakeId:', stakeId.toString());

            await freeClaim
                .connect(signers[3])
                .freeClaim(amount, proof, referrer);

            log.yellow('freeclaim dooone:');

            let unstakedClaims = await freeClaim.getAllUnstakedClaims();
            log.yellow('unstakedClaims:', unstakedClaims);

            time.setNextBlockTimestamp(stakeLaunchDate.add(1));
            mine();

            blockNumber = await ethers.provider.getBlockNumber();
            block = await ethers.provider.getBlock(blockNumber);
            timestamp = block.timestamp;
            log.cyan('stake has launched:', stakeLaunchDate.gte(timestamp));

            let migrateClaims = await stake.migrateUnstakedFreeClaims();
            await migrateClaims.wait();

            const newStakeId = await stake.idCounter();
            expect(newStakeId).to.be.gt(stakeId);

            let _stake = await stake.stakes(stakeId);

            log.yellow('stake:', _stake.toString());

            unstakedClaims = await freeClaim.getAllUnstakedClaims();
            log.yellow('unstakedClaims:', unstakedClaims.toString());
        });

        it('should make a free claim with a referral after stake launch', async () => {
            const referrer = inputs[0].address;
            const address = inputs[1].address;
            const amount = inputs[1].amount;

            const hashedLeaf = ethers.utils.solidityKeccak256(
                ['address', 'uint256'],
                [address, amount]
            );
            const proof = merkleTree.getHexProof(hashedLeaf);
            log.yellow('isBytesLike:', ethers.utils.isBytesLike(proof));

            const stakeLaunchDate = await stake.launchDate();
            log.cyan('stakeLaunchDate: ', stakeLaunchDate.toString());
            time.setNextBlockTimestamp(stakeLaunchDate.add(1));
            mine();
            const blockNumber = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNumber);
            const timestamp = block.timestamp;
            log.magenta('timestamp:', timestamp);
            log.cyan('stake has launched:', stakeLaunchDate.lte(timestamp));

            const stakeId = await stake.idCounter();
            await freeClaim
                .connect(signers[1])
                .freeClaim(amount, proof, referrer);
            const referralStakeOwner = await stake.ownerOf(stakeId);
            log.yellow('referralStakeOwner:', referralStakeOwner);
            log.yellow('signers[1].address:', signers[1].address);
            expect(referralStakeOwner).to.be.eq(referrer);
            const stakeOwner = await stake.ownerOf(stakeId.add(1));
            log.yellow('stakeOwner:', stakeOwner);
            expect(stakeOwner).to.be.eq(signers[1].address);
        });
    });
});
