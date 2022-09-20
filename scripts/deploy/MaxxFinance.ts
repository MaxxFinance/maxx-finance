import hre, { ethers } from 'hardhat';
import { MaxxFinance__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const transferTax = '500'; // 5%
    const whaleLimit = '1000000'; // 1 million
    const globalSellLimit = '1000000000'; // 1 billion

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = await MaxxFinance.deploy(
        maxxVaultAddress,
        transferTax,
        whaleLimit,
        globalSellLimit
    );

    // const maxxFinance = MaxxFinance.attach(process.env.MAXX_FINANCE_ADDRESS!);

    log.yellow('maxxFinance.address: ', maxxFinance.address);

    const blocksBetweenTransfers = await maxxFinance.setBlocksBetweenTransfers(
        2
    );
    await blocksBetweenTransfers.wait();
    log.yellow('blocksBetweenTransfers: ', blocksBetweenTransfers.hash);

    const blockLimited = await maxxFinance.updateBlockLimited(true);
    await blockLimited.wait();
    log.yellow('blockLimited: ', blockLimited.hash);

    const allowVault = await maxxFinance.allow(maxxVaultAddress);
    await allowVault.wait();
    log.yellow('allowVault: ', allowVault.hash);

    const omegaAddress = process.env.OMEGA_ADDRESS!;
    const omegaAmount = ethers.utils.parseEther('15000000000'); // 15 billion

    const transferOmega = await maxxFinance.transfer(omegaAddress, omegaAmount);
    await transferOmega.wait();
    log.yellow('transferOmega: ', transferOmega.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
