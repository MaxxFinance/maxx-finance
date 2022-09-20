import { ethers } from 'hardhat';
import {
    FreeClaim__factory,
    MaxxFinance__factory,
    MaxxStake__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const signers = await ethers.getSigners();
    const signer = signers[0];
    const freeClaimAddress = process.env.FREE_CLAIM_ADDRESS!;
    log.magenta('freeClaimAddress: ', freeClaimAddress);
    const maxxStakeAddress = process.env.MAXX_STAKE_ADDRESS!;
    log.magenta('maxxStakeAddress: ', maxxStakeAddress);
    const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
    log.magenta('maxxFinanceAddress: ', maxxFinanceAddress);
    const merkleRoot =
        '0xe6415e7304a8dc76e9415eca8345e3f1602ce4a67cdbc311450589b62f8c485c';

    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;

    const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);
    const totalClaimAmount = ethers.utils.parseEther('100000000'); // 100 million

    const approve = await maxxFinance.approve(
        freeClaimAddress,
        totalClaimAmount
    );
    await approve.wait();
    log.green('approve: ', approve.hash);

    const allowSigner = await maxxFinance.allow(signer.address);
    await allowSigner.wait();
    log.yellow('allowSigner: ', allowSigner.hash);

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;

    const freeClaim = FreeClaim.attach(freeClaimAddress);

    const setRoot = await freeClaim.setMerkleRoot(merkleRoot);
    await setRoot.wait();
    log.green('setRoot: ', setRoot.hash);

    const allowance = await maxxFinance.allowance(
        signer.address,
        freeClaimAddress
    );
    log.yellow('allowance: ', allowance.toString());
    log.yellow('totalClaimAmount: ', totalClaimAmount.toString());

    if (allowance.gte(totalClaimAmount)) {
        const senderBalance = await maxxFinance.balanceOf(signer.address);
        log.cyan('sender balance:', senderBalance.toString());
        const allocateMaxx = await freeClaim.allocateMaxx(totalClaimAmount, {
            gasLimit: 1_000_000,
        });
        await allocateMaxx.wait();
        log.green('allocateMaxx: ', allocateMaxx.hash);
        const newBalance = await maxxFinance.balanceOf(freeClaim.address);
        log.yellow('newBalance: ', newBalance.toString());
    } else {
        log.red('Allowance is not enough');
    }

    // const setMaxxStake = await freeClaim.setMaxxStake(maxxStakeAddress);
    // await setMaxxStake.wait();
    // log.green('setMaxxStake: ', setMaxxStake.hash);

    const allow = await maxxFinance.allow(freeClaimAddress);
    await allow.wait();
    log.yellow('allow: ', allow.hash);

    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;

    const maxxStake = MaxxStake.attach(maxxStakeAddress);
    const stakeFreeClaimAddress = await maxxStake.setFreeClaim(
        freeClaimAddress
    );
    await stakeFreeClaimAddress.wait();
    log.green('stakeFreeClaimAddress: ', stakeFreeClaimAddress.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
