import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { MaxxFinance } from "../typechain/MaxxFinance";
import { MaxxFinance__factory } from "../typechain/factories/MaxxFinance__factory";

describe("Maxx Token", () => {
  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;

  before(async () => {
    const signers = await ethers.getSigners();
    const deployer = signers[0];
    Maxx = (await ethers.getContractFactory(
      "MaxxFinance"
    )) as MaxxFinance__factory;
    maxx = await Maxx.deploy(deployer.address);
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(maxx.address).to.exist;
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
