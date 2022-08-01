import hre, { ethers } from "hardhat";
import { MaxxFinance__factory } from "../../typechain-types";
import log from "ololog";

async function main() {
  const maxxVaultAddress = process.env.MAXX_VAULT_ADDRESS!;
  const transferTax = "500"; // 5%
  const whaleLimit = "1000000"; // 1 million
  const globalSellLimit = "1000000000"; // 1 billion

  const MaxxFinance = (await ethers.getContractFactory(
    "MaxxFinance"
  )) as MaxxFinance__factory;

  const maxxFinance = await MaxxFinance.deploy(
    maxxVaultAddress,
    transferTax,
    whaleLimit,
    globalSellLimit
  );

  log.yellow("maxxFinance.address: ", maxxFinance.address);

  const blocksBetweenTransfers = await maxxFinance.setBlocksBetweenTransfers(2);
  await blocksBetweenTransfers.wait();
  log.yellow("blocksBetweenTransfers: ", blocksBetweenTransfers.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
