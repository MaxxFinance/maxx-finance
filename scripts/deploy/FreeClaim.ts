import hre, { ethers } from "hardhat";
import {
  FreeClaim,
  FreeClaim__factory,
  MaxxFinance,
  MaxxFinance__factory,
  MaxxStake,
  MaxxStake__factory,
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
    "FreeClaim"
  )) as FreeClaim__factory;
  const MaxxFinance = (await ethers.getContractFactory(
    "MaxxFinance"
  )) as MaxxFinance__factory;
  const MaxxStake = (await ethers.getContractFactory(
    "MaxxStake"
  )) as MaxxStake__factory;

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
