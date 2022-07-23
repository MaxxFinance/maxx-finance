import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { MaxxStake } from "../typechain/MaxxStake";
import { MaxxStake__factory } from "../typechain/factories/MaxxStake__factory";

import { MaxxFinance } from "../typechain/MaxxFinance";
import { MaxxFinance__factory } from "../typechain/factories/MaxxFinance__factory";

import { Marketplace } from "../typechain/Marketplace";
import { Marketplace__factory } from "../typechain/factories/Marketplace__factory";

describe.only("Marketplace", () => {
  let Stake: MaxxStake__factory;
  let stake: MaxxStake;
  const nft: any = "0xac7a698a85102f7b1dc7345e7f17ebca74e5a9e7"; // Default Artion Collection

  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;

  let Marketplace: Marketplace__factory;
  let marketplace: Marketplace;
  let deployer: any;
  let signers: any[];

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
    stake = await Stake.deploy(maxx.address, timestamp, nft);

    log.yellow("stake.address: ", stake.address);

    timestamp = timestamp + 1;

    Marketplace = (await ethers.getContractFactory(
      "Marketplace"
    )) as Marketplace__factory;
    marketplace = await Marketplace.deploy(stake.address, maxx.address);

    log.yellow("marketplace.address: ", marketplace.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(marketplace.address).to.exist;
      expect(stake.address).to.exist;
    });
    it("should grant marketplace role", async () => {
      const marketplaceRole = await stake.MARKETPLACE();
      await stake.grantRole(marketplaceRole, marketplace.address);
    });
  });

  describe("market", () => {
    it("should list stake", async () => {
      const stakeId = await stake.idCounter();
      const stakeDays = 365;
      const stakeAmount = ethers.utils.parseEther("100");
      log.green("test setup");
      await maxx.approve(stake.address, stakeAmount);
      log.green("max approved");
      const userStake = await stake.stake(stakeDays, stakeAmount);
      log.green("stake created");
      const listingAmount = ethers.utils.parseEther("110");

      const listStake = await marketplace.listStake(
        stakeId,
        listingAmount,
        5 * 24 * 60 * 60
      );
      log.green("stake listed");

      const listings = await marketplace.getAllListings();
      log.green("listings: ", listings);
      expect(listings.length).to.equal(1);

      const listing = await marketplace.listings(0);
      expect(listing.lister).to.equal(signers[0].address);
      expect(listing.amount).to.equal(listingAmount);
    });

    it("should emit a List event", async () => {
      const stakeId = await stake.idCounter();
      log.yellow("stakeId: ", stakeId);
      const stakeDays = 365;
      const stakeAmount = ethers.utils.parseEther("100");
      await maxx.approve(stake.address, stakeAmount);
      const userStake = await stake.stake(stakeDays, stakeAmount);
      const listingAmount = ethers.utils.parseEther("110");

      await expect(
        marketplace.listStake(stakeId, listingAmount, 5 * 24 * 60 * 60)
      )
        .to.emit(marketplace, "List")
        .withArgs(signers[0].address, stakeId, listingAmount);
    });

    it("should buy stake", async () => {
      const stakeId = 0;
      const amount = await marketplace.sellPrice(stakeId);
      await maxx.connect(signers[1]).approve(marketplace.address, amount);
      const maxxBefore = await maxx.balanceOf(signers[1].address);
      const buyStake = await marketplace.connect(signers[1]).buyStake(stakeId);
      log.green("stake bought");
      const maxxAfter = await maxx.balanceOf(signers[1].address);
      expect(maxxBefore.sub(maxxAfter)).to.equal(amount);
    });

    it("should emit a Purchase event", async () => {
      const stakeId = 1;
      const amount = await marketplace.sellPrice(stakeId);
      await maxx.connect(signers[1]).approve(marketplace.address, amount);
      const maxxBefore = await maxx.balanceOf(signers[1].address);
      await expect(marketplace.connect(signers[1]).buyStake(stakeId)).to.emit(marketplace, "Purchase").withArgs(signers[1].address, stakeId, amount);
    });

    it("return all listings", async () => {
      const listing0 = await marketplace.listings(0);
      const listing1 = await marketplace.listings(1);
      const expectedListings = [listing0, listing1]
      const listings = await marketplace.getAllListings()
      log.yellow("listings:", listings.toString());
      expect(listings).to.eq(expectedListings)
    });
  });
});
s