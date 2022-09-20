import hre, { ethers } from 'hardhat';
import { MaxxFinance__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = MaxxFinance.attach(process.env.MAXX_FINANCE_ADDRESS!);

    const amount = ethers.utils.parseEther('100000000'); // 1 million

    const to = '0xE84cbfd748FF3a24C0cD8A50eC147f971805bE67'; // Jordan

    const transfer = await maxxFinance.transfer(to, amount);
    await transfer.wait();
    log.yellow('transfer: ', transfer.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
