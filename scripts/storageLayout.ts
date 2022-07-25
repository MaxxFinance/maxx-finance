import hre from "hardhat";

const CONTRACT_NAME = "LiquidityAmplifier";

async function main() {
  await hre.storageLayout.export();

  const contractFactory = await hre.ethers.getContractFactory(CONTRACT_NAME);
  const contract = await contractFactory.deploy();

  await contract.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
