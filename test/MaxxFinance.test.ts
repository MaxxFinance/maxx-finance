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
    maxx = await Maxx.deploy(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit
  });

  describe("deploy", () => {
    it("should deploy", async () => {
      expect(maxx.address).to.exist;
    });
  });

  describe("access control", () => {
    it("should grant a new address the minter role", async () => {});
    it("should revoke the minter role", async () => {});
  });

  describe("transfer", () => {
    it("should transfer peer to peer without a transfer tax", async () => {});
    it("should collect a transfer tax when buy or sell from a DEX pool", async () => {});
    it("should transfer tokens from an authorized wallet", async () => {});
    it("should not transfer more tokens than user's balance", async () => {});
  });

  describe("burn", () => {
    it("should burn tokens from msg.sender", async () => {});
    it("should burn tokens from an authorized wallet", async () => {});
    it("should not burn more tokens than user's balance", async () => {});
  });

  describe("mint", () => {
    it("should mint tokens", async () => {});
    it("should mint tokens without minter role", async () => {});
  });
});
