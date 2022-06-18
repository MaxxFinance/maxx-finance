import { expect } from "chai";
import { ethers } from "hardhat";
import { utils } from "ethers";
import log from "ololog";

import { bytecode as ampliferBytecode } from "../artifacts/contracts/Amplifier.sol/LiquidityAmplifier.json";
import { bytecode as maxxBytecode } from "../artifacts/contracts/MaxxFinance.sol/MaxxFinance.json";
import { bytecode as maxxTestBytecode } from "../artifacts/contracts/MaxxFinanceTest.sol/MaxxFinanceTest.json";
import { bytecode as stakeBytecode } from "../artifacts/contracts/Stake.sol/MaxxStake.json";
import { bytecode as freeClaimBytecode } from "../artifacts/contracts/FreeClaim.sol/FreeClaim.json";

import { Deployer } from "../typechain/Deployer";
import { Deployer__factory } from "../typechain/factories/Deployer__factory";

function numberToUint256(value: any) {
  const hex = value.toString(16);
  return `0x${"0".repeat(64 - hex.length)}${hex}`;
}
function encodeParam(dataType: any, data: any) {
  const abiCoder = ethers.utils.defaultAbiCoder;
  return abiCoder.encode(dataType, data);
}

describe("Deployer", () => {
  let Deployer: Deployer__factory;
  let deployer: Deployer;

  before(async () => {
    Deployer = (await ethers.getContractFactory(
      "Deployer"
    )) as Deployer__factory;
    deployer = await Deployer.deploy();
  });

  describe("deploy -- self", () => {
    it("should be deployed", async () => {
      expect(deployer.address).to.exist;
    });
  });

  describe("deploy", () => {
    it("should deploy MaxxFinance.sol", async () => {
      const signers = await ethers.getSigners();
      const owner = signers[0];
      const constructorArgs = [owner.address];
      const constructorTypes = ["address"];
      const salt = 0;
      const constructor = encodeParam(constructorTypes, constructorArgs).slice(
        2
      );
      const bytecode = `${maxxBytecode}${constructor}`;
      const x = utils.keccak256(
        `0x${[
          "ff",
          deployer.address,
          numberToUint256(salt),
          ethers.utils.keccak256(bytecode),
        ]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      );

      const address = `0x${x.slice(-40)}`.toLowerCase();
      log.yellow("MaxxFinance.sol address:", address);
      expect(await deployer.deploy(bytecode, numberToUint256(salt)))
        .to.emit(deployer, "Deployed")
        .withArgs(address, salt);
    });

    it("should deploy MaxxFinanceTest.sol", async () => {
      const signers = await ethers.getSigners();
      const owner = signers[0];
      const constructorArgs = [owner.address];
      const constructorTypes = ["address"];
      const salt = 0;
      const constructor = encodeParam(constructorTypes, constructorArgs).slice(
        2
      );
      const bytecode = `${maxxTestBytecode}${constructor}`;
      const x = utils.keccak256(
        `0x${[
          "ff",
          deployer.address,
          numberToUint256(salt),
          ethers.utils.keccak256(bytecode),
        ]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      );

      const address = `0x${x.slice(-40)}`.toLowerCase();
      log.yellow("MaxxFinanceTest.sol address:", address);
      expect(await deployer.deploy(bytecode, numberToUint256(salt)))
        .to.emit(deployer, "Deployed")
        .withArgs(address, salt);
    });

    it("should deploy FreeClaim.sol", async () => {
      const constructorArgs = [
        ethers.utils.formatBytes32String("merkleRoot"),
        "10",
      ];
      const constructorTypes = ["bytes32", "uint256"];
      const salt = 0;
      const constructor = encodeParam(constructorTypes, constructorArgs).slice(
        2
      );
      const bytecode = `${freeClaimBytecode}${constructor}`;
      const x = utils.keccak256(
        `0x${[
          "ff",
          deployer.address,
          numberToUint256(salt),
          ethers.utils.keccak256(bytecode),
        ]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      );

      const address = `0x${x.slice(-40)}`.toLowerCase();
      log.yellow("FreeClaim.sol address:", address);
      expect(await deployer.deploy(bytecode, numberToUint256(salt)))
        .to.emit(deployer, "Deployed")
        .withArgs(address, salt);
    });

    it("should deploy Amplifier.sol", async () => {
      const constructorArgs = [
        "16422342",
        "0x0000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000",
      ];
      const constructorTypes = ["uint256", "address", "address"];
      const constructor = encodeParam(constructorTypes, constructorArgs).slice(
        2
      );
      const bytecode = `${ampliferBytecode}${constructor}`;
      const salt = 0;
      const x = utils.keccak256(
        `0x${[
          "ff",
          deployer.address,
          numberToUint256(salt),
          ethers.utils.keccak256(bytecode),
        ]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      );

      const address = `0x${x.slice(-40)}`.toLowerCase();
      log.yellow("Amplifier.sol address:", address);
      expect(await deployer.deploy(bytecode, numberToUint256(salt)))
        .to.emit(deployer, "Deployed")
        .withArgs(address, salt);
    });

    it("should deploy Stake.sol", async () => {
      const constructorArgs = [
        "0x0000000000000000000000000000000000000000",
        "16000000",
      ];
      const constructorTypes = ["address", "uint256"];
      const constructor = encodeParam(constructorTypes, constructorArgs).slice(
        2
      );
      const bytecode = `${stakeBytecode}${constructor}`;
      const salt = 0;
      const x = utils.keccak256(
        `0x${[
          "ff",
          deployer.address,
          numberToUint256(salt),
          ethers.utils.keccak256(bytecode),
        ]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      );

      const address = `0x${x.slice(-40)}`.toLowerCase();
      log.yellow("Stake.sol address:", address);
      expect(await deployer.deploy(bytecode, numberToUint256(salt)))
        .to.emit(deployer, "Deployed")
        .withArgs(address, salt);
    });
  });
});
