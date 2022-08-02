import hre, { ethers } from "hardhat";
import { MaxxStake__factory } from "../../typechain-types";
import log from "ololog";

async function main() {
  const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
  const maxxFinanceAddress = process.env.MAXX_FINANCE_ADDRESS!;
  const stakeLaunchDate = "1659420000"; // Tue Aug 02 2022 06:00:00 GMT+0000

  const MaxxStake = (await ethers.getContractFactory(
    "MaxxStake"
  )) as MaxxStake__factory;

  const maxxStake = await MaxxStake.deploy(
    maxxVaultAddress,
    maxxFinanceAddress,
    stakeLaunchDate
  );
  log.yellow("maxxStake.address: ", maxxStake.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
