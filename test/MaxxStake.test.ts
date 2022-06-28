import { expect } from "chai";
import hre, { ethers } from "hardhat";
import log from "ololog";

import { MaxxStake } from "../typechain/MaxxStake";
import { MaxxStake__factory } from "../typechain/factories/MaxxStake__factory";

import { MaxxFinance } from "../typechain/MaxxFinance";
import { MaxxFinance__factory } from "../typechain/factories/MaxxFinance__factory";

describe("Stake", () => {
  let Stake: MaxxStake__factory;
  let stake: MaxxStake;

  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;
  let deployer: any;
  let otherAddress: any;
  const nft: any = "0xac7a698a85102f7b1dc7345e7f17ebca74e5a9e7"; // Default Artion Collection
  let stakeCounter = -1;
  let days = 0;
  const amount = ethers.utils.parseEther("1");

  before(async () => {
    const signers = await ethers.getSigners();
    deployer = signers[0];
    otherAddress = signers[1];

    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    const timestamp = timestampBefore + 1;

    Stake = (await ethers.getContractFactory(
      "MaxxStake"
    )) as MaxxStake__factory;
    stake = await Stake.deploy(maxx.address, timestamp, nft);

    await maxx.grantRole(await maxx.MINTER_ROLE(), stake.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(stake.address).to.exist;
    });
  });

  describe("stake", () => {
    it("should transfer tokens when staked", async () => {
      const supplyBefore = await maxx.totalSupply();
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const stakedBalanceBefore = await maxx.balanceOf(stake.address);
      await maxx.approve(stake.address, amount);
      await stake.stake(30, amount);
      stakeCounter++;
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const stakedBalanceAfter = await maxx.balanceOf(stake.address);
      const supplyAfter = await maxx.totalSupply();
      expect(balanceBefore.sub(balanceAfter).toString()).to.equal(
        amount.toString()
      );
      expect(stakedBalanceAfter.sub(stakedBalanceBefore).toString()).to.equal(
        amount.toString()
      );
      expect(supplyBefore.sub(supplyAfter).toString()).to.equal("0");
    });

    it("should not allow a user to stake more than their balance", async () => {
      await maxx.transfer(otherAddress.address, amount);

      const balanceBefore = await maxx.balanceOf(otherAddress.address);

      await maxx
        .connect(otherAddress)
        .approve(stake.address, balanceBefore.add(1));
      await expect(
        stake.connect(otherAddress).stake(30, balanceBefore.add(1))
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });

    it("should emit a stake event", async () => {
      await maxx.approve(stake.address, amount);
      await expect(stake.stake(30, amount))
        .to.emit(stake, "Stake")
        .withArgs(deployer.address, 30, amount);
      stakeCounter++;
    });
  });

  describe("unstake", () => {
    it("should return principal + interest when unstaking after maturation", async () => {
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x278d00; // 2592000 seconds = 30 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 2592000 seconds = 30 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 30;

      const userStake = await stake.stakes(0);
      expect(userStake.owner.toString()).to.equal(deployer.address);

      const shares = userStake.shares;
      const fullInterest = (Number(shares) * 30) / 365 / 10;
      const fullPrincipalInterest = ethers.utils
        .parseEther("1")
        .add(fullInterest.toString());

      await stake.unstake(0);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference.gt(amount.toString())).to.be.true;
      expect(balanceDifference.toString()).to.be.equal(
        fullPrincipalInterest.toString()
      );
    });

    it("should assess an early unstaking penalty of 100%", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(30, amount);
      stakeCounter++;

      const balanceBefore = await maxx.balanceOf(deployer.address);
      const userStake = await stake.stakes(stakeCounter);
      expect(userStake.owner.toString()).to.equal(deployer.address);

      await stake.unstake(stakeCounter);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference).to.be.lt(amount.toString());
    });

    it("should assess an early unstaking penalty of 50%", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(30, amount);
      stakeCounter++;

      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x13c680; // 1296000 seconds = 15 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 1296000 seconds = 15 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 15;

      await stake.unstake(stakeCounter);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference.lt(amount.toString())).to.be.true;
    });

    it("should assess a late unstaking penalty", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(100, amount);
      stakeCounter++;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;
      const daysLate = 6;
      const userStake = await stake.stakes(stakeCounter);
      const shares = userStake.shares;
      const fullInterest = (Number(shares) * 10) / 365;
      await stake.unstake(stakeCounter);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      const fullPrincipalInterest = amount.add(fullInterest.toString());
      const penaltyPercentage = daysLate / 365;
      const expectedBalance =
        Number(fullPrincipalInterest) * (1 - penaltyPercentage);
      expect(balanceDifference.lt(fullPrincipalInterest)).to.be.true;
      expect(balanceDifference.gt(expectedBalance.toString())).to.be.true; // Will be greater because of truncation in the smart contract's calculation
    });
  });

  describe("restake", () => {
    it("should restake a matured stake", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(100, amount);
      stakeCounter++;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await stake.restake(stakeCounter, 0);
    });

    it("should not restake if user is not the owner the stake", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(100, amount);
      stakeCounter++;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await expect(
        stake.connect(otherAddress).restake(stakeCounter, 0)
      ).to.be.revertedWith("You are not the owner of this stake");
    });

    it("should not restake a stake that has not matured", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(121, amount);
      stakeCounter++;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await expect(stake.restake(stakeCounter, 0)).to.be.revertedWith(
        "You cannot restake a stake that is not matured"
      );
    });

    it("should top up the restake amount", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;
      let userStake = await stake.stakes(stakeCounter);
      const durationBefore = userStake.duration;
      const amountBefore = userStake.amount;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await maxx.approve(stake.address, amount);
      await stake.restake(stakeCounter, amount);
      userStake = await stake.stakes(stakeCounter);
      const durationAfter = userStake.duration;
      expect(durationAfter).to.be.equal(durationBefore);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceBefore.sub(balanceAfter);
      expect(balanceDifference.eq(amount)).to.be.true;
      const amountAfter = userStake.amount;
      expect(amountAfter.gt(amountBefore)).to.be.true;
    });

    it("should top up the restake amount without late penalties", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(121, amount);
      stakeCounter++;
      const balanceBefore = await maxx.balanceOf(deployer.address);
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await maxx.approve(stake.address, amount);
      await expect(stake.restake(stakeCounter, amount)).to.be.revertedWith(
        "You cannot restake a stake that is not matured"
      );
    });
  });

  describe("maxShare", () => {
    it("should change the stake to the max duration without penalty", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;
      const blockTime = 0x9e3400; // 10368000 seconds = 120 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 10368000 seconds = 120 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 120;

      await stake.maxShare(stakeCounter);
      const userStake = await stake.stakes(stakeCounter);
      const duration = userStake.duration;
      const maxDuration = 3333 * 24 * 60 * 60;
      expect(duration).to.be.equal(maxDuration);
    });

    it("should change the stake to the max duration even before maturation", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;
      const blockTime = 0x278d00; // 2592000 seconds = 30 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 2592000 seconds = 30 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 30;

      await stake.maxShare(stakeCounter);
      const userStake = await stake.stakes(stakeCounter);
      const duration = userStake.duration;
      const maxDuration = 3333 * 24 * 60 * 60;
      expect(duration).to.be.equal(maxDuration);
    });

    it("should emit a stake event", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;
      const blockTime = 0x278d00; // 2592000 seconds = 30 days
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [blockTime], // 2592000 seconds = 30 days
      });

      await hre.network.provider.request({
        method: "hardhat_mine",
        params: ["0x1"], // 1 block
      });

      days += 30;

      await expect(stake.maxShare(stakeCounter)).to.emit(stake, "Stake");
    });
  });

  describe("MarketPlace", () => {
    it("should list the stake on the marketplace", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;

      expect(await stake.market(stakeCounter)).to.be.false;
      await stake.listStake(stakeCounter, amount);
      expect(await stake.market(stakeCounter)).to.be.true;
      expect(await stake.sellPrice(stakeCounter)).to.be.equal(amount);
    });

    it("should emit a list event", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;

      expect(await stake.listStake(stakeCounter, amount))
        .to.emit(stake, "List")
        .withArgs(deployer.address, stakeCounter, amount);
    });

    it("should buy the stake", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;

      let userStake = await stake.stakes(stakeCounter);
      const ownerBefore = userStake.owner;

      expect(await stake.market(stakeCounter)).to.be.false;
      await stake.listStake(stakeCounter, amount);
      expect(await stake.market(stakeCounter)).to.be.true;
      expect(await stake.sellPrice(stakeCounter)).to.be.equal(amount);

      await maxx.connect(otherAddress).approve(stake.address, amount);
      await stake.connect(otherAddress).buyStake(stakeCounter, {
        value: amount,
      });
      userStake = await stake.stakes(stakeCounter);
      const ownerAfter = userStake.owner;

      expect(ownerAfter).to.be.equal(otherAddress.address);
      expect(ownerBefore).to.be.equal(deployer.address);
      expect(ownerAfter).to.be.not.equal(ownerBefore);
    });

    it("should not buy the stake if ETH isn't sent", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(120, amount);
      stakeCounter++;

      await stake.listStake(stakeCounter, amount);

      await maxx.connect(otherAddress).approve(stake.address, amount);
      await expect(
        stake.connect(otherAddress).buyStake(stakeCounter)
      ).to.be.revertedWith("Must send at least the asking price");
    });
  });

  describe("Transfer", () => {
    it("should transfer the stake to a new wallet", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(121, amount);
      stakeCounter++;

      let userStake = await stake.stakes(stakeCounter);
      const ownerBefore = userStake.owner;

      await stake.transferStake(stakeCounter, otherAddress.address);
      userStake = await stake.stakes(stakeCounter);
      const ownerAfter = userStake.owner;
      expect(ownerAfter).to.not.be.equal(ownerBefore);
      expect(ownerAfter).to.be.equal(otherAddress.address);
    });
  });

  describe("Utility Functions", () => {
    it("should return the days since launch", async () => {
      const daysSinceLaunch = await stake.getDaysSinceLaunch();
      expect(daysSinceLaunch).to.not.be.equal(0);
      expect(daysSinceLaunch).to.be.equal(days);
    });

    it("should change stake name", async () => {
      await maxx.approve(stake.address, amount);
      await stake.stake(121, amount);
      stakeCounter++;

      let userStake = await stake.stakes(stakeCounter);
      const nameBefore = userStake.name;

      const newName = "New Name";
      await stake.changeStakeName(stakeCounter, newName);
      userStake = await stake.stakes(stakeCounter);
      const nameAfter = userStake.name;
      expect(nameAfter).to.not.be.equal(nameBefore);
      expect(nameAfter).to.be.equal(newName);
    });
  });
});
