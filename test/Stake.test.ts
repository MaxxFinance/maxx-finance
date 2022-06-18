import { expect } from "chai";
import { ethers } from "hardhat";
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

  before(async () => {
    const signers = await ethers.getSigners();
    deployer = signers[0];

    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address);

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    const timestamp = timestampBefore + 1;

    Stake = (await ethers.getContractFactory(
      "MaxxStake"
    )) as MaxxStake__factory;
    stake = await Stake.deploy(maxx.address, timestamp);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(stake.address).to.exist;
    });
  });

  describe("stake", () => {
    it("should burn tokens when staked", async () => {
      const supplyBefore = await maxx.totalSupply();
      const balanceBefore = await maxx.balanceOf(deployer.address);
      await maxx.approve(stake.address, ethers.utils.parseEther("1"));
      log.yellow("burn approved");
      await stake.stake(
        30,
        ethers.utils.parseEther("1"),
        ethers.utils.formatBytes32String("name")
      );
      const balanceAfter = await maxx.balanceOf(deployer.address);
      log.yellow("balanceAfter:", balanceAfter.toString());
      const supplyAfter = await maxx.totalSupply();
      expect(balanceBefore.sub(balanceAfter).toString()).to.equal(
        ethers.utils.parseEther("1").toString()
      );
      expect(supplyBefore.sub(supplyAfter).toString()).to.equal(
        ethers.utils.parseEther("1").toString()
      );
    });

    it("should not allow a user to stake more than their balance", async () => {
      const balanceBefore = await maxx.balanceOf(deployer.address);
      await maxx.approve(stake.address, balanceBefore.add(1));
      await expect(
        stake.stake(
          30,
          balanceBefore.add(1),
          ethers.utils.formatBytes32String("name")
        )
      ).to.be.revertedWith("ERC20: burn amount exceeds balance");
    });
  });

  //   describe("unstake", () => {
  //     it("should mint tokens when unstaked", async () => {
  //       const balanceBefore = await maxx.balanceOf(deployer.address);
  //       await maxx.approve(stake.address, ethers.utils.parseEther("1"));
  //       log.yellow("burn approved");
  //       await stake.unstake(30, ethers.utils.parseEther("1"));
  //       const balanceAfter = await maxx.balanceOf(deployer.address);
  //       log.yellow("balanceAfter:", balanceAfter.toString());
  //       expect(balanceBefore.sub(balanceAfter).toString()).to.equal(
  //         ethers.utils.parseEther("1").toString()
  //       );
  //     });

  //   });
});
