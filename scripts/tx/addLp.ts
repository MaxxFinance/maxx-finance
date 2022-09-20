import hre, { ethers } from 'hardhat';
import { MaxxFinance__factory } from '../../typechain-types';
import log from 'ololog';

async function main() {
    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = MaxxFinance.attach(process.env.MAXX_FINANCE_ADDRESS!);

    const pool = '0xaB5F3E7C3347b6e5C06dcb29b19f45E3232F90b0';

    const addPool = await maxxFinance.addPool(pool);
    await addPool.wait();
    log.yellow('addPool: ', addPool.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
