import hre, { ethers } from 'hardhat';
import {
    FreeClaimTest__factory,
    LiquidityAmplifierTest__factory,
    MarketplaceTest__factory,
    MaxxFinanceTest__factory,
    MaxxStakeTest__factory,
    MAXXBoost__factory,
    MAXXGenesis__factory,
} from '../../typechain-types';
import log from 'ololog';

async function main() {
    const maxxVaultAddress = '0xDb0EAe4c4DDb75413d85B62B8391bFde75702B5a'; // mumbai only
    const transferTax = '500'; // 5%
    const whaleLimit = '1000000'; // 1 million
    const globalSellLimit = '1000000000'; // 1 billion
    const claimLaunchDate = '1666159200'; // 2022-10-19 00:00:00 UTC
    const merkleRoot =
        '0x9df1065c6764f376fb54b262ba6e60af3f1b500ccf55d87a8c11f7dc748dbcf6';
    const amplifierLaunchDate = '1666764000'; // 2022-10-26 00:00:00 UTC
    const stakeLaunchDate = '1667368800'; // 2022-11-2 00:00:00 UTC

    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaimTest'
    )) as FreeClaimTest__factory;
    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifierTest'
    )) as LiquidityAmplifierTest__factory;
    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinanceTest'
    )) as MaxxFinanceTest__factory;
    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStakeTest'
    )) as MaxxStakeTest__factory;
    const MAXXBoost = (await ethers.getContractFactory(
        'MAXXBoost'
    )) as MAXXBoost__factory;
    const MAXXGenesis = (await ethers.getContractFactory(
        'MAXXGenesis'
    )) as MAXXGenesis__factory;
    const maxxFinance = await MaxxFinance.deploy();
    await maxxFinance.deployed();
    log.yellow('maxxFinance.address: ', maxxFinance.address);

    const initMaxx = await maxxFinance.init(
        maxxVaultAddress,
        transferTax,
        whaleLimit,
        globalSellLimit
    );
    await initMaxx.wait();
    log.yellow('initMaxx: ', initMaxx.hash);

    const freeClaim = await FreeClaim.deploy();
    await freeClaim.deployed();
    log.yellow('freeClaim.address: ', freeClaim.address);

    let updateLaunchDate = await freeClaim.updateLaunchDate(claimLaunchDate);
    await updateLaunchDate.wait();
    log.yellow('updateLaunchDate: ', updateLaunchDate.hash);

    let setMerkleRoot = await freeClaim.setMerkleRoot(merkleRoot);
    await setMerkleRoot.wait();
    log.yellow('setMerkleRoot: ', setMerkleRoot.hash);

    let setMaxx = await freeClaim.setMaxx(maxxFinance.address);
    await setMaxx.wait();
    log.yellow('setMaxx: ', setMaxx.hash);

    // let freeClaimMaxxAllocation = ethers.utils.parseEther('2000000000'); // 2 billion
    // let allocateMaxxFreeClaim = await freeClaim.allocateMaxx(
    //     freeClaimMaxxAllocation
    // );

    const liquidityAmplifier = await LiquidityAmplifier.deploy();
    await liquidityAmplifier.deployed();
    log.yellow('liquidityAmplifier.address: ', liquidityAmplifier.address);

    const initAmplifier = await liquidityAmplifier.init(
        maxxVaultAddress,
        amplifierLaunchDate,
        maxxFinance.address
    );
    await initAmplifier.wait();
    log.yellow('initAmplifier: ', initAmplifier.hash);

    const maxxStake = await MaxxStake.deploy(
        maxxVaultAddress,
        maxxFinance.address,
        stakeLaunchDate
    );
    await maxxStake.deployed();
    log.yellow('maxxStake.address: ', maxxStake.address);

    const maxxBoost = await MAXXBoost.deploy(
        liquidityAmplifier.address,
        maxxStake.address
    );
    await maxxBoost.deployed();
    log.yellow('maxxBoost.address: ', maxxBoost.address);

    const maxxGenesis = await MAXXGenesis.deploy(liquidityAmplifier.address);
    await maxxGenesis.deployed();
    log.yellow('maxxGenesis.address: ', maxxGenesis.address);

    let setStake = await liquidityAmplifier.setStakeAddress(maxxStake.address);
    await setStake.wait();
    log.yellow('setStake: ', setStake.hash);

    let setMaxxGenesis = await liquidityAmplifier.setMaxxGenesis(
        maxxGenesis.address
    );
    await setMaxxGenesis.wait();
    log.yellow('setMaxxGenesis: ', setMaxxGenesis.hash);

    let dailyAllocations = [
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('1000000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('420000000'),
        ethers.utils.parseEther('680000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('1500000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('400000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('500000000'),
        ethers.utils.parseEther('1000000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('900000000'),
        ethers.utils.parseEther('200000000'),
        ethers.utils.parseEther('700000000'),
        ethers.utils.parseEther('800000000'),
        ethers.utils.parseEther('900000000'),
        ethers.utils.parseEther('600000000'),
        ethers.utils.parseEther('800000000'),
    ];

    if (dailyAllocations.length === 60) {
        let setDailyAllocations = await liquidityAmplifier.setDailyAllocations(
            dailyAllocations
        );
    }

    let transfer = await liquidityAmplifier.transferOwnership(maxxVaultAddress);
    await transfer.wait();
    log.yellow('transfer: ', transfer.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
