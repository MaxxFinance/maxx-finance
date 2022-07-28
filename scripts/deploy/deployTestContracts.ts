import hre, { ethers } from "hardhat";
import {
  FreeClaimTest,
  FreeClaimTest__factory,
  LiquidityAmplifierTest,
  LiquidityAmplifierTest__factory,
  MarketplaceTest,
  MarketplaceTest__factory,
  MaxxFinanceTest,
  MaxxFinanceTest__factory,
  MaxxStakeTest,
  MaxxStakeTest__factory,
} from "../../typechain-types";
import log from "ololog";

async function main() {
  const maxxVaultAddress = "";
  const transferTax = "500"; // 5%
  const whaleLimit = "1000000"; // 1 million
  const globalSellLimit = "1000000000"; // 1 billion
  const claimLaunchDate = "";
  const merkleRoot = "";
  const amplifierLaunchDate = "";
  const stakeLaunchDate = "";
  const maxxBoostAddress = "";
  const maxxGenesisAddress = "";

  const FreeClaim = (await ethers.getContractFactory(
    "FreeClaimTest"
  )) as FreeClaimTest__factory;
  const LiquidityAmplifier = (await ethers.getContractFactory(
    "LiquidityAmplifierTest"
  )) as LiquidityAmplifierTest__factory;
  const Marketplace = (await ethers.getContractFactory(
    "MarketplaceTest"
  )) as MarketplaceTest__factory;
  const MaxxFinance = (await ethers.getContractFactory(
    "MaxxFinanceTest"
  )) as MaxxFinanceTest__factory;
  const MaxxStake = (await ethers.getContractFactory(
    "MaxxStakeTest"
  )) as MaxxStakeTest__factory;

  const maxxFinance = await MaxxFinance.deploy(
    maxxVaultAddress,
    transferTax,
    whaleLimit,
    globalSellLimit
  );

  log.yellow("maxxFinance.address: ", maxxFinance.address);

  const freeClaim = await FreeClaim.deploy(
    claimLaunchDate,
    merkleRoot,
    maxxFinance.address
  );

  log.yellow("freeClaim.address: ", freeClaim.address);

  const liquidityAmplifier = await LiquidityAmplifier.deploy(
    maxxVaultAddress,
    amplifierLaunchDate,
    maxxFinance.address
  );
  log.yellow("liquidityAmplifier.address: ", liquidityAmplifier.address);

  const maxxStake = await MaxxStake.deploy(
    maxxVaultAddress,
    maxxFinance.address,
    stakeLaunchDate,
    maxxBoostAddress,
    maxxGenesisAddress
  );
  log.yellow("maxxStake.address: ", maxxStake.address);

  const marketplace = await Marketplace.deploy(maxxStake.address);
  log.yellow("marketplace.address: ", marketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
