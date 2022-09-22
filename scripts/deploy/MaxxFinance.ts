import hre, { ethers } from 'hardhat';
import { BigNumber } from 'ethers';
import { MaxxFinance__factory } from '../../typechain-types';
import { Deployment } from '../utils/contractDeploy';

export async function deployMaxxFinance(): Promise<Deployment> {
    const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
    const transferTax = BigNumber.from(process.env.TRANSFER_TAX!);
    const whaleLimit = BigNumber.from(process.env.WHALE_LIMIT!);
    const globalSellLimit = BigNumber.from(process.env.GLOBAL_SELL_LIMIT!);

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = await MaxxFinance.deploy(
        maxxVaultAddress,
        transferTax,
        whaleLimit,
        globalSellLimit
    );
    await maxxFinance.deployed();

    const blocksBetweenTransfers = await maxxFinance.setBlocksBetweenTransfers(
        2
    );
    await blocksBetweenTransfers.wait();

    const blockLimited = await maxxFinance.updateBlockLimited(true);
    await blockLimited.wait();

    const allowVault = await maxxFinance.allow(maxxVaultAddress);
    await allowVault.wait();

    const omegaAddress = process.env.OMEGA_ADDRESS!;
    const omegaAmount = ethers.utils.parseEther('15000000000'); // 15 billion

    const transferOmega = await maxxFinance.transfer(omegaAddress, omegaAmount);
    await transferOmega.wait();

    const omegaAddress2 = process.env.OMEGA_ADDRESS2!;
    const omegaAmount2 = ethers.utils.parseEther('150000000'); // 150 million

    const transferOmega2 = await maxxFinance.transfer(
        omegaAddress2,
        omegaAmount2
    );
    await transferOmega2.wait();

    const network = hre.network.name;
    if (network === 'polygon') {
        try {
            await hre.run('verify:verify', {
                address: maxxFinance.address,
                constructorArguments: [
                    maxxVaultAddress,
                    transferTax,
                    whaleLimit,
                    globalSellLimit,
                ],
            });
        } catch (e) {
            console.error(e);
        }
    }

    return {
        address: maxxFinance.address,
        block: maxxFinance.deployTransaction.blockNumber!,
    };
}

// deployMaxxFinance().catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
