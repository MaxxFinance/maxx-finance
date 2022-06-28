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
    it("should update burnedAmount", async () => {});
    it("should not burn more tokens than user's balance", async () => {});
    it("should decrease totalSupply", async () => {});
  });

  describe("mint", () => {
    it("should mint tokens", async () => {});
    it("should mint tokens without minter role", async () => {});
    it("should increase totalSupply", async () => {});
  });

  describe("bot protection", () => {
    it("should not allow transfers greater than the whale limit", async () => {});
    it("should not allow transfers greater than the global daily sell limit", async () => {});
    it("should not allow transfers when the contract is paused", async () => {});
    describe("allowlist/blocklist", () => {
      it("should block addresses that attempt to buy and sell in consecutive blocks", async () => {});
      it("should transfer tokens for allowlist addresses", async () => {});
    });
  });

  describe("variable updates", () => {
    it("should add pool", async () => {});
    it("should set transfer tax", async () => {});
    it("should set global daily sell limit", async () => {});
    it("should set whale limit", async () => {});
    it("should update blocks between transfers", async () => {});
  });
});
