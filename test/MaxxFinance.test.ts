import { expect } from "chai";
import { ethers } from "hardhat";
import log from "ololog";

import { MaxxFinance } from "../typechain/MaxxFinance";
import { MaxxFinance__factory } from "../typechain/factories/MaxxFinance__factory";

describe.only("Maxx Token", () => {
  let Maxx: MaxxFinance__factory;
  let maxx: MaxxFinance;
  let signers: any;
  let deployer: any;

  before(async () => {
    signers = await ethers.getSigners();
    deployer = signers[0];
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
    it("should grant a new address the minter role", async () => {
      const minter = signers[1];
      await maxx.grantRole(await maxx.MINTER_ROLE(), minter.address);
      expect(await maxx.hasRole(await maxx.MINTER_ROLE(), minter.address)).to.be
        .true;
    });
    it("should revoke the minter role", async () => {
      expect(await maxx.hasRole(await maxx.MINTER_ROLE(), deployer.address)).to
        .be.true;
      await maxx.revokeRole(await maxx.MINTER_ROLE(), deployer.address);
      expect(await maxx.hasRole(await maxx.MINTER_ROLE(), deployer.address)).to
        .be.false;
    });
  });

  describe("variable updates", () => {
    it("should add pool", async () => {
      const pool = signers[2].address;
      expect(await maxx.isPool(pool)).to.be.false;
      await maxx.addPool(pool);
      expect(await maxx.isPool(pool)).to.be.true;
    });
    it("should set transfer tax", async () => {
      const tax = 100;
      expect(await maxx.transferTax()).to.be.equal(500);
      await maxx.setTransferTax(tax);
      expect(await maxx.transferTax()).to.be.be.equal(tax);
    });
    it("should set global daily sell limit", async () => {
      const limit = 2000000000;
      expect(await maxx.globalDailySellLimit()).to.be.equal(
        ethers.utils.parseEther("1000000000")
      );
      await maxx.setGlobalDailySellLimit(limit);
      expect(await maxx.globalDailySellLimit()).to.be.equal(
        ethers.utils.parseEther(limit.toString())
      );
    });
    it("should not set global daily sell limit less than 1,000,000,000", async () => {
      const limit = 1000000; // 1,000,000
      await expect(maxx.setGlobalDailySellLimit(limit)).to.be.revertedWith(
        "Global daily sell limit must be greater than or equal to 1,000,000,000 tokens"
      );
    });
    it("should set whale limit", async () => {
      const limit = 1000000000;
      expect(await maxx.whaleLimit()).to.be.equal(
        ethers.utils.parseEther("1000000")
      );
      await maxx.setWhaleLimit(limit);
      expect(await maxx.whaleLimit()).to.be.equal(
        ethers.utils.parseEther(limit.toString())
      );
    });
    it("should not set whale limit less than 1,000,000", async () => {
      const limit = 100000; // 100,000
      await expect(maxx.setWhaleLimit(limit)).to.be.revertedWith(
        "Whale limit must be greater than or equal to 1,000,000"
      );
    });
    it("should update blocks between transfers", async () => {
      const blocks = 2;
      expect(await maxx.blocksBetweenTransfers()).to.be.equal(0);
      await maxx.updateBlocksBetweenTransfers(blocks);
      expect(await maxx.blocksBetweenTransfers()).to.be.equal(blocks);
    });

    it("should not update blocks between transfers greater than 5", async () => {
      const blocks = 20;
      await expect(
        maxx.updateBlocksBetweenTransfers(blocks)
      ).to.be.revertedWith(
        "Blocks between transfers must be less than or equal to 5"
      );
    });
  });

  describe("transfer", () => {
    it("should transfer peer to peer without a transfer tax", async () => {
      const to = signers[1].address;
      const amount = ethers.utils.parseEther("100");
      const balanceBefore = await maxx.balanceOf(to);
      await maxx.transfer(to, amount);
      const balanceAfter = await maxx.balanceOf(to);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference).to.eq(amount);
    });
    it("should collect a transfer tax when buy or sell from a DEX pool", async () => {
      const pool = signers[2].address;
      const amount = ethers.utils.parseEther("100");
      const balanceBefore = await maxx.balanceOf(pool);
      await maxx.addPool(pool);
      await maxx.transfer(pool, amount);
      const balanceAfter = await maxx.balanceOf(pool);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference).to.not.eq(amount);
    });
    it("should transfer tokens from an authorized wallet", async () => {
      // TODO passes when ran by itself, fails when ran with other tests
      const amount = ethers.utils.parseEther("1");

      await maxx.approve(signers[1].address, amount);

      const allowance = await maxx.allowance(
        deployer.address,
        signers[1].address
      );
      expect(allowance).to.eq(amount);

      log.yellow("allowance: " + allowance.toString());
      log.yellow("amount: " + amount.toString());

      const deployerBalanceBefore = await maxx.balanceOf(deployer.address);
      const signer2BalanceBefore = await maxx.balanceOf(signers[2].address);
      await maxx
        .connect(signers[1])
        .transferFrom(deployer.address, signers[2].address, amount);
      const deployerBalanceAfter = await maxx.balanceOf(deployer.address);
      const signer2BalanceAfter = await maxx.balanceOf(signers[2].address);

      const deployerBalanceDifference =
        deployerBalanceBefore.sub(deployerBalanceAfter);
      const signer2BalanceDifference =
        signer2BalanceAfter.sub(signer2BalanceBefore);
      expect(deployerBalanceDifference).to.eq(amount);
      expect(signer2BalanceDifference).to.eq(amount);
    });
    it("should not transfer more tokens than user's balance", async () => {
      const to = signers[3].address;
      let amount = ethers.utils.parseEther("1");
      await maxx.transfer(to, amount);

      amount = (await maxx.balanceOf(to)).add(1); // more than user's balance

      await expect(
        maxx.connect(signers[3]).transfer(deployer.address, amount)
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
  });

  describe("burn", () => {
    it("should burn tokens from msg.sender", async () => {
      const amount = ethers.utils.parseEther("100");
      const balanceBefore = await maxx.balanceOf(deployer.address);
      await maxx.burn(amount);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceBefore.sub(balanceAfter);
      expect(balanceDifference).to.eq(amount);
    });
    it("should burn tokens from an authorized wallet", async () => {
      const amount = ethers.utils.parseEther("100");
      await maxx.approve(signers[1].address, amount);

      const deployerBalanceBefore = await maxx.balanceOf(deployer.address);
      await maxx.connect(signers[1]).burnFrom(deployer.address, amount);
      const deployerBalanceAfter = await maxx.balanceOf(deployer.address);
      const deployerBalanceDifference =
        deployerBalanceBefore.sub(deployerBalanceAfter);
      expect(deployerBalanceDifference).to.eq(amount);
    });
    it("should update burnedAmount", async () => {
      const amount = ethers.utils.parseEther("100");
      const burnedAmountBefore = await maxx.burnedAmount();
      await maxx.burn(amount);
      const burnedAmountAfter = await maxx.burnedAmount();
      const burnedAmount = burnedAmountAfter.sub(burnedAmountBefore);
      expect(burnedAmount).to.eq(amount);
    });
    it("should not burn more tokens than user's balance", async () => {
      const to = signers[3].address;
      let amount = ethers.utils.parseEther("1");
      await maxx.transfer(to, amount);

      amount = (await maxx.balanceOf(to)).add(1); // more than user's balance

      await expect(maxx.connect(signers[3]).burn(amount)).to.be.revertedWith(
        "ERC20: burn amount exceeds balance"
      );
    });
    it("should decrease totalSupply", async () => {
      const amount = ethers.utils.parseEther("100");
      const totalSupplyBefore = await maxx.totalSupply();
      await maxx.burn(amount);
      const totalSupplyAfter = await maxx.totalSupply();
      const totalSupplyDifference = totalSupplyBefore.sub(totalSupplyAfter);
      expect(totalSupplyDifference).to.eq(amount);
    });
  });

  describe("mint", () => {
    it("should mint tokens", async () => {
      const minterRole = await maxx.MINTER_ROLE();
      await maxx.grantRole(minterRole, deployer.address);
      const amount = ethers.utils.parseEther("100");
      const balanceBefore = await maxx.balanceOf(deployer.address);
      await maxx.mint(deployer.address, amount);
      const balanceAfter = await maxx.balanceOf(deployer.address);
      const balanceDifference = balanceAfter.sub(balanceBefore);
      expect(balanceDifference).to.eq(amount);
    });
    it("should not mint tokens without minter role", async () => {
      const amount = ethers.utils.parseEther("100");
      await expect(
        maxx.connect(signers[2]).mint(deployer.address, amount)
      ).to.be.revertedWith("Caller is not a minter");
    });
    it("should increase totalSupply", async () => {
      const minterRole = await maxx.MINTER_ROLE();
      await maxx.grantRole(minterRole, deployer.address);
      const amount = ethers.utils.parseEther("100");
      const totalSupplyBefore = await maxx.totalSupply();
      await maxx.mint(deployer.address, amount);
      const totalSupplyAfter = await maxx.totalSupply();
      const totalSupplyDifference = totalSupplyAfter.sub(totalSupplyBefore);
      expect(totalSupplyDifference).to.eq(amount);
    });
  });

  describe("bot protection", () => {
    it("should not allow transfers when the contract is paused", async () => {
      await maxx.pause();
      const to = signers[1].address;
      const amount = ethers.utils.parseEther("100");
      await expect(maxx.transfer(to, amount)).to.be.revertedWith(
        "Pausable: paused"
      );
    });
    it("should allow transfers when the contract is unpaused", async () => {
      await maxx.unpause();
      const to = signers[1].address;
      const amount = ethers.utils.parseEther("100");
      await expect(maxx.transfer(to, amount)).to.be.not.reverted;
    });
    describe("allowlist/blocklist", () => {
      it("should block addresses that attempt to buy and sell in consecutive blocks", async () => {
        await maxx.updateBlockLimited(true);
        expect(await maxx.isBlockLimited()).to.eq(true);
        await maxx.updateBlocksBetweenTransfers(5);
        expect(await maxx.blocksBetweenTransfers()).to.eq(5);
        const to = signers[1].address;
        await maxx.addPool(to);
        const amount = ethers.utils.parseEther("100");
        await maxx.transfer(to, amount);

        // buy tokens (transfer from pool)
        const buyAmount = ethers.utils.parseEther("10");
        await maxx.connect(signers[1]).transfer(signers[0].address, buyAmount);

        // sell tokens (transfer to pool)
        const sellAmount = ethers.utils.parseEther("5");
        await expect(
          maxx.connect(signers[0]).transfer(signers[1].address, sellAmount)
        ).to.be.revertedWith("ERC20: Address is on blocklist");
      });
      it("should transfer tokens for allowlist addresses", async () => {
        await maxx.updateAllowlist(signers[0].address, true);
        expect(await maxx.isAllowed(signers[0].address)).to.eq(true);
        const to = signers[1].address;
        await maxx.addPool(to);
        const amount = ethers.utils.parseEther("100");
        await maxx.transfer(to, amount);

        // buy tokens (transfer from pool)
        const buyAmount = ethers.utils.parseEther("10");
        await maxx.connect(signers[1]).transfer(signers[0].address, buyAmount);

        // sell tokens (transfer to pool)
        const sellAmount = ethers.utils.parseEther("5");
        await expect(
          maxx.connect(signers[0]).transfer(signers[1].address, sellAmount)
        ).to.be.not.reverted;
      });
    });
    describe("Sell Limits", () => {
      it("should not allow transfers greater than the whale limit", async () => {
        const to = signers[1].address;
        const amount = (await maxx.whaleLimit()).add(1);
        const balanceBefore = await maxx.balanceOf(deployer.address);
        await expect(maxx.transfer(to, amount)).to.be.revertedWith(
          "ERC20: Transfer amount exceeds whale limit"
        );
        const balanceAfter = await maxx.balanceOf(deployer.address);
        const balanceDifference = balanceAfter.sub(balanceBefore);
        expect(balanceDifference).to.eq(0);
      });
      it("should not allow transfers greater than the global daily sell limit", async () => {
        await maxx.setGlobalDailySellLimit(1000000000); // 1 billion
        await maxx.setWhaleLimit(1000000001); // 1 billion + 1 -> more than the daily sell limit
        const to = signers[1].address;
        await maxx.addPool(to);
        const dailySellLimit = await maxx.globalDailySellLimit();
        const day = await maxx.getCurrentDay();
        const dailtAmountSold = await maxx.dailyAmountSold(day);
        const amount = dailySellLimit.sub(dailtAmountSold);
        // less than the global daily sell limit
        await maxx.transfer(to, amount);

        log.yellow("after first transfer");

        const balanceBefore = await maxx.balanceOf(deployer.address);

        // amount exceeds the global daily sell limit
        await expect(maxx.transfer(to, dailySellLimit)).to.be.revertedWith(
          "ERC20: Daily sell limit exceeded"
        );
        const balanceAfter = await maxx.balanceOf(deployer.address);
        const balanceDifference = balanceAfter.sub(balanceBefore);
        expect(balanceDifference).to.eq(0);
      });
    });
  });
});
