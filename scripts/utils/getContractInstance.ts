import { ethers } from 'hardhat';
import {
    MaxxFinance__factory,
    MaxxStake__factory,
    FreeClaim__factory,
    LiquidityAmplifier__factory,
    MAXXBoost__factory,
    MAXXGenesis__factory,
} from '../../typechain-types';
import {
    MaxxFinance,
    MaxxStake,
    FreeClaim,
    LiquidityAmplifier,
    MAXXBoost,
    MAXXGenesis,
} from '../../typechain-types';

import { ContractDeployments } from '../deploy/deployAll';

export interface Contracts {
    maxx: MaxxFinance;
    stake: MaxxStake;
    freeClaim: FreeClaim;
    amplifier: LiquidityAmplifier;
    maxxBoost: MAXXBoost;
    maxxGenesis: MAXXGenesis;
}

export async function getMaxxFinance(
    maxxFinanceAddress: string
): Promise<MaxxFinance> {
    const MaxxFinance = (await ethers.getContractFactory(
        'MaxxFinance'
    )) as MaxxFinance__factory;
    const maxxFinance = MaxxFinance.attach(maxxFinanceAddress);

    return maxxFinance;
}

export async function getMaxxStake(
    maxxStakeAddress: string
): Promise<MaxxStake> {
    const MaxxStake = (await ethers.getContractFactory(
        'MaxxStake'
    )) as MaxxStake__factory;
    const maxxStake = MaxxStake.attach(maxxStakeAddress);

    return maxxStake;
}

export async function getFreeClaim(
    freeClaimAddress: string
): Promise<FreeClaim> {
    const FreeClaim = (await ethers.getContractFactory(
        'FreeClaim'
    )) as FreeClaim__factory;
    const freeClaim = FreeClaim.attach(freeClaimAddress);

    return freeClaim;
}

export async function getLiquidityAmplifier(
    liquidityAmplifierAddress: string
): Promise<LiquidityAmplifier> {
    const LiquidityAmplifier = (await ethers.getContractFactory(
        'LiquidityAmplifier'
    )) as LiquidityAmplifier__factory;
    const liquidityAmplifier = LiquidityAmplifier.attach(
        liquidityAmplifierAddress
    );

    return liquidityAmplifier;
}

export async function getMAXXBoost(
    MAXXBoostAddress: string
): Promise<MAXXBoost> {
    const MAXXBoost = (await ethers.getContractFactory(
        'MAXXBoost'
    )) as MAXXBoost__factory;
    const MAXXBoostContract = MAXXBoost.attach(MAXXBoostAddress);

    return MAXXBoostContract;
}

export async function getMAXXGenesis(
    MAXXGenesisAddress: string
): Promise<MAXXGenesis> {
    const MAXXGenesis = (await ethers.getContractFactory(
        'MAXXGenesis'
    )) as MAXXGenesis__factory;
    const MAXXGenesisContract = MAXXGenesis.attach(MAXXGenesisAddress);

    return MAXXGenesisContract;
}

export async function getAllContracts(
    deployedContracts: ContractDeployments
): Promise<Contracts> {
    const contracts = {
        maxx: await getMaxxFinance(deployedContracts.maxx.address),
        stake: await getMaxxStake(deployedContracts.stake.address),
        freeClaim: await getFreeClaim(deployedContracts.freeClaim.address),
        amplifier: await getLiquidityAmplifier(
            deployedContracts.amplifier.address
        ),
        maxxBoost: await getMAXXBoost(deployedContracts.maxxBoost.address),
        maxxGenesis: await getMAXXGenesis(
            deployedContracts.maxxGenesis.address
        ),
    };

    return contracts;
}

export async function getAllContracts2(
    maxxFinanceAddress: string,
    maxxStakeAddress: string,
    liquidityAmplifierAddress: string,
    freeClaimAddress: string,
    maxxBoostAddress: string,
    maxxGenesisAddress: string
): Promise<Contracts> {
    const contracts = {
        maxx: await getMaxxFinance(maxxFinanceAddress),
        stake: await getMaxxStake(maxxStakeAddress),
        freeClaim: await getFreeClaim(freeClaimAddress),
        amplifier: await getLiquidityAmplifier(liquidityAmplifierAddress),
        maxxBoost: await getMAXXBoost(maxxBoostAddress),
        maxxGenesis: await getMAXXGenesis(maxxGenesisAddress),
    };

    return contracts;
}
