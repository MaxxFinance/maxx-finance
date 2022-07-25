import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { MaxxStake } from "../typechain-types/contracts/MaxxStake";
import { MaxxStake__factory } from "../typechain-types/factories/contracts/MaxxStake__factory";

import { MaxxFinance } from "../typechain-types/contracts/MaxxFinance";
import { MaxxFinance__factory } from "../typechain-types/factories/contracts/MaxxFinance__factory";

import { Marketplace } from "../typechain-types/contracts/Marketplace";
import { Marketplace__factory } from "../typechain-types/factories/contracts/Marketplace__factory";

describe.only("Marketplace", () => {
  let Stake: MaxxStake__factory;
  let stake: MaxxStake;
  const nft: any = "0x8634666bA15AdA4bbC83B9DbF285F73D9e46e4C2"; // Polygon Chicken Derby Collection
  const maxxVault = "0xBF7BF3d445aEc7B0c357163d5594DB8ca7C12D31";

  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;

  let Marketplace: Marketplace__factory;
  let marketplace: Marketplace;
  let deployer: any;
  let signers: any[];
  const duration = 5 * 24 * 60 * 60; // 5 days

  before(async () => {
    signers = await ethers.getSigners();
    deployer = signers[0];

    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

    await maxx.transfer(signers[1].address, ethers.utils.parseEther("100000"));

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    let timestamp = timestampBefore + 1;

    Stake = (await ethers.getContractFactory(
      "MaxxStake"
    )) as MaxxStake__factory;
    stake = await Stake.deploy(maxxVault, maxx.address, timestamp, nft);

    log.yellow("stake.address: ", stake.address);

    timestamp = timestamp + 1;

    Marketplace = (await ethers.getContractFactory(
      "Marketplace"
    )) as Marketplace__factory;
    marketplace = await Marketplace.deploy(stake.address);

    log.yellow("marketplace.address: ", marketplace.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(marketplace.address).to.exist;
      expect(stake.address).to.exist;
    });
  });

  describe("market", () => {
    it("should list stake", async () => {
      const stakeId = await stake.idCounter();
      log.yellow("stakeId: ", stakeId.toString());
      const stakeDays = 365;
      const stakeAmount = ethers.utils.parseEther("100");
      log.green("test setup");
      await maxx.approve(stake.address, stakeAmount);
      log.green("max approved");
      const userStake = await stake.stake(stakeDays, stakeAmount);
      log.green("stake created");
      const listingAmount = ethers.utils.parseEther("110");
      await stake.approve(marketplace.address, stakeId, true);
      const listStake = await marketplace.listStake(
        stakeId,
        listingAmount,
        duration
      );
      log.green("stake listed");

      const listing = await marketplace.listings(stakeId);
      expect(listing.lister).to.equal(signers[0].address);
      expect(listing.amount).to.equal(listingAmount);
    });

    it("should not list stake without approval", async () => {
      const stakeId = await stake.idCounter();
      log.yellow("stakeId: ", stakeId.toString());
      const stakeDays = 365;
      const stakeAmount = ethers.utils.parseEther("100");
      await maxx.approve(stake.address, stakeAmount);
      const userStake = await stake.stake(stakeDays, stakeAmount);
      const listingAmount = ethers.utils.parseEther("110");
      await expect(
        marketplace.listStake(stakeId, listingAmount, duration)
      ).to.be.revertedWithCustomError(marketplace, "NotApproved");
    });

    it("should emit a List event", async () => {
      const stakeId = await stake.idCounter();
      log.yellow("stakeId: ", stakeId.toString());
      const stakeDays = 365;
      const stakeAmount = ethers.utils.parseEther("100");
      await maxx.approve(stake.address, stakeAmount);
      const userStake = await stake.stake(stakeDays, stakeAmount);
      const listingAmount = ethers.utils.parseEther("110");
      await stake.approve(marketplace.address, stakeId, true);

      await expect(marketplace.listStake(stakeId, listingAmount, duration))
        .to.emit(marketplace, "List")
        .withArgs(signers[0].address, stakeId, listingAmount);
    });

    it("should delist stake from marketplace", async () => {
      const stakeId = Number(await stake.idCounter()) - 3;
      log.yellow("stakeId: ", stakeId.toString());
      const userStake = await stake.stakes(stakeId);
      log.yellow("stakeOwner:", userStake.owner);
      const listingBefore = await marketplace.listings(stakeId);
      log.yellow("listing.lister: ", listingBefore.lister);
      log.yellow("listing.amount: ", listingBefore.amount.toString());
      log.yellow("listing.endTime: ", listingBefore.endTime.toString());
      expect(listingBefore.lister).to.equal(signers[0].address);
      expect(listingBefore.amount).to.be.gt(0);
      await marketplace.delistStake(stakeId);
      const listingAfter = await marketplace.listings(stakeId);
      expect(listingAfter.lister).to.equal(ethers.constants.AddressZero);
      expect(listingAfter.amount).to.equal(0);
      expect(listingAfter.endTime).to.equal(0);
    });

    it("should emit a Delist event", async () => {
      const stakeId = Number(await stake.idCounter()) - 1;

      await expect(marketplace.delistStake(stakeId))
        .to.emit(marketplace, "Delist")
        .withArgs(signers[0].address, stakeId);
    });

    it("should buy stake", async () => {
      const stakeId = 0;
      await marketplace.listStake(
        stakeId,
        ethers.utils.parseEther("100"),
        duration
      );
      const amount = await marketplace.sellPrice(stakeId);
      const maticBefore = await signers[0].getBalance();
      await marketplace.connect(signers[1]).buyStake(stakeId, {
        value: amount,
      });
      log.green("stake bought");
      const maticAfter = await signers[0].getBalance();
      expect(maticAfter.sub(maticBefore)).to.equal(amount);
    });

    it("should emit a Purchase event", async () => {
      const stakeId = 2;
      await marketplace.listStake(
        stakeId,
        ethers.utils.parseEther("100"),
        duration
      );
      const amount = await marketplace.sellPrice(stakeId);
      await maxx.connect(signers[1]).approve(marketplace.address, amount);
      await expect(
        marketplace.connect(signers[1]).buyStake(stakeId, {
          value: amount,
        })
      )
        .to.emit(marketplace, "Purchase")
        .withArgs(signers[1].address, stakeId, amount);
    });
  });
});
