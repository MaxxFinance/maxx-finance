import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { LiquidityAmplifier } from "../typechain/LiquidityAmplifier";
import { LiquidityAmplifier__factory } from "../typechain/factories/LiquidityAmplifier__factory";

import { MaxxStake } from "../typechain/MaxxStake";
import { MaxxStake__factory } from "../typechain/factories/MaxxStake__factory";

import { MaxxFinance } from "../typechain/MaxxFinance";
import { MaxxFinance__factory } from "../typechain/factories/MaxxFinance__factory";

describe("Liquidity Amplifier", () => {
  let Amplifier: LiquidityAmplifier__factory;
  let amplifier: LiquidityAmplifier;

  let Stake: MaxxStake__factory;
  let stake: MaxxStake;

  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;
  let deployer: any;
  const nft: any = "0xac7a698a85102f7b1dc7345e7f17ebca74e5a9e7"; // Default Artion Collection

  before(async () => {
    const signers = await ethers.getSigners();
    deployer = signers[0];

    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit

    const blockNumBefore = await ethers.provider.getBlockNumber();
    const blockBefore = await ethers.provider.getBlock(blockNumBefore);
    const timestampBefore = blockBefore.timestamp;
    let timestamp = timestampBefore + 1;

    Stake = (await ethers.getContractFactory(
      "MaxxStake"
    )) as MaxxStake__factory;
    stake = await Stake.deploy(maxx.address, timestamp, nft);

    timestamp = timestamp + 1;

    Amplifier = (await ethers.getContractFactory(
      "LiquidityAmplifier"
    )) as LiquidityAmplifier__factory;
    amplifier = await Amplifier.deploy(timestamp, stake.address, maxx.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(amplifier.address).to.exist;
    });
  });

  //   describe("stake", () => {
  //     it("should stake", async () => {
  //       const balanceBefore = await maxx.balanceOf(stake.address);
  //       const tx = await stake.stake(30, ethers.utils.parseEther("1"));
  //       const balanceAfter = await maxx.balanceOf(stake.address);
  //       expect(balanceAfter.sub(balanceBefore).toString()).to.equal(
  //         ethers.utils.parseEther("1").toString()
  //       );
  //     });
  //   });
});
