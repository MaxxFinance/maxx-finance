import { time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import log from 'ololog';

import { MaxxFinance } from '../typechain-types/contracts/MaxxFinance';
import {
    MaxxFinance__factory,
    LiquidityAmplifier__factory,
} from '../typechain-types/';

describe('Maxx Token', () => {
    let Maxx: MaxxFinance__factory;
    let maxx: MaxxFinance;
    let signers: any;
    let deployer: any;

    before(async () => {
        signers = await ethers.getSigners();
        deployer = signers[0];
        Maxx = (await ethers.getContractFactory(
            'MaxxFinance'
        )) as MaxxFinance__factory;
        maxx = await Maxx.deploy();
        await maxx.init(deployer.address, 500, 1000000, 1000000000); // 5% transfer tax, 1M whaleLimit, 1B globalDailySellLimit
    });

    describe('deploy', () => {
        it('should deploy', async () => {
            expect(maxx.address).to.exist;
        });
    });

    describe('access control', () => {
        it('should grant a new address the minter role', async () => {
            const minter = signers[1];
            await maxx.grantRole(await maxx.MINTER_ROLE(), minter.address);
            expect(await maxx.hasRole(await maxx.MINTER_ROLE(), minter.address))
                .to.be.true;
        });
        it('should revoke the minter role', async () => {
            await maxx.revokeRole(await maxx.MINTER_ROLE(), deployer.address);
            expect(
                await maxx.hasRole(await maxx.MINTER_ROLE(), deployer.address)
            ).to.be.false;
        });
    });

    describe('variable updates', () => {
        it('should add pool', async () => {
            const pool = signers[2].address;
            expect(await maxx.isPool(pool)).to.be.false;
            await maxx.addPool(pool);
            expect(await maxx.isPool(pool)).to.be.true;
        });
        it('should set min transfer tax', async () => {
            const taxBefore = 500;
            const tax = 100;
            expect(await maxx.minTransferTax()).to.be.equal(taxBefore);
            await maxx.setMinTransferTax(tax);
            expect(await maxx.minTransferTax()).to.be.be.equal(tax);
        });
        it('should set max transfer tax', async () => {
            const taxBefore = 500;
            const tax = 1000;
            expect(await maxx.maxTransferTax()).to.be.equal(taxBefore);
            await maxx.setMaxTransferTax(tax);
            expect(await maxx.maxTransferTax()).to.be.be.equal(tax);
        });
        it('should not set min transfer tax greater than max transfer tax', async () => {
            const taxBefore = 100;
            const tax = 2000;
            expect(await maxx.minTransferTax()).to.be.equal(taxBefore);
            await expect(
                maxx.setMinTransferTax(tax)
            ).to.be.revertedWithCustomError(maxx, 'InvalidTax');
            expect(await maxx.minTransferTax()).to.be.be.equal(taxBefore);
        });
        it('should not set max transfer tax less than min transfer tax', async () => {
            const taxBefore = 1000;
            const tax = 50;
            expect(await maxx.maxTransferTax()).to.be.equal(taxBefore);
            await expect(
                maxx.setMaxTransferTax(tax)
            ).to.be.revertedWithCustomError(maxx, 'InvalidTax');
            expect(await maxx.maxTransferTax()).to.be.be.equal(taxBefore);
        });
        it('should set global daily sell limit', async () => {
            const limit = 2000000000;
            expect(await maxx.globalDailySellLimit()).to.be.equal(
                ethers.utils.parseEther('1000000000')
            );
            await maxx.setGlobalDailySellLimit(limit);
            expect(await maxx.globalDailySellLimit()).to.be.equal(
                ethers.utils.parseEther(limit.toString())
            );
        });
        it('should not set global daily sell limit less than 1,000,000,000', async () => {
            const limit = 1000000; // 1,000,000
            await expect(
                maxx.setGlobalDailySellLimit(limit)
            ).to.be.revertedWithCustomError(maxx, 'ConsumerProtection');
        });
        it('should set whale limit', async () => {
            const limit = 1000000000;
            expect(await maxx.whaleLimit()).to.be.equal(
                ethers.utils.parseEther('1000000')
            );
            await maxx.setWhaleLimit(limit);
            expect(await maxx.whaleLimit()).to.be.equal(
                ethers.utils.parseEther(limit.toString())
            );
        });
        it('should not set whale limit less than 1,000,000', async () => {
            const limit = 100000; // 100,000
            await expect(
                maxx.setWhaleLimit(limit)
            ).to.be.revertedWithCustomError(maxx, 'ConsumerProtection');
        });
        it('should update blocks between transfers', async () => {
            const blocks = 2;
            expect(await maxx.blocksBetweenTransfers()).to.be.equal(0);
            await maxx.setBlocksBetweenTransfers(blocks);
            expect(await maxx.blocksBetweenTransfers()).to.be.equal(blocks);
        });

        it('should not update blocks between transfers greater than 5', async () => {
            const blocks = 20;
            await expect(
                maxx.setBlocksBetweenTransfers(blocks)
            ).to.be.revertedWithCustomError(maxx, 'ConsumerProtection');
        });
    });

    describe('transfer', () => {
        it('should transfer peer to peer without a transfer tax', async () => {
            const to = signers[1].address;
            const amount = ethers.utils.parseEther('100');
            const balanceBefore = await maxx.balanceOf(to);
            await maxx.transfer(to, amount);
            const balanceAfter = await maxx.balanceOf(to);
            const balanceDifference = balanceAfter.sub(balanceBefore);
            expect(balanceDifference).to.eq(amount);
        });
        it('should collect a transfer tax when buy or sell from a DEX pool', async () => {
            const pool = signers[2].address;
            const amount = ethers.utils.parseEther('100');
            const balanceBefore = await maxx.balanceOf(pool);
            await maxx.addPool(pool);
            await maxx.transfer(pool, amount);
            const balanceAfter = await maxx.balanceOf(pool);
            const balanceDifference = balanceAfter.sub(balanceBefore);
            expect(balanceDifference).to.not.eq(amount);
        });
        it('should transfer tokens from an authorized wallet', async () => {
            const amount = ethers.utils.parseEther('1');

            await maxx.approve(signers[1].address, amount);

            const allowance = await maxx.allowance(
                deployer.address,
                signers[1].address
            );
            expect(allowance).to.eq(amount);

            log.yellow('allowance: ' + allowance.toString());
            log.yellow('amount: ' + amount.toString());

            const deployerBalanceBefore = await maxx.balanceOf(
                deployer.address
            );
            const signer3BalanceBefore = await maxx.balanceOf(
                signers[3].address
            );
            await maxx
                .connect(signers[1])
                .transferFrom(deployer.address, signers[3].address, amount);
            const deployerBalanceAfter = await maxx.balanceOf(deployer.address);
            const signer3BalanceAfter = await maxx.balanceOf(
                signers[3].address
            );

            const deployerBalanceDifference =
                deployerBalanceBefore.sub(deployerBalanceAfter);
            const signer3BalanceDifference =
                signer3BalanceAfter.sub(signer3BalanceBefore);
            expect(deployerBalanceDifference).to.eq(amount);
            expect(signer3BalanceDifference).to.eq(amount);
        });
        it("should not transfer more tokens than user's balance", async () => {
            const to = signers[3].address;
            let amount = ethers.utils.parseEther('1');
            await maxx.transfer(to, amount);

            amount = (await maxx.balanceOf(to)).add(1); // more than user's balance

            await expect(
                maxx.connect(signers[3]).transfer(deployer.address, amount)
            ).to.be.revertedWith('ERC20: transfer amount exceeds balance');
        });
        it('should transfer the token allocation to the liquidity amplifier', async () => {
            const LiquidityAmplifier = (await ethers.getContractFactory(
                'LiquidityAmplifier'
            )) as LiquidityAmplifier__factory;
            const timestamp = (await time.latest()) + 1;
            const liquidityAmplifier = await LiquidityAmplifier.deploy(
                signers[0].address,
                timestamp,
                maxx.address
            );
            const to = liquidityAmplifier.address;
            const amount = ethers.utils.parseEther('100');
            const balanceBefore = await maxx.balanceOf(to);
            await maxx.transfer(to, amount);
            const balanceAfter = await maxx.balanceOf(to);
            const balanceDifference = balanceAfter.sub(balanceBefore);
            expect(balanceDifference).to.eq(amount);
        });
    });

    describe('burn', () => {
        it('should burn tokens from msg.sender', async () => {
            const amount = ethers.utils.parseEther('100');
            const balanceBefore = await maxx.balanceOf(deployer.address);
            await maxx.burn(amount);
            const balanceAfter = await maxx.balanceOf(deployer.address);
            const balanceDifference = balanceBefore.sub(balanceAfter);
            expect(balanceDifference).to.eq(amount);
        });
        it('should burn tokens from an authorized wallet', async () => {
            const amount = ethers.utils.parseEther('100');
            await maxx.approve(signers[1].address, amount);

            const deployerBalanceBefore = await maxx.balanceOf(
                deployer.address
            );
            await maxx.connect(signers[1]).burnFrom(deployer.address, amount);
            const deployerBalanceAfter = await maxx.balanceOf(deployer.address);
            const deployerBalanceDifference =
                deployerBalanceBefore.sub(deployerBalanceAfter);
            expect(deployerBalanceDifference).to.eq(amount);
        });
        it('should update burnedAmount', async () => {
            const amount = ethers.utils.parseEther('100');
            const burnedAmountBefore = await maxx.burnedAmount();
            await maxx.burn(amount);
            const burnedAmountAfter = await maxx.burnedAmount();
            const burnedAmount = burnedAmountAfter.sub(burnedAmountBefore);
            expect(burnedAmount).to.eq(amount);
        });
        it("should not burn more tokens than user's balance", async () => {
            const to = signers[3].address;
            let amount = ethers.utils.parseEther('1');
            await maxx.transfer(to, amount);

            amount = (await maxx.balanceOf(to)).add(1); // more than user's balance

            await expect(
                maxx.connect(signers[3]).burn(amount)
            ).to.be.revertedWith('ERC20: burn amount exceeds balance');
        });
        it('should decrease totalSupply', async () => {
            const amount = ethers.utils.parseEther('100');
            const totalSupplyBefore = await maxx.totalSupply();
            await maxx.burn(amount);
            const totalSupplyAfter = await maxx.totalSupply();
            const totalSupplyDifference =
                totalSupplyBefore.sub(totalSupplyAfter);
            expect(totalSupplyDifference).to.eq(amount);
        });
    });

    describe('mint', () => {
        it('should mint tokens', async () => {
            const minterRole = await maxx.MINTER_ROLE();
            await maxx.grantRole(minterRole, deployer.address);
            const amount = ethers.utils.parseEther('100');
            const balanceBefore = await maxx.balanceOf(deployer.address);
            await maxx.mint(deployer.address, amount);
            const balanceAfter = await maxx.balanceOf(deployer.address);
            const balanceDifference = balanceAfter.sub(balanceBefore);
            expect(balanceDifference).to.eq(amount);
        });
        it('should not mint tokens without minter role', async () => {
            const amount = ethers.utils.parseEther('100');
            await expect(
                maxx.connect(signers[2]).mint(deployer.address, amount)
            ).to.be.revertedWith(
                'AccessControl: account 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc is missing role 0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6'
            );
        });
        it('should increase totalSupply', async () => {
            const minterRole = await maxx.MINTER_ROLE();
            await maxx.grantRole(minterRole, deployer.address);
            const amount = ethers.utils.parseEther('100');
            const totalSupplyBefore = await maxx.totalSupply();
            await maxx.mint(deployer.address, amount);
            const totalSupplyAfter = await maxx.totalSupply();
            const totalSupplyDifference =
                totalSupplyAfter.sub(totalSupplyBefore);
            expect(totalSupplyDifference).to.eq(amount);
        });
    });

    describe('bot protection', () => {
        it('should not allow transfers when the contract is paused', async () => {
            await maxx.pause();
            const to = signers[1].address;
            const amount = ethers.utils.parseEther('100');
            await expect(maxx.transfer(to, amount)).to.be.revertedWith(
                'Pausable: paused'
            );
        });
        it('should allow transfers when the contract is unpaused', async () => {
            await maxx.unpause();
            const to = signers[1].address;
            const amount = ethers.utils.parseEther('100');
            await expect(maxx.transfer(to, amount)).to.be.not.reverted;
        });
        describe('allowlist/blocklist', () => {
            it('should block addresses that attempt to buy and sell in consecutive blocks', async () => {
                await maxx.updateBlockLimited(true);
                expect(await maxx.isBlockLimited()).to.eq(true);
                await maxx.setBlocksBetweenTransfers(5);
                expect(await maxx.blocksBetweenTransfers()).to.eq(5);
                const to = signers[1].address;
                await maxx.addPool(to);
                const amount = ethers.utils.parseEther('100');
                await maxx.transfer(to, amount);

                // buy tokens (transfer from pool)
                const buyAmount = ethers.utils.parseEther('10');
                await maxx
                    .connect(signers[1])
                    .transfer(signers[0].address, buyAmount);

                // sell tokens (transfer to pool)
                const sellAmount = ethers.utils.parseEther('5');
                const amountBefore0 = await maxx.balanceOf(signers[0].address);
                const amountBefore1 = await maxx.balanceOf(signers[1].address);
                const transferSuccess = await maxx
                    .connect(signers[0])
                    .transfer(signers[1].address, sellAmount);
                const amountAfter0 = await maxx.balanceOf(signers[0].address);
                const amountAfter1 = await maxx.balanceOf(signers[1].address);
                expect(amountAfter0).to.eq(amountBefore0);
                expect(amountAfter1).to.eq(amountBefore1);
            });
            it('should transfer tokens for allowlist addresses', async () => {
                await maxx.allow(signers[0].address);
                expect(await maxx.isAllowed(signers[0].address)).to.eq(true);
                await maxx.allow(signers[1].address);
                expect(await maxx.isAllowed(signers[1].address)).to.eq(true);
                const to = signers[1].address;
                await maxx.addPool(to);
                const amount = ethers.utils.parseEther('100');
                let blocked = await maxx.isBlocked(to);
                log.yellow('blocked:', blocked);
                await maxx.transfer(to, amount);

                blocked = await maxx.isBlocked(to);
                log.yellow('blocked:', blocked);

                // buy tokens (transfer from pool)
                const buyAmount = ethers.utils.parseEther('10');
                await maxx
                    .connect(signers[1])
                    .transfer(signers[0].address, buyAmount);

                blocked = await maxx.isBlocked(to);
                log.yellow('blocked:', blocked);

                // sell tokens (transfer to pool)
                const sellAmount = ethers.utils.parseEther('5');
                await expect(
                    maxx
                        .connect(signers[0])
                        .transfer(signers[1].address, sellAmount)
                ).to.be.not.reverted;
            });
        });
        describe('Sell Limits', () => {
            it('should allow transfers to LP greater than the whale limit', async () => {
                const to = signers[8].address;
                await maxx.addPool(to);
                const amount = (await maxx.whaleLimit()).add(1);
                await maxx.disallow(to);
                const balanceBefore = await maxx.balanceOf(to);
                await expect(maxx.transfer(to, amount)).to.not.be.reverted;
                const balanceAfter = await maxx.balanceOf(to);
                const balanceDifference = balanceAfter.sub(balanceBefore);
                expect(amount).to.be.gt(balanceDifference);
            });
            it('should allow transfers to LP greater than the global daily sell limit', async () => {
                await maxx.setGlobalDailySellLimit(1000000000); // 1 billion
                await maxx.setWhaleLimit(1000000001); // 1 billion + 1 -> more than the daily sell limit
                const to = signers[8].address;
                await maxx.addPool(to);
                const dailySellLimit = await maxx.globalDailySellLimit();
                const day = await maxx.getCurrentDay();
                const dailyAmountSold = await maxx.dailyAmountSold(day);
                const amount = dailySellLimit.sub(dailyAmountSold);
                // less than the global daily sell limit
                await maxx.transfer(to, amount);

                log.yellow('after first transfer');

                const balanceBefore = await maxx.balanceOf(to);

                // amount exceeds the global daily sell limit
                await expect(maxx.transfer(to, dailySellLimit)).to.not.be
                    .reverted;
                const balanceAfter = await maxx.balanceOf(to);
                const balanceDifference = balanceAfter.sub(balanceBefore);
                expect(balanceDifference).to.be.lt(dailySellLimit);
            });
        });
    });
});
