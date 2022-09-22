import hre, { ethers } from 'hardhat';

import { deployFreeClaim } from './FreeClaim';
import { deployMaxxFinance } from './MaxxFinance';
import { deployMaxxStake } from './MaxxStake';
import { deployLiquidityAmplifier } from './LiquidityAmplifier';
import { deployMaxxBoost } from './MAXXBoost';
import { deployMaxxGenesis } from './MAXXGenesis';
import { deployMarketplace } from './Marketplace';

import { Deployment } from '../utils/contractDeploy';

export interface ContractDeployments {
    maxx: Deployment;
    stake: Deployment;
    freeClaim: Deployment;
    amplifier: Deployment;
    maxxBoost: Deployment;
    maxxGenesis: Deployment;
}

export async function deployAll(): Promise<ContractDeployments> {
    const network = hre.network.name;

    let stakeLaunchDate: string,
        freeClaimStartDate: string,
        amplifierLaunchDate: string;
    switch (network) {
        case 'mumbai':
            const blockNumBefore = await ethers.provider.getBlockNumber();
            const blockBefore = await ethers.provider.getBlock(blockNumBefore);
            const timestampBefore = blockBefore.timestamp;
            stakeLaunchDate = (timestampBefore + 1).toString();
            freeClaimStartDate = (timestampBefore + 2).toString();
            amplifierLaunchDate = (timestampBefore + 3).toString();
            break;
        default:
            stakeLaunchDate = process.env.STAKE_LAUNCH_DATE!;
            freeClaimStartDate = process.env.FREE_CLAIM_START_DATE!;
            amplifierLaunchDate = process.env.AMPLIFIER_LAUNCH_DATE!;
            break;
    }

    const maxx = await deployMaxxFinance();
    const stake = await deployMaxxStake(maxx.address, stakeLaunchDate);
    const freeClaim = await deployFreeClaim(maxx.address, freeClaimStartDate);
    const amplifier = await deployLiquidityAmplifier(
        maxx.address,
        amplifierLaunchDate
    );
    const maxxBoost = await deployMaxxBoost(amplifier.address, stake.address);
    const maxxGenesis = await deployMaxxGenesis(amplifier.address);

    return {
        maxx,
        stake,
        freeClaim,
        amplifier,
        maxxBoost,
        maxxGenesis,
    };
}

// deployAll().catch((error) => {
//     console.error(error);
//     process.exitCode = 1;
// });
