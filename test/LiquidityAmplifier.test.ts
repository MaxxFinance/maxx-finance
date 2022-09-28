import { time, takeSnapshot } from '@nomicfoundation/hardhat-network-helpers';
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import log from 'ololog';

import { LiquidityAmplifier } from '../typechain-types/contracts/LiquidityAmplifier';
import { LiquidityAmplifier__factory } from '../typechain-types/factories/contracts/LiquidityAmplifier__factory';

import { MaxxStake } from '../typechain-types/contracts/MaxxStake';
import { MaxxStake__factory } from '../typechain-types/factories/contracts/MaxxStake__factory';

import { MaxxFinance } from '../typechain-types/contracts/MaxxFinance';
import { MaxxFinance__factory } from '../typechain-types/factories/contracts/MaxxFinance__factory';

describe('Liquidity Amplifier', () => {
    let Amplifier: LiquidityAmplifier__factory;
    let amplifier: LiquidityAmplifier;

    let Stake: MaxxStake__factory;
    let stake: MaxxStake;

    let Maxx: MaxxFinance__factory;
    let maxx: MaxxFinance;
    let deployer: any;
    const nft: any = '0x8634666bA15AdA4bbC83B9DbF285F73D9e46e4C2'; // Polygon Chicken Derby Collection
    const maxxVault = '0xBF7BF3d445aEc7B0c357163d5594DB8ca7C12D31';
    let timestamp: number;

    before(async () => {
        const signers = await ethers.getSigners();
        deployer = signers[0];

        Maxx = (await ethers.getContractFactory(
            'MaxxFinance'
        )) as MaxxFinance__factory;
        maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

        const timestampBefore = await time.latest();
        timestamp = timestampBefore + 1;

        Stake = (await ethers.getContractFactory(
            'MaxxStake'
        )) as MaxxStake__factory;
        stake = await Stake.deploy(maxxVault, maxx.address, timestamp);

        timestamp = timestamp + 86400; // +1 day

        Amplifier = (await ethers.getContractFactory(
            'LiquidityAmplifier'
        )) as LiquidityAmplifier__factory;
        amplifier = await Amplifier.deploy(maxxVault, timestamp, maxx.address);
    });

    describe('deploy', () => {
        it('should deploy', async () => {
            expect(maxx.address).to.exist;
            expect(stake.address).to.exist;
            expect(amplifier.address).to.exist;
        });
    });

    describe('initialize', () => {
        it('should set stake address', async () => {
            await amplifier.setStakeAddress(stake.address);
            const stakeAddress = await amplifier.stake();
            expect(stakeAddress).to.equal(stake.address);
        });

        it('should set maxx daily allocations', async () => {
            const dailyAllocations: [
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber
            ] = [
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
            ];

            await amplifier.setDailyAllocations(dailyAllocations);
        });

        it('should set maxx daily allocations after initialization', async () => {
            const dailyAllocations: [
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber,
                BigNumber
            ] = [
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
                ethers.utils.parseEther('1000000'),
            ];

            await expect(
                amplifier.setDailyAllocations(dailyAllocations)
            ).to.be.revertedWithCustomError(amplifier, 'AlreadyInitialized');
        });

        // tested with maxxDailyAllocation as a public variable and changed back to private
        it('should change a daily maxx allocation', async () => {
            const dailyAllocation = ethers.utils.parseEther('2000000'); // 2 million maxx
            // const allocationBefore = await amplifier.maxxDailyAllocation(0);
            // log.yellow("allocationBefore: ", allocationBefore);
            await expect(amplifier.changeDailyAllocation(0, dailyAllocation)).to
                .be.not.reverted;
            // const allocationAfter = await amplifier.maxxDailyAllocation(0);
            // log.yellow("allocationAfter: ", allocationAfter);
            // expect(allocationAfter).to.be.not.eq(allocationBefore);
            // expect(allocationAfter).to.be.eq(dailyAllocation);
        });

        it('should change the launch date', async () => {
            const launchDate = timestamp + 55000;
            const oldLaunchDate = await amplifier.launchDate();
            await amplifier.changeLaunchDate(launchDate);
            const newLaunchDate = await amplifier.launchDate();
            expect(newLaunchDate).to.be.not.eq(oldLaunchDate);
            expect(newLaunchDate).to.be.eq(launchDate);
        });

        it('should not change the start date to a day that has passed', async () => {
            const launchDate = timestamp - 86400; // 1 day ago
            await expect(amplifier.changeLaunchDate(launchDate)).to.be.reverted;
        });

        it('should not change the start date after it has passed', async () => {
            const launchDate = timestamp + 8640000; // +100 days

            const snapshot = await takeSnapshot();

            const now = await time.latest();
            const launch = await amplifier.launchDate();
            const fastForward = launch.sub(now).add(1);
            await time.increase(fastForward); // increase time 1 day
            await expect(amplifier.changeLaunchDate(launchDate)).to.be.reverted;

            await snapshot.restore();
        });
    });

    describe('deposit', () => {
        it('should deposit matic', async () => {
            const launchDate = await amplifier.launchDate();
            await time.increaseTo(Number(launchDate) + 1);
            const currentDay = await amplifier.getDay();
            log.yellow('currentDay:', currentDay);
            await expect(amplifier['deposit()']()).to.not.be.reverted;
        });
    });
});
